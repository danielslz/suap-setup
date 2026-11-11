#!/usr/bin/env bash
set -u

# docker/dockhand-revert.sh - Reverte docker/dockhand-setup.sh
# Derruba o stack Compose (Dockhand). O volume dockhand_data, a imagem e o diretório do
# stack (${DOCKER_STACKS_DIR:-/opt/docker}/dockhand, que guarda segredos) só são removidos com confirmação; o
# diretório é preservado enquanto o volume existir. Também trata containers
# criados antes por 'docker run'.
# Suporta REVERT_DRY_RUN=1 e REVERT_ASSUME_YES=1.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

IMAGE_NAME="${DOCKHAND_IMAGE:-fnsys/dockhand:latest}"
stack_revert "dockhand" "suap-dockhand" "dockhand" "dockhand_data" "${IMAGE_NAME}"

msg_action "Reversão do Dockhand concluída."
