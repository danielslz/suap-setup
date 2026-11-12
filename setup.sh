#!/usr/bin/env bash
set -u

# setup.sh - Ponto de entrada principal do suap-setup
# Exibe menu, coleta variáveis conforme a opção escolhida e executa o script.

# Determinar diretório raiz do repositório (onde este script está)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carregar biblioteca compartilhada
source "${SCRIPT_DIR}/lib/common.sh"

ENV_FILE="${SCRIPT_DIR}/.env"

# Detectar distribuição Linux (define DISTRO_TYPE e DISTRO_NAME)
detect_distro

# --- Menu interativo agrupado ---
# Cada entrada: "id interno|rótulo". Entradas "#|Título" são cabeçalhos de seção.
# A numeração exibida é sequencial; o id interno (1-12) é o que roteia o script.
if [ "${DISTRO_TYPE}" = "macos" ]; then
  MENU_ENTRIES=(
    "#|Ambiente SUAP"
    "1|Configurar ambiente de desenvolvimento"
    "#|Via Docker"
    "5|SUAP dev (docker compose)"
    "6|SUAP prod (suap_deploy)"
    "7|Dockhand (gerenciador Docker web)"
    "13|Arcane (gerenciador Docker web)"
    "10|MinIO (object storage S3)"
    "11|Redis (porta 6379 exposta)"
    "12|PostgreSQL (porta 5432 exposta)"
  )
else
  MENU_ENTRIES=(
    "#|Ambiente SUAP (no host)"
    "1|Configurar ambiente de desenvolvimento"
    "2|Configurar ambiente de produção"
    "8|Atualizar SUAP (produção)"
    "#|Serviços (no host)"
    "3|Instalar Redis"
    "4|Instalar Nginx"
    "9|Instalar PostgreSQL"
    "#|Via Docker"
    "5|SUAP dev (docker compose)"
    "6|SUAP prod (suap_deploy)"
    "7|Dockhand (gerenciador Docker web)"
    "13|Arcane (gerenciador Docker web)"
    "10|MinIO (object storage S3)"
    "11|Redis (porta 6379 exposta)"
    "12|PostgreSQL (porta 5432 exposta)"
    "14|HAProxy (balanceador do suap_deploy)"
    "15|Arcane Agent (host remoto, modo Direct)"
  )
fi

MENU_IDS=()
echo ""
echo "${GREEN}=== SUAP Setup ===${NO_COLOR}"
for _entry in "${MENU_ENTRIES[@]}"; do
  _id="${_entry%%|*}"
  _label="${_entry#*|}"
  if [ "${_id}" = "#" ]; then
    echo ""
    echo "${YELLOW}${_label}${NO_COLOR}"
  else
    MENU_IDS+=("${_id}")
    printf '  %2d) %s\n' "${#MENU_IDS[@]}" "${_label}"
  fi
done
echo ""
echo "   R) Reverter uma funcionalidade"
echo "   0) Sair"
echo ""
read -rp "Escolha uma opção [0-${#MENU_IDS[@]}, R]: " CHOICE

# Sair imediatamente se opção 0
if [ "${CHOICE}" = "0" ]; then
  echo "Saindo..."
  exit 0
fi

# --- Submenu de reversão (opção R) ---
# Exibe as funcionalidades que suportam reversão (conforme a plataforma),
# roteia para o respectivo script <distro>/<rotina>-revert.sh e executa.
run_revert_submenu() {
  echo ""
  echo "${GREEN}=== SUAP Setup — Reverter ===${NO_COLOR}"
  echo "${YELLOW}Reversão conservadora: artefatos pré-existentes são preservados;"
  echo "operações destrutivas (apagar diretórios/bancos, desinstalar pacotes)"
  echo "pedem confirmação.${NO_COLOR}"
  echo ""

  # Monta a lista de reversões disponíveis conforme a plataforma.
  # Cada item: "rótulo|script relativo ao SCRIPT_DIR"
  local -a items=()
  if [ "${DISTRO_TYPE}" = "macos" ]; then
    items+=("Reverter ambiente de desenvolvimento|${DISTRO_TYPE}/suap-dev-revert.sh")
    items+=("Reverter ambiente dev via Docker|docker/dev/docker-setup-revert.sh")
    items+=("Reverter ambiente prod via Docker|docker/prod/docker-setup-revert.sh")
    items+=("Reverter Dockhand|docker/dockhand-revert.sh")
    items+=("Reverter Arcane|docker/arcane-revert.sh")
    items+=("Reverter MinIO|docker/minio-revert.sh")
    items+=("Reverter Redis (Docker)|docker/redis-revert.sh")
    items+=("Reverter PostgreSQL (Docker)|docker/postgres-revert.sh")
  else
    items+=("Reverter ambiente de desenvolvimento|${DISTRO_TYPE}/suap-dev-revert.sh")
    items+=("Reverter ambiente de produção|${DISTRO_TYPE}/suap-prod-revert.sh")
    items+=("Reverter Redis|${DISTRO_TYPE}/install-redis-revert.sh")
    items+=("Reverter Nginx|${DISTRO_TYPE}/install-nginx-revert.sh")
    items+=("Reverter ambiente dev via Docker|docker/dev/docker-setup-revert.sh")
    items+=("Reverter ambiente prod via Docker|docker/prod/docker-setup-revert.sh")
    items+=("Reverter Dockhand|docker/dockhand-revert.sh")
    items+=("Reverter Arcane|docker/arcane-revert.sh")
    items+=("Reverter PostgreSQL|${DISTRO_TYPE}/install-postgres-revert.sh")
    items+=("Reverter MinIO|docker/minio-revert.sh")
    items+=("Reverter Redis (Docker)|docker/redis-revert.sh")
    items+=("Reverter PostgreSQL (Docker)|docker/postgres-revert.sh")
    items+=("Reverter HAProxy (Docker)|docker/haproxy-revert.sh")
    items+=("Reverter Arcane Agent|docker/arcane-agent-revert.sh")
    items+=("Reverter instalação do Docker|docker/install-docker-revert.sh")
  fi

  local i
  for i in "${!items[@]}"; do
    echo "$((i + 1))) ${items[$i]%%|*}"
  done
  echo "0) Voltar"
  echo ""
  read -rp "Escolha uma opção para reverter: " REV_CHOICE

  if [ "${REV_CHOICE}" = "0" ]; then
    echo "Voltando..."
    exit 0
  fi

  # Validar seleção numérica dentro do intervalo
  if ! [[ "${REV_CHOICE}" =~ ^[0-9]+$ ]] || [ "${REV_CHOICE}" -lt 1 ] || [ "${REV_CHOICE}" -gt "${#items[@]}" ]; then
    msg_error "Opção de reversão inválida."
    exit 1
  fi

  local selected="${items[$((REV_CHOICE - 1))]}"
  local rev_script="${SCRIPT_DIR}/${selected#*|}"

  if [ ! -f "${rev_script}" ]; then
    msg_error "A reversão desta funcionalidade ainda não está disponível."
    msg_error "Script não encontrado: ${rev_script}"
    exit 2
  fi

  msg_action "Executando ${rev_script}..."
  bash "${rev_script}"
  exit $?
}

if [ "${CHOICE}" = "R" ] || [ "${CHOICE}" = "r" ]; then
  run_revert_submenu
fi

# Traduzir a opção exibida (sequencial) para o id interno
if [[ "${CHOICE}" =~ ^[0-9]+$ ]] && [ "${CHOICE}" -ge 1 ] && [ "${CHOICE}" -le "${#MENU_IDS[@]}" ]; then
  INTERNAL_CHOICE="${MENU_IDS[$((CHOICE - 1))]}"
else
  msg_error "Opção inválida: use 0 a ${#MENU_IDS[@]} ou R."
  exit 1
fi

# --- Coletar variáveis de ambiente conforme a opção escolhida ---
# Mapeamento de variáveis necessárias por opção:
#   0: nenhuma
#   1 (dev):        PYTHON_VERSION, BASE_DIR, SUAP_DIR, VENV_DIR, SUAP_GIT_URL
#   2 (prod):       PYTHON_VERSION, BASE_DIR, SUAP_DIR, VENV_DIR, SUAP_GIT_URL, GUNICORN_WORKERS, CELERY_MAX_WORKERS, CELERY_BROKER_URL, CELERY_FLOWER_AUTH
#   3 (redis):      nenhuma
#   4 (nginx):      nenhuma
#   5 (docker dev): PYTHON_VERSION, SUAP_GIT_URL, SUAP_DIR, SUAP_IMAGE
#   6 (docker prod):SUAP_DEPLOY_DIR, SUAP_DEPLOY_GIT_URL
#   7 (dockhand):   nenhuma
#   8 (update):     PYTHON_VERSION, BASE_DIR, SUAP_DIR, VENV_DIR
#   9 (postgres):   POSTGRES_VERSION
#   10 (minio):     SUAP_MINIO_DIR, SUAP_MINIO_GIT_URL
#   11 (redis docker): nenhuma
#   12 (postgres docker): nenhuma
#   13 (arcane): nenhuma
#   14 (haproxy): nenhuma
#   15 (arcane agent): nenhuma

ensure_env_for_option "${ENV_FILE}" "${INTERNAL_CHOICE}"

# Carregar variáveis
if [ -f "${ENV_FILE}" ]; then
  load_env_file "${ENV_FILE}"
fi

# Determinar script a executar
case "${INTERNAL_CHOICE}" in
  1) TARGET_SCRIPT="${SCRIPT_DIR}/${DISTRO_TYPE}/suap-dev.sh" ;;
  2) TARGET_SCRIPT="${SCRIPT_DIR}/${DISTRO_TYPE}/suap-prod.sh" ;;
  3) TARGET_SCRIPT="${SCRIPT_DIR}/${DISTRO_TYPE}/install-redis.sh" ;;
  4) TARGET_SCRIPT="${SCRIPT_DIR}/${DISTRO_TYPE}/install-nginx.sh" ;;
  5) TARGET_SCRIPT="${SCRIPT_DIR}/docker/dev/docker-setup.sh" ;;
  6) TARGET_SCRIPT="${SCRIPT_DIR}/docker/prod/docker-setup.sh" ;;
  7) TARGET_SCRIPT="${SCRIPT_DIR}/docker/dockhand-setup.sh" ;;
  8) TARGET_SCRIPT="${SCRIPT_DIR}/${DISTRO_TYPE}/suap-update.sh" ;;
  9) TARGET_SCRIPT="${SCRIPT_DIR}/${DISTRO_TYPE}/install-postgres.sh" ;;
  10) TARGET_SCRIPT="${SCRIPT_DIR}/docker/minio-setup.sh" ;;
  11) TARGET_SCRIPT="${SCRIPT_DIR}/docker/redis-setup.sh" ;;
  12) TARGET_SCRIPT="${SCRIPT_DIR}/docker/postgres-setup.sh" ;;
  13) TARGET_SCRIPT="${SCRIPT_DIR}/docker/arcane-setup.sh" ;;
  14) TARGET_SCRIPT="${SCRIPT_DIR}/docker/haproxy-setup.sh" ;;
  15) TARGET_SCRIPT="${SCRIPT_DIR}/docker/arcane-agent-setup.sh" ;;
esac

# Verificar existência do script antes de executar
if [ ! -f "${TARGET_SCRIPT}" ]; then
  msg_error "Script não encontrado: ${TARGET_SCRIPT}"
  exit 2
fi

# Executar o script selecionado
msg_action "Executando ${TARGET_SCRIPT}..."
bash "${TARGET_SCRIPT}"
