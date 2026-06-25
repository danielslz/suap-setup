#!/bin/bash
set -u

# Determinar diretório raiz do projeto (um nível acima de rpm/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source funções utilitárias
source "${SCRIPT_DIR}/lib/common.sh"

# Definir tipo de distribuição
DISTRO_TYPE="rpm"
export DISTRO_TYPE

# --- Instalação do Redis ---

REDIS_PKG="redis"
REDIS_SERVICE="redis"

if is_pkg_installed "${REDIS_PKG}"; then
  msg_skip "Redis (${REDIS_PKG}) já está instalado."
else
  msg_action "Instalando ${REDIS_PKG}..."
  sudo dnf install -y "${REDIS_PKG}"
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
