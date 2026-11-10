#!/usr/bin/env bash
set -u

# docker/prod/docker-setup-revert.sh - Reverte docker/prod/docker-setup.sh
#
# Etapas (projeto suap_deploy em SUAP_DEPLOY_DIR):
#   1. make down — para os serviços e remove os volumes suap_static/suap_docker/suap_docs
#      (derrubar a produção: confirmação obrigatória)
#   2. Volume suap_pgdata (banco local, profile local-db): somente com confirmação
#   3. Imagens do compose: somente com confirmação
#   4. Diretório SUAP_DEPLOY_DIR (contém .env, deploy/media e deploy/backup):
#      somente com confirmação
# Suporta REVERT_DRY_RUN=1 e REVERT_ASSUME_YES=1.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

# Mesmo cálculo de SUAP_DEPLOY_DIR do setup
if [ -z "${SUAP_DEPLOY_DIR:-}" ]; then
  if [ -n "${SUAP_DIR:-}" ]; then
    SUAP_DEPLOY_DIR="$(dirname "$(eval echo "${SUAP_DIR}")")/suap_deploy"
  else
    SUAP_DEPLOY_DIR="${HOME}/Projetos/suap_deploy"
  fi
fi
SUAP_DEPLOY_DIR=$(eval echo "${SUAP_DEPLOY_DIR}")

if [ ! -d "${SUAP_DEPLOY_DIR}" ]; then
  msg_skip "Diretório ${SUAP_DEPLOY_DIR} não existe. Nada a reverter."
  exit 0
fi

if command -v docker &>/dev/null; then
  _compose_file="${SUAP_DEPLOY_DIR}/docker-compose.yml"

  # 1. Derrubar serviços
  if confirm_destructive "PARAR todos os serviços de produção do suap_deploy em ${SUAP_DEPLOY_DIR} (a aplicação ficará fora do ar)"; then
    if [ -f "${SUAP_DEPLOY_DIR}/Makefile" ] && command -v make &>/dev/null; then
      msg_action "Executando 'make down'..."
      make -C "${SUAP_DEPLOY_DIR}" down || msg_error "Falha em 'make down'."
    elif [ -f "${_compose_file}" ]; then
      msg_action "Executando 'docker compose down'..."
      (cd "${SUAP_DEPLOY_DIR}" && docker compose down) || msg_error "Falha em 'docker compose down'."
    fi

    # 2. Volume do banco local
    if docker volume ls --format '{{.Name}}' | grep -q '^suap_pgdata$'; then
      if confirm_destructive "APAGAR o volume Docker 'suap_pgdata' (banco PostgreSQL local, irreversível)"; then
        msg_action "Removendo volume suap_pgdata..."
        docker volume rm suap_pgdata >/dev/null || msg_error "Falha ao remover suap_pgdata."
      else
        msg_skip "Volume suap_pgdata preservado."
      fi
    fi

    # 3. Imagens
    if [ -f "${_compose_file}" ] && confirm_destructive "remover as imagens usadas pelo compose do suap_deploy"; then
      msg_action "Removendo imagens do compose..."
      (cd "${SUAP_DEPLOY_DIR}" && docker compose down --rmi all >/dev/null 2>&1) || msg_error "Não foi possível remover todas as imagens."
    fi
  else
    msg_skip "Serviços preservados."
  fi
else
  msg_skip "Docker não encontrado. Pulando serviços, volumes e imagens."
fi

# 4. Diretório (.env, media e backups)
revert_dir "${SUAP_DEPLOY_DIR}" --destructive

msg_action "Reversão do ambiente Docker de produção concluída."
