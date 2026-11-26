#!/usr/bin/env bash
# lib/release.sh - Funções de release do suap-setup (download, verificação, instalação)
# Compatível com bash 3.2 (macOS). Requer lib/common.sh (msg_*) já carregado.
#
# Layout do prefixo: <prefix>/releases/<tag>, <prefix>/current (symlink),
# <prefix>/previous (arquivo com a tag anterior).
#
# Ganchos para teste/espelho:
#   SUAP_SETUP_RELEASES_URL  URL base das releases (aceita file://)
#   SUAP_SETUP_LATEST_TAG    Tag a usar como "última", sem consultar a rede

# release_repo_url()
release_repo_url() {
  echo "${SUAP_SETUP_RELEASES_URL:-https://github.com/danielslz/suap-setup/releases}"
}

# release_asset_url(tag, asset)
release_asset_url() {
  echo "$(release_repo_url)/download/$1/$2"
}

# release_latest_tag()
# Ecoa a tag da última release estável; retorna 1 se não conseguir resolver.
release_latest_tag() {
  local url final tag
  if [ -n "${SUAP_SETUP_LATEST_TAG:-}" ]; then
    echo "${SUAP_SETUP_LATEST_TAG}"
    return 0
  fi
  url="$(release_repo_url)/latest"
  final="$(curl -fsSIL --connect-timeout 10 --max-time 60 -o /dev/null -w '%{url_effective}' "${url}" 2>/dev/null)" || {
    msg_error "Não foi possível consultar a última versão em ${url}. Verifique a conexão."
    return 1
  }
  tag="${final##*/}"
  if ! [[ "${tag}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    msg_error "Resposta inesperada ao consultar ${url}: '${final}'."
    return 1
  fi
  echo "${tag}"
}

# release_download(url, destino)
release_download() {
  if ! curl -fsSL --connect-timeout 10 --max-time 300 -o "$2" "$1" 2>/dev/null; then
    msg_error "Falha ao baixar: $1"
    return 1
  fi
}

# _release_sha256(arquivo)
_release_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# release_verify(tarball, SHA256SUMS)
release_verify() {
  local file="$1" sums="$2" name expected actual
  name="$(basename "${file}")"
  expected="$(awk -v n="${name}" '$2 == n || $2 == "*" n {print $1; exit}' "${sums}")"
  if [ -z "${expected}" ]; then
    msg_error "SHA256SUMS não contém ${name}."
    return 1
  fi
  actual="$(_release_sha256 "${file}")"
  if [ "${expected}" != "${actual}" ]; then
    msg_error "Checksum divergente para ${name} (esperado ${expected}, obtido ${actual})."
    return 1
  fi
}

# _priv(caminho, comando...)
# Executa o comando; usa sudo só se o ancestral existente de <caminho> não for gravável.
_priv() {
  local path="$1" probe
  shift
  probe="${path}"
  while [ ! -e "${probe}" ] && [ "${probe}" != "/" ] && [ "${probe}" != "." ]; do
    probe="$(dirname "${probe}")"
  done
  if [ -w "${probe}" ]; then
    "$@"
  else
    sudo "$@"
  fi
}

# release_install_dir(tarball|diretório, prefixo)
# Instala em <prefixo>/releases/<tag> (tag = v + VERSION). Reutiliza se já existir íntegro.
release_install_dir() {
  local src="$1" prefix="$2" tmp root ver tag
  tmp="${prefix}/releases/.tmp.$$"
  _priv "${prefix}" mkdir -p "${prefix}/releases" || return 1
  _priv "${prefix}/releases" rm -rf "${tmp}"
  _priv "${prefix}/releases" mkdir -p "${tmp}" || return 1
  if [ -d "${src}" ]; then
    _priv "${prefix}/releases" cp -R "${src}/." "${tmp}/" || {
      _priv "${prefix}/releases" rm -rf "${tmp}"
      return 1
    }
  else
    _priv "${prefix}/releases" tar -xzf "${src}" -C "${tmp}" --strip-components=1 || {
      msg_error "Falha ao extrair ${src}."
      _priv "${prefix}/releases" rm -rf "${tmp}"
      return 1
    }
  fi
  ver="$(head -n 1 "${tmp}/VERSION" 2>/dev/null | tr -d '[:space:]')"
  if [ -z "${ver}" ]; then
    msg_error "Pacote sem arquivo VERSION."
    _priv "${prefix}/releases" rm -rf "${tmp}"
    return 1
  fi
  tag="v${ver}"
  if [ -n "${RELEASE_EXPECTED_TAG:-}" ] && [ "${RELEASE_EXPECTED_TAG}" != "${tag}" ]; then
    msg_error "VERSION do pacote (${tag}) difere da versão esperada (${RELEASE_EXPECTED_TAG})."
    _priv "${prefix}/releases" rm -rf "${tmp}"
    return 1
  fi
  root="${prefix}/releases/${tag}"
  if [ -f "${root}/VERSION" ] && [ "$(head -n 1 "${root}/VERSION" | tr -d '[:space:]')" = "${ver}" ]; then
    msg_skip "Versão ${tag} já instalada em ${root}."
    _priv "${prefix}/releases" rm -rf "${tmp}"
  else
    _priv "${prefix}/releases" rm -rf "${root}"
    _priv "${prefix}/releases" mv "${tmp}" "${root}" || return 1
    msg_action "Versão ${tag} instalada em ${root}."
  fi
  RELEASE_INSTALLED_TAG="${tag}"
}

# release_current_tag(prefixo): ecoa a tag apontada por current (vazio se não houver)
release_current_tag() {
  local target
  target="$(readlink "$1/current" 2>/dev/null)" || return 0
  basename "${target}"
}

# release_switch_current(prefixo, tag)
# Troca <prefixo>/current de forma atômica e grava a tag anterior em <prefixo>/previous.
release_switch_current() {
  local prefix="$1" tag="$2" old tmplink
  if [ ! -d "${prefix}/releases/${tag}" ]; then
    msg_error "Versão ${tag} não está instalada em ${prefix}/releases."
    return 1
  fi
  old="$(release_current_tag "${prefix}")"
  if [ "${old}" = "${tag}" ]; then
    msg_skip "current já aponta para ${tag}."
    return 0
  fi
  if [ -n "${old}" ]; then
    echo "${old}" | _priv "${prefix}" tee "${prefix}/previous" >/dev/null || return 1
  fi
  tmplink="${prefix}/.current.tmp.$$"
  _priv "${prefix}" ln -sfn "releases/${tag}" "${tmplink}" || return 1
  if ! _priv "${prefix}" mv -T "${tmplink}" "${prefix}/current" 2>/dev/null; then
    _priv "${prefix}" mv -fh "${tmplink}" "${prefix}/current" || {
      _priv "${prefix}" rm -f "${tmplink}"
      return 1
    }
  fi
}

# release_prune(prefixo)
# Mantém as 3 releases mais recentes; nunca remove current nem previous.
release_prune() {
  local prefix="$1" keep cur prev name
  cur="$(release_current_tag "${prefix}")"
  prev="$(head -n 1 "${prefix}/previous" 2>/dev/null | tr -d '[:space:]')"
  keep="$(ls -1 "${prefix}/releases" 2>/dev/null | grep '^v' | sort -t. -k1.2,1n -k2,2n -k3,3n | tail -n 3)"
  for name in $(ls -1 "${prefix}/releases" 2>/dev/null | grep '^v'); do
    [ "${name}" = "${cur}" ] && continue
    [ "${name}" = "${prev}" ] && continue
    echo "${keep}" | grep -qx "${name}" && continue
    _priv "${prefix}/releases" rm -rf "${prefix}/releases/${name}"
    msg_action "Release antiga removida: ${name}"
  done
}
