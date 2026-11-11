#!/usr/bin/env bash
set -u

# docker/redis-revert.sh - Reverte docker/redis-setup.sh
# Derruba o stack Compose (Redis (Docker)). O volume suap-redis-data, a imagem e o diretório do
# stack (${DOCKER_STACKS_DIR:-/opt/docker}/redis, que guarda segredos) só são removidos com confirmação; o
# diretório é preservado enquanto o volume existir. Também trata containers
# criados antes por 'docker run'.
# Suporta REVERT_DRY_RUN=1 e REVERT_ASSUME_YES=1.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

IMAGE_NAME="${REDIS_DOCKER_IMAGE:-redis:7-alpine}"
stack_revert "redis" "suap-redis" "suap-redis" "suap-redis-data" "${IMAGE_NAME}"

msg_action "Reversão do Redis (Docker) concluída."
