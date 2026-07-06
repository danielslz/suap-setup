#!/bin/bash

# Determinar BASE_DIR a partir do local deste script
# O runner fica em $BASE_DIR/scripts/ — então BASE_DIR é o diretório pai
RUNNER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$RUNNER_DIR")"

# Carregar variáveis centralizadas do .env (copiado pelo script de produção)
ENV_FILE="${BASE_DIR}/.env"
if [ -f "$ENV_FILE" ]; then
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    key=$(echo "$key" | xargs)
    value=$(eval echo "$value")
    export "$key=$value"
  done < <(grep -v '^\s*#' "$ENV_FILE" | grep -v '^\s*$')
fi

# Defaults (caso .env não defina)
: "${SUAP_DIR:=$BASE_DIR/suap}"
: "${VENV_DIR:=$BASE_DIR/venv}"

# Variáveis de execução
LOG_DIR=${BASE_DIR}/logs
LOG_FILE=${LOG_DIR}/gunicorn.log
TIMEOUT=600

NUM_WORKERS=${GUNICORN_WORKERS:-5}
NUM_THREADS=${GUNICORN_THREADS:-1}

# Detectar usuário de serviço
if id "www-data" &>/dev/null; then
  USER=www-data
  GROUP=www-data
elif id "nginx" &>/dev/null; then
  USER=nginx
  GROUP=nginx
else
  USER=$(whoami)
  GROUP=$(id -gn)
fi

# Execução
echo "### Iniciando Gunicorn (${NUM_WORKERS} workers, ${NUM_THREADS} threads)"
cd "${SUAP_DIR}"
exec "${VENV_DIR}/bin/gunicorn" suap.wsgi:application \
  -w $NUM_WORKERS --threads $NUM_THREADS -b :8000 \
  --user=$USER --group=$GROUP --log-level=info \
  --max-requests=2000 --max-requests-jitter=100 \
  --log-file=$LOG_FILE 2>>$LOG_FILE \
  --timeout=$TIMEOUT
