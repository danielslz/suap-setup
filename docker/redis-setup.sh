#!/usr/bin/env bash
set -u

# docker/redis-setup.sh - Sobe um Redis via Docker expondo a porta padrão (6379)
# para que seja acessível a partir de outras máquinas.
#
# Variáveis opcionais (ambiente ou .env):
#   REDIS_DOCKER_PORT      Porta exposta no host (padrão: 6379)
#   REDIS_DOCKER_PASSWORD  Senha (requirepass). Se vazia, será solicitada.
#   REDIS_DOCKER_IMAGE     Imagem (padrão: redis:7-alpine)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${SCRIPT_DIR}/lib/common.sh"

# Carregar .env se existir (opcional)
if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

check_docker_available

CONTAINER_NAME="suap-redis"
VOLUME_NAME="suap-redis-data"
REDIS_PORT="${REDIS_DOCKER_PORT:-6379}"
REDIS_IMAGE="${REDIS_DOCKER_IMAGE:-redis:7-alpine}"
REDIS_PASSWORD="${REDIS_DOCKER_PASSWORD:-}"

# Idempotência: já em execução
if docker ps --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  msg_skip "Container ${CONTAINER_NAME} já está ativo. Acesso: redis://<ip-deste-servidor>:${REDIS_PORT}"
  exit 0
fi

# Container existe mas está parado: apenas iniciar
if docker ps -a --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  msg_action "Container ${CONTAINER_NAME} existe e está parado. Iniciando..."
  if ! docker start "${CONTAINER_NAME}" >/dev/null; then
    msg_error "Falha ao iniciar o container ${CONTAINER_NAME}."
    exit 1
  fi
  msg_action "Redis iniciado. Acesso: redis://<ip-deste-servidor>:${REDIS_PORT}"
  exit 0
fi

# Como a porta fica exposta na rede, exigir senha
if [ -z "${REDIS_PASSWORD}" ]; then
  echo ""
  echo "${YELLOW}O Redis ficará acessível a outras máquinas. Defina uma senha.${NO_COLOR}"
  read -srp "Senha do Redis (Enter para gerar uma aleatória): " REDIS_PASSWORD
  echo ""
  if [ -z "${REDIS_PASSWORD}" ]; then
    REDIS_PASSWORD="$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)"
    echo "  Senha gerada: ${REDIS_PASSWORD}"
  fi
fi

msg_action "Baixando imagem ${REDIS_IMAGE}..."
if ! docker pull "${REDIS_IMAGE}"; then
  msg_error "Falha ao baixar a imagem ${REDIS_IMAGE}."
  exit 1
fi

msg_action "Iniciando container ${CONTAINER_NAME} na porta ${REDIS_PORT}..."
if ! docker run -d \
  --name "${CONTAINER_NAME}" \
  -p "${REDIS_PORT}:6379" \
  -v "${VOLUME_NAME}:/data" \
  --restart unless-stopped \
  "${REDIS_IMAGE}" \
  redis-server --appendonly yes --bind 0.0.0.0 --protected-mode yes --requirepass "${REDIS_PASSWORD}" >/dev/null; then
  msg_error "Falha ao iniciar o container ${CONTAINER_NAME}."
  exit 1
fi

if ! docker ps --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  msg_error "Container não está em execução. Verifique: docker logs ${CONTAINER_NAME}"
  exit 1
fi

msg_action "Redis iniciado com sucesso!"
echo ""
echo "  Acesso:  redis://:<senha>@<ip-deste-servidor>:${REDIS_PORT}/0"
echo "  Teste:   redis-cli -h <ip-deste-servidor> -p ${REDIS_PORT} -a '<senha>' ping"
echo "  Libere a porta ${REDIS_PORT}/tcp no firewall se necessário."
echo ""
