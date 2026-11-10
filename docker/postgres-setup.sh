#!/usr/bin/env bash
set -u

# docker/postgres-setup.sh - Sobe um PostgreSQL via Docker expondo a porta padrão
# (5432) para que seja acessível a partir de outras máquinas.
#
# Variáveis opcionais (ambiente ou .env):
#   POSTGRES_VERSION          Versão da imagem (padrão: 16)
#   POSTGRES_DOCKER_PORT      Porta exposta no host (padrão: 5432)
#   POSTGRES_DOCKER_DB        Nome do banco (padrão: suap)
#   POSTGRES_DOCKER_USER      Usuário da aplicação (padrão: suap_app)
#   POSTGRES_DOCKER_PASSWORD  Senha do usuário. Se vazia, será solicitada.
#   POSTGRES_DOCKER_IMAGE     Imagem completa (sobrescreve POSTGRES_VERSION)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${SCRIPT_DIR}/lib/common.sh"

# Carregar .env se existir (opcional)
if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

check_docker_available

CONTAINER_NAME="suap-postgres"
VOLUME_NAME="suap-postgres-data"
PG_PORT="${POSTGRES_DOCKER_PORT:-5432}"
PG_IMAGE="${POSTGRES_DOCKER_IMAGE:-postgres:${POSTGRES_VERSION:-16}}"
PG_DB="${POSTGRES_DOCKER_DB:-suap}"
PG_USER="${POSTGRES_DOCKER_USER:-suap_app}"
PG_PASSWORD="${POSTGRES_DOCKER_PASSWORD:-}"

# Idempotência: já em execução
if docker ps --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  msg_skip "Container ${CONTAINER_NAME} já está ativo. Acesso: postgresql://<ip-deste-servidor>:${PG_PORT}"
  exit 0
fi

# Container existe mas está parado: apenas iniciar
if docker ps -a --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  msg_action "Container ${CONTAINER_NAME} existe e está parado. Iniciando..."
  if ! docker start "${CONTAINER_NAME}" >/dev/null; then
    msg_error "Falha ao iniciar o container ${CONTAINER_NAME}."
    exit 1
  fi
  msg_action "PostgreSQL iniciado. Acesso: postgresql://<ip-deste-servidor>:${PG_PORT}"
  exit 0
fi

# Perguntar apenas o que não foi definido; como a porta fica exposta, exigir senha
echo ""
echo "${GREEN}=== Configuração do PostgreSQL (Docker) ===${NO_COLOR}"
if [ -z "${POSTGRES_DOCKER_DB:-}" ]; then
  read -rp "Nome do banco [${PG_DB}]: " _in
  PG_DB="${_in:-${PG_DB}}"
fi
if [ -z "${POSTGRES_DOCKER_USER:-}" ]; then
  read -rp "Nome do usuário de aplicação [${PG_USER}]: " _in
  PG_USER="${_in:-${PG_USER}}"
fi
if [ -z "${PG_PASSWORD}" ]; then
  echo "${YELLOW}O PostgreSQL ficará acessível a outras máquinas. Defina uma senha.${NO_COLOR}"
  read -srp "Senha do usuário (Enter para gerar uma aleatória): " PG_PASSWORD
  echo ""
  if [ -z "${PG_PASSWORD}" ]; then
    PG_PASSWORD="$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)"
    echo "  Senha gerada: ${PG_PASSWORD}"
  fi
fi

msg_action "Baixando imagem ${PG_IMAGE}..."
if ! docker pull "${PG_IMAGE}"; then
  msg_error "Falha ao baixar a imagem ${PG_IMAGE}."
  exit 1
fi

msg_action "Iniciando container ${CONTAINER_NAME} na porta ${PG_PORT}..."
if ! docker run -d \
  --name "${CONTAINER_NAME}" \
  -p "${PG_PORT}:5432" \
  -e POSTGRES_DB="${PG_DB}" \
  -e POSTGRES_USER="${PG_USER}" \
  -e POSTGRES_PASSWORD="${PG_PASSWORD}" \
  -v "${VOLUME_NAME}:/var/lib/postgresql/data" \
  --restart unless-stopped \
  "${PG_IMAGE}" \
  -c listen_addresses='*' -c bytea_output=escape >/dev/null; then
  msg_error "Falha ao iniciar o container ${CONTAINER_NAME}."
  exit 1
fi

if ! docker ps --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  msg_error "Container não está em execução. Verifique: docker logs ${CONTAINER_NAME}"
  exit 1
fi

msg_action "PostgreSQL iniciado com sucesso!"
echo ""
echo "  Banco:    ${PG_DB}"
echo "  Usuário:  ${PG_USER}"
echo "  Acesso:   postgresql://${PG_USER}:<senha>@<ip-deste-servidor>:${PG_PORT}/${PG_DB}"
echo "  Teste:    psql -h <ip-deste-servidor> -p ${PG_PORT} -U ${PG_USER} -d ${PG_DB}"
echo "  Libere a porta ${PG_PORT}/tcp no firewall se necessário."
echo ""
