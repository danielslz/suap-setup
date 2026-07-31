#!/usr/bin/env bash
set -u

# docker/dev/docker-setup.sh - Setup Docker para desenvolvimento
# Delega para o docker-compose.dev.yml nativo do projeto SUAP (suap).
#
# Este script NÃO mantém Dockerfiles próprios. Ele utiliza os Dockerfiles
# oficiais do repositório SUAP, garantindo que a configuração de build
# esteja sempre atualizada com o upstream.

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

# 5. Garantir que SUAP_DIR está configurado e aponta para o código
if [ -z "${SUAP_DIR:-}" ]; then
  msg_error "SUAP_DIR não está definido no .env"
  msg_error "Defina o caminho do repositório SUAP (ex: \$HOME/Projetos/suap)"
  exit 1
fi

# Expandir variáveis no path
SUAP_DIR=$(eval echo "${SUAP_DIR}")

# 6. Se SUAP_DIR não existe, clonar o repositório
if [ ! -d "${SUAP_DIR}" ]; then
  resolve_git_url "${SCRIPT_DIR}/.env"
  msg_action "Repositório SUAP não encontrado em ${SUAP_DIR}. Clonando..."
  mkdir -p "$(dirname "${SUAP_DIR}")"
  if ! git clone "${SUAP_GIT_URL}" "${SUAP_DIR}"; then
    msg_error "Falha ao clonar o repositório SUAP."
    exit 1
  fi
  msg_action "Repositório clonado com sucesso em ${SUAP_DIR}"
fi

# 7. Verificar que o compose do SUAP existe
COMPOSE_FILE="${SUAP_DIR}/docker/docker-compose.dev.yml"
if [ ! -f "${COMPOSE_FILE}" ]; then
  msg_error "Arquivo docker-compose.dev.yml não encontrado em:"
  msg_error "  ${COMPOSE_FILE}"
  msg_error ""
  msg_error "Verifique se SUAP_DIR aponta para o repositório correto."
  exit 1
fi

# 8. Garantir que o .env do SUAP existe (necessário para o compose)
if [ ! -f "${SUAP_DIR}/.env" ]; then
  if [ -f "${SUAP_DIR}/.env.dev.sample" ]; then
    msg_action "Gerando ${SUAP_DIR}/.env a partir do .env.dev.sample..."
    cp "${SUAP_DIR}/.env.dev.sample" "${SUAP_DIR}/.env"
  else
    msg_error "Arquivo .env não encontrado em ${SUAP_DIR}."
    msg_error "Crie o .env com as configurações do SUAP antes de prosseguir."
    exit 1
  fi
fi

# 9. Ajustar variáveis padrão no .env do SUAP se não estiverem definidas
# Garante que SUAP_IMAGE aponte para o registry configurado
if [ -n "${SUAP_IMAGE:-}" ] && ! grep -q "^SUAP_IMAGE=" "${SUAP_DIR}/.env"; then
  echo "SUAP_IMAGE=${SUAP_IMAGE}" >> "${SUAP_DIR}/.env"
fi

# 10. Garantir que settings.py existe (necessário para Django)
if [ ! -f "${SUAP_DIR}/suap/settings.py" ]; then
  if [ -f "${SUAP_DIR}/suap/settings_sample.py" ]; then
    msg_action "Gerando suap/settings.py a partir do sample..."
    cp "${SUAP_DIR}/suap/settings_sample.py" "${SUAP_DIR}/suap/settings.py"
  fi
fi

# 11. Garantir permissão de execução nos scripts bin/
if [ -d "${SUAP_DIR}/bin" ]; then
  chmod +x "${SUAP_DIR}/bin/"*.sh 2>/dev/null || true
fi

# 12. Exportar variáveis para o compose
export SUAP_IMAGE="${SUAP_IMAGE:-}"
export SUAP_PDF_IMAGE="${SUAP_PDF_IMAGE:-}"
export SUAP_AI_IMAGE="${SUAP_AI_IMAGE:-}"
export CELERY_QUEUE="${CELERY_QUEUE:-geral}"
export CELERY_BROKER_URL="${CELERY_BROKER_URL:-redis://redis:6379/3}"
export FLOWER_BASIC_AUTH="${CELERY_FLOWER_AUTH:-admin:admin}"
export COMPOSE_DOCKER_CLI_BUILD=1
export DOCKER_BUILDKIT=1

# 13. Determinar quais serviços subir
# Serviços base que sempre sobem
SERVICES="web celery celery-beat redis db"

# Serviços opcionais
if [ "${START_FLOWER:-true}" = "true" ]; then
  SERVICES="${SERVICES} celery-flower"
fi
if [ "${START_CRON:-true}" = "true" ]; then
  SERVICES="${SERVICES} cron"
fi

# 14. Build e up
msg_action "Iniciando ambiente de desenvolvimento SUAP..."
msg_action "Compose: ${COMPOSE_FILE}"
msg_action "Serviços: ${SERVICES}"
echo ""

cd "${SUAP_DIR}"
docker compose -f "${COMPOSE_FILE}" build
docker compose -f "${COMPOSE_FILE}" up ${SERVICES}

# 15. Mensagem final (exibida após Ctrl+C)
echo ""
msg_action "=== Ambiente Docker de Desenvolvimento ==="
echo ""
echo "  Acesso à aplicação: http://localhost:8000"
echo "  Celery Flower:      http://localhost:5555"
echo "  PostgreSQL:          localhost:5432"
echo "  Redis:               localhost:6379"
echo ""
echo "  Comandos úteis:"
echo "    Parar containers:      docker compose -f ${COMPOSE_FILE} down"
echo "    Ver logs:              docker compose -f ${COMPOSE_FILE} logs -f"
echo "    Reiniciar containers:  docker compose -f ${COMPOSE_FILE} restart"
echo "    Acessar shell do app:  docker compose -f ${COMPOSE_FILE} exec web bash"
echo "    Rodar migrate:         docker compose -f ${COMPOSE_FILE} exec web python manage.py migrate"
echo ""
