#!/usr/bin/env bash
set -u

# docker/dockhand-setup.sh - Setup do Dockhand (gerenciador Docker via web) com Docker Compose.
# O stack fica em ${DOCKER_STACKS_DIR:-/opt/docker}/dockhand/ (compose.yaml + .env).
#
# Variáveis opcionais (ambiente, .env do suap-setup ou .env do stack):
#   DOCKHAND_PORT     Porta exposta no host (padrão: 9093). O container escuta na 3000.
#   DOCKHAND_IMAGE    Imagem (padrão: fnsys/dockhand:latest, Docker Hub)
#   DOCKER_STACKS_DIR Base dos stacks (padrão: /opt/docker)

# Determinar diretório raiz do repositório (um nível acima deste script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Source da biblioteca compartilhada
source "${SCRIPT_DIR}/lib/common.sh"

# Carregar .env se existir (opcional)
if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

# 2. Verificar se Docker está disponível
check_docker_available

PROJECT="suap-dockhand"
CONTAINER_NAME="dockhand"

stack_init "dockhand"
stack_env_load DOCKHAND_PORT DOCKHAND_IMAGE
DOCKHAND_PORT="${DOCKHAND_PORT:-9093}"
DOCKHAND_IMAGE="${DOCKHAND_IMAGE:-fnsys/dockhand:latest}"

# 3. Assumir container criado antes por 'docker run' (se houver)
stack_adopt_legacy "${CONTAINER_NAME}" "${PROJECT}" || exit 1

stack_env_write DOCKHAND_PORT DOCKHAND_IMAGE || exit 1

cat > "${STACK_FILE}" <<'EOF'
# Gerado por suap-setup (docker/dockhand-setup.sh). Para alterar valores, edite o
# .env ao lado (ou defina variáveis e rode o script novamente).
name: suap-dockhand
services:
  dockhand:
    image: ${DOCKHAND_IMAGE}
    container_name: dockhand
    ports:
      - "${DOCKHAND_PORT}:3000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - dockhand_data:/app/data
    restart: unless-stopped
volumes:
  dockhand_data:
    name: dockhand_data
EOF

# 4. Obter a imagem e subir (o compose recria o container se algo mudou, ex.: porta)
msg_action "Subindo o stack Dockhand (${STACK_DIR})..."
if ! stack_compose "${PROJECT}" pull; then
  msg_error "Falha ao baixar imagem do Dockhand."
  exit 1
fi
if ! stack_compose "${PROJECT}" up -d --remove-orphans; then
  msg_error "Falha ao subir o stack Dockhand."
  exit 1
fi

# 5. Verificar se o container iniciou com sucesso
if ! docker ps --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  msg_error "Container Dockhand não está em execução. Verifique os logs com: docker logs dockhand"
  exit 1
fi

# 6. Exibir URL de acesso
msg_action "Dockhand em execução! Acesso: http://localhost:${DOCKHAND_PORT}"
echo "  Stack: ${STACK_DIR}"
