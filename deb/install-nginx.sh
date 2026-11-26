#!/bin/bash
set -u

# Determinar diretório raiz do projeto (parent de deb/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source da biblioteca compartilhada
source "${SCRIPT_DIR}/lib/common.sh"

# Carregar variáveis do .env centralizado
load_env_file "${SUAP_SETUP_ENV_FILE}"

# Definir tipo de distribuição
DISTRO_TYPE="deb"
export DISTRO_TYPE

# --- Instalar pacote Nginx ---

if is_pkg_installed "nginx"; then
  msg_skip "Nginx já está instalado."
else
  msg_action "Instalando Nginx..."
  sudo apt-get update
  sudo apt-get install -y nginx
fi

# --- Iniciar e habilitar serviço ---

msg_action "Iniciando serviço Nginx..."
sudo systemctl start nginx

msg_action "Habilitando Nginx para iniciar no boot..."
sudo systemctl enable nginx

# --- Copiar configuração do SUAP ---

NGINX_CONF_PATH=$(get_nginx_conf_path)
NGINX_CONFIGURED=false

if [ -f "${NGINX_CONF_PATH}" ]; then
  msg_skip "Configuração do SUAP já existe em ${NGINX_CONF_PATH}."
else
  msg_action "Copiando configuração do SUAP para ${NGINX_CONF_PATH}..."
  sudo cp "${SCRIPT_DIR}/nginx/suap" "${NGINX_CONF_PATH}"

  # Criar link simbólico em sites-enabled
  msg_action "Criando link simbólico em /etc/nginx/sites-enabled/suap..."
  sudo ln -sf /etc/nginx/sites-available/suap /etc/nginx/sites-enabled/suap

  NGINX_CONFIGURED=true
fi

# Remover configuração padrão somente se a configuração do SUAP acabou de ser instalada
if [ "${NGINX_CONFIGURED}" = "true" ] && [ -e /etc/nginx/sites-enabled/default ]; then
  msg_action "Removendo configuração padrão do Nginx..."
  sudo rm -f /etc/nginx/sites-enabled/default
fi

# --- Testar configuração ---

msg_action "Testando configuração do Nginx..."
sudo nginx -t

# --- Recarregar Nginx ---

msg_action "Recarregando Nginx..."
sudo systemctl reload nginx

# --- Mensagem de sucesso ---

echo ""
msg_action "Nginx instalado e configurado com sucesso!"
echo ""
echo "⚠️  IMPORTANTE: Edite o arquivo de configuração para ajustar os IPs dos servidores backend (upstream)."
echo "Arquivo: ${NGINX_CONF_PATH}"
echo "Certifique-se de informar corretamente os IPs dos servidores no bloco 'upstream app_django'."
