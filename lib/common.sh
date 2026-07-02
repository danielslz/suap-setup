#!/usr/bin/env bash
# lib/common.sh - Funções utilitárias compartilhadas
# Sourced por todos os scripts do suap-setup

# --- Output Colorido ---

GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
NO_COLOR=$(tput sgr0)

# msg_action(mensagem)
# Exibe mensagem em verde (ação sendo executada)
msg_action() { echo "${GREEN}>>> $1 ${NO_COLOR}"; }

# msg_skip(mensagem)
# Exibe mensagem em amarelo (etapa já concluída)
msg_skip() { echo "${YELLOW}>>> $1 ${NO_COLOR}"; }

# msg_error(mensagem)
# Exibe mensagem em vermelho (erro)
msg_error() { echo "${RED}ERRO: $1 ${NO_COLOR}"; }

# --- Gerenciamento do Arquivo .env ---

# require_env_file(env_path)
# Verifica se o .env existe; caso contrário, exibe erro e aborta.
# Usado pelos scripts individuais que NÃO devem iniciar o wizard.
# Exit 1 se o arquivo não existir
require_env_file() {
  local env_path="${1}"

  if [ ! -f "${env_path}" ]; then
    msg_error "Arquivo .env não encontrado em '${env_path}'."
    msg_error "Execute o setup.sh primeiro para gerar o arquivo de configuração."
    exit 1
  fi
}

# create_default_env(env_path)
# Cria arquivo .env com valores padrão e comentários descritivos.
# Parâmetros: caminho absoluto onde criar o .env
create_default_env() {
  local env_path="${1}"

  cat > "${env_path}" << 'EOF'
# =============================================================
# Configuração centralizada do suap-setup
# Edite este arquivo conforme seu ambiente
# =============================================================

# Versão do Python a ser utilizada
PYTHON_VERSION=3.12

# Diretório base para instalação
# Desenvolvimento: $HOME/Projetos
# Produção: /opt
BASE_DIR=/opt

# Diretório onde o código SUAP será clonado
SUAP_DIR=${BASE_DIR}/suap

# Diretório do virtualenv
# Desenvolvimento: ${SUAP_DIR}/.venv
# Produção: /opt/venv/suap
VENV_DIR=${BASE_DIR}/venv

# URL do repositório Git do SUAP
GIT_URL=
EOF

  msg_action "Arquivo .env criado em ${env_path} com valores padrão."
  msg_action "Edite o arquivo conforme seu ambiente antes de prosseguir."
}

# interactive_env_wizard(env_path)
# Assistente interativo para criação do .env na primeira execução pelo wrapper.
# Solicita ao usuário: PYTHON_VERSION, BASE_DIR, SUAP_DIR, VENV_DIR, GIT_URL.
# Para cada variável:
#   - Exibe nome, descrição do propósito, exemplos e valor padrão (dev)
#   - Se o usuário pressiona Enter sem digitar → usa valor padrão
# Exceção: GIT_URL não possui valor padrão → exit 1 se vazia
# Após coleta, grava o .env com comentários descritivos e exibe confirmação.
# Parâmetros: caminho absoluto onde criar o .env
# Exit 1 se GIT_URL vazia
interactive_env_wizard() {
  local env_path="${1}"

  echo ""
  echo "${GREEN}=== Assistente de Configuração do suap-setup ===${NO_COLOR}"
  echo "Responda às perguntas abaixo para criar o arquivo .env."
  echo "Pressione Enter para aceitar o valor padrão entre colchetes."
  echo ""

  # --- PYTHON_VERSION ---
  echo "${GREEN}PYTHON_VERSION${NO_COLOR}"
  echo "  ${YELLOW}Descrição:${NO_COLOR} Versão do Python a ser utilizada na instalação."
  echo "  ${YELLOW}Exemplos:${NO_COLOR} 3.11, 3.12, 3.13"
  local default_python="3.12"
  read -rp "  Valor [${GREEN}${default_python}${NO_COLOR}]: " input_python
  local python_version="${input_python:-${default_python}}"
  echo ""

  # --- BASE_DIR ---
  echo "${GREEN}BASE_DIR${NO_COLOR}"
  echo "  ${YELLOW}Descrição:${NO_COLOR} Diretório base para instalação do projeto."
  echo "  ${YELLOW}Exemplos:${NO_COLOR} \$HOME/Projetos (dev), /opt (prod)"
  local default_basedir="\$HOME/Projetos"
  read -rp "  Valor [${GREEN}${default_basedir}${NO_COLOR}]: " input_basedir
  local base_dir="${input_basedir:-${default_basedir}}"
  echo ""

  # --- SUAP_DIR ---
  echo "${GREEN}SUAP_DIR${NO_COLOR}"
  echo "  ${YELLOW}Descrição:${NO_COLOR} Diretório onde o código SUAP será clonado."
  echo "  ${YELLOW}Exemplos:${NO_COLOR} \${BASE_DIR}/suap, /opt/suap"
  local default_suapdir="\${BASE_DIR}/suap"
  read -rp "  Valor [${GREEN}${default_suapdir}${NO_COLOR}]: " input_suapdir
  local suap_dir="${input_suapdir:-${default_suapdir}}"
  echo ""

  # --- VENV_DIR ---
  echo "${GREEN}VENV_DIR${NO_COLOR}"
  echo "  ${YELLOW}Descrição:${NO_COLOR} Diretório do virtualenv Python."
  echo "  ${YELLOW}Exemplos:${NO_COLOR} \${SUAP_DIR}/.venv (dev), /opt/venv/suap (prod)"
  local default_venvdir="\${SUAP_DIR}/.venv"
  read -rp "  Valor [${GREEN}${default_venvdir}${NO_COLOR}]: " input_venvdir
  local venv_dir="${input_venvdir:-${default_venvdir}}"
  echo ""

  # --- GIT_URL ---
  echo "${GREEN}GIT_URL${NO_COLOR}"
  echo "  ${YELLOW}Descrição:${NO_COLOR} URL do repositório Git do SUAP (${RED}obrigatório${NO_COLOR})."
  echo "  ${YELLOW}Exemplos:${NO_COLOR} https://github.com/org/suap.git, git@github.com:org/suap.git"
  read -rp "  Valor (${RED}obrigatório${NO_COLOR}): " input_giturl
  local git_url="${input_giturl}"
  echo ""

  if [ -z "${git_url}" ]; then
    msg_error "GIT_URL é obrigatória. Não é possível continuar sem a URL do repositório."
    exit 1
  fi

  # --- Gravar .env ---
  cat > "${env_path}" << EOF
# =============================================================
# Configuração centralizada do suap-setup
# Edite este arquivo conforme seu ambiente
# =============================================================

# Versão do Python a ser utilizada
PYTHON_VERSION=${python_version}

# Diretório base para instalação
# Desenvolvimento: \$HOME/Projetos
# Produção: /opt
BASE_DIR=${base_dir}

# Diretório onde o código SUAP será clonado
SUAP_DIR=${suap_dir}

# Diretório do virtualenv
# Desenvolvimento: \${SUAP_DIR}/.venv
# Produção: /opt/venv/suap
VENV_DIR=${venv_dir}

# URL do repositório Git do SUAP
GIT_URL=${git_url}
EOF

  # --- Confirmação ---
  echo ""
  echo "${GREEN}=== Arquivo .env criado com sucesso ===${NO_COLOR}"
  echo "  Caminho: ${GREEN}${env_path}${NO_COLOR}"
  echo ""
  echo "  Valores configurados:"
  echo "    ${YELLOW}PYTHON_VERSION${NO_COLOR} = ${python_version}"
  echo "    ${YELLOW}BASE_DIR${NO_COLOR}       = ${base_dir}"
  echo "    ${YELLOW}SUAP_DIR${NO_COLOR}       = ${suap_dir}"
  echo "    ${YELLOW}VENV_DIR${NO_COLOR}       = ${venv_dir}"
  echo "    ${YELLOW}GIT_URL${NO_COLOR}        = ${git_url}"
  echo ""
  msg_action "Configuração salva. Prosseguindo com a execução..."
}

# load_env_file(env_path)
# Carrega variáveis do arquivo .env centralizado.
# Cria o arquivo com valores padrão se não existir.
# Parâmetros: caminho absoluto do .env
load_env_file() {
  local env_path="${1}"

  if [ ! -f "${env_path}" ]; then
    create_default_env "${env_path}"
  fi

  # Carregar variáveis ignorando comentários e linhas vazias
  while IFS='=' read -r key value; do
    # Ignorar linhas vazias e comentários
    [[ -z "${key}" || "${key}" =~ ^[[:space:]]*# ]] && continue
    # Remover espaços em branco ao redor da chave
    key=$(echo "${key}" | xargs)
    # Expandir variáveis no valor (ex: ${BASE_DIR}/suap)
    value=$(eval echo "${value}")
    export "${key}=${value}"
  done < <(grep -v '^\s*#' "${env_path}" | grep -v '^\s*$')
}

# resolve_git_url(env_path)
# Lê GIT_URL do .env ou solicita ao usuário via prompt interativo.
# Persiste o valor informado no .env para uso futuro.
# Parâmetros: caminho do .env
# Exit 1 se URL informada estiver vazia
resolve_git_url() {
  local env_path="${1}"

  if [ -n "${GIT_URL:-}" ]; then
    msg_skip "GIT_URL já configurada: ${GIT_URL}"
    return 0
  fi

  echo ""
  read -rp "Informe a URL do repositório Git do SUAP: " GIT_URL

  if [ -z "${GIT_URL}" ]; then
    msg_error "URL do repositório não pode ser vazia."
    exit 1
  fi

  # Persistir no .env
  sed -i "s|^GIT_URL=.*|GIT_URL=${GIT_URL}|" "${env_path}"
  export GIT_URL
  msg_action "GIT_URL salva no arquivo .env."
}

# --- Detecção de Distribuição ---

# detect_distro()
# Lê /etc/os-release e classifica em "deb" ou "rpm".
# Retorno: define DISTRO_TYPE ("deb"|"rpm") e DISTRO_NAME
# Exit 3 se /etc/os-release não existe ou distro não suportada
detect_distro() {
  if [ ! -f /etc/os-release ]; then
    msg_error "Arquivo /etc/os-release não encontrado. Não é possível detectar a distribuição."
    exit 3
  fi

  local id=""
  local id_like=""

  # Ler ID e ID_LIKE do /etc/os-release
  id=$(grep -oP '^ID=\K.*' /etc/os-release | tr -d '"')
  id_like=$(grep -oP '^ID_LIKE=\K.*' /etc/os-release | tr -d '"')

  # Classificar por família
  if echo "${id} ${id_like}" | grep -qiE '(debian|ubuntu)'; then
    DISTRO_TYPE="deb"
    DISTRO_NAME="${id}"
  elif echo "${id} ${id_like}" | grep -qiE '(rhel|fedora|centos)'; then
    DISTRO_TYPE="rpm"
    DISTRO_NAME="${id}"
  else
    msg_error "Distribuição não suportada: ${id}. Somente distribuições Debian-like e RPM-like são suportadas."
    exit 3
  fi

  export DISTRO_TYPE
  export DISTRO_NAME
}

# get_supervisor_conf_dir()
# Retorna o diretório de configuração do Supervisor baseado na distro.
# "/etc/supervisor/conf.d" (Debian) ou "/etc/supervisord.d" (RPM)
get_supervisor_conf_dir() {
  if [ "${DISTRO_TYPE}" = "deb" ]; then
    echo "/etc/supervisor/conf.d"
  else
    echo "/etc/supervisord.d"
  fi
}

# get_nginx_conf_path()
# Retorna o caminho de destino da configuração do Nginx.
# Debian: "/etc/nginx/sites-available/suap"
# RPM: "/etc/nginx/conf.d/suap.conf"
get_nginx_conf_path() {
  if [ "${DISTRO_TYPE}" = "deb" ]; then
    echo "/etc/nginx/sites-available/suap"
  else
    echo "/etc/nginx/conf.d/suap.conf"
  fi
}

# --- Verificações Idempotentes ---

# is_pkg_installed(pkg_name)
# Verifica se um pacote está instalado.
# Usa dpkg (Debian) ou rpm -q (RPM) conforme DISTRO_TYPE.
# Retorno: 0 se instalado, 1 caso contrário
is_pkg_installed() {
  local pkg_name="${1}"

  if [ "${DISTRO_TYPE}" = "deb" ]; then
    dpkg -l | grep -q "^ii  ${pkg_name} " 2>/dev/null
  else
    rpm -q "${pkg_name}" &>/dev/null
  fi
}

# check_all_packages_installed(pkg_list...)
# Verifica se todos os pacotes da lista estão instalados.
# Retorno: 0 se todos instalados, 1 se algum faltando
check_all_packages_installed() {
  local pkg
  for pkg in "$@"; do
    if ! is_pkg_installed "${pkg}"; then
      return 1
    fi
  done
  return 0
}

# --- Verificação de Pré-requisitos Docker ---

# check_docker_available()
# Verifica se Docker e Docker Compose estão instalados.
# Exit 1 com mensagem de erro se não disponíveis
check_docker_available() {
  if ! command -v docker &>/dev/null; then
    msg_error "Docker não está instalado. Instale o Docker antes de prosseguir."
    msg_error "Instruções: https://docs.docker.com/engine/install/"
    exit 1
  fi

  if ! docker compose version &>/dev/null; then
    msg_error "Docker Compose não está disponível. Instale o plugin Docker Compose."
    msg_error "Instruções: https://docs.docker.com/compose/install/"
    exit 1
  fi
}
