#!/bin/bash
set -u

# deb/suap-prod.sh - Configuração do ambiente de produção SUAP (Debian/Ubuntu)
# Utiliza lib/common.sh para funções compartilhadas e .env para variáveis centralizadas.

# --- 1. Source lib/common.sh ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- 2. Carregar variáveis centralizadas ---
load_env_file "${SCRIPT_DIR}/.env"

# Definir valores padrão de produção (caso não estejam no .env)
: "${BASE_DIR:=/opt}"
: "${SUAP_DIR:=$BASE_DIR/suap}"
: "${VENV_DIR:=$BASE_DIR/venv}"
: "${PYTHON_VERSION:=3.12}"

export DISTRO_TYPE="deb"

# --- 3. Validar execução como root ---
if [ "$EUID" -ne 0 ]; then
  msg_error "Este script deve ser executado como root. Use sudo ou entre como root."
  exit 1
fi

# --- 4. Resolver GIT_URL ---
resolve_git_url "${SCRIPT_DIR}/.env"

# --- 5. Verificar e instalar dependências do sistema ---
PACKAGES=(
  # Base e utilitários
  locales vim git build-essential language-pack-pt cron ntpdate supervisor openssl curl libpq-dev tmpreaper swig
  # Python
  python3-dev python3-venv python3-pip
  # LDAP
  libldap2-dev libsasl2-dev
  # Pillow
  libjpeg-dev libfreetype6-dev zlib1g-dev
  # PyMSSQL
  freetds-dev
  # lxml
  libxmlsec1-dev libxml2-dev libxslt1-dev
  # WeasyPrint
  libpango-1.0-0 libpangoft2-1.0-0 libharfbuzz-subset0
  # Magic
  libmagic1
  # PDF
  qpdf ghostscript poppler-utils mupdf-tools wkhtmltopdf
)

msg_action "Verificando dependências do sistema operacional"
if ! check_all_packages_installed "${PACKAGES[@]}"; then
  msg_action "Instalando dependências do sistema operacional"
  apt update -qy
  apt upgrade -y
  apt install -y --fix-missing "${PACKAGES[@]}"
else
  msg_skip "Dependências do sistema já estão instaladas"
fi

# --- 6. Configurar locale e timezone ---
CURRENT_LOCALE=$(locale 2>/dev/null | grep "^LANG=" | cut -d= -f2 || echo "")
if [ "${CURRENT_LOCALE}" != "pt_BR.UTF-8" ]; then
  msg_action "Configurando locale para pt_BR.UTF-8"
  update-locale LANG=pt_BR.UTF-8
else
  msg_skip "Locale já configurado para pt_BR.UTF-8"
fi

CURRENT_TZ=$(timedatectl show -p Timezone --value 2>/dev/null || echo "")
if [ "${CURRENT_TZ}" != "America/Fortaleza" ]; then
  msg_action "Configurando timezone para America/Fortaleza"
  timedatectl set-timezone America/Fortaleza
else
  msg_skip "Timezone já configurado para America/Fortaleza"
fi

# --- 7. Clone/pull do código SUAP (com --depth 1) ---
if [ ! -d "${SUAP_DIR}/.git" ]; then
  msg_action "Baixando código SUAP"
  cd "${BASE_DIR}"
  git clone --depth 1 "${GIT_URL}"
  cd "${SUAP_DIR}"
else
  msg_skip "Código SUAP já foi baixado, atualizando..."
  cd "${SUAP_DIR}"
  git checkout master
  git pull
fi

# --- 8. Gerar settings.py e .env a partir dos samples ---
if [ ! -f "${SUAP_DIR}/suap/settings.py" ]; then
  msg_action "Gerando settings.py"
  cp "${SUAP_DIR}/suap/settings_sample.py" "${SUAP_DIR}/suap/settings.py"
else
  msg_skip "settings.py já foi gerado"
fi

if [ ! -f "${SUAP_DIR}/.env" ]; then
  msg_action "Gerando .env"
  cp "${SUAP_DIR}/.env.dev.sample" "${SUAP_DIR}/.env"
else
  msg_skip ".env já foi gerado"
fi

# --- 9. Criar virtualenv com python3 -m venv ---
if [ ! -d "${VENV_DIR}/suap" ]; then
  msg_action "Criando virtualenv em ${VENV_DIR}/suap"
  mkdir -p "${VENV_DIR}"
  python3 -m venv "${VENV_DIR}/suap"
else
  msg_skip "Virtualenv já foi criado"
fi

# --- 10. Instalar/atualizar dependências via pip ---
msg_action "Instalando/atualizando libs SUAP"
cd "${SUAP_DIR}"
source "${VENV_DIR}/suap/bin/activate"
pip install --upgrade pip
if [ -f "${SUAP_DIR}/pyproject.toml" ]; then
  pip install . --group prod --no-cache-dir
elif [ -d "${SUAP_DIR}/requirements" ]; then
  pip install -r requirements/production.txt --no-cache-dir
else
  msg_error "Não foi encontrado o pyproject.toml nem a pasta requirements em ${SUAP_DIR}"
  exit 1
fi
pip install "setuptools<82.0.0"

# --- 11. Configurar Supervisor ---
msg_action "Configurando o Supervisor"
mkdir -p "${BASE_DIR}/logs"
mkdir -p "${BASE_DIR}/scripts"

SUPERVISOR_CONF_DIR=$(get_supervisor_conf_dir)

# Menu do Supervisor (SUAP / Celery / Ambos)
echo ""
echo "Qual serviço você deseja configurar no Supervisor?"
echo "1) SUAP (servidor web)"
echo "2) Celery (processamento de tarefas assíncronas)"
echo "3) Ambos (SUAP + Celery)"
echo ""
read -rp "Escolha uma opção (1/2/3): " supervisor_choice

case ${supervisor_choice} in
  1)
    msg_action "Configurando supervisor para SUAP"
    if [ -f "${SCRIPT_DIR}/supervisor/suap.conf" ]; then
      cp "${SCRIPT_DIR}/supervisor/suap.conf" "${SUPERVISOR_CONF_DIR}/suap.conf"
      cp "${SCRIPT_DIR}/supervisor/run_suap.sh" "${BASE_DIR}/scripts/run_suap.sh"
      chmod +x "${BASE_DIR}/scripts/run_suap.sh"
      msg_action "✓ SUAP configurado"
    else
      msg_error "Arquivo supervisor/suap.conf não encontrado em ${SCRIPT_DIR}"
      exit 1
    fi
    ;;
  2)
    msg_action "Configurando supervisor para Celery"
    if [ -f "${SCRIPT_DIR}/supervisor/celery_worker.conf" ]; then
      cp "${SCRIPT_DIR}/supervisor/celery_worker.conf" "${SUPERVISOR_CONF_DIR}/celery_worker.conf"
      cp "${SCRIPT_DIR}/supervisor/run_celery_worker.sh" "${BASE_DIR}/scripts/run_celery_worker.sh"
      chmod +x "${BASE_DIR}/scripts/run_celery_worker.sh"
      cp "${SCRIPT_DIR}/supervisor/celery_beat.conf" "${SUPERVISOR_CONF_DIR}/celery_beat.conf"
      cp "${SCRIPT_DIR}/supervisor/run_celery_beat.sh" "${BASE_DIR}/scripts/run_celery_beat.sh"
      chmod +x "${BASE_DIR}/scripts/run_celery_beat.sh"
      cp "${SCRIPT_DIR}/supervisor/celery_flower.conf" "${SUPERVISOR_CONF_DIR}/celery_flower.conf"
      cp "${SCRIPT_DIR}/supervisor/run_celery_flower.sh" "${BASE_DIR}/scripts/run_celery_flower.sh"
      chmod +x "${BASE_DIR}/scripts/run_celery_flower.sh"
      msg_action "✓ Celery configurado"
    else
      msg_error "Arquivo supervisor/celery_worker.conf não encontrado em ${SCRIPT_DIR}"
      exit 1
    fi
    ;;
  3)
    msg_action "Configurando supervisor para SUAP e Celery"
    if [ -f "${SCRIPT_DIR}/supervisor/suap.conf" ] && [ -f "${SCRIPT_DIR}/supervisor/celery_worker.conf" ]; then
      cp "${SCRIPT_DIR}/supervisor/suap.conf" "${SUPERVISOR_CONF_DIR}/suap.conf"
      cp "${SCRIPT_DIR}/supervisor/run_suap.sh" "${BASE_DIR}/scripts/run_suap.sh"
      chmod +x "${BASE_DIR}/scripts/run_suap.sh"
      cp "${SCRIPT_DIR}/supervisor/celery_worker.conf" "${SUPERVISOR_CONF_DIR}/celery_worker.conf"
      cp "${SCRIPT_DIR}/supervisor/run_celery_worker.sh" "${BASE_DIR}/scripts/run_celery_worker.sh"
      chmod +x "${BASE_DIR}/scripts/run_celery_worker.sh"
      cp "${SCRIPT_DIR}/supervisor/celery_beat.conf" "${SUPERVISOR_CONF_DIR}/celery_beat.conf"
      cp "${SCRIPT_DIR}/supervisor/run_celery_beat.sh" "${BASE_DIR}/scripts/run_celery_beat.sh"
      chmod +x "${BASE_DIR}/scripts/run_celery_beat.sh"
      cp "${SCRIPT_DIR}/supervisor/celery_flower.conf" "${SUPERVISOR_CONF_DIR}/celery_flower.conf"
      cp "${SCRIPT_DIR}/supervisor/run_celery_flower.sh" "${BASE_DIR}/scripts/run_celery_flower.sh"
      chmod +x "${BASE_DIR}/scripts/run_celery_flower.sh"
      msg_action "✓ SUAP e Celery configurados"
    else
      msg_error "Um ou mais arquivos de configuração não foram encontrados em ${SCRIPT_DIR}/supervisor"
      exit 1
    fi
    ;;
  *)
    msg_error "Opção inválida. Abortando."
    exit 1
    ;;
esac

# --- 12. Aplicar configurações do Supervisor ---
supervisorctl reread
supervisorctl update

# --- 13. Ajustar permissões ---
chown -R www-data:www-data "${SUAP_DIR}"
chown -R www-data:www-data "${BASE_DIR}/logs"
chown -R www-data:www-data "${VENV_DIR}/suap"

# --- 14. Mensagem final com próximos passos ---
echo ""
msg_action "SUAP instalado com sucesso em ${SUAP_DIR}!"
echo ""
echo "Próximos passos:"
echo "  1. Recarregue as configurações: ${GREEN}source ${HOME}/.bashrc${NO_COLOR}"
echo "  2. Edite as variáveis de ambiente: ${GREEN}nano ${SUAP_DIR}/suap/.env${NO_COLOR}"
echo "  3. Acesse o diretório do SUAP:  ${GREEN}cd ${SUAP_DIR}${NO_COLOR}"
case ${supervisor_choice} in
  1)
    echo "  4. Para rodar o SUAP: ${GREEN}supervisorctl start suap${NO_COLOR}"
    ;;
  2)
    echo "  4. Para rodar todos os serviços Celery:"
    echo "     - Worker: ${GREEN}supervisorctl start celery-worker${NO_COLOR}"
    echo "     - Beat: ${GREEN}supervisorctl start celery-beat${NO_COLOR}"
    echo "     - Flower: ${GREEN}supervisorctl start celery-flower${NO_COLOR}"
    echo "     - Todos: ${GREEN}supervisorctl start celery-worker celery-beat celery-flower${NO_COLOR}"
    ;;
  3)
    echo "  4. Para rodar SUAP e todos os serviços Celery:"
    echo "     - SUAP: ${GREEN}supervisorctl start suap${NO_COLOR}"
    echo "     - Celery Worker: ${GREEN}supervisorctl start celery-worker${NO_COLOR}"
    echo "     - Celery Beat: ${GREEN}supervisorctl start celery-beat${NO_COLOR}"
    echo "     - Celery Flower: ${GREEN}supervisorctl start celery-flower${NO_COLOR}"
    echo "     - Todos: ${GREEN}supervisorctl start all${NO_COLOR}"
    ;;
esac
echo ""
