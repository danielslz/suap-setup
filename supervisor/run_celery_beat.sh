#!/bin/bash

### definicao de variaveis
BASE_DIR=/opt
SUAP_DIR=$BASE_DIR/suap
VENV_DIR=$BASE_DIR/venv

GREEN=`tput setaf 2`
NO_COLOR=`tput sgr0`

echo "${GREEN}### Iniciando Celery Beat${NO_COLOR}"
source $VENV_DIR/bin/activate
cd $SUAP_DIR
celery -A suap beat -l INFO --scheduler django_celery_beat.schedulers:DatabaseScheduler
