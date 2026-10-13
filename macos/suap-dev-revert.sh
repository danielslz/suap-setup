#!/bin/bash
set -u

# macos/suap-dev-revert.sh - Reversão do ambiente de desenvolvimento SUAP (macOS)
# Desfaz, de forma conservadora, o que macos/suap-dev.sh registrou no manifesto:
# remove o virtualenv, os arquivos gerados e, mediante confirmação, o diretório
# do SUAP e os pacotes Homebrew instalados pela rotina. Preserva artefatos
# pré-existentes, o UV e o Python instalado via UV. (No macOS não há wkhtmltopdf.)
#
# Modos (variáveis de ambiente):
#   REVERT_DRY_RUN=1    -> apenas lista o que seria removido
#   REVERT_ASSUME_YES=1 -> confirma automaticamente operações destrutivas

### Determinar diretório raiz do projeto (portável para macOS)
SCRIPT_DIR=$(cd "$(dirname "$0")" && cd .. && pwd)

### Source lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

### Carregar variáveis centralizadas (se existirem)
if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

DISTRO_TYPE="macos"
export DISTRO_TYPE
MANIFEST_KEY="suap-dev"

### Suporte a --dry-run por argumento
DRY_RUN_ARG=""
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN_ARG="--dry-run"
fi

### Resumo do que será revertido
echo ""
echo "${GREEN}=== Reversão do ambiente de desenvolvimento (macOS) ===${NO_COLOR}"
if manifest_is_empty "${MANIFEST_KEY}"; then
  msg_skip "Não há nada registrado para reverter (manifesto '${MANIFEST_KEY}' vazio)."
  exit 0
fi
echo "Artefatos registrados no manifesto:"
manifest_entries "${MANIFEST_KEY}" | while IFS=$'\t' read -r _t _id _meta; do
  printf '  - %-10s %s %s\n' "${_t}" "${_id}" "${_meta:+(${_meta})}"
done
echo ""
echo "Política conservadora: pacotes Homebrew e o diretório do SUAP só são"
echo "removidos mediante confirmação. UV e Python (via UV) são preservados."
echo ""

### Executar a reversão
revert_apply "${MANIFEST_KEY}" ${DRY_RUN_ARG}
