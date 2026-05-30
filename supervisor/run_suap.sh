#!/bin/bash

# definicao de variaveis
BASE_DIR=/opt
SUAP_DIR=$BASE_DIR/suap
VENV_DIR=$BASE_DIR/venv
LOG_DIR=$BASE_DIR/logs
LOG_FILE=$LOG_DIR/gunicorn.log
TIMEOUT=600  # 10 minutos

NUM_WORKERS=9 # idealmente deve ser 2n + 1 (n = qtd de processadores)
NUM_THREADS=1
USER=www-data
GROUP=www-data

GREEN=`tput setaf 2`
NO_COLOR=`tput sgr0`

# configuracoes para uv
export UV_PYTHON_DOWNLOADS=manual
export UV_COMPILE_BYTECODE=1
export UV_LINK_MODE=copy
export UV_CACHE_DIR=$VENV_DIR/.cache/uv
export UV_PYTHON_INSTALL_DIR=$VENV_DIR/.local/share/uv/python
export UV_PROJECT_ENVIRONMENT=$VENV_DIR/suap

# execucao do script
echo "${GREEN}### Iniciando Gunicorn${NO_COLOR}"
#source $VENV_DIR/bin/activate
cd $SUAP_DIR
uv run gunicorn suap.wsgi:application -w $NUM_WORKERS --threads $NUM_THREADS -b :8000 \
  --user=$USER --group=$GROUP --log-level=info \
  --max-requests=2000 --max-requests-jitter=100 \
  --log-file=$LOG_FILE 2>>$LOG_FILE \
  --timeout=$TIMEOUT
