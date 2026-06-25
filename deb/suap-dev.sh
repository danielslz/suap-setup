#!/bin/bash
set -u

# deb/suap-dev.sh - Configuração do ambiente de desenvolvimento SUAP (Debian/Ubuntu)
# Utiliza lib/common.sh para funções compartilhadas e .env para variáveis centralizadas.

# --- 1. Source lib/common.sh ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- 2. Carregar variáveis centralizadas ---
load_env_file "${SCRIPT_DIR}/.env"

# Definir valores padrão de desenvolvimento (caso não estejam no .env)
: "${BASE_DIR:=$HOME/Projetos}"
: "${SUAP_DIR:=$BASE_DIR/suap}"
: "${VENV_DIR:=$SUAP_DIR/.venv}"
: "${PYTHON_VERSION:=3.12}"

export DISTRO_TYPE="deb"

# --- 3. Resolver GIT_URL ---
resolve_git_url "${SCRIPT_DIR}/.env"

# --- 4. Verificar e instalar dependências do sistema ---
PACKAGES=(
  # Ferramentas de compilação e utilitários
  locales vim git build-essential language-pack-pt openssl curl wget libpq-dev tmpreaper swig
  # LDAP
  libldap2-dev libsasl2-dev
  # Pillow
  libjpeg-dev libpng-dev zlib1g-dev libfreetype6-dev
  # PyMSSQL
  freetds-dev
  # lxml
  libxml2-dev libxslt1-dev libxmlsec1-dev
  # WeasyPrint
  libcairo2-dev libpango1.0-dev libgdk-pixbuf2.0-dev libffi-dev
  # PDF
  poppler-utils
  # Python dev headers
  python3-dev
)

if ! check_all_packages_installed "${PACKAGES[@]}"; then
  msg_action "Instalando dependências do sistema operacional"
  sudo apt update -qy
  sudo apt install -y --fix-missing "${PACKAGES[@]}"
else
  msg_skip "Dependências do sistema já estão instaladas"
fi

# --- 5. Configurar locale pt_BR.UTF-8 ---
CURRENT_LOCALE=$(locale 2>/dev/null | grep "^LANG=" | cut -d= -f2 || echo "")
if [ "${CURRENT_LOCALE}" != "pt_BR.UTF-8" ]; then
  msg_action "Configurando locale para pt_BR.UTF-8"
  sudo locale-gen pt_BR.UTF-8
  sudo update-locale LANG=pt_BR.UTF-8
else
  msg_skip "Locale já configurado para pt_BR.UTF-8"
fi

# --- 6. Configurar timezone America/Fortaleza ---
CURRENT_TZ=$(timedatectl show -p Timezone --value 2>/dev/null || echo "")
if [ "${CURRENT_TZ}" != "America/Fortaleza" ]; then
  msg_action "Configurando timezone para America/Fortaleza"
  sudo timedatectl set-timezone America/Fortaleza
else
  msg_skip "Timezone já configurado para America/Fortaleza"
fi

# --- 7. Instalar UV ---
if ! command -v uv &>/dev/null; then
  msg_action "Instalando UV (gerenciador de pacotes Python)"
  curl -LsSf https://astral.sh/uv/install.sh | sh

  # Garantir UV disponível no PATH da sessão atual
  if [ -f "$HOME/.local/bin/env" ]; then
    source "$HOME/.local/bin/env"
  fi

  # Adicionar auto-completar ao .bashrc (se não já adicionado)
  if ! grep -q 'uv generate-shell-completion bash' "$HOME/.bashrc" 2>/dev/null; then
    echo 'eval "$(uv generate-shell-completion bash)"' >> "$HOME/.bashrc"
  fi
else
  msg_skip "UV já está instalado"
fi

# --- 8. Clone/pull do repositório SUAP ---
if [ ! -d "${SUAP_DIR}/.git" ]; then
  msg_action "Clonando repositório SUAP"
  mkdir -p "${BASE_DIR}"
  cd "${BASE_DIR}"
  git clone "${GIT_URL}" suap
else
  msg_skip "Repositório SUAP já existe, atualizando..."
  cd "${SUAP_DIR}"
  git checkout master
  git pull
fi

cd "${SUAP_DIR}"

# --- 9. Gerar settings.py e .env a partir dos samples ---
if [ ! -f "${SUAP_DIR}/suap/settings.py" ]; then
  msg_action "Gerando settings.py a partir do sample"
  cp "${SUAP_DIR}/suap/settings_sample.py" "${SUAP_DIR}/suap/settings.py"
else
  msg_skip "settings.py já existe"
fi

if [ ! -f "${SUAP_DIR}/.env" ]; then
  msg_action "Gerando .env a partir do sample"
  cp "${SUAP_DIR}/.env.dev.sample" "${SUAP_DIR}/.env"
else
  msg_skip ".env do SUAP já existe"
fi

# --- 10. Instalar Python via UV ---
if ! uv python list --only-installed 2>/dev/null | grep -q "${PYTHON_VERSION}"; then
  msg_action "Instalando Python ${PYTHON_VERSION} via UV"
  uv python install "${PYTHON_VERSION}"
else
  msg_skip "Python ${PYTHON_VERSION} já está instalado"
fi

# --- 11. Criar virtualenv ---
if [ ! -d "${VENV_DIR}" ]; then
  msg_action "Criando virtualenv com Python ${PYTHON_VERSION}"
  cd "${SUAP_DIR}"
  uv venv --python "${PYTHON_VERSION}"
else
  msg_skip "Virtualenv já existe em ${VENV_DIR}"
fi

# --- 12. Instalar/atualizar dependências Python ---
msg_action "Instalando/atualizando dependências Python"
cd "${SUAP_DIR}"
if [ -f "${SUAP_DIR}/pyproject.toml" ]; then
  uv sync --group dev
elif [ -d "${SUAP_DIR}/requirements" ]; then
  uv pip install -r requirements/development.txt
else
  msg_error "Não foi encontrado pyproject.toml nem a pasta requirements em ${SUAP_DIR}"
  exit 1
fi

# --- 13. Mensagem final com próximos passos ---
echo ""
msg_action "SUAP instalado/atualizado com sucesso em ${SUAP_DIR}!"
echo ""
echo "Próximos passos:"
echo "  1. Recarregue o bashrc:        ${GREEN}source ~/.bashrc${NO_COLOR}"
echo "  2. Edite as variáveis de ambiente: ${GREEN}nano ${SUAP_DIR}/.env${NO_COLOR}"
echo "  3. Acesse o diretório do SUAP:  ${GREEN}cd ${SUAP_DIR}${NO_COLOR}"
echo "  4. Rode o servidor dev:         ${GREEN}uv run python manage.py runserver 0.0.0.0:8000${NO_COLOR}"
echo ""
