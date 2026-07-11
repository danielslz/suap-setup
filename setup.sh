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
  echo "0) Sair"
  echo ""
  read -rp "Escolha uma opção [0-4]: " CHOICE
else
  echo "1) Configurar ambiente de desenvolvimento"
  echo "2) Configurar ambiente de produção"
  echo "3) Instalar Redis"
  echo "4) Instalar Nginx"
  echo "5) Configurar ambiente dev via Docker"
  echo "6) Configurar ambiente prod via Docker"
  echo "7) Iniciar Dockhand (via Docker)"
  echo "0) Sair"
  echo ""
  read -rp "Escolha uma opção [0-7]: " CHOICE
fi

# Sair imediatamente se opção 0
if [ "${CHOICE}" = "0" ]; then
  echo "Saindo..."
  exit 0
fi

# Remapear opções do macOS para o mapeamento interno
if [ "${DISTRO_TYPE}" = "macos" ]; then
  case "${CHOICE}" in
    1) INTERNAL_CHOICE="1" ;;  # dev
    2) INTERNAL_CHOICE="5" ;;  # docker dev
    3) INTERNAL_CHOICE="6" ;;  # docker prod
    4) INTERNAL_CHOICE="7" ;;  # dockhand
    *)
      msg_error "Opção inválida: use 0, 1, 2, 3 ou 4."
      exit 1
      ;;
  esac
else
  case "${CHOICE}" in
    1|2|3|4|5|6|7) INTERNAL_CHOICE="${CHOICE}" ;;
    *)
      msg_error "Opção inválida: use 0, 1, 2, 3, 4, 5, 6 ou 7."
      exit 1
      ;;
  esac
fi

# --- Coletar variáveis de ambiente conforme a opção escolhida ---
# Mapeamento de variáveis necessárias por opção:
#   0: nenhuma
#   1 (dev):        PYTHON_VERSION, BASE_DIR, SUAP_DIR, VENV_DIR, GIT_URL
#   2 (prod):       PYTHON_VERSION, BASE_DIR, SUAP_DIR, VENV_DIR, GIT_URL, GUNICORN_WORKERS, CELERY_MAX_WORKERS, CELERY_BROKER_URL, CELERY_FLOWER_AUTH
#   3 (redis):      nenhuma
#   4 (nginx):      nenhuma
#   5 (docker dev): PYTHON_VERSION, GIT_URL
#   6 (docker prod):PYTHON_VERSION, GIT_URL
#   7 (dockhand):   nenhuma

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
esac

# Verificar existência do script antes de executar
if [ ! -f "${TARGET_SCRIPT}" ]; then
  msg_error "Script não encontrado: ${TARGET_SCRIPT}"
  exit 2
fi

# Executar o script selecionado
msg_action "Executando ${TARGET_SCRIPT}..."
bash "${TARGET_SCRIPT}"
