#!/bin/bash

### definicao de variaveis
PYTHON_VERSION=3.12
BASE_DIR=$HOME/Projetos
SUAP_DIR=$BASE_DIR/suap
GIT_URL=git@gitlab.ifma.edu.br:ndsis/suap.git

GREEN=`tput setaf 2`
NO_COLOR=`tput sgr0`

# instalar dependencias do sistema
echo "${GREEN}>>> Instalando as dependências do sistema operacional ${NO_COLOR}"
BASE="locales vim git build-essential language-pack-pt openssl curl libpq-dev tmpreaper swig"
LDAP="libldap2-dev libsasl2-dev"
PILLOW="libjpeg-dev libfreetype6-dev zlib1g-dev"
PYMSSQL="freetds-dev"
LXML="libxmlsec1-dev libxml2-dev libxslt1-dev"
WEASYPRINT="libpango-1.0-0 libpangoft2-1.0-0 libharfbuzz-subset0"
MAGIC="libmagic1"
PDF="qpdf ghostscript poppler-utils mupdf-tools wkhtmltopdf"
sudo apt update -qy; \
sudo apt install -y --fix-missing $BASE $LDAP $PILLOW $PYMSSQL $LXML $WEASYPRINT $MAGIC $PDF
sudo update-locale LANG=pt_BR.UTF-8
sudo timedatectl set-timezone America/Fortaleza

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
fi

# baixar codigo do suap
echo "${GREEN}>>> Baixando código SUAP ${NO_COLOR}"
mkdir -p $BASE_DIR
cd $BASE_DIR
if [ -d $SUAP_DIR/.git ]; then
	cd $SUAP_DIR
	git checkout master
	git pull
else
	git clone $GIT_URL
	cd $SUAP_DIR
fi

# gerar settings.py
cp $SUAP_DIR/suap/settings_sample.py $SUAP_DIR/suap/settings.py

# gerar .env
cp $SUAP_DIR/.env.dev.sample $SUAP_DIR/.env

# instalar python
echo "${GREEN}>>> Instalando Python ${NO_COLOR}" $PYTHON_VERSION
uv python install $PYTHON_VERSION

# criar virtualenv
echo "${GREEN}>>> Criando virtualenv ${NO_COLOR}" $VIRTUALENV_NAME
cd $SUAP_DIR
uv venv --python $PYTHON_VERSION

# instalar dependencias
echo "${GREEN}>>> Instalando libs SUAP ${NO_COLOR}"
cd $SUAP_DIR
uv sync --group dev

# mensagem final
echo "${GREEN}SUAP instalado com sucesso em $SUAP_DIR! ${NO_COLOR}"
echo "Para configurar as variáveis de ambiente, edite o arquivo ${GREEN}$SUAP_DIR/suap/.env ${NO_COLOR}"
echo "Para recarregar as configurações neste terminal, rode: ${GREEN}source $HOME/.bashrc${NO_COLOR}"
echo "Para rodar o servidor de desenvolvimento, rode: ${GREEN}uv python manage.py runserver 0.0.0.0:8000${NO_COLOR}"