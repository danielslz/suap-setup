#!/bin/bash
set -u

# deb/suap-dev-revert.sh - Reversão do ambiente de desenvolvimento SUAP (Debian/Ubuntu)
# Desfaz, de forma conservadora, o que deb/suap-dev.sh registrou no manifesto:
# remove o virtualenv, o binário wkhtmltopdf (se instalado pela rotina), os
# arquivos gerados e, mediante confirmação, o diretório do SUAP e os pacotes de
# sistema instalados pela rotina. Preserva artefatos pré-existentes, o UV e o
# Python instalado via UV.
#
# Modos (variáveis de ambiente):
#   REVERT_DRY_RUN=1    -> apenas lista o que seria removido
#   REVERT_ASSUME_YES=1 -> confirma automaticamente operações destrutivas

# --- 1. Source lib/common.sh ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- 2. Carregar variáveis centralizadas (se existirem) ---
if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

export DISTRO_TYPE="deb"
MANIFEST_KEY="suap-dev"

# --- 3. Suporte a --dry-run por argumento ---
DRY_RUN_ARG=""
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN_ARG="--dry-run"
fi

# --- 4. Resumo do que será revertido ---
echo ""
echo "${GREEN}=== Reversão do ambiente de desenvolvimento (Debian) ===${NO_COLOR}"
if manifest_is_empty "${MANIFEST_KEY}"; then
  msg_skip "Não há nada registrado para reverter (manifesto '${MANIFEST_KEY}' vazio)."
  exit 0
fi
echo "Artefatos registrados no manifesto:"
manifest_entries "${MANIFEST_KEY}" | while IFS=$'\t' read -r _t _id _meta; do
  printf '  - %-10s %s %s\n' "${_t}" "${_id}" "${_meta:+(${_meta})}"
done
echo ""
echo "Política conservadora: pacotes de sistema, o diretório do SUAP e dados"
echo "do usuário só são removidos mediante confirmação. UV e Python (via UV)"
echo "são preservados."
echo ""

# --- 5. Executar a reversão ---
revert_apply "${MANIFEST_KEY}" ${DRY_RUN_ARG}
