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

# Variáveis de execução
: "${CELERY_BROKER_URL:=redis://127.0.0.1:6379/3}"
: "${CELERY_FLOWER_AUTH:=admin:admin}"

# Execução — usar caminho absoluto do celery no venv
echo "### Iniciando Celery Flower"
cd "${SUAP_DIR}"
exec "${VENV_DIR}/bin/celery" -b "${CELERY_BROKER_URL}" flower \
  --purge_offline_workers=1 --basic_auth="${CELERY_FLOWER_AUTH}"
