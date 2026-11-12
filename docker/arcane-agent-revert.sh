#!/usr/bin/env bash
set -u

# docker/arcane-agent-revert.sh - Reverte docker/arcane-agent-setup.sh
# Derruba o stack Compose do agent. O volume arcane-agent-data, a imagem e o diretório do stack
# (${DOCKER_STACKS_DIR:-/opt/docker}/arcane-agent, que guarda o token) só são removidos com
# confirmação; o diretório é mantido enquanto o volume existir. Remova também o environment
# correspondente no Arcane Manager (o token deixa de valer).
# Suporta REVERT_DRY_RUN=1 e REVERT_ASSUME_YES=1.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

IMAGE_NAME="${ARCANE_AGENT_IMAGE:-ghcr.io/getarcaneapp/agent:latest}"
stack_revert "arcane-agent" "suap-arcane-agent" "arcane-agent" "arcane-agent-data" "${IMAGE_NAME}"

msg_skip "Lembre-se de remover o environment deste host no Arcane Manager."
msg_action "Reversão do Arcane Agent concluída."
