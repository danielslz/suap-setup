#!/usr/bin/env bash
set -u

# docker/minio-revert.sh - Reverte docker/minio-setup.sh
#
# Etapas:
#   1. Registra volumes e imagens dos containers do projeto suap-minio
#   2. Para e remove os containers (make down, ou make stop como fallback)
#   3. Volumes (dados do MinIO) e imagens: removidos somente com confirmação
#   4. Diretório SUAP_MINIO_DIR (clone do repositório + .env com credenciais):
#      removido somente com confirmação
# Suporta REVERT_DRY_RUN=1 e REVERT_ASSUME_YES=1.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

SUAP_MINIO_DIR="${SUAP_MINIO_DIR:-/opt/suap-minio}"
SUAP_MINIO_DIR=$(eval echo "${SUAP_MINIO_DIR}")

if [ ! -d "${SUAP_MINIO_DIR}" ]; then
  msg_skip "Diretório ${SUAP_MINIO_DIR} não existe. Nada a reverter."
  exit 0
fi

_dir_abs="$(cd "${SUAP_MINIO_DIR}" && pwd -P)"
_volumes=""
_images=""

if command -v docker &>/dev/null; then
  # 1. Registrar volumes/imagens dos containers do projeto (label do docker compose)
  _ids="$(docker ps -a -q --filter "label=com.docker.compose.project.working_dir=${_dir_abs}" 2>/dev/null || true)"
  for _id in ${_ids}; do
    _volumes+=" $(docker inspect -f '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}} {{end}}{{end}}' "${_id}" 2>/dev/null || true)"
    _images+=" $(docker inspect -f '{{.Config.Image}}' "${_id}" 2>/dev/null || true)"
  done
  _volumes="$(echo "${_volumes}" | tr ' ' '\n' | sed '/^$/d' | sort -u)"
  _images="$(echo "${_images}" | tr ' ' '\n' | sed '/^$/d' | sort -u)"

  # 2. Parar e remover containers
  if [ -n "${_ids}" ]; then
    if _dry; then
      echo "  ${YELLOW}[dry-run]${NO_COLOR} pararia e removeria os containers do projeto em ${_dir_abs}"
    elif [ -f "${_dir_abs}/Makefile" ] && command -v make &>/dev/null; then
      msg_action "Removendo containers do MinIO..."
      if make -C "${_dir_abs}" -n down &>/dev/null; then
        make -C "${_dir_abs}" down || msg_error "Falha em 'make down'."
      else
        make -C "${_dir_abs}" stop || msg_error "Falha em 'make stop'."
      fi
    fi
    # Garantir remoção mesmo que o Makefile apenas pare os containers
    if ! _dry; then
      # shellcheck disable=SC2086
      docker rm -f ${_ids} >/dev/null 2>&1 || true
    fi
  else
    msg_skip "Nenhum container do suap-minio encontrado."
  fi

  # 3. Volumes (dados) e imagens — destrutivo
  for _vol in ${_volumes}; do
    if confirm_destructive "APAGAR o volume Docker '${_vol}' (dados do MinIO, irreversível)"; then
      msg_action "Removendo volume ${_vol}..."
      docker volume rm "${_vol}" >/dev/null 2>&1 || msg_error "Falha ao remover o volume ${_vol}."
    else
      msg_skip "Volume ${_vol} preservado."
    fi
  done
  for _img in ${_images}; do
    if confirm_destructive "remover a imagem Docker '${_img}'"; then
      msg_action "Removendo imagem ${_img}..."
      docker rmi "${_img}" >/dev/null 2>&1 || msg_error "Não foi possível remover a imagem ${_img} (em uso por outro container?)."
    else
      msg_skip "Imagem ${_img} preservada."
    fi
  done
else
  msg_skip "Docker não encontrado. Pulando containers, volumes e imagens."
fi

# 4. Diretório do projeto (contém .env com credenciais e dados em bind mounts)
revert_dir "${_dir_abs}" --destructive

msg_action "Reversão do MinIO concluída."
