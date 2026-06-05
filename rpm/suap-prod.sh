#!/bin/bash

### definicao de variaveis
PYTHON_VERSION=3.12
BASE_DIR=/opt
SUAP_DIR=$BASE_DIR/suap
VENV_DIR=$SUAP_DIR/.venv
INSTALL_SCRIPT_DIR=$(dirname $(readlink -f $0))
GIT_URL=git@gitlab.ifma.edu.br:ndsis/suap.git

GREEN=`tput setaf 2`
NO_COLOR=`tput sgr0`

# instalar dependencias do sistema
echo "${GREEN}>>> Instalando as dependências do sistema operacional ${NO_COLOR}"
BASE="glibc-langpack-pt_BR vim git openssl supervisor curl postgresql-devel tmpwatch swig cronie chrony"
LDAP="openldap-devel cyrus-sasl-devel"
PILLOW="libjpeg-turbo-devel freetype-devel zlib-devel"
PYMSSQL="freetds-devel"
LXML="xmlsec1-devel libxml2-devel libxslt-devel"
WEASYPRINT="pango harfbuzz"
MAGIC="file-libs"
PDF="qpdf ghostscript poppler-utils mupdf-tools wkhtmltopdf"
sudo dnf -y install $BASE $LDAP $PILLOW $PYMSSQL $LXML $WEASYPRINT $MAGIC $PDF
sudo localectl set-locale LANG=pt_BR.UTF-8
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
	git clone --depth 1 $GIT_URL
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
uv sync --group prod

# configurar supervisor
echo "${GREEN}>>> Configurando o Supervisor ${NO_COLOR}"
mkdir -p $BASE_DIR/logs
mkdir -p $BASE_DIR/scripts

# Copiar arquivos baseado na escolha do usuário
case $supervisor_choice in
	1)
		echo "${GREEN}>>> Configurando supervisor para SUAP ${NO_COLOR}"
		if [ -f "$INSTALL_SCRIPT_DIR/supervisor/suap.conf" ]; then
			sudo cp "$INSTALL_SCRIPT_DIR/supervisor/suap.conf" /etc/supervisor/conf.d/suap.conf
			sudo cp "$INSTALL_SCRIPT_DIR/supervisor/run_suap.sh" "$BASE_DIR/scripts/run_suap.sh"
			sudo chmod +x "$BASE_DIR/scripts/run_suap.sh"
			echo "${GREEN}✓ SUAP configurado${NO_COLOR}"
		else
			echo "Erro: arquivo supervisor/suap.conf não encontrado em $INSTALL_SCRIPT_DIR"
			exit 1
		fi
		;;
	2)
		echo "${GREEN}>>> Configurando supervisor para Celery ${NO_COLOR}"
		if [ -f "$INSTALL_SCRIPT_DIR/supervisor/celery_worker.conf" ]; then
			sudo cp "$INSTALL_SCRIPT_DIR/supervisor/celery_worker.conf" /etc/supervisor/conf.d/celery_worker.conf
			sudo cp "$INSTALL_SCRIPT_DIR/supervisor/run_celery_worker.sh" "$BASE_DIR/scripts/run_celery_worker.sh"
			sudo chmod +x "$BASE_DIR/scripts/run_celery_worker.sh"
			sudo cp "$INSTALL_SCRIPT_DIR/supervisor/celery_beat.conf" /etc/supervisor/conf.d/celery_beat.conf
			sudo cp "$INSTALL_SCRIPT_DIR/supervisor/run_celery_beat.sh" "$BASE_DIR/scripts/run_celery_beat.sh"
			sudo chmod +x "$BASE_DIR/scripts/run_celery_beat.sh"
			sudo cp "$INSTALL_SCRIPT_DIR/supervisor/celery_flower.conf" /etc/supervisor/conf.d/celery_flower.conf
			sudo cp "$INSTALL_SCRIPT_DIR/supervisor/run_celery_flower.sh" "$BASE_DIR/scripts/run_celery_flower.sh"
			sudo chmod +x "$BASE_DIR/scripts/run_celery_flower.sh"
			echo "${GREEN}✓ Celery configurado${NO_COLOR}"
		else
			echo "Erro: arquivo supervisor/celery_worker.conf não encontrado em $INSTALL_SCRIPT_DIR"
			exit 1
		fi
		;;
	3)
		echo "${GREEN}>>> Configurando supervisor para SUAP e Celery ${NO_COLOR}"
		if [ -f "$INSTALL_SCRIPT_DIR/supervisor/suap.conf" ] && [ -f "$INSTALL_SCRIPT_DIR/supervisor/celery_worker.conf" ]; then
			sudo cp "$INSTALL_SCRIPT_DIR/supervisor/suap.conf" /etc/supervisor/conf.d/suap.conf
			sudo cp "$INSTALL_SCRIPT_DIR/supervisor/run_suap.sh" "$BASE_DIR/scripts/run_suap.sh"
			sudo chmod +x "$BASE_DIR/scripts/run_suap.sh"
			sudo cp "$INSTALL_SCRIPT_DIR/supervisor/celery_worker.conf" /etc/supervisor/conf.d/celery_worker.conf
			sudo cp "$INSTALL_SCRIPT_DIR/supervisor/run_celery_worker.sh" "$BASE_DIR/scripts/run_celery_worker.sh"
			sudo chmod +x "$BASE_DIR/scripts/run_celery_worker.sh"
			sudo cp "$INSTALL_SCRIPT_DIR/supervisor/celery_beat.conf" /etc/supervisor/conf.d/celery_beat.conf
			sudo cp "$INSTALL_SCRIPT_DIR/supervisor/run_celery_beat.sh" "$BASE_DIR/scripts/run_celery_beat.sh"
			sudo chmod +x "$BASE_DIR/scripts/run_celery_beat.sh"
			sudo cp "$INSTALL_SCRIPT_DIR/supervisor/celery_flower.conf" /etc/supervisor/conf.d/celery_flower.conf
			sudo cp "$INSTALL_SCRIPT_DIR/supervisor/run_celery_flower.sh" "$BASE_DIR/scripts/run_celery_flower.sh"
			sudo chmod +x "$BASE_DIR/scripts/run_celery_flower.sh"
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

sudo supervisorctl reread
sudo supervisorctl update

# mensagem final
echo ""
echo "${GREEN}SUAP instalado com sucesso em $SUAP_DIR! ${NO_COLOR}"
echo ""
echo "Próximos passos:"
echo "1. Para recarregar as configurações neste terminal: ${GREEN}source $HOME/.bashrc${NO_COLOR}"
echo "2. Para configurar as variáveis de ambiente, edite: ${GREEN}$SUAP_DIR/suap/.env ${NO_COLOR}"
echo "3. Para ir para a pasta do SUAP: ${GREEN}cd $SUAP_DIR${NO_COLOR}"
echo ""
case $supervisor_choice in
	1)
		echo "4. Para rodar o SUAP: ${GREEN}sudo supervisorctl start suap${NO_COLOR}"
		;;
	2)
		echo "4. Para rodar todos os serviços Celery:"
		echo "   - Worker: ${GREEN}sudo supervisorctl start celery-worker${NO_COLOR}"
		echo "   - Beat: ${GREEN}sudo supervisorctl start celery-beat${NO_COLOR}"
		echo "   - Flower: ${GREEN}sudo supervisorctl start celery-flower${NO_COLOR}"
		echo "   - Todos: ${GREEN}sudo supervisorctl start celery-worker celery-beat celery-flower${NO_COLOR}"
		;;
	3)
		echo "4. Para rodar SUAP e todos os serviços Celery:"
		echo "   - SUAP: ${GREEN}sudo supervisorctl start suap${NO_COLOR}"
		echo "   - Celery Worker: ${GREEN}sudo supervisorctl start celery-worker${NO_COLOR}"
		echo "   - Celery Beat: ${GREEN}sudo supervisorctl start celery-beat${NO_COLOR}"
		echo "   - Celery Flower: ${GREEN}sudo supervisorctl start celery-flower${NO_COLOR}"
		echo "   - Todos: ${GREEN}sudo supervisorctl start all${NO_COLOR}"
		;;
esac

