#!/usr/bin/env bash
set -u
# install.sh - Instalador do suap-setup (tarball de release)
# Uso: curl -fsSL <URL>/install.sh | sudo bash
#      ./install.sh [--prefix DIR] [--bin-dir DIR] [--config-dir DIR] [--state-dir DIR]
#                   [--version vX.Y.Z] [--from-dir DIR] [--migrate-from DIR]
#                   [--completion-dir DIR] [--no-completion]
# Compatível com bash 3.2 (macOS).

if [ "$(uname -s)" = "Darwin" ]; then
  PREFIX="${HOME}/.local/share/suap-setup"
  BIN_DIR="${HOME}/.local/bin"
  CONFIG_DIR="${HOME}/.config/suap-setup"
  STATE_DIR="${HOME}/.local/state/suap-setup"
  COMPLETION_DIR=""
else
  PREFIX="/opt/suap-setup"
  BIN_DIR="/usr/local/bin"
  CONFIG_DIR="/etc/suap-setup"
  STATE_DIR="/var/lib/suap-setup"
  COMPLETION_DIR="/usr/share/bash-completion/completions"
fi
WANT_TAG=""
FROM_DIR=""
MIGRATE_FROM=""
NO_COMPLETION=0

usage() {
  echo "Uso: install.sh [opções]"
  echo "  --prefix DIR          Diretório de instalação (padrão: ${PREFIX})"
  echo "  --bin-dir DIR         Onde criar o comando suap-setup (padrão: ${BIN_DIR})"
  echo "  --config-dir DIR      Diretório do .env (padrão: ${CONFIG_DIR})"
  echo "  --state-dir DIR       Diretório de estado (padrão: ${STATE_DIR})"
  echo "  --completion-dir DIR  Diretório do autocompletar do bash"
  echo "  --version vX.Y.Z      Instala uma versão específica (padrão: a última estável)"
  echo "  --from-dir DIR        Instala a partir de uma árvore já extraída (com VERSION)"
  echo "  --migrate-from DIR    Após instalar, copia .env e estado de um clone"
  echo "  --no-completion       Não instala o autocompletar"
}

_err() { echo "ERRO: $1" >&2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix | --bin-dir | --config-dir | --state-dir | --completion-dir | --version | --from-dir | --migrate-from)
      if [ $# -lt 2 ]; then
        _err "$1 exige um valor."
        exit 1
      fi
      case "$1" in
        --prefix) PREFIX="$2" ;;
        --bin-dir) BIN_DIR="$2" ;;
        --config-dir) CONFIG_DIR="$2" ;;
        --state-dir) STATE_DIR="$2" ;;
        --completion-dir) COMPLETION_DIR="$2" ;;
        --version) WANT_TAG="$2" ;;
        --from-dir) FROM_DIR="$2" ;;
        --migrate-from) MIGRATE_FROM="$2" ;;
      esac
      shift 2
      ;;
    --no-completion)
      NO_COMPLETION=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      _err "Opção desconhecida: $1"
      usage
      exit 1
      ;;
  esac
done

# Árvore local: --from-dir, ou o diretório deste script se tiver VERSION e lib/release.sh
TREE="${FROM_DIR}"
if [ -z "${TREE}" ] && [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  _here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -f "${_here}/VERSION" ] && [ -f "${_here}/lib/release.sh" ]; then
    TREE="${_here}"
  fi
fi

# Sem árvore local: baixa, verifica e reexecuta o install.sh extraído
if [ -z "${TREE}" ]; then
  REPO_URL="${SUAP_SETUP_RELEASES_URL:-https://github.com/danielslz/suap-setup/releases}"
  TAG="${WANT_TAG}"
  if [ -z "${TAG}" ]; then
    if [ -n "${SUAP_SETUP_LATEST_TAG:-}" ]; then
      TAG="${SUAP_SETUP_LATEST_TAG}"
    else
      _final="$(curl -fsSIL --connect-timeout 10 --max-time 60 -o /dev/null -w '%{url_effective}' "${REPO_URL}/latest" 2>/dev/null)" || {
        _err "Não foi possível consultar a última versão em ${REPO_URL}/latest. Verifique a conexão."
        exit 1
      }
      TAG="${_final##*/}"
    fi
  fi
  if ! [[ "${TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
    _err "Versão inválida: '${TAG}'."
    exit 1
  fi
  _tmp="$(mktemp -d)" || exit 1
  trap 'rm -rf "${_tmp}"' EXIT
  _asset="suap-setup-${TAG}.tar.gz"
  for _f in "${_asset}" SHA256SUMS; do
    if ! curl -fsSL --connect-timeout 10 --max-time 300 -o "${_tmp}/${_f}" "${REPO_URL}/download/${TAG}/${_f}" 2>/dev/null; then
      _err "Falha ao baixar: ${REPO_URL}/download/${TAG}/${_f}"
      exit 1
    fi
  done
  _expected="$(awk -v n="${_asset}" '$2 == n || $2 == "*" n {print $1; exit}' "${_tmp}/SHA256SUMS")"
  if command -v sha256sum >/dev/null 2>&1; then
    _actual="$(sha256sum "${_tmp}/${_asset}" | awk '{print $1}')"
  else
    _actual="$(shasum -a 256 "${_tmp}/${_asset}" | awk '{print $1}')"
  fi
  if [ -z "${_expected}" ] || [ "${_expected}" != "${_actual}" ]; then
    _err "Checksum do ${_asset} não confere com o SHA256SUMS. Nada foi instalado."
    exit 1
  fi
  mkdir -p "${_tmp}/src" && tar -xzf "${_tmp}/${_asset}" -C "${_tmp}/src" --strip-components=1 || {
    _err "Falha ao extrair ${_asset}."
    exit 1
  }
  _extra=""
  [ "${NO_COMPLETION}" = "1" ] && _extra="--no-completion"
  # Reexecuta (sem exec, para o trap limpar o tmp depois)
  bash "${_tmp}/src/install.sh" --from-dir "${_tmp}/src" --prefix "${PREFIX}" --bin-dir "${BIN_DIR}" \
    --config-dir "${CONFIG_DIR}" --state-dir "${STATE_DIR}" --completion-dir "${COMPLETION_DIR}" \
    --migrate-from "${MIGRATE_FROM}" ${_extra}
  exit $?
fi

if [ ! -f "${TREE}/VERSION" ] || [ ! -f "${TREE}/lib/release.sh" ]; then
  _err "Árvore inválida em ${TREE} (faltam VERSION e/ou lib/release.sh)."
  exit 1
fi
TREE="$(cd "${TREE}" && pwd -P)"

# shellcheck source=lib/common.sh
source "${TREE}/lib/common.sh"
# shellcheck source=lib/release.sh
source "${TREE}/lib/release.sh"

release_install_dir "${TREE}" "${PREFIX}" || exit 1
TAG="${RELEASE_INSTALLED_TAG}"
release_switch_current "${PREFIX}" "${TAG}" || exit 1
release_prune "${PREFIX}"

# Comando no PATH
_priv "${BIN_DIR}" mkdir -p "${BIN_DIR}" || exit 1
_priv "${BIN_DIR}" ln -sfn "${PREFIX}/current/bin/suap-setup" "${BIN_DIR}/suap-setup" || exit 1
msg_action "Comando instalado: ${BIN_DIR}/suap-setup"

# Autocompletar
if [ "${NO_COMPLETION}" = "1" ]; then
  msg_skip "Autocompletar ignorado (--no-completion)."
elif [ -n "${COMPLETION_DIR}" ]; then
  _priv "${COMPLETION_DIR}" mkdir -p "${COMPLETION_DIR}" || exit 1
  _priv "${COMPLETION_DIR}" ln -sfn "${PREFIX}/current/completions/suap-setup.bash" "${COMPLETION_DIR}/suap-setup" || exit 1
  msg_action "Autocompletar instalado: ${COMPLETION_DIR}/suap-setup"
else
  echo "Para ativar o autocompletar, adicione ao seu shell: source <(suap-setup completion bash)"
fi

# Diretórios de configuração e estado (modo 700, dono do usuário que chamou o sudo)
_owner=""
if [ "$(id -u)" = "0" ] && [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  _owner="${SUDO_USER}"
fi
for _d in "${CONFIG_DIR}" "${STATE_DIR}"; do
  _priv "${_d}" mkdir -p "${_d}" || exit 1
  _priv "${_d}" chmod 700 "${_d}" || exit 1
  if [ -n "${_owner}" ]; then
    _priv "${_d}" chown "${_owner}" "${_d}" || exit 1
  fi
done
msg_action "Configuração: ${CONFIG_DIR}/.env; estado: ${STATE_DIR}"
if [ "${CONFIG_DIR}" != "$(SUAP_SETUP_CONFIG_DIR='' SUAP_SETUP_STATE_DIR='' suap_setup_default_config_dir)" ] ||
  [ "${STATE_DIR}" != "$(SUAP_SETUP_CONFIG_DIR='' SUAP_SETUP_STATE_DIR='' suap_setup_default_state_dir)" ]; then
  echo "Diretórios fora do padrão: exporte SUAP_SETUP_CONFIG_DIR=${CONFIG_DIR} e SUAP_SETUP_STATE_DIR=${STATE_DIR}."
fi

if [ -n "${MIGRATE_FROM}" ]; then
  env -u SUAP_SETUP_ENV_FILE SUAP_SETUP_CONFIG_DIR="${CONFIG_DIR}" SUAP_SETUP_STATE_DIR="${STATE_DIR}" \
    "${PREFIX}/current/bin/suap-setup" config migrate --from "${MIGRATE_FROM}" || exit 1
fi

msg_action "suap-setup ${TAG} instalado. Teste com: suap-setup version"
