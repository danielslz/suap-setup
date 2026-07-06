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

# Execução — usar caminho absoluto do celery no venv
echo "### Iniciando Celery Beat"
cd "${SUAP_DIR}"
exec "${VENV_DIR}/bin/celery" -A suap beat -l INFO --scheduler django_celery_beat.schedulers:DatabaseScheduler
