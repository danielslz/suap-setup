#!/usr/bin/env bash
set -u

# docker/postgres-setup.sh - Sobe um PostgreSQL via Docker Compose expondo a porta
# padrão (5432) para que seja acessível a partir de outras máquinas.
#
# O stack fica em ${DOCKER_STACKS_DIR:-/opt/docker}/postgres/ (compose.yaml + .env).
#
# Variáveis opcionais (ambiente, .env do suap-setup ou .env do stack):
#   POSTGRES_VERSION          Versão da imagem (padrão: 16)
#   POSTGRES_DOCKER_PORT      Porta exposta no host (padrão: 5432)
#   POSTGRES_DOCKER_DB        Nome do banco (padrão: suap)
#   POSTGRES_DOCKER_USER      Usuário da aplicação (padrão: suap_app)
#   POSTGRES_DOCKER_PASSWORD  Senha do usuário. Se vazia, será solicitada.
#   POSTGRES_DOCKER_IMAGE     Imagem completa (sobrescreve POSTGRES_VERSION)
#   DOCKER_STACKS_DIR         Base dos stacks (padrão: /opt/docker)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${SCRIPT_DIR}/lib/common.sh"

# Carregar .env se existir (opcional)
if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

check_docker_available

PROJECT="suap-postgres"
CONTAINER_NAME="suap-postgres"

stack_init "postgres"
stack_env_load POSTGRES_DOCKER_PORT POSTGRES_DOCKER_DB POSTGRES_DOCKER_USER POSTGRES_DOCKER_PASSWORD POSTGRES_DOCKER_IMAGE
POSTGRES_DOCKER_PORT="${POSTGRES_DOCKER_PORT:-5432}"
POSTGRES_DOCKER_IMAGE="${POSTGRES_DOCKER_IMAGE:-postgres:${POSTGRES_VERSION:-16}}"
POSTGRES_DOCKER_DB="${POSTGRES_DOCKER_DB:-}"
POSTGRES_DOCKER_USER="${POSTGRES_DOCKER_USER:-}"
POSTGRES_DOCKER_PASSWORD="${POSTGRES_DOCKER_PASSWORD:-}"

# Perguntar apenas o que ainda não foi definido; como a porta fica exposta, exigir senha
if [ -z "${POSTGRES_DOCKER_DB}" ] || [ -z "${POSTGRES_DOCKER_USER}" ] || [ -z "${POSTGRES_DOCKER_PASSWORD}" ]; then
  echo ""
  echo "${GREEN}=== Configuração do PostgreSQL (Docker) ===${NO_COLOR}"
fi
if [ -z "${POSTGRES_DOCKER_DB}" ]; then
  read -rp "Nome do banco [suap]: " _in
  POSTGRES_DOCKER_DB="${_in:-suap}"
fi
if [ -z "${POSTGRES_DOCKER_USER}" ]; then
  read -rp "Nome do usuário de aplicação [suap_app]: " _in
  POSTGRES_DOCKER_USER="${_in:-suap_app}"
fi
if [ -z "${POSTGRES_DOCKER_PASSWORD}" ]; then
  echo "${YELLOW}O PostgreSQL ficará acessível a outras máquinas. Defina uma senha.${NO_COLOR}"
  read -srp "Senha do usuário (Enter para gerar uma aleatória): " POSTGRES_DOCKER_PASSWORD
  echo ""
  if [ -z "${POSTGRES_DOCKER_PASSWORD}" ]; then
    POSTGRES_DOCKER_PASSWORD="$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)"
    echo "  Senha gerada: ${POSTGRES_DOCKER_PASSWORD}"
  fi
fi

stack_adopt_legacy "${CONTAINER_NAME}" "${PROJECT}" || exit 1

stack_env_write POSTGRES_DOCKER_PORT POSTGRES_DOCKER_DB POSTGRES_DOCKER_USER POSTGRES_DOCKER_PASSWORD POSTGRES_DOCKER_IMAGE || exit 1

cat > "${STACK_FILE}" <<'EOF'
# Gerado por suap-setup (docker/postgres-setup.sh). Para alterar valores, edite o
# .env ao lado (ou defina variáveis e rode o script novamente).
# POSTGRES_DB/USER/PASSWORD só têm efeito na primeira inicialização do volume.
name: suap-postgres
services:
  postgres:
    image: ${POSTGRES_DOCKER_IMAGE}
    container_name: suap-postgres
    command: ["-c", "listen_addresses=*", "-c", "bytea_output=escape"]
    environment:
      POSTGRES_DB: ${POSTGRES_DOCKER_DB}
      POSTGRES_USER: ${POSTGRES_DOCKER_USER}
      POSTGRES_PASSWORD: ${POSTGRES_DOCKER_PASSWORD}
    ports:
      - "${POSTGRES_DOCKER_PORT}:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    restart: unless-stopped
volumes:
  pgdata:
    name: suap-postgres-data
EOF

msg_action "Subindo o stack PostgreSQL (${STACK_DIR})..."
if ! stack_compose "${PROJECT}" pull; then
  msg_error "Falha ao baixar a imagem ${POSTGRES_DOCKER_IMAGE}."
  exit 1
fi
if ! stack_compose "${PROJECT}" up -d --remove-orphans; then
  msg_error "Falha ao subir o stack PostgreSQL."
  exit 1
fi

if ! docker ps --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  msg_error "Container não está em execução. Verifique: docker logs ${CONTAINER_NAME}"
  exit 1
fi

msg_action "PostgreSQL em execução!"
echo ""
echo "  Stack:    ${STACK_DIR}"
echo "  Banco:    ${POSTGRES_DOCKER_DB}"
echo "  Usuário:  ${POSTGRES_DOCKER_USER}"
echo "  Senha:    guardada em ${STACK_ENV}"
echo "  Acesso:   postgresql://${POSTGRES_DOCKER_USER}:<senha>@<ip-deste-servidor>:${POSTGRES_DOCKER_PORT}/${POSTGRES_DOCKER_DB}"
echo "  Teste:    psql -h <ip-deste-servidor> -p ${POSTGRES_DOCKER_PORT} -U ${POSTGRES_DOCKER_USER} -d ${POSTGRES_DOCKER_DB}"
echo "  Libere a porta ${POSTGRES_DOCKER_PORT}/tcp no firewall se necessário."
echo ""
