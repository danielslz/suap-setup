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

# Exibir menu interativo
echo ""
echo "${GREEN}=== SUAP Setup ===${NO_COLOR}"
if [ "${DISTRO_TYPE}" = "macos" ]; then
  echo "1) Configurar ambiente de desenvolvimento"
  echo "2) Configurar ambiente dev via Docker"
  echo "3) Configurar ambiente prod via Docker"
  echo "4) Iniciar Dockhand (via Docker)"
  echo "5) Instalar MinIO (via Docker)"
  echo "R) Reverter uma funcionalidade"
  echo "0) Sair"
  echo ""
  read -rp "Escolha uma opção [0-5, R]: " CHOICE
else
  echo "1) Configurar ambiente de desenvolvimento"
  echo "2) Configurar ambiente de produção"
  echo "3) Instalar Redis"
  echo "4) Instalar Nginx"
  echo "5) Configurar ambiente dev via Docker"
  echo "6) Configurar ambiente prod via Docker"
  echo "7) Iniciar Dockhand (via Docker)"
  echo "8) Atualizar SUAP (produção)"
  echo "9) Instalar PostgreSQL"
  echo "10) Instalar MinIO (via Docker)"
  echo "R) Reverter uma funcionalidade"
  echo "0) Sair"
  echo ""
  read -rp "Escolha uma opção [0-10, R]: " CHOICE
fi

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
    items+=("Reverter MinIO|docker/minio-revert.sh")
  else
    items+=("Reverter ambiente de desenvolvimento|${DISTRO_TYPE}/suap-dev-revert.sh")
    items+=("Reverter ambiente de produção|${DISTRO_TYPE}/suap-prod-revert.sh")
    items+=("Reverter Redis|${DISTRO_TYPE}/install-redis-revert.sh")
    items+=("Reverter Nginx|${DISTRO_TYPE}/install-nginx-revert.sh")
    items+=("Reverter ambiente dev via Docker|docker/dev/docker-setup-revert.sh")
    items+=("Reverter ambiente prod via Docker|docker/prod/docker-setup-revert.sh")
    items+=("Reverter Dockhand|docker/dockhand-revert.sh")
    items+=("Reverter PostgreSQL|${DISTRO_TYPE}/install-postgres-revert.sh")
    items+=("Reverter MinIO|docker/minio-revert.sh")
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

# Remapear opções do macOS para o mapeamento interno
if [ "${DISTRO_TYPE}" = "macos" ]; then
  case "${CHOICE}" in
    1) INTERNAL_CHOICE="1" ;;  # dev
    2) INTERNAL_CHOICE="5" ;;  # docker dev
    3) INTERNAL_CHOICE="6" ;;  # docker prod
    4) INTERNAL_CHOICE="7" ;;  # dockhand
    5) INTERNAL_CHOICE="10" ;; # minio
    *)
      msg_error "Opção inválida: use 0, 1, 2, 3, 4 ou 5."
      exit 1
      ;;
  esac
else
  case "${CHOICE}" in
    1|2|3|4|5|6|7|8|9|10) INTERNAL_CHOICE="${CHOICE}" ;;
    *)
      msg_error "Opção inválida: use 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 ou 10."
      exit 1
      ;;
  esac
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
esac

# Verificar existência do script antes de executar
if [ ! -f "${TARGET_SCRIPT}" ]; then
  msg_error "Script não encontrado: ${TARGET_SCRIPT}"
  exit 2
fi

# Executar o script selecionado
msg_action "Executando ${TARGET_SCRIPT}..."
bash "${TARGET_SCRIPT}"
