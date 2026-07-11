#!/usr/bin/env bash
set -u

# docker/dev/docker-setup.sh - Script de setup Docker para desenvolvimento
# Verifica pré-requisitos, resolve URL do repositório e inicia containers.

# Determinar diretório raiz do repositório suap-setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# 1. Source da biblioteca compartilhada
source "${SCRIPT_DIR}/lib/common.sh"

# 2. Verificar existência do .env
require_env_file "${SCRIPT_DIR}/.env"

# 3. Carregar variáveis do .env centralizado
load_env_file "${SCRIPT_DIR}/.env"

# 4. Verificar se Docker e Docker Compose estão disponíveis
check_docker_available

# 5. Garantir que GIT_URL está configurada
resolve_git_url "${SCRIPT_DIR}/.env"

# 6. Se SUAP_DIR não existe ou não contém pyproject.toml, clonar o repositório
if [ ! -d "${SUAP_DIR}" ] || [ ! -f "${SUAP_DIR}/pyproject.toml" ]; then
  msg_action "Repositório SUAP não encontrado em ${SUAP_DIR}. Clonando..."
  mkdir -p "$(dirname "${SUAP_DIR}")"
  if ! git clone "${GIT_URL}" "${SUAP_DIR}"; then
    msg_error "Falha ao clonar o repositório SUAP."
    exit 1
  fi
  if [ ! -f "${SUAP_DIR}/pyproject.toml" ]; then
    msg_error "Clone concluído, mas pyproject.toml não encontrado em ${SUAP_DIR}."
    msg_error "Verifique se a URL do repositório está correta."
    exit 1
  fi
  msg_action "Repositório clonado com sucesso em ${SUAP_DIR}"
fi

# 7. Garantir que o .env do SUAP existe (necessário para o compose)
if [ ! -f "${SUAP_DIR}/.env" ]; then
  if [ -f "${SUAP_DIR}/.env.dev.sample" ]; then
    msg_action "Gerando ${SUAP_DIR}/.env a partir do sample..."
    cp "${SUAP_DIR}/.env.dev.sample" "${SUAP_DIR}/.env"
  else
    msg_action "Criando ${SUAP_DIR}/.env vazio..."
    touch "${SUAP_DIR}/.env"
  fi
fi

# 8. Exportar variáveis necessárias para o compose
export SUAP_DIR
export PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
export COMPOSE_DOCKER_CLI_BUILD=1
export DOCKER_BUILDKIT=1

# O Dockerfile fica no suap-setup mas o context é o SUAP_DIR.
export DOCKERFILE_DEV="${SCRIPT_DIR}/docker/dev/Dockerfile"

# 9. Executar docker compose up --build
msg_action "Iniciando containers Docker de desenvolvimento (Python ${PYTHON_VERSION})..."
msg_action "Context: ${SUAP_DIR}"

COMPOSE_FILE="${SCRIPT_DIR}/docker/dev/docker-compose.yml"

docker compose -f "${COMPOSE_FILE}" build \
  --build-arg PYTHON_VERSION="${PYTHON_VERSION}"
docker compose -f "${COMPOSE_FILE}" up

# 9. Exibir mensagem com URL de acesso e comandos úteis
echo ""
msg_action "=== Ambiente Docker de Desenvolvimento ==="
echo ""
echo "  Acesso à aplicação: http://localhost:8000"
echo "  PostgreSQL:          localhost:5432"
echo "  Redis:               localhost:6379"
echo ""
echo "  Comandos úteis:"
echo "    Parar containers:      docker compose -f ${COMPOSE_FILE} down"
echo "    Ver logs:              docker compose -f ${COMPOSE_FILE} logs -f"
echo "    Reiniciar containers:  docker compose -f ${COMPOSE_FILE} restart"
echo "    Acessar shell do app:  docker compose -f ${COMPOSE_FILE} exec web bash"
echo ""
