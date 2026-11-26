#!/usr/bin/env bash
# lib/paths.sh - Resolução de caminhos de configuração e estado do suap-setup
# Compatível com bash 3.2 (macOS). Sem efeitos colaterais: apenas ecoa caminhos.
#
# Variáveis de sobrescrita (todas opcionais):
#   SUAP_SETUP_ENV_FILE    Caminho completo do .env
#   SUAP_SETUP_CONFIG_DIR  Diretório de configuração (contém o .env)
#   SUAP_SETUP_STATE_DIR   Diretório de estado (manifestos, chaves)

# suap_setup_root()
# Raiz física da instalação (diretório acima de lib/).
suap_setup_root() {
  (cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
}

# suap_setup_is_release_install()
# Retorna 0 se a raiz veio de um tarball de release (existe o arquivo VERSION).
suap_setup_is_release_install() {
  [ -f "$(suap_setup_root)/VERSION" ]
}

# suap_setup_version()
# Ecoa a versão: conteúdo de VERSION, ou git describe, ou "dev".
suap_setup_version() {
  local root version=""
  root="$(suap_setup_root)"
  if [ -f "${root}/VERSION" ]; then
    version="$(head -n 1 "${root}/VERSION" 2>/dev/null | tr -d '[:space:]')"
  elif command -v git >/dev/null 2>&1; then
    version="$(git -C "${root}" describe --tags --always 2>/dev/null || true)"
  fi
  echo "${version:-dev}"
}

# suap_setup_default_config_dir()
# Linux: /etc/suap-setup; macOS: ~/.config/suap-setup. Respeita SUAP_SETUP_CONFIG_DIR.
suap_setup_default_config_dir() {
  if [ -n "${SUAP_SETUP_CONFIG_DIR:-}" ]; then
    echo "${SUAP_SETUP_CONFIG_DIR}"
  elif [ "$(uname -s)" = "Darwin" ]; then
    echo "${HOME}/.config/suap-setup"
  else
    echo "/etc/suap-setup"
  fi
}

# suap_setup_default_state_dir()
# Linux: /var/lib/suap-setup; macOS: ~/.local/state/suap-setup. Respeita SUAP_SETUP_STATE_DIR.
suap_setup_default_state_dir() {
  if [ -n "${SUAP_SETUP_STATE_DIR:-}" ]; then
    echo "${SUAP_SETUP_STATE_DIR}"
  elif [ "$(uname -s)" = "Darwin" ]; then
    echo "${HOME}/.local/state/suap-setup"
  else
    echo "/var/lib/suap-setup"
  fi
}

# _suap_setup_dir_has_files(dir)
# Retorna 0 se o diretório existe e contém ao menos um arquivo.
_suap_setup_dir_has_files() {
  [ -d "${1}" ] && [ -n "$(ls -A "${1}" 2>/dev/null)" ]
}

# suap_setup_resolve_env_file()
# Precedência: SUAP_SETUP_ENV_FILE > <config-dir>/.env (se existir) >
# <raiz>/.env legado (se existir) > destino de criação (tarball: config-dir; clone: <raiz>/.env).
suap_setup_resolve_env_file() {
  local root cfg
  if [ -n "${SUAP_SETUP_ENV_FILE:-}" ]; then
    echo "${SUAP_SETUP_ENV_FILE}"
    return 0
  fi
  root="$(suap_setup_root)"
  cfg="$(suap_setup_default_config_dir)"
  if [ -f "${cfg}/.env" ]; then
    echo "${cfg}/.env"
  elif [ -f "${root}/.env" ]; then
    echo "${root}/.env"
  elif suap_setup_is_release_install; then
    echo "${cfg}/.env"
  else
    echo "${root}/.env"
  fi
}

# suap_setup_resolve_state_dir()
# Precedência: SUAP_SETUP_STATE_DIR > dir de estado novo (se já tiver arquivos) >
# <raiz>/.state legado (se tiver arquivos) > destino de criação
# (tarball: dir novo; clone: <raiz>/.state).
suap_setup_resolve_state_dir() {
  local root st
  if [ -n "${SUAP_SETUP_STATE_DIR:-}" ]; then
    echo "${SUAP_SETUP_STATE_DIR}"
    return 0
  fi
  root="$(suap_setup_root)"
  st="$(suap_setup_default_state_dir)"
  if _suap_setup_dir_has_files "${st}"; then
    echo "${st}"
  elif _suap_setup_dir_has_files "${root}/.state"; then
    echo "${root}/.state"
  elif suap_setup_is_release_install; then
    echo "${st}"
  else
    echo "${root}/.state"
  fi
}
