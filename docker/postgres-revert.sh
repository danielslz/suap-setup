#!/usr/bin/env bash
set -u

# docker/postgres-revert.sh - Reverte docker/postgres-setup.sh
# Remove o container suap-postgres. O volume de dados (suap-postgres-data) só é
# apagado mediante confirmação, pois contém o banco de dados.
# Suporta REVERT_DRY_RUN=1 e REVERT_ASSUME_YES=1.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

if ! command -v docker &>/dev/null; then
  msg_skip "Docker não encontrado. Nada a reverter."
  exit 0
fi

CONTAINER_NAME="suap-postgres"
VOLUME_NAME="suap-postgres-data"

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
  if confirm_destructive "APAGAR o volume Docker '${VOLUME_NAME}' (banco de dados PostgreSQL, irreversível)"; then
    msg_action "Removendo volume ${VOLUME_NAME}..."
    docker volume rm "${VOLUME_NAME}" >/dev/null || { msg_error "Falha ao remover o volume."; exit 1; }
  else
    msg_skip "Volume ${VOLUME_NAME} preservado."
  fi
else
  msg_skip "Volume ${VOLUME_NAME} não existe."
fi

msg_action "Reversão do PostgreSQL (Docker) concluída."
