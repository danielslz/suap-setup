#!/bin/bash

# Carregar variáveis centralizadas do .env de produção
# O arquivo é copiado pelo script de produção (suap-prod.sh) para BASE_DIR/.env
ENV_FILE="/opt/.env"
if [ -f "$ENV_FILE" ]; then
  # Carregar linha por linha para expandir variáveis na ordem correta
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
LOG_DIR=${BASE_DIR}/logs
LOG_FILE=${LOG_DIR}/gunicorn.log
TIMEOUT=600  # 10 minutos

NUM_WORKERS=${GUNICORN_WORKERS:-5}
NUM_THREADS=${GUNICORN_THREADS:-1}

# Detectar usuário de serviço: www-data (Debian) ou nginx (RPM)
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

# Execução — usar caminho absoluto do gunicorn no venv
echo "### Iniciando Gunicorn (${NUM_WORKERS} workers, ${NUM_THREADS} threads)"
cd "${SUAP_DIR}"
exec "${VENV_DIR}/bin/gunicorn" suap.wsgi:application \
  -w $NUM_WORKERS --threads $NUM_THREADS -b :8000 \
  --user=$USER --group=$GROUP --log-level=info \
  --max-requests=2000 --max-requests-jitter=100 \
  --log-file=$LOG_FILE 2>>$LOG_FILE \
  --timeout=$TIMEOUT
