#!/usr/bin/env bash
set -u
# lib/cmd-config.sh - suap-setup config migrate [--from DIR] [--dry-run]
# Copia <DIR>/.env e <DIR>/.state/* de um clone para os caminhos novos, sem sobrescrever
# e sem alterar o clone.
LIB_CFG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_CFG}/common.sh"
# shellcheck source=lib/release.sh
source "${LIB_CFG}/release.sh"

usage() {
  echo "Uso: suap-setup config migrate [--from DIR] [--dry-run]"
  echo "  --from DIR   Clone de origem (contém .env e/ou .state)"
  echo "  --dry-run    Mostra o que seria copiado, sem escrever"
  echo "Nunca sobrescreve destinos existentes e não altera o clone."
}

if [ "${1:-}" != "migrate" ]; then
  msg_error "Uso: suap-setup config {path|migrate}."
  exit 2
fi
shift

FROM=""
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --from)
      if [ $# -lt 2 ]; then
        msg_error "--from exige um diretório."
        exit 1
      fi
      FROM="$2"
      shift
      ;;
    --dry-run) DRY=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      msg_error "Opção desconhecida: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

_has_data() { [ -f "$1/.env" ] || [ -d "$1/.state" ]; }

if [ -z "${FROM}" ]; then
  found=""
  candidates="${HOME}/suap-setup"
  if [ -n "${SUDO_USER:-}" ] && [[ "${SUDO_USER}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    sudo_home="$(eval echo "~${SUDO_USER}" 2>/dev/null)"
    [ -n "${sudo_home}" ] && candidates="${candidates}"$'\n'"${sudo_home}/suap-setup"
  fi
  while IFS= read -r c; do
    if [ -d "${c}" ] && _has_data "${c}"; then
      found="${c}"
      break
    fi
  done <<<"${candidates}"
  if [ -n "${found}" ]; then
    msg_action "Clone encontrado em ${found}. Para migrar, rode:"
    echo "  suap-setup config migrate --from ${found}"
    exit 0
  fi
  msg_error "Nenhum clone encontrado. Informe com --from DIR."
  exit 1
fi

if [ ! -d "${FROM}" ] || ! _has_data "${FROM}"; then
  msg_error "Nada para migrar em ${FROM} (esperado .env e/ou .state)."
  exit 1
fi
FROM="$(cd "${FROM}" && pwd -P)"
DEST_ENV="$(suap_setup_resolve_env_file)"
DEST_STATE="$(suap_setup_resolve_state_dir)"

# _ensure_dir(dir): cria o diretório (sudo só se necessário), com dono do usuário
_ensure_dir() {
  [ -d "$1" ] && return 0
  _priv "$1" mkdir -p "$1" || return 1
  if [ ! -w "$1" ]; then
    _priv "$1" chown "$(id -un)" "$1" 2>/dev/null || true
  fi
}

# _copy_one(origem, destino, modo): cp sem sobrescrever
_copy_one() {
  local src="$1" dst="$2" mode="$3"
  if [ -e "${dst}" ]; then
    msg_skip "Já existe, mantido: ${dst}"
    return 0
  fi
  if [ "${DRY}" = "1" ]; then
    msg_action "[dry-run] Copiaria ${src} -> ${dst}"
    return 0
  fi
  _ensure_dir "$(dirname "${dst}")" || return 1
  _priv "${dst}" cp -R "${src}" "${dst}" || return 1
  if [ -f "${dst}" ] && [ -n "${mode}" ]; then
    _priv "${dst}" chmod "${mode}" "${dst}"
  fi
  if [ ! -w "${dst}" ]; then
    _priv "${dst}" chown -R "$(id -un)" "${dst}" 2>/dev/null || true
  fi
  msg_action "Copiado: ${src} -> ${dst}"
}

rc=0
if [ -f "${FROM}/.env" ]; then
  if [ "${FROM}/.env" -ef "${DEST_ENV}" ]; then
    msg_skip "Origem e destino do .env são o mesmo arquivo; nada a copiar."
  else
    _copy_one "${FROM}/.env" "${DEST_ENV}" 600 || rc=1
  fi
fi
if [ -d "${FROM}/.state" ] && ! [ "${FROM}/.state" -ef "${DEST_STATE}" ]; then
  for f in "${FROM}/.state"/* "${FROM}/.state"/.[!.]*; do
    [ -e "${f}" ] || continue
    name="$(basename "${f}")"
    mode=""
    [ "${name}" = "arcane.key" ] && mode=600
    _copy_one "${f}" "${DEST_STATE}/${name}" "${mode}" || rc=1
  done
fi
[ "${rc}" = "0" ] && echo "Destinos: .env em ${DEST_ENV}; estado em ${DEST_STATE}."
exit "${rc}"
