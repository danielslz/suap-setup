#!/bin/bash

### definicao de variaveis
BASE_DIR=/opt
SUAP_DIR=$BASE_DIR/suap
VENV_DIR=$BASE_DIR/venv

CELERY_BROKER_URL=${CELERY_BROKER_URL:-"redis://192.168.1.100:6379/3"}
FLOWER_BASIC_AUTH=${CELERY_FLOWER_AUTH:?"ERRO: variável CELERY_FLOWER_AUTH não definida. Defina no formato 'usuario:senha'."}

GREEN=`tput setaf 2`
NO_COLOR=`tput sgr0`

echo "${GREEN}### Iniciando Celery Flower${NO_COLOR}"
source $VENV_DIR/suap/bin/activate
cd $SUAP_DIR
celery -b "${CELERY_BROKER_URL}" flower --purge_offline_workers=1 --basic_auth=$FLOWER_BASIC_AUTH
