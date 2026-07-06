#!/bin/bash

# Carregar variáveis centralizadas do .env de produção
ENV_FILE="/opt/.env"
if [ -f "$ENV_FILE" ]; then
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    key=$(echo "$key" | xargs)
    value=$(eval echo "$value")
    export "$key=$value"
  done < <(grep -v '^\s*#' "$ENV_FILE" | grep -v '^\s*$')
fi

# Defaults caso variáveis não estejam definidas
: "${BASE_DIR:=/opt}"
: "${SUAP_DIR:=$BASE_DIR/suap}"
: "${VENV_DIR:=$BASE_DIR/venv}"

# Variáveis de execução (configuráveis via .env)
MAX_WORKERS=${CELERY_MAX_WORKERS:-5}
MIN_WORKERS=${CELERY_MIN_WORKERS:-2}
CELERY_QUEUE=${CELERY_QUEUE:-geral,celery_beat}

# Execução — usar caminho absoluto do celery no venv
echo "### Iniciando Celery Worker (${MIN_WORKERS}-${MAX_WORKERS} workers)"
cd "${SUAP_DIR}"
exec "${VENV_DIR}/bin/celery" -A suap worker --autoscale=$MAX_WORKERS,$MIN_WORKERS -l INFO -Q $CELERY_QUEUE
