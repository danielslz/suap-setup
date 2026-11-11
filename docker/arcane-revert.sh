#!/usr/bin/env bash
set -u

# docker/arcane-revert.sh - Reverte docker/arcane-setup.sh
# Remove o container "arcane". O volume arcane-data (banco do Arcane), a imagem e
# a chave de criptografia guardada só são removidos com confirmação (a chave é
# preservada enquanto o volume existir). A pasta de projetos Compose NUNCA é
# apagada: ela pode conter stacks de outras aplicações.
# Suporta REVERT_DRY_RUN=1 e REVERT_ASSUME_YES=1.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

CONTAINER_NAME="arcane"
VOLUME_NAME="arcane-data"
IMAGE_NAME="${ARCANE_IMAGE:-ghcr.io/getarcaneapp/manager:latest}"
PROJECTS_DIR="${ARCANE_PROJECTS_DIR:-/opt/docker}"

if command -v docker &>/dev/null; then
  if docker ps -a --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    if _dry; then
      echo "  ${YELLOW}[dry-run]${NO_COLOR} removeria o container ${CONTAINER_NAME}"
    else
      msg_action "Removendo container ${CONTAINER_NAME}..."
      docker rm -f "${CONTAINER_NAME}" >/dev/null || { msg_error "Falha ao remover ${CONTAINER_NAME}."; exit 1; }
    fi
  else
    msg_skip "Container ${CONTAINER_NAME} não existe."
  fi

  if docker volume ls --format '{{.Name}}' | grep -q "^${VOLUME_NAME}$"; then
    if confirm_destructive "APAGAR o volume Docker '${VOLUME_NAME}' (dados do Arcane, irreversível)"; then
      msg_action "Removendo volume ${VOLUME_NAME}..."
      docker volume rm "${VOLUME_NAME}" >/dev/null || msg_error "Falha ao remover o volume ${VOLUME_NAME}."
    else
      msg_skip "Volume ${VOLUME_NAME} preservado."
    fi
  else
    msg_skip "Volume ${VOLUME_NAME} não existe."
  fi

  if docker image inspect "${IMAGE_NAME}" &>/dev/null; then
    if confirm_destructive "remover a imagem Docker '${IMAGE_NAME}'"; then
      msg_action "Removendo imagem ${IMAGE_NAME}..."
      docker rmi "${IMAGE_NAME}" >/dev/null || msg_error "Não foi possível remover a imagem ${IMAGE_NAME}."
    else
      msg_skip "Imagem ${IMAGE_NAME} preservada."
    fi
  else
    msg_skip "Imagem ${IMAGE_NAME} não existe."
  fi
else
  msg_skip "Docker não encontrado. Pulando container, volume e imagem."
fi

# Chave de criptografia: sem ela, um volume preservado fica ilegível
_state_dir="$(_manifest_state_dir 2>/dev/null || true)"
_key_file="${_state_dir:+${_state_dir}/arcane.key}"
if [ -n "${_key_file}" ] && [ -f "${_key_file}" ]; then
  if docker volume ls --format '{{.Name}}' 2>/dev/null | grep -q "^${VOLUME_NAME}$"; then
    msg_skip "Chave ${_key_file} preservada (o volume ${VOLUME_NAME} ainda existe e precisa dela)."
  elif confirm_destructive "remover a chave de criptografia ${_key_file}"; then
    revert_file "${_key_file}"
  else
    msg_skip "Chave ${_key_file} preservada."
  fi
fi

# Pasta de projetos: apenas informar
if [ -d "${PROJECTS_DIR}" ]; then
  msg_skip "Pasta de projetos ${PROJECTS_DIR} preservada (pode conter stacks de outras aplicações). Remova manualmente se desejar."
fi

msg_action "Reversão do Arcane concluída."
