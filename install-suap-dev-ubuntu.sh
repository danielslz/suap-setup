#!/bin/bash

### definicao de variaveis
PYTHON_VERSION=3.12
BASE_DIR=$HOME/Projetos
SUAP_DIR=$BASE_DIR/suap
GIT_URL=git@gitlab.ifma.edu.br:ndsis/suap.git

GREEN=`tput setaf 2`
NO_COLOR=`tput sgr0`

# instalar dependencias do sistema
echo "${GREEN} >>> Instalando as dependências do sistema operacional ${NO_COLOR}"
sudo apt update
sudo apt install -y --fix-missing locales make build-essential \
        git libldap2-dev libsasl2-dev libpq-dev ghostscript \
        libjpeg-dev libfreetype6-dev zlib1g-dev language-pack-pt \
        freetds-dev libxmlsec1-dev libxml2-dev libxslt1-dev \
        libblas-dev liblapack-dev libatlas-base-dev gfortran \
        libglu1-mesa libcairo2 libcairo2-dev libcups2 libdbus-glib-1-2 libxinerama1 libsm6 \
        tmpreaper libgdk-pixbuf2.0-0 libffi-dev shared-mime-info \
        python3-cffi libpango-1.0-0 libpangocairo-1.0-0 \
        swig openssl curl qpdf wkhtmltopdf poppler-utils mupdf-tools
sudo update-locale LANG=pt_BR.UTF-8
sudo timedatectl set-timezone America/Fortaleza

# instalar uv
if ! [ -x "$(command -v uv)" ]; then
	echo "${GREEN} >>> Instalando o uv ${NO_COLOR}"
	curl -LsSf https://astral.sh/uv/install.sh | sh
	# adiciona variaveis ao bashrc
	echo 'eval "$(uv generate-shell-completion bash)"' >> $HOME/.bashrc
	# carrega novos valores bashrc
	source $HOME/.bashrc
	# testa se tem pyenv no path, caso contrario exporta agora
	if ! [ -x "$(command -v uv)" ]; then
		eval "$(uv generate-shell-completion bash)"
	fi
fi

# baixar codigo do suap
echo "${GREEN} >>> Baixando código SUAP ${NO_COLOR}"
mkdir $BASE_DIR
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
cp $SUAP_DIR/suap/.env.dev.sample $SUAP_DIR/suap/.env

# instalar python
echo "${GREEN} >>> Instalando Python ${NO_COLOR}" $PYTHON_VERSION
uv python install $PYTHON_VERSION

# criar virtualenv
echo "${GREEN} >>> Criando virtualenv ${NO_COLOR}" $VIRTUALENV_NAME
cd $SUAP_DIR
uv venv --python $PYTHON_VERSION

# instalar dependencias
echo "${GREEN} >>> Instalando libs SUAP ${NO_COLOR}"
cd $SUAP_DIR
uv sync --group dev

# mensagem final
echo "${GREEN} SUAP instalado com sucesso! ${NO_COLOR}"
echo "Para configurar as variáveis de ambiente, edite o arquivo ${GREEN}$SUAP_DIR/suap/.env ${NO_COLOR}"
echo "Para rodar o servidor de desenvolvimento, rode: ${GREEN}uv run -- suap runserver 0.0.0.0:8000${NO_COLOR}"