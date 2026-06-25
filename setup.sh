#!/usr/bin/env bash
set -u

# setup.sh - Ponto de entrada principal do suap-setup
# Detecta a distribuição, exibe menu interativo e roteia para o script apropriado.

# Determinar diretório raiz do repositório (onde este script está)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carregar biblioteca compartilhada
source "${SCRIPT_DIR}/lib/common.sh"

# Carregar variáveis do .env centralizado (cria se não existir)
load_env_file "${SCRIPT_DIR}/.env"

# Detectar distribuição Linux (define DISTRO_TYPE e DISTRO_NAME)
detect_distro

# Exibir menu interativo
echo ""
echo "=== SUAP Setup ==="
echo "1) Configurar ambiente de desenvolvimento"
echo "2) Configurar ambiente de produção"
echo "3) Instalar Redis"
echo "4) Instalar Nginx"
echo "5) Configurar ambiente dev via Docker"
echo "6) Configurar ambiente prod via Docker"
echo ""
read -rp "Escolha uma opção [1-6]: " CHOICE

# Determinar script a executar baseado na opção
case "${CHOICE}" in
  1)
    TARGET_SCRIPT="${SCRIPT_DIR}/${DISTRO_TYPE}/suap-dev.sh"
    ;;
  2)
    TARGET_SCRIPT="${SCRIPT_DIR}/${DISTRO_TYPE}/suap-prod.sh"
    ;;
  3)
    TARGET_SCRIPT="${SCRIPT_DIR}/${DISTRO_TYPE}/install-redis.sh"
    ;;
  4)
    TARGET_SCRIPT="${SCRIPT_DIR}/${DISTRO_TYPE}/install-nginx.sh"
    ;;
  5)
    TARGET_SCRIPT="${SCRIPT_DIR}/docker/dev/docker-setup.sh"
    ;;
  6)
    TARGET_SCRIPT="${SCRIPT_DIR}/docker/prod/docker-setup.sh"
    ;;
  *)
    msg_error "Opção inválida: use 1, 2, 3, 4, 5 ou 6."
    exit 1
    ;;
esac

# Verificar existência do script antes de executar
if [ ! -f "${TARGET_SCRIPT}" ]; then
  msg_error "Script não encontrado: ${TARGET_SCRIPT}"
  exit 2
fi

# Executar o script selecionado
msg_action "Executando ${TARGET_SCRIPT}..."
bash "${TARGET_SCRIPT}"
