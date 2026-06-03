#!/bin/bash

### definicao de variaveis
BASE_DIR=/opt
SUAP_DIR=$BASE_DIR/suap
VENV_DIR=$BASE_DIR/venv

MAX_WORKERS=5
MIN_WORKERS=2
CELERY_QUEUE=${CELERY_QUEUE:-geral,celery_beat}

GREEN=`tput setaf 2`
NO_COLOR=`tput sgr0`

echo "${GREEN}### Iniciando Celery Worker${NO_COLOR}"
source $VENV_DIR/suap/bin/activate
cd $SUAP_DIR
celery -A suap worker --autoscale=$MAX_WORKERS,$MIN_WORKERS -l INFO -Q $CELERY_QUEUE
