#!/usr/bin/env bash
set -u

# docker/dockhand-revert.sh - Reverte docker/dockhand-setup.sh
# Remove o container "dockhand". Volumes Docker associados ao container (dados e
# configurações do Dockhand) e a imagem só são removidos com confirmação.
# O socket /var/run/docker.sock é apenas montado no container; nada é alterado nele.
# Suporta REVERT_DRY_RUN=1 e REVERT_ASSUME_YES=1.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

if ! command -v docker &>/dev/null; then
  msg_skip "Docker não encontrado. Nada a reverter."
  exit 0
fi

CONTAINER_NAME="dockhand"
IMAGE_NAME="lscr.io/linuxserver/dockhand:latest"
_volumes=""

if docker ps -a --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  # Guardar volumes nomeados/anônimos antes de remover o container
  _volumes="$(docker inspect -f '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}} {{end}}{{end}}' "${CONTAINER_NAME}" 2>/dev/null || true)"
  if _dry; then
    echo "  ${YELLOW}[dry-run]${NO_COLOR} removeria o container ${CONTAINER_NAME}"
  else
    msg_action "Removendo container ${CONTAINER_NAME}..."
    docker rm -f "${CONTAINER_NAME}" >/dev/null || { msg_error "Falha ao remover ${CONTAINER_NAME}."; exit 1; }
  fi
else
  msg_skip "Container ${CONTAINER_NAME} não existe."
fi

# Volumes (dados do Dockhand) — destrutivo
for _vol in ${_volumes}; do
  if confirm_destructive "APAGAR o volume Docker '${_vol}' (dados do Dockhand, irreversível)"; then
    msg_action "Removendo volume ${_vol}..."
    docker volume rm "${_vol}" >/dev/null || msg_error "Falha ao remover o volume ${_vol}."
  else
    msg_skip "Volume ${_vol} preservado."
  fi
done

# Imagem
if docker image inspect "${IMAGE_NAME}" &>/dev/null; then
  if confirm_destructive "remover a imagem Docker '${IMAGE_NAME}'"; then
    msg_action "Removendo imagem ${IMAGE_NAME}..."
    docker rmi "${IMAGE_NAME}" >/dev/null || msg_error "Falha ao remover a imagem ${IMAGE_NAME}."
  else
    msg_skip "Imagem ${IMAGE_NAME} preservada."
  fi
else
  msg_skip "Imagem ${IMAGE_NAME} não existe."
fi

msg_action "Reversão do Dockhand concluída."
