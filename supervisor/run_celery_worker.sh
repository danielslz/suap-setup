#!/bin/bash

# Carregar variáveis centralizadas do .env de produção
ENV_FILE="/opt/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

# Defaults caso variáveis não estejam definidas
: "${BASE_DIR:=/opt}"
: "${SUAP_DIR:=$BASE_DIR/suap}"
: "${VENV_DIR:=$BASE_DIR/venv}"

# Variáveis de execução
MAX_WORKERS=5
MIN_WORKERS=2
CELERY_QUEUE=${CELERY_QUEUE:-geral,celery_beat}

# Execução
echo "### Iniciando Celery Worker"
source "${VENV_DIR}/bin/activate"
cd "${SUAP_DIR}"
celery -A suap worker --autoscale=$MAX_WORKERS,$MIN_WORKERS -l INFO -Q $CELERY_QUEUE
