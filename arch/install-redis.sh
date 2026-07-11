#!/bin/bash
set -u

# Determinar diretório raiz do projeto (um nível acima de arch/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source funções utilitárias
source "${SCRIPT_DIR}/lib/common.sh"

# Carregar variáveis do .env centralizado
load_env_file "${SCRIPT_DIR}/.env"

# Definir tipo de distribuição
DISTRO_TYPE="arch"
export DISTRO_TYPE

# --- Instalação do Redis ---

REDIS_PKG="redis"
REDIS_SERVICE="redis"

if is_pkg_installed "${REDIS_PKG}"; then
  msg_skip "Redis (${REDIS_PKG}) já está instalado."
else
  msg_action "Instalando ${REDIS_PKG}..."
  sudo pacman -S --needed --noconfirm "${REDIS_PKG}"
fi

# Iniciar serviço
msg_action "Iniciando serviço ${REDIS_SERVICE}..."
sudo systemctl start "${REDIS_SERVICE}"

# Habilitar início automático no boot
msg_action "Habilitando ${REDIS_SERVICE} para iniciar no boot..."
sudo systemctl enable "${REDIS_SERVICE}"

# Exibir status do serviço
msg_action "Status do serviço ${REDIS_SERVICE}:"
sudo systemctl status "${REDIS_SERVICE}" --no-pager
