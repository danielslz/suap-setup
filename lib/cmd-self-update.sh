#!/usr/bin/env bash
set -u
# lib/cmd-self-update.sh - suap-setup self-update [--check] [--version vX.Y.Z] [--rollback]
LIB_SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_SELF}/common.sh"
# shellcheck source=lib/release.sh
source "${LIB_SELF}/release.sh"

usage() {
  echo "Uso: suap-setup self-update [opções]"
  echo "  --check            Apenas informa se há versão nova (não altera nada)"
  echo "  --version vX.Y.Z   Instala uma versão específica (inclui pré-release e downgrade)"
  echo "  --rollback         Volta para a versão anterior"
  echo "  -h, --help         Mostra esta ajuda"
}

CHECK=0
ROLLBACK=0
WANT_TAG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK=1 ;;
    --rollback) ROLLBACK=1 ;;
    --version)
      if [ $# -lt 2 ]; then
        msg_error "--version exige um valor (ex.: v1.2.3)."
        exit 1
      fi
      WANT_TAG="$2"
      shift
      ;;
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

if [ -n "${WANT_TAG}" ] && ! [[ "${WANT_TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
  msg_error "Versão inválida: '${WANT_TAG}' (use vX.Y.Z ou vX.Y.Z-rc.1)."
  exit 1
fi

ROOT="$(suap_setup_root)"
if [ "$(basename "$(dirname "${ROOT}")")" != "releases" ]; then
  msg_error "Esta instalação é um clone do repositório (${ROOT}); o self-update só atualiza instalações por tarball."
  echo "Para migrar: instale com o install.sh (curl -fsSL <URL>/install.sh | sudo bash) e rode"
  echo "'suap-setup config migrate --from ${ROOT}' para copiar o .env e o estado. O clone não é alterado."
  exit 1
fi
PREFIX="$(dirname "$(dirname "${ROOT}")")"
CURRENT_TAG="v$(suap_setup_version)"

if [ "${ROLLBACK}" = "1" ]; then
  prev="$(head -n 1 "${PREFIX}/previous" 2>/dev/null | tr -d '[:space:]')"
  if [ -z "${prev}" ] || [ ! -d "${PREFIX}/releases/${prev}" ]; then
    msg_error "Não há versão anterior para restaurar."
    exit 1
  fi
  release_switch_current "${PREFIX}" "${prev}" || exit 1
  msg_action "Versão restaurada: ${CURRENT_TAG} -> ${prev}"
  exit 0
fi

if [ -n "${WANT_TAG}" ]; then
  TAG="${WANT_TAG}"
else
  TAG="$(release_latest_tag)" || exit 1
fi

if [ "${CHECK}" = "1" ]; then
  if [ "${TAG}" = "${CURRENT_TAG}" ]; then
    msg_skip "O suap-setup já está na versão mais recente (${CURRENT_TAG})."
  else
    msg_action "Versão instalada: ${CURRENT_TAG}. Disponível: ${TAG}. Rode 'suap-setup self-update'."
  fi
  exit 0
fi

if [ "${TAG}" = "${CURRENT_TAG}" ]; then
  msg_skip "O suap-setup já está na versão mais recente (${CURRENT_TAG})."
  exit 0
fi

TMP="$(mktemp -d)" || exit 1
trap 'rm -rf "${TMP}"' EXIT
ASSET="suap-setup-${TAG}.tar.gz"
msg_action "Baixando ${TAG}..."
release_download "$(release_asset_url "${TAG}" "${ASSET}")" "${TMP}/${ASSET}" || exit 1
release_download "$(release_asset_url "${TAG}" "SHA256SUMS")" "${TMP}/SHA256SUMS" || exit 1
release_verify "${TMP}/${ASSET}" "${TMP}/SHA256SUMS" || exit 1

RELEASE_EXPECTED_TAG="${TAG}"
release_install_dir "${TMP}/${ASSET}" "${PREFIX}" || exit 1
release_switch_current "${PREFIX}" "${TAG}" || exit 1
release_prune "${PREFIX}"

msg_action "Atualizado: ${CURRENT_TAG} -> ${TAG}"
echo "Para voltar à versão anterior: suap-setup self-update --rollback"
