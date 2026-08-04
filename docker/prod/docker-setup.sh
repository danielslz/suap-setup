#!/usr/bin/env bash
set -u

# docker/prod/docker-setup.sh - Setup Docker para produção
# Delega para o projeto suap_deploy, que é o orquestrador oficial de produção.
#
# O suap_deploy:
#   - Puxa imagens pré-construídas do registry GitLab
#   - Usa OWASP ModSecurity CRS como WAF no Nginx
#   - Suporta resource limits por container
#   - Integra com Vault para segredos (opcional)
#   - Inclui serviços auxiliares (pdfprinter, ai)
#
# Este script automatiza o clone/configuração do suap_deploy e delega
# o gerenciamento dos containers para o Makefile dele.

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

# 5. Garantir que SUAP_DEPLOY_DIR está configurado
if [ -z "${SUAP_DEPLOY_DIR:-}" ]; then
  # Fallback: mesmo diretório pai do SUAP_DIR
  if [ -n "${SUAP_DIR:-}" ]; then
    SUAP_DEPLOY_DIR="$(dirname "$(eval echo "${SUAP_DIR}")")/suap_deploy"
  else
    SUAP_DEPLOY_DIR="${HOME}/Projetos/suap_deploy"
  fi
fi
SUAP_DEPLOY_DIR=$(eval echo "${SUAP_DEPLOY_DIR}")

# 6. Garantir que SUAP_DEPLOY_GIT_URL está configurado
SUAP_DEPLOY_GIT_URL="${SUAP_DEPLOY_GIT_URL:-}"
if [ -z "${SUAP_DEPLOY_GIT_URL}" ]; then
  msg_error "SUAP_DEPLOY_GIT_URL não está definido no .env"
  msg_error "Execute setup.sh e escolha a opção 6 para configurar."
  exit 1
fi

# 7. Se SUAP_DEPLOY_DIR não existe, clonar o repositório
if [ ! -d "${SUAP_DEPLOY_DIR}" ]; then
  msg_action "Repositório suap_deploy não encontrado em ${SUAP_DEPLOY_DIR}. Clonando..."
  if ! mkdir -p "$(dirname "${SUAP_DEPLOY_DIR}")" 2>/dev/null; then
    sudo mkdir -p "$(dirname "${SUAP_DEPLOY_DIR}")"
    sudo chown "${USER}:${USER}" "$(dirname "${SUAP_DEPLOY_DIR}")"
  fi
  if ! git clone --recurse-submodules "${SUAP_DEPLOY_GIT_URL}" "${SUAP_DEPLOY_DIR}"; then
    msg_error "Falha ao clonar o repositório suap_deploy."
    msg_error "Verifique se você tem acesso a: ${SUAP_DEPLOY_GIT_URL}"
    exit 1
  fi
  msg_action "Repositório clonado com sucesso em ${SUAP_DEPLOY_DIR}"
elif [ -d "${SUAP_DEPLOY_DIR}/.git" ]; then
  # Atualizar submodules se já existe
  msg_action "Atualizando submodules do suap_deploy..."
  cd "${SUAP_DEPLOY_DIR}" && git submodule update --init --recursive 2>/dev/null || true
fi

# 8. Verificar que o Makefile existe
if [ ! -f "${SUAP_DEPLOY_DIR}/Makefile" ]; then
  msg_error "Makefile não encontrado em ${SUAP_DEPLOY_DIR}."
  msg_error "Verifique se o repositório suap_deploy está correto."
  exit 1
fi

# 9. Configurar .env do suap_deploy se não existir
if [ ! -f "${SUAP_DEPLOY_DIR}/.env" ]; then
  if [ -f "${SUAP_DEPLOY_DIR}/env.prod.sample" ]; then
    msg_action "Gerando ${SUAP_DEPLOY_DIR}/.env a partir do env.prod.sample..."
    cp "${SUAP_DEPLOY_DIR}/env.prod.sample" "${SUAP_DEPLOY_DIR}/.env"
    msg_action "ATENÇÃO: Edite ${SUAP_DEPLOY_DIR}/.env com as credenciais corretas antes de prosseguir."
    echo ""
    echo "  Variáveis críticas para configurar:"
    echo "    DATABASE_HOST, DATABASE_USER, DATABASE_PASSWORD"
    echo "    SUAP_IMAGE (imagem do registry)"
    echo "    REDIS_LOCATION, CELERY_BROKER_URL"
    echo "    SECRET_KEY"
    echo ""
    read -rp "Pressione Enter após editar o .env, ou Ctrl+C para cancelar... "
  else
    msg_error "Arquivo .env não encontrado em ${SUAP_DEPLOY_DIR} e não há sample disponível."
    msg_error "Crie o .env com as configurações de produção antes de prosseguir."
    exit 1
  fi
fi

# 10. Menu de ações
cd "${SUAP_DEPLOY_DIR}"

echo ""
echo "${GREEN}=== Gerenciamento Docker de Produção (suap_deploy) ===${NO_COLOR}"
echo ""
echo "  Diretório: ${SUAP_DEPLOY_DIR}"
echo ""
echo "  1) Fazer pull das imagens e iniciar todos os serviços"
echo "  2) Fazer build local das imagens (a partir do código-fonte)"
echo "  3) Apenas iniciar serviços (sem pull/build)"
echo "  4) Parar todos os serviços"
echo "  5) Ver status dos containers"
echo "  6) Ver logs"
echo "  7) Acessar shell do container web"
echo "  8) Executar backup do banco"
echo "  0) Sair"
echo ""
read -rp "Escolha uma opção [0-8]: " PROD_CHOICE

case "${PROD_CHOICE}" in
  1)
    msg_action "Fazendo pull das imagens..."
    make pull-image
    make pull-pdf-image 2>/dev/null || true
    make pull-ai-image 2>/dev/null || true
    msg_action "Iniciando serviços..."
    make start-web
    make start-celery
    make start-celery-beat
    make start-flower
    make start-cron
    make start-pdf 2>/dev/null || true
    make start-ai 2>/dev/null || true
    echo ""
    msg_action "Todos os serviços iniciados."
    make status
    ;;
  2)
    msg_action "Fazendo build das imagens a partir do código-fonte..."
    msg_action "Isso requer que os submodules estejam atualizados."
    git submodule update --remote
    make build
    msg_action "Build concluído. Deseja iniciar os serviços? [s/N]"
    read -rp "" _start
    if [[ "${_start}" =~ ^[sS]$ ]]; then
      make start-web
      make start-celery
      make start-celery-beat
      make start-flower
      make start-cron
      echo ""
      msg_action "Serviços iniciados."
      make status
    fi
    ;;
  3)
    msg_action "Iniciando serviços..."
    make start-web
    make start-celery
    make start-celery-beat
    make start-flower
    make start-cron
    make start-pdf 2>/dev/null || true
    make start-ai 2>/dev/null || true
    echo ""
    make status
    ;;
  4)
    msg_action "Parando todos os serviços..."
    make stop
    msg_action "Serviços parados."
    ;;
  5)
    make status
    ;;
  6)
    make logs
    ;;
  7)
    make bash
    ;;
  8)
    msg_action "Executando backup do banco..."
    make backup
    msg_action "Backup concluído."
    ;;
  0)
    echo "Saindo..."
    exit 0
    ;;
  *)
    msg_error "Opção inválida."
    exit 1
    ;;
esac

echo ""
msg_action "=== Comandos úteis (executar dentro de ${SUAP_DEPLOY_DIR}) ==="
echo ""
echo "  make start-web        Iniciar web + nginx"
echo "  make start-celery     Iniciar celery worker"
echo "  make stop             Parar todos os serviços"
echo "  make status           Ver status dos containers"
echo "  make logs             Ver logs"
echo "  make bash             Acessar shell do container web"
echo "  make backup           Fazer backup do banco"
echo "  make build            Build local das imagens"
echo "  make push-image       Push da imagem para o registry"
echo ""
