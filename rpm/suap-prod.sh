#!/bin/bash
set -u

### definicao de variaveis
PYTHON_VERSION=3.12
BASE_DIR=/opt
SUAP_DIR=$BASE_DIR/suap
VENV_DIR=$BASE_DIR/venv
INSTALL_SCRIPT_DIR=$(cd "$(dirname $(readlink -f $0))" && cd .. && pwd)
GIT_URL=git@gitlab.ifma.edu.br:ndsis/suap.git

GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
NO_COLOR=`tput sgr0`

if [ "$EUID" -ne 0 ]; then
  echo "Este script deve ser executado como root. Use sudo ou entre como root."
  exit 1
fi

# instalar dependencias do sistema
echo "${GREEN}>>> Verificando dependências do sistema operacional ${NO_COLOR}"
BASE="glibc-langpack-pt_BR vim git openssl supervisor curl postgresql-devel tmpwatch swig cronie chrony gcc gcc-c++"
PYTHON="python3-devel python3-virtualenv python3-pip python3.12-devel"
LDAP="openldap-devel cyrus-sasl-devel"
PILLOW="libjpeg-turbo-devel freetype-devel zlib-devel"
PYMSSQL="freetds-devel"
LXML="xmlsec1-devel libxml2-devel libxslt-devel"
WEASYPRINT="pango harfbuzz"
MAGIC="file-libs"
PDF="qpdf ghostscript poppler-utils mupdf-tools wkhtmltopdf"

# Verificar se as dependências já foram instaladas
DEPS_INSTALLED=true
for pkg in $BASE $PYTHON $LDAP $PILLOW $PYMSSQL $LXML $WEASYPRINT $MAGIC $PDF; do
    if ! rpm -q "$pkg" &>/dev/null; then
        DEPS_INSTALLED=false
        break
    fi
done

if [ "$DEPS_INSTALLED" = false ]; then
    echo "${GREEN}>>> Instalando as dependências do sistema operacional ${NO_COLOR}"
	dnf upgrade -y
    dnf -y install $BASE $PYTHON $LDAP $PILLOW $PYMSSQL $LXML $WEASYPRINT $MAGIC $PDF
fi

# Verificar locale
CURRENT_LANG=$(localectl | grep -Eo 'LANG=[^ ]+' | cut -d'=' -f2)
if [ "$CURRENT_LANG" != "pt_BR.UTF-8" ]; then
    echo "${GREEN}>>> Configurando locale para pt_BR.UTF-8 ${NO_COLOR}"
    localectl set-locale LANG=pt_BR.UTF-8
else
    echo "${YELLOW}>>> Locale já configurado para pt_BR.UTF-8 ${NO_COLOR}"
fi

# Verificar timezone
CURRENT_TZ=$(timedatectl show -p Timezone --value)
if [ "$CURRENT_TZ" != "America/Fortaleza" ]; then
    echo "${GREEN}>>> Configurando timezone para America/Fortaleza ${NO_COLOR}"
    timedatectl set-timezone America/Fortaleza
else
    echo "${YELLOW}>>> Timezone já configurado para America/Fortaleza ${NO_COLOR}"
fi

# baixar codigo do suap
if [ ! -d "$SUAP_DIR/.git" ]; then
    echo "${GREEN}>>> Baixando código SUAP ${NO_COLOR}"
    mkdir -p "$BASE_DIR"
    cd "$BASE_DIR"
    git clone --depth 1 "$GIT_URL"
    cd "$SUAP_DIR"
else
    echo "${YELLOW}>>> Código SUAP já foi baixado, atualizando... ${NO_COLOR}"
    cd "$SUAP_DIR"
    git checkout master
    git pull
fi

# gerar settings.py
if [ ! -f "$SUAP_DIR/suap/settings.py" ]; then
    echo "${GREEN}>>> Gerando settings.py ${NO_COLOR}"
    cp "$SUAP_DIR/suap/settings_sample.py" "$SUAP_DIR/suap/settings.py"
else
    echo "${YELLOW}>>> settings.py já foi gerado ${NO_COLOR}"
fi

# gerar .env
if [ ! -f "$SUAP_DIR/.env" ]; then
    echo "${GREEN}>>> Gerando .env ${NO_COLOR}"
    cp "$SUAP_DIR/.env.dev.sample" "$SUAP_DIR/.env"
else
    echo "${YELLOW}>>> .env já foi gerado ${NO_COLOR}"
fi

# criar virtualenv
if [ ! -d "$VENV_DIR/suap" ]; then
    echo "${GREEN}>>> Criando virtualenv ${NO_COLOR}$VENV_DIR"
    mkdir -p "$VENV_DIR"
    python3.12 -m venv "$VENV_DIR/suap"
else
    echo "${YELLOW}>>> Virtualenv já foi criado ${NO_COLOR}"
fi

# instalar dependencias
echo "${GREEN}>>> Instalando/atualizando libs SUAP ${NO_COLOR}"
cd "$SUAP_DIR"
source "$VENV_DIR/suap/bin/activate"
pip install --upgrade pip
pip install "setuptools<82.0.0"
pip install . --group prod --no-cache-dir

# configurar supervisor
echo "${GREEN}>>> Configurando o Supervisor ${NO_COLOR}"
systemctl enable --now supervisord
mkdir -p $BASE_DIR/logs
mkdir -p $BASE_DIR/scripts

# Perguntar ao usuário o que configurar
echo ""
echo "Qual serviço você deseja configurar no Supervisor?"
echo "1) SUAP (servidor web)"
echo "2) Celery (processamento de tarefas assíncronas)"
echo "3) Ambos (SUAP + Celery)"
echo ""
read -p "Escolha uma opção (1/2/3): " supervisor_choice

# Copiar arquivos baseado na escolha do usuário
case $supervisor_choice in
	1)
		echo "${GREEN}>>> Configurando supervisor para SUAP ${NO_COLOR}"
		if [ -f "$INSTALL_SCRIPT_DIR/supervisor/suap.conf" ]; then			
			cp "$INSTALL_SCRIPT_DIR/supervisor/suap.conf" /etc/supervisord.d/suap.conf
			cp "$INSTALL_SCRIPT_DIR/supervisor/run_suap.sh" "$BASE_DIR/scripts/run_suap.sh"
			chmod +x "$BASE_DIR/scripts/run_suap.sh"
			echo "${GREEN}✓ SUAP configurado${NO_COLOR}"
		else
			echo "Erro: arquivo supervisor/suap.conf não encontrado em $INSTALL_SCRIPT_DIR"
			exit 1
		fi
		;;
	2)
		echo "${GREEN}>>> Configurando supervisor para Celery ${NO_COLOR}"
		if [ -f "$INSTALL_SCRIPT_DIR/supervisor/celery_worker.conf" ]; then
			cp "$INSTALL_SCRIPT_DIR/supervisor/celery_worker.conf" /etc/supervisord.d/celery_worker.conf
			cp "$INSTALL_SCRIPT_DIR/supervisor/run_celery_worker.sh" "$BASE_DIR/scripts/run_celery_worker.sh"
			chmod +x "$BASE_DIR/scripts/run_celery_worker.sh"
			cp "$INSTALL_SCRIPT_DIR/supervisor/celery_beat.conf" /etc/supervisord.d/celery_beat.conf
			cp "$INSTALL_SCRIPT_DIR/supervisor/run_celery_beat.sh" "$BASE_DIR/scripts/run_celery_beat.sh"
			chmod +x "$BASE_DIR/scripts/run_celery_beat.sh"
			cp "$INSTALL_SCRIPT_DIR/supervisor/celery_flower.conf" /etc/supervisord.d/celery_flower.conf
			cp "$INSTALL_SCRIPT_DIR/supervisor/run_celery_flower.sh" "$BASE_DIR/scripts/run_celery_flower.sh"
			chmod +x "$BASE_DIR/scripts/run_celery_flower.sh"
			echo "${GREEN}✓ Celery configurado${NO_COLOR}"
		else
			echo "Erro: arquivo supervisor/celery_worker.conf não encontrado em $INSTALL_SCRIPT_DIR"
			exit 1
		fi
		;;
	3)
		echo "${GREEN}>>> Configurando supervisor para SUAP e Celery ${NO_COLOR}"
		if [ -f "$INSTALL_SCRIPT_DIR/supervisor/suap.conf" ] && [ -f "$INSTALL_SCRIPT_DIR/supervisor/celery_worker.conf" ]; then
			cp "$INSTALL_SCRIPT_DIR/supervisor/suap.conf" /etc/supervisord.d/suap.conf
			cp "$INSTALL_SCRIPT_DIR/supervisor/run_suap.sh" "$BASE_DIR/scripts/run_suap.sh"
			chmod +x "$BASE_DIR/scripts/run_suap.sh"
			cp "$INSTALL_SCRIPT_DIR/supervisor/celery_worker.conf" /etc/supervisord.d/celery_worker.conf
			cp "$INSTALL_SCRIPT_DIR/supervisor/run_celery_worker.sh" "$BASE_DIR/scripts/run_celery_worker.sh"
			chmod +x "$BASE_DIR/scripts/run_celery_worker.sh"
			cp "$INSTALL_SCRIPT_DIR/supervisor/celery_beat.conf" /etc/supervisord.d/celery_beat.conf
			cp "$INSTALL_SCRIPT_DIR/supervisor/run_celery_beat.sh" "$BASE_DIR/scripts/run_celery_beat.sh"
			chmod +x "$BASE_DIR/scripts/run_celery_beat.sh"
			cp "$INSTALL_SCRIPT_DIR/supervisor/celery_flower.conf" /etc/supervisord.d/celery_flower.conf
			cp "$INSTALL_SCRIPT_DIR/supervisor/run_celery_flower.sh" "$BASE_DIR/scripts/run_celery_flower.sh"
			chmod +x "$BASE_DIR/scripts/run_celery_flower.sh"
			echo "${GREEN}✓ SUAP e Celery configurados${NO_COLOR}"
		else
			echo "Erro: um ou mais arquivos de configuração não foram encontrados em $INSTALL_SCRIPT_DIR/supervisor"
			exit 1
		fi
		;;
	*)
		echo "Opção inválida. Abortando."
		exit 1
		;;
esac

supervisorctl reread
supervisorctl update

# mensagem final
echo ""
echo "${GREEN}SUAP instalado com sucesso em $SUAP_DIR! ${NO_COLOR}"
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

