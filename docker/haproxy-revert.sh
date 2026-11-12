#!/usr/bin/env bash
set -u

# docker/haproxy-revert.sh - Reverte docker/haproxy-setup.sh
# Derruba o stack Compose do HAProxy. A imagem e o diretório do stack
# (${DOCKER_STACKS_DIR:-/opt/docker}/haproxy: haproxy.cfg e .env com a senha das
# estatísticas) só são removidos com confirmação. O certificado em
# ${HAPROXY_CERT_DIR:-/etc/ssl/suap/haproxy} NUNCA é apagado (pode ser o seu certificado).
# Suporta REVERT_DRY_RUN=1 e REVERT_ASSUME_YES=1.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

IMAGE_NAME="${HAPROXY_IMAGE:-haproxy:lts-alpine}"
stack_revert "haproxy" "suap-haproxy" "suap-haproxy" "" "${IMAGE_NAME}"

_cert_dir="${HAPROXY_CERT_DIR:-/etc/ssl/suap/haproxy}"
[ -d "${_cert_dir}" ] && msg_skip "Certificado em ${_cert_dir} preservado. Remova manualmente se desejar."

msg_action "Reversão do HAProxy concluída."
