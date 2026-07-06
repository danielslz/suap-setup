#!/bin/bash
set -u

### Determinar diretório do projeto
INSTALL_SCRIPT_DIR=$(cd "$(dirname $(readlink -f $0))" && cd .. && pwd)
ENV_FILE="$INSTALL_SCRIPT_DIR/.env"

# Source da biblioteca compartilhada
source "$INSTALL_SCRIPT_DIR/lib/common.sh"

# Verificar existência do .env
require_env_file "$ENV_FILE"

# Carregar variáveis do .env centralizado
load_env_file "$ENV_FILE"

# Elevar para root se necessário
if [ "$EUID" -ne 0 ]; then
  msg_action "Elevando permissões com sudo..."
  exec sudo bash "$0" "$@"
fi

# Garantir GIT_URL disponível
resolve_git_url "$ENV_FILE"

# Forçar DISTRO_TYPE para RPM (este script é específico para RPM)
DISTRO_TYPE="rpm"
export DISTRO_TYPE

# Definir diretório do Supervisor via função compartilhada
SUPERVISOR_CONF_DIR=$(get_supervisor_conf_dir)

# --- Instalar dependências do sistema ---
msg_action "Verificando dependências do sistema operacional"
BASE="glibc-langpack-pt vim git openssl supervisor curl postgresql-devel tmpwatch swig cronie chrony gcc gcc-c++"
PYTHON="python3-devel python3-virtualenv python3-pip python3.12-devel"
LDAP="openldap-devel cyrus-sasl-devel"
PILLOW="libjpeg-turbo-devel freetype-devel zlib-devel"
PYMSSQL="freetds-devel"
LXML="xmlsec1-devel libxml2-devel libxslt-devel"
WEASYPRINT="pango harfbuzz"
MAGIC="file-libs"
PDF="qpdf ghostscript poppler-utils mupdf wkhtmltopdf"

ALL_PACKAGES="$BASE $PYTHON $LDAP $PILLOW $PYMSSQL $LXML $WEASYPRINT $MAGIC $PDF"

if ! check_all_packages_installed $ALL_PACKAGES; then
    msg_action "Instalando as dependências do sistema operacional"
    dnf upgrade -y
    if ! dnf -y install $ALL_PACKAGES; then
        msg_error "Falha na instalação de pacotes do sistema."
        exit 1
    fi
else
    msg_skip "Todas as dependências do sistema já estão instaladas"
fi

# --- Configurar locale (RPM-specific: localectl) ---
CURRENT_LANG=$(localectl | grep -Eo 'LANG=[^ ]+' | cut -d'=' -f2)
if [ "$CURRENT_LANG" != "pt_BR.UTF-8" ]; then
    msg_action "Configurando locale para pt_BR.UTF-8"
    localectl set-locale LANG=pt_BR.UTF-8
else
    msg_skip "Locale já configurado para pt_BR.UTF-8"
fi

# --- Configurar timezone ---
CURRENT_TZ=$(timedatectl show -p Timezone --value)
if [ "$CURRENT_TZ" != "America/Fortaleza" ]; then
    msg_action "Configurando timezone para America/Fortaleza"
    timedatectl set-timezone America/Fortaleza
else
    msg_skip "Timezone já configurado para America/Fortaleza"
fi

# --- Baixar/atualizar código SUAP ---
if [ ! -d "$SUAP_DIR/.git" ]; then
    msg_action "Baixando código SUAP"
    mkdir -p "$BASE_DIR"
    cd "$BASE_DIR"
    git clone --depth 1 "$GIT_URL"
    cd "$SUAP_DIR"
else
    msg_skip "Código SUAP já foi baixado, atualizando..."
    cd "$SUAP_DIR"
    git checkout master
    git pull
fi

# --- Gerar settings.py ---
if [ ! -f "$SUAP_DIR/suap/settings.py" ]; then
    msg_action "Gerando settings.py"
    cp "$SUAP_DIR/suap/settings_sample.py" "$SUAP_DIR/suap/settings.py"
else
    msg_skip "settings.py já foi gerado"
fi

# --- Gerar .env do SUAP ---
if [ ! -f "$SUAP_DIR/.env" ]; then
    msg_action "Gerando .env"
    cp "$SUAP_DIR/.env.dev.sample" "$SUAP_DIR/.env"
else
    msg_skip ".env já foi gerado"
fi

# --- Copiar .env centralizado para BASE_DIR (usado pelos runners do Supervisor) ---
msg_action "Copiando .env para ${BASE_DIR}/.env (usado pelos runners do Supervisor)"
cp "$ENV_FILE" "$BASE_DIR/.env"

# --- Instalar UV (se não disponível no PATH) ---
if command -v uv &>/dev/null; then
    msg_skip "UV já está instalado"
elif [ -x "${HOME}/.cargo/bin/uv" ]; then
    msg_skip "UV encontrado em ~/.cargo/bin/uv, adicionando ao PATH"
    export PATH="${HOME}/.cargo/bin:${PATH}"
elif [ -x "${HOME}/.local/bin/uv" ]; then
    msg_skip "UV encontrado em ~/.local/bin/uv, adicionando ao PATH"
    export PATH="${HOME}/.local/bin:${PATH}"
else
    msg_action "Instalando UV (gerenciador de pacotes Python)"
    curl -LsSf https://astral.sh/uv/install.sh | sh

    if [ -f "${HOME}/.local/bin/env" ]; then
        source "${HOME}/.local/bin/env"
    fi
fi

# --- Instalar Python via UV (se não disponível) ---
if ! uv python list --only-installed 2>/dev/null | grep -q "${PYTHON_VERSION}"; then
    msg_action "Instalando Python ${PYTHON_VERSION} via UV"
    uv python install "${PYTHON_VERSION}"
else
    msg_skip "Python ${PYTHON_VERSION} já está instalado"
fi

# --- Criar virtualenv com UV ---
if [ ! -d "$VENV_DIR" ]; then
    msg_action "Criando virtualenv em $VENV_DIR"
    mkdir -p "$(dirname "$VENV_DIR")"
    uv venv --python "${PYTHON_VERSION}" "$VENV_DIR"
else
    msg_skip "Virtualenv já existe em $VENV_DIR"
fi

# --- Instalar dependências Python via UV ---
msg_action "Instalando/atualizando libs SUAP"
cd "$SUAP_DIR"
# UV_PROJECT_ENVIRONMENT indica ao uv sync onde instalar (em vez do .venv local)
export UV_PROJECT_ENVIRONMENT="$VENV_DIR"
if [ -f "$SUAP_DIR/pyproject.toml" ]; then
    if ! uv sync --group prod; then
        msg_error "Falha na instalação de dependências Python."
        exit 1
    fi
elif [ -d "$SUAP_DIR/requirements" ]; then
    if ! uv pip install --python "$VENV_DIR/bin/python" -r requirements/production.txt; then
        msg_error "Falha na instalação de dependências Python."
        exit 1
    fi
else
    msg_error "Não foi encontrado o pyproject.toml nem a pasta requirements em $SUAP_DIR"
    exit 1
fi

# --- Coletar arquivos estáticos ---
msg_action "Coletando arquivos estáticos (collectstatic)"
"$VENV_DIR/bin/python" manage.py collectstatic --noinput

# --- Configurar Supervisor (RPM-specific: supervisord) ---
msg_action "Configurando o Supervisor"
systemctl enable --now supervisord
mkdir -p "$BASE_DIR/logs"
mkdir -p "$BASE_DIR/scripts"

# Garantir que o usuário de serviço existe antes de configurar o Supervisor
WEBUSER="nginx"
if ! id "$WEBUSER" &>/dev/null; then
    msg_action "Criando usuário $WEBUSER para execução dos serviços"
    useradd -r -s /sbin/nologin "$WEBUSER"
fi

# Menu do Supervisor
echo ""
echo "Qual serviço você deseja configurar no Supervisor?"
echo "1) SUAP (servidor web)"
echo "2) Celery (processamento de tarefas assíncronas)"
echo "3) Ambos (SUAP + Celery)"
echo ""
read -rp "Escolha uma opção (1/2/3): " supervisor_choice

# Copiar arquivos baseado na escolha do usuário
FILES_COPIED=false

case $supervisor_choice in
    1)
        msg_action "Configurando supervisor para SUAP"
        if [ -f "$INSTALL_SCRIPT_DIR/supervisor/suap.conf" ]; then
            cp "$INSTALL_SCRIPT_DIR/supervisor/suap.conf" "$SUPERVISOR_CONF_DIR/suap.ini"
            cp "$INSTALL_SCRIPT_DIR/supervisor/run_suap.sh" "$BASE_DIR/scripts/run_suap.sh"
            chmod +x "$BASE_DIR/scripts/run_suap.sh"
            FILES_COPIED=true
            msg_action "✓ SUAP configurado"
        else
            msg_error "Arquivo supervisor/suap.conf não encontrado em $INSTALL_SCRIPT_DIR"
            exit 1
        fi
        ;;
    2)
        msg_action "Configurando supervisor para Celery"
        if [ -f "$INSTALL_SCRIPT_DIR/supervisor/celery_worker.conf" ]; then
            cp "$INSTALL_SCRIPT_DIR/supervisor/celery_worker.conf" "$SUPERVISOR_CONF_DIR/celery_worker.ini"
            cp "$INSTALL_SCRIPT_DIR/supervisor/run_celery_worker.sh" "$BASE_DIR/scripts/run_celery_worker.sh"
            chmod +x "$BASE_DIR/scripts/run_celery_worker.sh"
            cp "$INSTALL_SCRIPT_DIR/supervisor/celery_beat.conf" "$SUPERVISOR_CONF_DIR/celery_beat.ini"
            cp "$INSTALL_SCRIPT_DIR/supervisor/run_celery_beat.sh" "$BASE_DIR/scripts/run_celery_beat.sh"
            chmod +x "$BASE_DIR/scripts/run_celery_beat.sh"
            cp "$INSTALL_SCRIPT_DIR/supervisor/celery_flower.conf" "$SUPERVISOR_CONF_DIR/celery_flower.ini"
            cp "$INSTALL_SCRIPT_DIR/supervisor/run_celery_flower.sh" "$BASE_DIR/scripts/run_celery_flower.sh"
            chmod +x "$BASE_DIR/scripts/run_celery_flower.sh"
            FILES_COPIED=true
            msg_action "✓ Celery configurado"
        else
            msg_error "Arquivo supervisor/celery_worker.conf não encontrado em $INSTALL_SCRIPT_DIR"
            exit 1
        fi
        ;;
    3)
        msg_action "Configurando supervisor para SUAP e Celery"
        if [ -f "$INSTALL_SCRIPT_DIR/supervisor/suap.conf" ] && [ -f "$INSTALL_SCRIPT_DIR/supervisor/celery_worker.conf" ]; then
            cp "$INSTALL_SCRIPT_DIR/supervisor/suap.conf" "$SUPERVISOR_CONF_DIR/suap.ini"
            cp "$INSTALL_SCRIPT_DIR/supervisor/run_suap.sh" "$BASE_DIR/scripts/run_suap.sh"
            chmod +x "$BASE_DIR/scripts/run_suap.sh"
            cp "$INSTALL_SCRIPT_DIR/supervisor/celery_worker.conf" "$SUPERVISOR_CONF_DIR/celery_worker.ini"
            cp "$INSTALL_SCRIPT_DIR/supervisor/run_celery_worker.sh" "$BASE_DIR/scripts/run_celery_worker.sh"
            chmod +x "$BASE_DIR/scripts/run_celery_worker.sh"
            cp "$INSTALL_SCRIPT_DIR/supervisor/celery_beat.conf" "$SUPERVISOR_CONF_DIR/celery_beat.ini"
            cp "$INSTALL_SCRIPT_DIR/supervisor/run_celery_beat.sh" "$BASE_DIR/scripts/run_celery_beat.sh"
            chmod +x "$BASE_DIR/scripts/run_celery_beat.sh"
            cp "$INSTALL_SCRIPT_DIR/supervisor/celery_flower.conf" "$SUPERVISOR_CONF_DIR/celery_flower.ini"
            cp "$INSTALL_SCRIPT_DIR/supervisor/run_celery_flower.sh" "$BASE_DIR/scripts/run_celery_flower.sh"
            chmod +x "$BASE_DIR/scripts/run_celery_flower.sh"
            FILES_COPIED=true
            msg_action "✓ SUAP e Celery configurados"
        else
            msg_error "Um ou mais arquivos de configuração não foram encontrados em $INSTALL_SCRIPT_DIR/supervisor"
            exit 1
        fi
        ;;
    *)
        msg_error "Opção inválida. Abortando."
        exit 1
        ;;
esac

if [ "$FILES_COPIED" = "true" ]; then
    # Ajustar usuário nos .ini do Supervisor (www-data → nginx para RPM)
    sed -i 's/www-data/nginx/g' "$SUPERVISOR_CONF_DIR"/*.ini 2>/dev/null || true
    # Ajustar paths nos .ini para usar BASE_DIR correto
    sed -i "s|/opt/scripts|${BASE_DIR}/scripts|g" "$SUPERVISOR_CONF_DIR"/*.ini 2>/dev/null || true
    sed -i "s|/opt/suap|${SUAP_DIR}|g" "$SUPERVISOR_CONF_DIR"/*.ini 2>/dev/null || true
    sed -i "s|/opt/logs|${BASE_DIR}/logs|g" "$SUPERVISOR_CONF_DIR"/*.ini 2>/dev/null || true
    supervisorctl reread
    supervisorctl update
else
    msg_skip "Nenhum arquivo copiado, pulando supervisorctl"
fi

# --- Corrigir permissões ---
chown -R "$WEBUSER:$WEBUSER" "$SUAP_DIR"
chown -R "$WEBUSER:$WEBUSER" "$BASE_DIR/logs"
chown -R "$WEBUSER:$WEBUSER" "$VENV_DIR"

# --- Mensagem final ---
echo ""
msg_action "SUAP instalado com sucesso em $SUAP_DIR!"
echo ""
echo "Próximos passos:"
echo "1. Para recarregar as configurações neste terminal: ${GREEN}source $HOME/.bashrc${NO_COLOR}"
echo "2. Para configurar as variáveis de ambiente, edite: ${GREEN}$SUAP_DIR/suap/.env ${NO_COLOR}"
echo "3. Para ir para a pasta do SUAP: ${GREEN}cd $SUAP_DIR${NO_COLOR}"
case $supervisor_choice in
    1)
        echo "4. Para rodar o SUAP: ${GREEN}supervisorctl start suap${NO_COLOR}"
        ;;
    2)
        echo "4. Para rodar todos os serviços Celery:"
        echo "   - Worker: ${GREEN}supervisorctl start celery-worker${NO_COLOR}"
        echo "   - Beat: ${GREEN}supervisorctl start celery-beat${NO_COLOR}"
        echo "   - Flower: ${GREEN}supervisorctl start celery-flower${NO_COLOR}"
        echo "   - Todos: ${GREEN}supervisorctl start celery-worker celery-beat celery-flower${NO_COLOR}"
        ;;
    3)
        echo "4. Para rodar SUAP e todos os serviços Celery:"
        echo "   - SUAP: ${GREEN}supervisorctl start suap${NO_COLOR}"
        echo "   - Celery Worker: ${GREEN}supervisorctl start celery-worker${NO_COLOR}"
        echo "   - Celery Beat: ${GREEN}supervisorctl start celery-beat${NO_COLOR}"
        echo "   - Celery Flower: ${GREEN}supervisorctl start celery-flower${NO_COLOR}"
        echo "   - Todos: ${GREEN}supervisorctl start all${NO_COLOR}"
        ;;
esac
echo ""
echo "${YELLOW}Para ajustar configurações (workers, Redis, etc.), edite:${NO_COLOR} ${GREEN}$BASE_DIR/.env${NO_COLOR}"
echo ""
