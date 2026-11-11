#!/usr/bin/env bash
set -u

# docker/redis-setup.sh - Sobe um Redis via Docker Compose expondo a porta padrão
# (6379) para que seja acessível a partir de outras máquinas.
#
# O stack fica em ${DOCKER_STACKS_DIR:-/opt/docker}/redis/ (compose.yaml + .env).
#
# Variáveis opcionais (ambiente, .env do suap-setup ou .env do stack):
#   REDIS_DOCKER_PORT      Porta exposta no host (padrão: 6379)
#   REDIS_DOCKER_PASSWORD  Senha (requirepass). Se vazia, será solicitada.
#   REDIS_DOCKER_IMAGE     Imagem (padrão: redis:7-alpine)
#   DOCKER_STACKS_DIR      Base dos stacks (padrão: /opt/docker)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${SCRIPT_DIR}/lib/common.sh"

# Carregar .env se existir (opcional)
if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

check_docker_available

PROJECT="suap-redis"
CONTAINER_NAME="suap-redis"

stack_init "redis"
stack_env_load REDIS_DOCKER_PORT REDIS_DOCKER_PASSWORD REDIS_DOCKER_IMAGE
REDIS_DOCKER_PORT="${REDIS_DOCKER_PORT:-6379}"
REDIS_DOCKER_IMAGE="${REDIS_DOCKER_IMAGE:-redis:7-alpine}"
REDIS_DOCKER_PASSWORD="${REDIS_DOCKER_PASSWORD:-}"

# Como a porta fica exposta na rede, exigir senha
if [ -z "${REDIS_DOCKER_PASSWORD}" ]; then
  echo ""
  echo "${YELLOW}O Redis ficará acessível a outras máquinas. Defina uma senha.${NO_COLOR}"
  read -srp "Senha do Redis (Enter para gerar uma aleatória): " REDIS_DOCKER_PASSWORD
  echo ""
  if [ -z "${REDIS_DOCKER_PASSWORD}" ]; then
    REDIS_DOCKER_PASSWORD="$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)"
    echo "  Senha gerada: ${REDIS_DOCKER_PASSWORD}"
  fi
fi

stack_adopt_legacy "${CONTAINER_NAME}" "${PROJECT}" || exit 1

stack_env_write REDIS_DOCKER_PORT REDIS_DOCKER_PASSWORD REDIS_DOCKER_IMAGE || exit 1

cat > "${STACK_FILE}" <<'EOF'
# Gerado por suap-setup (docker/redis-setup.sh). Para alterar valores, edite o
# .env ao lado (ou defina variáveis e rode o script novamente).
name: suap-redis
services:
  redis:
    image: ${REDIS_DOCKER_IMAGE}
    container_name: suap-redis
    command:
      - sh
      - -c
      - exec redis-server --appendonly yes --bind 0.0.0.0 --protected-mode yes --requirepass "$$REDIS_PASSWORD"
    environment:
      REDIS_PASSWORD: ${REDIS_DOCKER_PASSWORD}
    ports:
      - "${REDIS_DOCKER_PORT}:6379"
    volumes:
      - redis-data:/data
    restart: unless-stopped
volumes:
  redis-data:
    name: suap-redis-data
EOF

msg_action "Subindo o stack Redis (${STACK_DIR})..."
if ! stack_compose "${PROJECT}" pull; then
  msg_error "Falha ao baixar a imagem ${REDIS_DOCKER_IMAGE}."
  exit 1
fi
if ! stack_compose "${PROJECT}" up -d --remove-orphans; then
  msg_error "Falha ao subir o stack Redis."
  exit 1
fi

if ! docker ps --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  msg_error "Container não está em execução. Verifique: docker logs ${CONTAINER_NAME}"
  exit 1
fi

msg_action "Redis em execução!"
echo ""
echo "  Stack:   ${STACK_DIR}"
echo "  Acesso:  redis://:<senha>@<ip-deste-servidor>:${REDIS_DOCKER_PORT}/0"
echo "  Senha:   guardada em ${STACK_ENV}"
echo "  Teste:   redis-cli -h <ip-deste-servidor> -p ${REDIS_DOCKER_PORT} -a '<senha>' ping"
echo "  Libere a porta ${REDIS_DOCKER_PORT}/tcp no firewall se necessário."
echo ""
