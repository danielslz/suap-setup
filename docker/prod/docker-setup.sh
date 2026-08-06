#!/usr/bin/env bash
set -u

# docker/prod/docker-setup.sh - Setup Docker para produção
# Delega para o projeto suap_deploy, que é o orquestrador oficial de produção.
#
# O suap_deploy:
#   - Suporta modo "registry" (pull de imagens pré-construídas) e "local" (build a partir do código)
#   - Usa OWASP ModSecurity CRS como WAF no Nginx
#   - Suporta resource limits por container
#   - Controla serviços via COMPOSE_PROFILES no .env
#   - Inclui serviços auxiliares (pdfprinter, ai, celery-beat, celery-flower)
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
  _parent_dir="$(dirname "${SUAP_DEPLOY_DIR}")"
  # Criar diretório pai se não existir e garantir permissão de escrita
  if [ ! -d "${_parent_dir}" ]; then
    mkdir -p "${_parent_dir}" 2>/dev/null || sudo mkdir -p "${_parent_dir}"
  fi
  if [ ! -w "${_parent_dir}" ]; then
    sudo chown "${USER}:${USER}" "${_parent_dir}"
  fi
  if ! git clone "${SUAP_DEPLOY_GIT_URL}" "${SUAP_DEPLOY_DIR}"; then
    msg_error "Falha ao clonar o repositório suap_deploy."
    msg_error "Verifique se você tem acesso a: ${SUAP_DEPLOY_GIT_URL}"
    exit 1
  fi
  msg_action "Repositório clonado com sucesso em ${SUAP_DEPLOY_DIR}"
elif [ -d "${SUAP_DEPLOY_DIR}/.git" ]; then
  msg_skip "Repositório suap_deploy já existe em ${SUAP_DEPLOY_DIR}"
fi

# 8. Verificar que o Makefile existe
if [ ! -f "${SUAP_DEPLOY_DIR}/Makefile" ]; then
  msg_error "Makefile não encontrado em ${SUAP_DEPLOY_DIR}."
  msg_error "Verifique se o repositório suap_deploy está correto."
  exit 1
fi

# 8.1 Garantir que 'make' está instalado
if ! command -v make &>/dev/null; then
  msg_action "Comando 'make' não encontrado. Instalando..."
  case "${DISTRO_TYPE:-}" in
    deb)
      sudo apt-get update && sudo apt-get install -y make
      ;;
    rpm)
      sudo dnf install -y make
      ;;
    arch)
      sudo pacman -S --needed --noconfirm make
      ;;
    *)
      msg_error "'make' não está instalado e não foi possível instalar automaticamente."
      msg_error "Instale o pacote 'make' manualmente e tente novamente."
      exit 1
      ;;
  esac
  if ! command -v make &>/dev/null; then
    msg_error "Falha ao instalar 'make'. Verifique os erros acima."
    exit 1
  fi
fi

# 9. Configurar .env do suap_deploy se não existir
if [ ! -f "${SUAP_DEPLOY_DIR}/.env" ]; then
  msg_action "Arquivo .env não encontrado em ${SUAP_DEPLOY_DIR}. Executando 'make setup' para gerar..."
  cd "${SUAP_DEPLOY_DIR}"
  if ! make setup; then
    msg_error "Falha ao executar 'make setup' no suap_deploy."
    msg_error "Execute manualmente: cd ${SUAP_DEPLOY_DIR} && make setup"
    exit 1
  fi
  if [ ! -f "${SUAP_DEPLOY_DIR}/.env" ]; then
    msg_error "O comando 'make setup' não gerou o arquivo .env esperado."
    msg_error "Crie o .env manualmente em ${SUAP_DEPLOY_DIR} antes de prosseguir."
    exit 1
  fi
  msg_action ".env gerado com sucesso via 'make setup'."
else
  msg_skip ".env já existe em ${SUAP_DEPLOY_DIR}"
fi

# 10. Menu de ações
cd "${SUAP_DEPLOY_DIR}"

echo ""
echo "${GREEN}=== Gerenciamento Docker de Produção (suap_deploy) ===${NO_COLOR}"
echo ""
echo "  Diretório: ${SUAP_DEPLOY_DIR}"
echo ""
echo "  1) Fazer pull das imagens e iniciar serviços (modo registry)"
echo "  2) Fazer build local das imagens e iniciar (modo local)"
echo "  3) Apenas iniciar serviços (make up)"
echo "  4) Parar todos os serviços (make down)"
echo "  5) Reiniciar serviços (make restart)"
echo "  6) Ver status dos containers"
echo "  7) Ver logs"
echo "  8) Acessar shell do container web"
echo "  9) Executar backup do banco"
echo "  10) Executar restore do banco"
echo "  11) Executar setup interativo (make setup)"
echo "  0) Sair"
echo ""
read -rp "Escolha uma opção [0-11]: " PROD_CHOICE

case "${PROD_CHOICE}" in
  1)
    msg_action "Fazendo pull das imagens..."
    docker compose pull
    msg_action "Iniciando serviços..."
    make up
    echo ""
    msg_action "Serviços iniciados."
    make status
    ;;
  2)
    msg_action "Fazendo build das imagens a partir do código-fonte..."
    make build
    msg_action "Iniciando serviços..."
    make up
    echo ""
    msg_action "Serviços iniciados."
    make status
    ;;
  3)
    msg_action "Iniciando serviços..."
    make up
    echo ""
    make status
    ;;
  4)
    msg_action "Parando todos os serviços..."
    make down
    msg_action "Serviços parados."
    ;;
  5)
    msg_action "Reiniciando serviços..."
    make restart
    echo ""
    make status
    ;;
  6)
    make status
    ;;
  7)
    make logs
    ;;
  8)
    make bash
    ;;
  9)
    msg_action "Executando backup do banco..."
    make backup
    msg_action "Backup concluído. Arquivos em ${SUAP_DEPLOY_DIR}/deploy/backup/"
    ;;
  10)
    echo ""
    echo "  Dumps disponíveis em ${SUAP_DEPLOY_DIR}/deploy/backup/:"
    ls -1 "${SUAP_DEPLOY_DIR}/deploy/backup/"*.sql 2>/dev/null || echo "  (nenhum dump encontrado)"
    echo ""
    read -rp "Caminho do dump (ex: deploy/backup/dump_2024-01-01+12-00-00.sql): " DUMP_PATH
    if [ -z "${DUMP_PATH}" ]; then
      msg_error "Nenhum arquivo informado. Operação cancelada."
      exit 1
    fi
    if [ ! -f "${DUMP_PATH}" ]; then
      msg_error "Arquivo não encontrado: ${DUMP_PATH}"
      exit 1
    fi
    msg_action "Executando restore do banco..."
    make restore DUMP="${DUMP_PATH}"
    msg_action "Restore concluído."
    ;;
  11)
    msg_action "Executando setup interativo do suap_deploy..."
    make setup
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
echo "  make help             Listar todos os targets disponíveis"
echo "  make setup            Setup interativo (modo imagem, .env, nginx, certs)"
echo "  make build            Build local das imagens (base + app + pdf)"
echo "  make up               Iniciar serviços (respeita COMPOSE_PROFILES do .env)"
echo "  make down             Parar serviços"
echo "  make restart          Reiniciar (down + up)"
echo "  make status           Ver status dos containers"
echo "  make logs             Ver logs (SERVICES=\"web nginx\" para filtrar)"
echo "  make bash             Shell no container web"
echo "  make shell            Django manage.py shell"
echo "  make exec COMMAND=... Comando arbitrário no container web"
echo "  make begin            Criar DB + carga inicial (banco novo)"
echo "  make backup           Dump do banco em deploy/backup/"
echo "  make restore DUMP=... Restaurar dump"
echo "  make psql             Abrir psql usando credenciais do .env"
echo ""
echo "  Profiles controlam quais serviços sobem (variável COMPOSE_PROFILES no .env):"
echo "    default             = web + nginx + pdfprinter + celery"
echo "    celery-beat         = scheduler (apenas UM nó)"
echo "    celery-flower       = UI em :5555 (apenas UM nó)"
echo "    ai                  = serviço de IA"
echo "    local-db            = PostgreSQL em container (só homologação)"
echo "    local-redis         = Redis em container (só homologação)"
echo ""
