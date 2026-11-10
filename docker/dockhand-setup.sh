#!/usr/bin/env bash
set -u

# docker/dockhand-setup.sh - Script de setup do Dockhand (gerenciador Docker via web)
# Verifica pré-requisitos, pull da imagem e inicia container Dockhand.

# Determinar diretório raiz do repositório (um nível acima deste script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Source da biblioteca compartilhada
source "${SCRIPT_DIR}/lib/common.sh"

# Carregar .env se existir (opcional; permite definir DOCKHAND_PORT / DOCKHAND_IMAGE)
if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

# 2. Verificar se Docker está disponível
check_docker_available

# Imagem oficial (Docker Hub). Pode ser sobrescrita via DOCKHAND_IMAGE (ex.: fnsys/dockhand:v1.0.55)
DOCKHAND_IMAGE="${DOCKHAND_IMAGE:-fnsys/dockhand:latest}"
# Porta exposta no host (padrão: 9093). O container escuta na 3000.
DOCKHAND_PORT="${DOCKHAND_PORT:-9093}"

# 3. Verificar se container "dockhand" já está em execução
if docker ps --filter "name=^dockhand$" --format '{{.Names}}' | grep -q "^dockhand$"; then
  msg_skip "Container Dockhand já está ativo. Acesso: http://localhost:${DOCKHAND_PORT}"
  exit 0
fi

# 4. Obter imagem mais recente do Dockhand
msg_action "Baixando imagem do Dockhand..."
if ! docker pull "${DOCKHAND_IMAGE}"; then
  msg_error "Falha ao baixar imagem do Dockhand."
  exit 1
fi

# 5. Iniciar container Dockhand
msg_action "Iniciando container Dockhand..."
if ! docker run -d \
  --name dockhand \
  -p "${DOCKHAND_PORT}:3000" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v dockhand_data:/app/data \
  --restart unless-stopped \
  "${DOCKHAND_IMAGE}"; then
  msg_error "Falha ao iniciar container Dockhand."
  exit 1
fi

# 6. Verificar se o container iniciou com sucesso
if ! docker ps --filter "name=^dockhand$" --format '{{.Names}}' | grep -q "^dockhand$"; then
  msg_error "Container Dockhand não está em execução. Verifique os logs com: docker logs dockhand"
  exit 1
fi

# 7. Exibir URL de acesso
msg_action "Dockhand iniciado com sucesso! Acesso: http://localhost:${DOCKHAND_PORT}"
