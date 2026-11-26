#!/usr/bin/env bash
set -u
# scripts/build-release.sh - Gera os assets de uma release do suap-setup
# Uso: scripts/build-release.sh <vX.Y.Z[-pre]> [--out DIR]
# Gera em DIR (padrão: dist): suap-setup-<versão>.tar.gz, install.sh e SHA256SUMS.
# Requer tar GNU (--sort, --owner) e um repositório git com o commit HEAD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() {
  echo "ERRO: $1" >&2
  exit 1
}

VERSION_TAG=""
OUT_DIR="dist"
while [ $# -gt 0 ]; do
  case "$1" in
    --out)
      [ $# -ge 2 ] || die "--out exige um diretório."
      OUT_DIR="$2"
      shift 2
      ;;
    -h | --help)
      echo "Uso: $0 <vX.Y.Z[-pre]> [--out DIR]"
      exit 0
      ;;
    -*) die "Opção desconhecida: $1" ;;
    *)
      [ -z "${VERSION_TAG}" ] || die "Informe apenas uma versão."
      VERSION_TAG="$1"
      shift
      ;;
  esac
done

[ -n "${VERSION_TAG}" ] || die "Informe a versão (ex.: v1.2.3)."
if ! [[ "${VERSION_TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
  die "Versão inválida: '${VERSION_TAG}' (use vX.Y.Z ou vX.Y.Z-rc.1)."
fi

mkdir -p "${OUT_DIR}" || die "Não foi possível criar ${OUT_DIR}."
OUT_DIR="$(cd "${OUT_DIR}" && pwd)"
NAME="suap-setup-${VERSION_TAG}"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

git -C "${SCRIPT_DIR}" archive --prefix="${NAME}/" HEAD | tar -x -C "${TMP}" ||
  die "Falha ao executar git archive."
echo "${VERSION_TAG#v}" >"${TMP}/${NAME}/VERSION"
MTIME="$(git -C "${SCRIPT_DIR}" log -1 --format=%ct)"

(
  cd "${TMP}" &&
    tar --sort=name --owner=0 --group=0 --numeric-owner --mtime="@${MTIME}" -cf - "${NAME}" |
    gzip -n >"${OUT_DIR}/${NAME}.tar.gz"
) || die "Falha ao empacotar o tarball."

[ -f "${TMP}/${NAME}/install.sh" ] || die "install.sh não encontrado no repositório."
cp "${TMP}/${NAME}/install.sh" "${OUT_DIR}/install.sh"

if command -v sha256sum >/dev/null 2>&1; then
  SHA_CMD="sha256sum"
else
  SHA_CMD="shasum -a 256"
fi
(cd "${OUT_DIR}" && ${SHA_CMD} "${NAME}.tar.gz" install.sh >SHA256SUMS) ||
  die "Falha ao gerar SHA256SUMS."

echo "Release ${VERSION_TAG} gerada em ${OUT_DIR}:"
ls -1 "${OUT_DIR}"
