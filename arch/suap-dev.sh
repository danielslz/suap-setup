#!/bin/bash
set -u

# arch/suap-dev.sh - Configuração do ambiente de desenvolvimento SUAP (Arch Linux)
# Algoritmo:
# 1. Source lib/common.sh
# 2. load_env_file() - carregar variáveis centralizadas
# 3. resolve_git_url() - garantir GIT_URL disponível
# 4. Verificar e instalar dependências do sistema (pacman -Q / pacman -S)
# 5. Configurar locale pt_BR.UTF-8 (se necessário)
# 6. Configurar timezone America/Fortaleza (se necessário)
# 7. Instalar UV (se não disponível no PATH)
# 8. Clone/pull do repositório SUAP
# 9. Gerar settings.py e .env (se não existem)
# 10. Instalar Python via UV (se não disponível)
# 11. Criar virtualenv (se não existe)
# 12. Instalar/atualizar dependências Python
# 13. Exibir mensagem final com próximos passos

### Determinar diretório raiz do projeto
SCRIPT_DIR=$(cd "$(dirname "$(readlink -f "$0")")" && cd .. && pwd)

### 1. Source lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

### Forçar tipo de distribuição para Arch
DISTRO_TYPE="arch"
export DISTRO_TYPE

### 2. Verificar existência do .env
require_env_file "${SCRIPT_DIR}/.env"

### 3. Carregar variáveis centralizadas
load_env_file "${SCRIPT_DIR}/.env"

### Sobrescrever variáveis para ambiente de desenvolvimento
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
BASE_DIR="${HOME}/Projetos"
SUAP_DIR="${BASE_DIR}/suap"
VENV_DIR="${SUAP_DIR}/.venv"

### 3. Garantir GIT_URL disponível
resolve_git_url "${SCRIPT_DIR}/.env"

### 4. Verificar e instalar dependências do sistema
PACKAGES=(
  base-devel
  python
  openldap libsasl
  libjpeg-turbo libpng zlib freetype2
  freetds
  libxml2 libxslt xmlsec
  cairo pango gdk-pixbuf2
  libffi
  poppler
  git curl wget
)

if ! check_all_packages_installed "${PACKAGES[@]}"; then
  msg_action "Instalando dependências do sistema operacional"
  if ! sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"; then
    msg_error "Falha na instalação de pacotes do sistema."
    exit 1
  fi
else
  msg_skip "Dependências do sistema já estão instaladas"
fi

### 5. Configurar locale pt_BR.UTF-8 (se necessário)
if [[ "$(localectl status)" != *"pt_BR.UTF-8"* ]]; then
  msg_action "Configurando locale para pt_BR.UTF-8"
  sudo sed -i 's/^#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen
  sudo locale-gen
  sudo localectl set-locale LANG=pt_BR.UTF-8
else
  msg_skip "Locale já configurado para pt_BR.UTF-8"
fi

### 6. Configurar timezone America/Fortaleza (se necessário)
CURRENT_TZ=$(timedatectl show -p Timezone --value 2>/dev/null || echo "")
if [ "${CURRENT_TZ}" != "America/Fortaleza" ]; then
  msg_action "Configurando timezone para America/Fortaleza"
  sudo timedatectl set-timezone America/Fortaleza
else
  msg_skip "Timezone já configurado para America/Fortaleza"
fi

### 7. Instalar UV (se não disponível no PATH)
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

  # Adicionar auto-completar ao .bashrc (se não já adicionado)
  if ! grep -q 'uv generate-shell-completion bash' "${HOME}/.bashrc" 2>/dev/null; then
    echo 'eval "$(uv generate-shell-completion bash)"' >> "${HOME}/.bashrc"
  fi
fi

### 8. Clone/pull do repositório SUAP
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

### 9. Gerar settings.py e .env (se não existem)
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

### 10. Instalar Python via UV (se não disponível)
if ! uv python list --only-installed 2>/dev/null | grep -q "${PYTHON_VERSION}"; then
  msg_action "Instalando Python ${PYTHON_VERSION} via UV"
  uv python install "${PYTHON_VERSION}"
else
  msg_skip "Python ${PYTHON_VERSION} já está instalado"
fi

### 11. Criar virtualenv (se não existe)
if [ ! -d "${VENV_DIR}" ]; then
  msg_action "Criando virtualenv com Python ${PYTHON_VERSION}"
  cd "${SUAP_DIR}"
  uv venv --python "${PYTHON_VERSION}"
else
  msg_skip "Virtualenv já existe em ${VENV_DIR}"
fi

### 12. Instalar/atualizar dependências Python
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

### 13. Mensagem final com próximos passos
echo ""
msg_action "SUAP instalado/atualizado com sucesso em ${SUAP_DIR}!"
echo ""
echo "Próximos passos:"
echo "  1. Recarregue o bashrc:        ${GREEN}source ~/.bashrc${NO_COLOR}"
echo "  2. Edite as variáveis de ambiente: ${GREEN}nano ${SUAP_DIR}/.env${NO_COLOR}"
echo "  3. Acesse o diretório do SUAP:  ${GREEN}cd ${SUAP_DIR}${NO_COLOR}"
echo "  4. Rode o servidor dev:         ${GREEN}uv run python manage.py runserver 0.0.0.0:8000${NO_COLOR}"
echo ""
