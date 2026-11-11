#!/usr/bin/env bash
set -u

# docker/postgres-revert.sh - Reverte docker/postgres-setup.sh
# Derruba o stack Compose (PostgreSQL (Docker)). O volume suap-postgres-data, a imagem e o diretório do
# stack (${DOCKER_STACKS_DIR:-/opt/docker}/postgres, que guarda segredos) só são removidos com confirmação; o
# diretório é preservado enquanto o volume existir. Também trata containers
# criados antes por 'docker run'.
# Suporta REVERT_DRY_RUN=1 e REVERT_ASSUME_YES=1.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

IMAGE_NAME="${POSTGRES_DOCKER_IMAGE:-postgres:${POSTGRES_VERSION:-16}}"
stack_revert "postgres" "suap-postgres" "suap-postgres" "suap-postgres-data" "${IMAGE_NAME}"

msg_action "Reversão do PostgreSQL (Docker) concluída."
