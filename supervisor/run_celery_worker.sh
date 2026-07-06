#!/bin/bash

# Determinar BASE_DIR a partir do local deste script
RUNNER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$RUNNER_DIR")"

# Carregar variáveis centralizadas do .env
ENV_FILE="${BASE_DIR}/.env"
if [ -f "$ENV_FILE" ]; then
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    key=$(echo "$key" | xargs)
    value=$(eval echo "$value")
    export "$key=$value"
  done < <(grep -v '^\s*#' "$ENV_FILE" | grep -v '^\s*$')
fi

# Defaults
: "${SUAP_DIR:=$BASE_DIR/suap}"
: "${VENV_DIR:=$BASE_DIR/venv}"

# Variáveis de execução
MAX_WORKERS=${CELERY_MAX_WORKERS:-5}
MIN_WORKERS=${CELERY_MIN_WORKERS:-2}
CELERY_QUEUE=${CELERY_QUEUE:-geral,celery_beat}

# Execução
echo "### Iniciando Celery Worker (${MIN_WORKERS}-${MAX_WORKERS} workers)"
cd "${SUAP_DIR}"
exec "${VENV_DIR}/bin/celery" -A suap worker --autoscale=$MAX_WORKERS,$MIN_WORKERS -l INFO -Q $CELERY_QUEUE
