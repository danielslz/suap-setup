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
# ensure_env_for_option(env_path, menu_option)
# Verifica e coleta apenas as variáveis necessárias para a opção escolhida.
# Se o .env já existe e contém as variáveis necessárias, não pergunta nada.
# Se falta alguma variável, pergunta somente as que faltam.
#
# Mapeamento de variáveis por opção:
#   1 (dev):         PYTHON_VERSION, BASE_DIR, SUAP_DIR, VENV_DIR, GIT_URL
#   2 (prod):        PYTHON_VERSION, BASE_DIR, SUAP_DIR, VENV_DIR, GIT_URL, GUNICORN_WORKERS, GUNICORN_THREADS, CELERY_MAX_WORKERS, CELERY_MIN_WORKERS, CELERY_BROKER_URL, CELERY_FLOWER_AUTH
#   3 (redis):       nenhuma
#   4 (nginx):       nenhuma
#   5 (docker dev):  PYTHON_VERSION, GIT_URL
#   6 (docker prod): PYTHON_VERSION, GIT_URL
#   7 (dockhand):    nenhuma
ensure_env_for_option() {
  local env_path="${1}"
  local option="${2}"

  # Opções que não precisam de variáveis
  case "${option}" in
    3|4|7) return 0 ;;
  esac

  # Carregar variáveis existentes (se .env já existe)
  if [ -f "${env_path}" ]; then
    set -a
    source "${env_path}" 2>/dev/null || true
    set +a
  fi

  local needs_update=false
  local header_shown=false

  _show_header() {
    if [ "$header_shown" = "false" ]; then
      echo ""
      echo "${GREEN}=== Configuração do ambiente ===${NO_COLOR}"
      echo "Pressione Enter para aceitar o valor padrão entre colchetes."
      echo ""
      header_shown=true
    fi
  }

  # --- Variáveis comuns (opções 1, 2, 5, 6) ---

  # PYTHON_VERSION
  if [ -z "${PYTHON_VERSION:-}" ]; then
    _show_header
    echo "${GREEN}PYTHON_VERSION${NO_COLOR}"
    echo "  ${YELLOW}Descrição:${NO_COLOR} Versão do Python a ser utilizada."
    echo "  ${YELLOW}Exemplos:${NO_COLOR} 3.11, 3.12, 3.13"
    read -rp "  Valor [${GREEN}3.12${NO_COLOR}]: " _input
    PYTHON_VERSION="${_input:-3.12}"
    needs_update=true
    echo ""
  fi

  # Para Docker (5, 6) só precisa de PYTHON_VERSION e GIT_URL
  if [ "${option}" = "5" ] || [ "${option}" = "6" ]; then
    # GIT_URL (necessária para 5, 6)
    if [ -z "${GIT_URL:-}" ]; then
      _show_header
      echo "${GREEN}GIT_URL${NO_COLOR}"
      echo "  ${YELLOW}Descrição:${NO_COLOR} URL do repositório Git do SUAP (${RED}obrigatório${NO_COLOR})."
      echo "  ${YELLOW}Exemplos:${NO_COLOR} https://github.com/org/suap.git, git@github.com:org/suap.git"
      read -rp "  Valor (${RED}obrigatório${NO_COLOR}): " _input
      if [ -z "${_input}" ]; then
        msg_error "GIT_URL é obrigatória. Não é possível continuar sem a URL do repositório."
        exit 1
      fi
      GIT_URL="${_input}"
      needs_update=true
      echo ""
    fi
    if [ "$needs_update" = "true" ]; then
      _write_env "${env_path}"
    fi
    return 0
  fi

  # --- Variáveis de diretórios (opções 1, 2) ---

  if [ -z "${BASE_DIR:-}" ]; then
    _show_header
    local _default_base
    if [ "${option}" = "1" ]; then _default_base='$HOME/Projetos'; else _default_base="/opt"; fi
    echo "${GREEN}BASE_DIR${NO_COLOR}"
    echo "  ${YELLOW}Descrição:${NO_COLOR} Diretório base para instalação do projeto."
    echo "  ${YELLOW}Exemplos:${NO_COLOR} \$HOME/Projetos (dev), /opt (prod)"
    read -rp "  Valor [${GREEN}${_default_base}${NO_COLOR}]: " _input
    BASE_DIR="${_input:-$_default_base}"
    needs_update=true
    echo ""
  fi

  if [ -z "${SUAP_DIR:-}" ]; then
    _show_header
    echo "${GREEN}SUAP_DIR${NO_COLOR}"
    echo "  ${YELLOW}Descrição:${NO_COLOR} Diretório onde o código SUAP será clonado."
    echo "  ${YELLOW}Exemplos:${NO_COLOR} \${BASE_DIR}/suap, /opt/suap"
    local _suap_default='${BASE_DIR}/suap'
    read -rp "  Valor [${GREEN}\${BASE_DIR}/suap${NO_COLOR}]: " _input
    SUAP_DIR="${_input:-$_suap_default}"
    needs_update=true
    echo ""
  fi

  if [ -z "${VENV_DIR:-}" ]; then
    _show_header
    local _default_venv
    if [ "${option}" = "1" ]; then _default_venv='${SUAP_DIR}/.venv'; else _default_venv="/opt/venv"; fi
    echo "${GREEN}VENV_DIR${NO_COLOR}"
    echo "  ${YELLOW}Descrição:${NO_COLOR} Diretório do virtualenv Python."
    echo "  ${YELLOW}Exemplos:${NO_COLOR} \${SUAP_DIR}/.venv (dev), /opt/venv (prod)"
    read -rp "  Valor [${GREEN}${_default_venv}${NO_COLOR}]: " _input
    VENV_DIR="${_input:-$_default_venv}"
    needs_update=true
    echo ""
  fi

  # GIT_URL (necessária para opções 1, 2)
  if [ -z "${GIT_URL:-}" ]; then
    _show_header
    echo "${GREEN}GIT_URL${NO_COLOR}"
    echo "  ${YELLOW}Descrição:${NO_COLOR} URL do repositório Git do SUAP (${RED}obrigatório${NO_COLOR})."
    echo "  ${YELLOW}Exemplos:${NO_COLOR} https://github.com/org/suap.git, git@github.com:org/suap.git"
    read -rp "  Valor (${RED}obrigatório${NO_COLOR}): " _input
    if [ -z "${_input}" ]; then
      msg_error "GIT_URL é obrigatória. Não é possível continuar sem a URL do repositório."
      exit 1
    fi
    GIT_URL="${_input}"
    needs_update=true
    echo ""
  fi

  # --- Variáveis de produção (opção 2) ---

  if [ "${option}" = "2" ]; then
    if [ -z "${GUNICORN_WORKERS:-}" ]; then
      _show_header
      echo "${GREEN}GUNICORN_WORKERS${NO_COLOR}"
      echo "  ${YELLOW}Descrição:${NO_COLOR} Número de workers do Gunicorn (recomendado: 2n+1, n = nº CPUs)."
      read -rp "  Valor [${GREEN}5${NO_COLOR}]: " _input
      GUNICORN_WORKERS="${_input:-5}"
      needs_update=true
      echo ""
    fi

    if [ -z "${GUNICORN_THREADS:-}" ]; then
      _show_header
      echo "${GREEN}GUNICORN_THREADS${NO_COLOR}"
      echo "  ${YELLOW}Descrição:${NO_COLOR} Número de threads por worker do Gunicorn."
      read -rp "  Valor [${GREEN}1${NO_COLOR}]: " _input
      GUNICORN_THREADS="${_input:-1}"
      needs_update=true
      echo ""
    fi

    if [ -z "${CELERY_MAX_WORKERS:-}" ]; then
      _show_header
      echo "${GREEN}CELERY_MAX_WORKERS${NO_COLOR}"
      echo "  ${YELLOW}Descrição:${NO_COLOR} Máximo de workers do Celery (autoscale)."
      read -rp "  Valor [${GREEN}5${NO_COLOR}]: " _input
      CELERY_MAX_WORKERS="${_input:-5}"
      needs_update=true
      echo ""
    fi

    if [ -z "${CELERY_MIN_WORKERS:-}" ]; then
      _show_header
      echo "${GREEN}CELERY_MIN_WORKERS${NO_COLOR}"
      echo "  ${YELLOW}Descrição:${NO_COLOR} Mínimo de workers do Celery (autoscale)."
      read -rp "  Valor [${GREEN}2${NO_COLOR}]: " _input
      CELERY_MIN_WORKERS="${_input:-2}"
      needs_update=true
      echo ""
    fi

    if [ -z "${CELERY_BROKER_URL:-}" ]; then
      _show_header
      echo "${GREEN}CELERY_BROKER_URL${NO_COLOR}"
      echo "  ${YELLOW}Descrição:${NO_COLOR} URL do broker Redis usado pelo Celery."
      echo "  ${YELLOW}Formato:${NO_COLOR} redis://HOST:PORTA/DB"
      read -rp "  Valor [${GREEN}redis://127.0.0.1:6379/3${NO_COLOR}]: " _input
      CELERY_BROKER_URL="${_input:-redis://127.0.0.1:6379/3}"
      needs_update=true
      echo ""
    fi

    if [ -z "${CELERY_FLOWER_AUTH:-}" ]; then
      _show_header
      echo "${GREEN}CELERY_FLOWER_AUTH${NO_COLOR}"
      echo "  ${YELLOW}Descrição:${NO_COLOR} Autenticação do Celery Flower (interface web)."
      echo "  ${YELLOW}Formato:${NO_COLOR} usuario:senha"
      read -rp "  Valor [${GREEN}admin:admin${NO_COLOR}]: " _input
      CELERY_FLOWER_AUTH="${_input:-admin:admin}"
      needs_update=true
      echo ""
    fi
  fi

  # --- Gravar .env se houve atualização ---
  if [ "$needs_update" = "true" ]; then
    _write_env "${env_path}"
  fi
}

# _write_env(env_path)
# Grava o arquivo .env com todas as variáveis coletadas
_write_env() {
  local env_path="${1}"

  # Usar heredoc SEM expansão ('ENVEOF') e substituir via printf
  # para preservar strings como ${BASE_DIR}/suap literalmente
  {
    echo "# ============================================================="
    echo "# Configuração centralizada do suap-setup"
    echo "# Edite este arquivo conforme seu ambiente"
    echo "# ============================================================="
    echo ""
    echo "# Versão do Python a ser utilizada"
    printf 'PYTHON_VERSION=%s\n' "${PYTHON_VERSION:-3.12}"
    echo ""
    echo "# Diretório base para instalação"
    printf 'BASE_DIR=%s\n' "${BASE_DIR:-/opt}"
    echo ""
    echo "# Diretório onde o código SUAP será clonado"
    local _suap_default='${BASE_DIR}/suap'
    printf 'SUAP_DIR=%s\n' "${SUAP_DIR:-$_suap_default}"
    echo ""
    echo "# Diretório do virtualenv"
    local _venv_default='${SUAP_DIR}/.venv'
    printf 'VENV_DIR=%s\n' "${VENV_DIR:-$_venv_default}"
    echo ""
    echo "# URL do repositório Git do SUAP"
    printf 'GIT_URL=%s\n' "${GIT_URL:-}"
    echo ""
    echo "# --- Gunicorn (produção) ---"
    echo "# Número de workers (recomendado: 2n + 1, onde n = nº de CPUs)"
    printf 'GUNICORN_WORKERS=%s\n' "${GUNICORN_WORKERS:-5}"
    echo ""
    echo "# Número de threads por worker"
    printf 'GUNICORN_THREADS=%s\n' "${GUNICORN_THREADS:-1}"
    echo ""
    echo "# --- Celery (produção) ---"
    echo "# URL do broker Redis"
    printf 'CELERY_BROKER_URL=%s\n' "${CELERY_BROKER_URL:-redis://127.0.0.1:6379/3}"
    echo ""
    echo "# Autenticação do Celery Flower (usuario:senha)"
    printf 'CELERY_FLOWER_AUTH=%s\n' "${CELERY_FLOWER_AUTH:-admin:admin}"
    echo ""
    echo "# Máximo de workers (autoscale)"
    printf 'CELERY_MAX_WORKERS=%s\n' "${CELERY_MAX_WORKERS:-5}"
    echo ""
    echo "# Mínimo de workers (autoscale)"
    printf 'CELERY_MIN_WORKERS=%s\n' "${CELERY_MIN_WORKERS:-2}"
    echo ""
    echo "# Filas do Celery (separadas por vírgula)"
    printf 'CELERY_QUEUE=%s\n' "${CELERY_QUEUE:-geral,celery_beat}"
  } > "${env_path}"

  echo ""
  echo "${GREEN}=== Arquivo .env criado com sucesso ===${NO_COLOR}"
  echo "  Caminho: ${GREEN}${env_path}${NO_COLOR}"
  echo ""
  echo "  PYTHON_VERSION = ${PYTHON_VERSION:-3.12}"
  echo "  BASE_DIR       = ${BASE_DIR:-/opt}"
  echo "  SUAP_DIR       = ${SUAP_DIR:-\${BASE_DIR}/suap}"
  echo "  VENV_DIR       = ${VENV_DIR:-\${SUAP_DIR}/.venv}"
  echo "  GIT_URL        = ${GIT_URL:-}"
  echo ""
  msg_action "Configuração salva. Prosseguindo..."
}

# interactive_env_wizard(env_path)
# Mantida para compatibilidade — chama ensure_env_for_option com opção 1 (dev defaults)
interactive_env_wizard() {
  ensure_env_for_option "${1}" "1"
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
# Primeiro verifica uname -s: se "Darwin" → classifica como "macos".
# Caso contrário, lê /etc/os-release e classifica em "deb", "rpm" ou "arch".
# Retorno: define DISTRO_TYPE ("deb"|"rpm"|"arch"|"macos") e DISTRO_NAME
# Exit 3 se:
#   - não é macOS E /etc/os-release não existe
#   - distro não suportada (não é Debian, RPM nem Arch)
detect_distro() {
  # Verificar macOS antes de ler /etc/os-release
  if [ "$(uname -s)" = "Darwin" ]; then
    DISTRO_TYPE="macos"
    DISTRO_NAME="macos"
    export DISTRO_TYPE
    export DISTRO_NAME
    return 0
  fi

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
  elif echo "${id} ${id_like}" | grep -qiE '(arch)'; then
    DISTRO_TYPE="arch"
    DISTRO_NAME="${id}"
  else
    msg_error "Distribuição não suportada: ${id}. Somente distribuições Debian-like, RPM-like, Arch-like e macOS são suportadas."
    exit 3
  fi

  export DISTRO_TYPE
  export DISTRO_NAME
}

# get_supervisor_conf_dir()
# Retorna o diretório de configuração do Supervisor baseado na distro.
# Debian: "/etc/supervisor/conf.d"
# RPM:    "/etc/supervisord.d"
# Arch:   "/etc/supervisor.d/"
# macOS:  N/A (não suporta produção)
get_supervisor_conf_dir() {
  case "${DISTRO_TYPE}" in
    deb)  echo "/etc/supervisor/conf.d" ;;
    rpm)  echo "/etc/supervisord.d" ;;
    arch) echo "/etc/supervisor.d/" ;;
  esac
}

# get_nginx_conf_path()
# Retorna o caminho de destino da configuração do Nginx.
# Debian: "/etc/nginx/sites-available/suap"
# RPM:    "/etc/nginx/conf.d/suap.conf"
# Arch:   "/etc/nginx/conf.d/suap.conf"
# macOS:  N/A
get_nginx_conf_path() {
  case "${DISTRO_TYPE}" in
    deb)  echo "/etc/nginx/sites-available/suap" ;;
    rpm)  echo "/etc/nginx/conf.d/suap.conf" ;;
    arch) echo "/etc/nginx/conf.d/suap.conf" ;;
    *)    echo "/etc/nginx/conf.d/suap.conf" ;;
  esac
}

# --- Verificações Idempotentes ---

# is_pkg_installed(pkg_name)
# Verifica se um pacote está instalado.
# Usa dpkg (Debian), rpm -q (RPM), pacman (Arch) ou brew (macOS) conforme DISTRO_TYPE.
# Retorno: 0 se instalado, 1 caso contrário
is_pkg_installed() {
  local pkg_name="${1}"

  case "${DISTRO_TYPE}" in
    deb)
      dpkg -l | grep -q "^ii  ${pkg_name} " 2>/dev/null
      ;;
    rpm)
      rpm -q "${pkg_name}" &>/dev/null
      ;;
    arch)
      pacman -Q "${pkg_name}" &>/dev/null
      ;;
    macos)
      brew list --formula 2>/dev/null | grep -q "^${pkg_name}$"
      ;;
    *)
      return 1
      ;;
  esac
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
# Comportamento por DISTRO_TYPE quando Docker não está presente:
#   deb/rpm: oferece instalar via docker/install-docker.sh (se existir). Se o
#            script não existir ou o usuário recusar, exibe URL e faz exit 1.
#   arch:    oferece instalar via pacman -S --needed --noconfirm docker docker-compose.
#            Se o usuário recusar, faz exit 1.
#   macos:   exibe mensagem advisory com URL do Docker Desktop e faz exit 1.
# Após Docker presente, verifica Docker Compose (docker compose version).
# Requer: DISTRO_TYPE definida (via detect_distro)
# Exit 1 se Docker ou Docker Compose não estiverem disponíveis
check_docker_available() {
  local install_script
  install_script="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/docker/install-docker.sh"

  if ! command -v docker &>/dev/null; then
    case "${DISTRO_TYPE}" in
      deb|rpm)
        if [ -x "${install_script}" ]; then
          msg_action "Docker não está instalado."
          read -rp "Deseja instalar o Docker agora? [s/N]: " _resposta
          if [[ "${_resposta}" =~ ^[sS]$ ]]; then
            bash "${install_script}"
            if ! command -v docker &>/dev/null; then
              msg_error "Falha ao instalar Docker. Verifique os erros acima."
              exit 1
            fi
          else
            msg_error "Docker é necessário para prosseguir."
            msg_error "Instruções: https://docs.docker.com/engine/install/"
            exit 1
          fi
        else
          msg_error "Docker não está instalado."
          msg_error "Instruções: https://docs.docker.com/engine/install/"
          exit 1
        fi
        ;;
      arch)
        msg_action "Docker não está instalado."
        read -rp "Deseja instalar Docker e Docker Compose via pacman? [s/N]: " _resposta
        if [[ "${_resposta}" =~ ^[sS]$ ]]; then
          sudo pacman -S --needed --noconfirm docker docker-compose
          if ! command -v docker &>/dev/null; then
            msg_error "Falha ao instalar Docker. Verifique os erros acima."
            exit 1
          fi
        else
          msg_error "Docker é necessário para prosseguir."
          exit 1
        fi
        ;;
      macos)
        msg_error "Docker não está instalado."
        msg_error "No macOS, o Docker Desktop é obrigatório."
        msg_error "Download: https://docs.docker.com/desktop/install/mac-install/"
        exit 1
        ;;
      *)
        msg_error "Docker não está instalado. Instale o Docker antes de prosseguir."
        msg_error "Instruções: https://docs.docker.com/engine/install/"
        exit 1
        ;;
    esac
  fi

  if ! docker compose version &>/dev/null; then
    msg_error "Docker Compose não está disponível. Instale o plugin Docker Compose."
    msg_error "Instruções: https://docs.docker.com/compose/install/"
    exit 1
  fi
}
