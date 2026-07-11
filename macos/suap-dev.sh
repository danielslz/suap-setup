#!/bin/bash
set -u

# macos/suap-dev.sh - Configuração do ambiente de desenvolvimento SUAP (macOS)
# Algoritmo:
# 1. Source lib/common.sh
# 2. Verificar Homebrew disponível
# 3. load_env_file() - carregar variáveis centralizadas
# 4. resolve_git_url() - garantir GIT_URL disponível
# 5. Verificar e instalar dependências do sistema (brew install)
# 6. Locale: pular (não necessário no macOS)
# 7. Configurar timezone America/Fortaleza (se necessário)
# 8. Instalar UV (se não disponível no PATH)
# 9. Clone/pull do repositório SUAP
# 10. Gerar settings.py e .env (se não existem)
# 11. Instalar Python via UV (se não disponível)
# 12. Criar virtualenv (se não existe)
# 13. Instalar/atualizar dependências Python
# 14. Exibir mensagem final com próximos passos

### Determinar diretório raiz do projeto (portável para macOS onde readlink -f pode não existir)
SCRIPT_DIR=$(cd "$(dirname "$0")" && cd .. && pwd)

### 1. Source lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

### Forçar tipo de distribuição para macOS
DISTRO_TYPE="macos"
export DISTRO_TYPE

### 2. Verificar Homebrew disponível
if ! command -v brew &>/dev/null; then
  msg_error "Homebrew não está instalado. Instale em: https://brew.sh"
  exit 1
fi

### 3. Verificar existência do .env
require_env_file "${SCRIPT_DIR}/.env"

### 4. Carregar variáveis centralizadas
load_env_file "${SCRIPT_DIR}/.env"

### Sobrescrever variáveis para ambiente de desenvolvimento
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
BASE_DIR="${HOME}/Projetos"
SUAP_DIR="${BASE_DIR}/suap"
VENV_DIR="${SUAP_DIR}/.venv"

### 5. Garantir GIT_URL disponível
resolve_git_url "${SCRIPT_DIR}/.env"

### 6. Verificar e instalar dependências do sistema
PACKAGES=(
  openldap
  libpq
  freetype
  libxml2
  libxslt
  xmlsec1
  cairo
  pango
  gdk-pixbuf
  libffi
  poppler
  git
  curl
  wget
  python@3.12
  jpeg-turbo
  libpng
  freetds
)

if ! check_all_packages_installed "${PACKAGES[@]}"; then
  msg_action "Instalando dependências do sistema via Homebrew"
  if ! brew install "${PACKAGES[@]}"; then
    msg_error "Falha na instalação de pacotes via Homebrew."
    exit 1
  fi
else
  msg_skip "Dependências do sistema já estão instaladas"
fi

### 7. Locale: não necessário no macOS
msg_skip "Locale não necessário no macOS"

### 8. Configurar timezone America/Fortaleza (se necessário)
CURRENT_TZ=$(systemsetup -gettimezone 2>/dev/null | awk -F': ' '{print $2}' || echo "")
if [ "${CURRENT_TZ}" != "America/Fortaleza" ]; then
  msg_action "Configurando timezone para America/Fortaleza"
  sudo systemsetup -settimezone America/Fortaleza
else
  msg_skip "Timezone já configurado para America/Fortaleza"
fi

### 9. Instalar UV (se não disponível no PATH)
if command -v uv &>/dev/null; then
  msg_skip "UV já está instalado"
elif [ -x "${HOME}/.cargo/bin/uv" ]; then
  msg_skip "UV encontrado em ~/.cargo/bin/uv, adicionando ao PATH"
  export PATH="${HOME}/.cargo/bin:${PATH}"
elif [ -x "${HOME}/.local/bin/uv" ]; then
  msg_skip "UV encontrado em ~/.local/bin/uv, adicionando ao PATH"
  export PATH="${HOME}/.local/bin:${PATH}"
else
  msg_action "Instalando o UV"
  curl -LsSf https://astral.sh/uv/install.sh | sh

  # Garantir UV disponível no PATH da sessão atual
  if [ -f "${HOME}/.local/bin/env" ]; then
    source "${HOME}/.local/bin/env"
  fi

  # Adicionar auto-completar ao .zshrc (macOS usa zsh por padrão)
  if ! grep -q 'uv generate-shell-completion zsh' "${HOME}/.zshrc" 2>/dev/null; then
    echo 'eval "$(uv generate-shell-completion zsh)"' >> "${HOME}/.zshrc"
  fi
fi

### 10. Clone/pull do repositório SUAP
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

### 11. Gerar settings.py e .env (se não existem)
if [ ! -f "${SUAP_DIR}/suap/settings.py" ]; then
  msg_action "Gerando settings.py a partir do sample"
  cp "${SUAP_DIR}/suap/settings_sample.py" "${SUAP_DIR}/suap/settings.py"
else
  msg_skip "settings.py já existe"
fi

if [ ! -f "${SUAP_DIR}/.env" ]; then
  msg_action "Gerando .env do SUAP a partir do sample"
  cp "${SUAP_DIR}/.env.dev.sample" "${SUAP_DIR}/.env"
else
  msg_skip ".env do SUAP já existe"
fi

### 12. Instalar Python via UV (se não disponível)
if ! uv python list --only-installed 2>/dev/null | grep -q "${PYTHON_VERSION}"; then
  msg_action "Instalando Python ${PYTHON_VERSION} via UV"
  uv python install "${PYTHON_VERSION}"
else
  msg_skip "Python ${PYTHON_VERSION} já está instalado"
fi

### 13. Criar virtualenv (se não existe)
if [ ! -d "${VENV_DIR}" ]; then
  msg_action "Criando virtualenv com Python ${PYTHON_VERSION}"
  cd "${SUAP_DIR}"
  uv venv --python "${PYTHON_VERSION}"
else
  msg_skip "Virtualenv já existe em ${VENV_DIR}"
fi

### 14. Instalar/atualizar dependências Python
msg_action "Instalando/atualizando dependências Python"
cd "${SUAP_DIR}"
if [ -f "${SUAP_DIR}/pyproject.toml" ]; then
  if ! uv sync --group dev; then
    msg_error "Falha na instalação de dependências Python."
    exit 1
  fi
elif [ -d "${SUAP_DIR}/requirements" ]; then
  if ! uv pip install -r requirements/development.txt; then
    msg_error "Falha na instalação de dependências Python."
    exit 1
  fi
else
  msg_error "Não foi encontrado pyproject.toml nem a pasta requirements em ${SUAP_DIR}"
  exit 1
fi

### 15. Mensagem final com próximos passos
echo ""
msg_action "SUAP instalado/atualizado com sucesso em ${SUAP_DIR}!"
echo ""
echo "Próximos passos:"
echo "  1. Recarregue o zshrc:          ${GREEN}source ~/.zshrc${NO_COLOR}"
echo "  2. Edite as variáveis de ambiente: ${GREEN}nano ${SUAP_DIR}/.env${NO_COLOR}"
echo "  3. Acesse o diretório do SUAP:  ${GREEN}cd ${SUAP_DIR}${NO_COLOR}"
echo "  4. Rode o servidor dev:         ${GREEN}uv run python manage.py runserver 0.0.0.0:8000${NO_COLOR}"
echo ""
