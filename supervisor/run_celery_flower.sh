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
CELERY_BROKER_URL=${CELERY_BROKER_URL:-"redis://192.168.1.100:6379/3"}
FLOWER_BASIC_AUTH=${CELERY_FLOWER_AUTH:?"ERRO: variável CELERY_FLOWER_AUTH não definida. Defina no formato 'usuario:senha'."}

# Execução
echo "### Iniciando Celery Flower"
source "${VENV_DIR}/bin/activate"
cd "${SUAP_DIR}"
celery -b "${CELERY_BROKER_URL}" flower --purge_offline_workers=1 --basic_auth=$FLOWER_BASIC_AUTH
