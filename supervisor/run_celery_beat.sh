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

# Execução
echo "### Iniciando Celery Beat"
source "${VENV_DIR}/bin/activate"
cd "${SUAP_DIR}"
celery -A suap beat -l INFO --scheduler django_celery_beat.schedulers:DatabaseScheduler
