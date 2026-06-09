#!/bin/bash

### definicao de variaveis
PYTHON_VERSION=3.12
BASE_DIR=$HOME/Projetos
SUAP_DIR=$BASE_DIR/suap
VENV_DIR=$SUAP_DIR/.venv
SCRIPT_DIR=$(cd "$(dirname $(readlink -f $0))" && cd .. && pwd)
ENV_FILE="$SCRIPT_DIR/.env"

# Carregar GIT_URL do arquivo .env ou perguntar ao usuário
if [ -f "$ENV_FILE" ] && grep -q "^GIT_URL=" "$ENV_FILE"; then
	GIT_URL=$(grep "^GIT_URL=" "$ENV_FILE" | cut -d'=' -f2-)
else
	read -p "Informe a URL do repositório Git do SUAP: " GIT_URL
	if [ -z "$GIT_URL" ]; then
		echo "Erro: a URL do repositório não pode ser vazia."
		exit 1
	fi
	# Salvar no arquivo .env
	if [ -f "$ENV_FILE" ]; then
		echo "GIT_URL=$GIT_URL" >> "$ENV_FILE"
	else
		echo "GIT_URL=$GIT_URL" > "$ENV_FILE"
	fi
fi

GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
NO_COLOR=`tput sgr0`

# instalar dependencias do sistema
echo "${GREEN}>>> Verificando dependências do sistema operacional ${NO_COLOR}"
BASE="glibc-langpack-pt_BR vim git openssl curl postgresql-devel tmpwatch swig cronie chrony gcc gcc-c++"
LDAP="openldap-devel cyrus-sasl-devel"
PILLOW="libjpeg-turbo-devel freetype-devel zlib-devel"
PYMSSQL="freetds-devel"
LXML="xmlsec1-devel libxml2-devel libxslt-devel"
WEASYPRINT="pango harfbuzz"
MAGIC="file-libs"
PDF="qpdf ghostscript poppler-utils mupdf-tools wkhtmltopdf"

# Verificar se as dependências já foram instaladas
DEPS_INSTALLED=true
for pkg in $BASE $LDAP $PILLOW $PYMSSQL $LXML $WEASYPRINT $MAGIC $PDF; do
	if ! rpm -q "$pkg" &>/dev/null; then
		DEPS_INSTALLED=false
		break
	fi
done

if [ "$DEPS_INSTALLED" = false ]; then
	echo "${GREEN}>>> Instalando as dependências do sistema operacional ${NO_COLOR}"
	sudo dnf upgrade -y
	sudo dnf -y install $BASE $LDAP $PILLOW $PYMSSQL $LXML $WEASYPRINT $MAGIC $PDF
fi

# Verificar locale
CURRENT_LANG=$(localectl | grep "LANG=" | cut -d'=' -f2)
if [ "$CURRENT_LANG" != "pt_BR.UTF-8" ]; then
	echo "${GREEN}>>> Configurando locale para pt_BR.UTF-8 ${NO_COLOR}"
	sudo localectl set-locale LANG=pt_BR.UTF-8
else
	echo "${YELLOW}>>> Locale já configurado para pt_BR.UTF-8 ${NO_COLOR}"
fi

# Verificar timezone
CURRENT_TZ=$(timedatectl show -p Timezone --value)
if [ "$CURRENT_TZ" != "America/Fortaleza" ]; then
	echo "${GREEN}>>> Configurando timezone para America/Fortaleza ${NO_COLOR}"
	sudo timedatectl set-timezone America/Fortaleza
else
	echo "${YELLOW}>>> Timezone já configurado para America/Fortaleza ${NO_COLOR}"
fi

# instalar uv
if ! [ -x "$(command -v uv)" ]; then
	echo "${GREEN}>>> Instalando o uv ${NO_COLOR}"
	curl -LsSf https://astral.sh/uv/install.sh | sh
	# adiciona variaveis ao bashrc
	echo 'eval "$(uv generate-shell-completion bash)"' >> $HOME/.bashrc
	# carrega novos valores bashrc
	source $HOME/.bashrc
	# testa se tem uv no path, caso contrario exporta agora
	if ! [ -x "$(command -v uv)" ]; then
		source $HOME/.local/bin/env
		eval "$(uv generate-shell-completion bash)"
	fi
else
	echo "${YELLOW}>>> uv já foi instalado anteriormente ${NO_COLOR}"
fi

# baixar codigo do suap
if [ ! -d $SUAP_DIR/.git ]; then
	echo "${GREEN}>>> Baixando código SUAP ${NO_COLOR}"
	mkdir -p $BASE_DIR
	cd $BASE_DIR
	git clone $GIT_URL
	cd $SUAP_DIR
else
	echo "${YELLOW}>>> Código SUAP já foi baixado, atualizando... ${NO_COLOR}"
	cd $SUAP_DIR
	git checkout master
	git pull
fi

# gerar settings.py
if [ ! -f $SUAP_DIR/suap/settings.py ]; then
	echo "${GREEN}>>> Gerando settings.py ${NO_COLOR}"
	cp $SUAP_DIR/suap/settings_sample.py $SUAP_DIR/suap/settings.py
else
	echo "${YELLOW}>>> settings.py já foi gerado ${NO_COLOR}"
fi

# gerar .env
if [ ! -f $SUAP_DIR/.env ]; then
	echo "${GREEN}>>> Gerando .env ${NO_COLOR}"
	cp $SUAP_DIR/.env.dev.sample $SUAP_DIR/.env
else
	echo "${YELLOW}>>> .env já foi gerado ${NO_COLOR}"
fi

# instalar python
if ! uv python list | grep -q $PYTHON_VERSION; then
	echo "${GREEN}>>> Instalando Python ${NO_COLOR}" $PYTHON_VERSION
	uv python install $PYTHON_VERSION
else
	echo "${YELLOW}>>> Python $PYTHON_VERSION já foi instalado ${NO_COLOR}"
fi

# criar virtualenv
if [ ! -d $VENV_DIR ]; then
	echo "${GREEN}>>> Criando virtualenv ${NO_COLOR}"
	cd $SUAP_DIR
	uv venv --python $PYTHON_VERSION
else
	echo "${YELLOW}>>> Virtualenv já foi criado ${NO_COLOR}"
fi

# instalar dependencias
echo "${GREEN}>>> Instalando/atualizando libs SUAP ${NO_COLOR}"
cd $SUAP_DIR
uv sync --group dev

# mensagem final
echo "${GREEN}SUAP instalado/atualizado com sucesso em $SUAP_DIR! ${NO_COLOR}"
echo "Para recarregar as configurações neste terminal, rode: ${GREEN}source $HOME/.bashrc${NO_COLOR}"
echo "Para configurar as variáveis de ambiente, edite o arquivo ${GREEN}$SUAP_DIR/suap/.env ${NO_COLOR}"
echo "Para ir para a pasta do SUAP, rode: ${GREEN}cd $SUAP_DIR${NO_COLOR}"
echo "Para rodar o servidor de desenvolvimento, rode: ${GREEN}uv run python manage.py runserver 0.0.0.0:8000${NO_COLOR}"