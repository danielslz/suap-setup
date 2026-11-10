#!/usr/bin/env bash
set -u

# docker/dev/docker-setup-revert.sh - Reverte docker/dev/docker-setup.sh
#
# Etapas (compose: ${SUAP_DIR}/docker/docker-compose.dev.yml):
#   1. docker compose down (containers e rede) — sempre
#   2. Volumes (ex.: dados do PostgreSQL de desenvolvimento): somente com confirmação
#   3. Imagens construídas localmente: somente com confirmação
# O repositório SUAP em SUAP_DIR e os arquivos gerados nele (.env, settings.py)
# são PRESERVADOS (podem conter trabalho do usuário).
# Suporta REVERT_DRY_RUN=1 e REVERT_ASSUME_YES=1.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

if ! command -v docker &>/dev/null; then
  msg_skip "Docker não encontrado. Nada a reverter."
  exit 0
fi

if [ -z "${SUAP_DIR:-}" ]; then
  msg_skip "SUAP_DIR não está definido no .env. Nada a reverter."
  exit 0
fi
SUAP_DIR=$(eval echo "${SUAP_DIR}")
COMPOSE_FILE="${SUAP_DIR}/docker/docker-compose.dev.yml"

if [ ! -f "${COMPOSE_FILE}" ]; then
  msg_skip "Compose não encontrado em ${COMPOSE_FILE}. Nada a reverter."
  exit 0
fi

# Variáveis exigidas na interpolação do compose (mesmas do setup)
export SUAP_IMAGE="${SUAP_IMAGE:-suap}"
export SUAP_PDF_IMAGE="${SUAP_PDF_IMAGE:-suap-pdf}"
export SUAP_AI_IMAGE="${SUAP_AI_IMAGE:-suap-ai}"
export CELERY_QUEUE="${CELERY_QUEUE:-geral}"
export CELERY_BROKER_URL="${CELERY_BROKER_URL:-redis://redis:6379/3}"
export FLOWER_BASIC_AUTH="${CELERY_FLOWER_AUTH:-admin:admin}"

_flags=()
if confirm_destructive "APAGAR os volumes do compose de desenvolvimento (ex.: dados do PostgreSQL dev, irreversível)"; then
  _flags+=("-v")
else
  msg_skip "Volumes preservados."
fi
if confirm_destructive "remover as imagens construídas localmente pelo compose de desenvolvimento"; then
  _flags+=("--rmi" "local")
else
  msg_skip "Imagens preservadas."
fi

if _dry; then
  echo "  ${YELLOW}[dry-run]${NO_COLOR} executaria: docker compose -f ${COMPOSE_FILE} down ${_flags[*]:-}"
else
  msg_action "Parando e removendo o ambiente Docker de desenvolvimento..."
  if ! (cd "${SUAP_DIR}" && docker compose -f "${COMPOSE_FILE}" down --remove-orphans ${_flags[@]+"${_flags[@]}"}); then
    msg_error "Falha ao executar 'docker compose down'."
    exit 1
  fi
fi

msg_skip "Repositório ${SUAP_DIR} preservado (inclui .env e settings.py gerados). Remova manualmente se desejar."
msg_action "Reversão do ambiente Docker de desenvolvimento concluída."
