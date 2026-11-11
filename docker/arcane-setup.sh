#!/usr/bin/env bash
set -u

# docker/arcane-setup.sh - Setup do Arcane (gerenciador Docker via web)
# Verifica pré-requisitos, baixa a imagem e inicia o container Arcane.
# Referência: https://getarcane.app/docs/get-started/installation
#
# Variáveis opcionais (ambiente ou .env):
#   ARCANE_PORT            Porta exposta no host (padrão: 3552)
#   ARCANE_IMAGE           Imagem (padrão: ghcr.io/getarcaneapp/manager:latest)
#   ARCANE_PROJECTS_DIR    Pasta dos projetos Compose (padrão: /opt/docker)
#   ARCANE_APP_URL         URL pública (padrão: http://localhost:<porta>)
#   ARCANE_ENCRYPTION_KEY  Chave de 32 bytes (hex). Se vazia, é gerada e guardada
#                          em <state>/arcane.key (chmod 600)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${SCRIPT_DIR}/lib/common.sh"

# Carregar .env se existir (opcional)
if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

check_docker_available

CONTAINER_NAME="arcane"
VOLUME_NAME="arcane-data"
ARCANE_PORT="${ARCANE_PORT:-3552}"
ARCANE_IMAGE="${ARCANE_IMAGE:-ghcr.io/getarcaneapp/manager:latest}"
ARCANE_PROJECTS_DIR="${ARCANE_PROJECTS_DIR:-/opt/docker}"
ARCANE_APP_URL="${ARCANE_APP_URL:-http://localhost:${ARCANE_PORT}}"

# Idempotência: já em execução
if docker ps --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  msg_skip "Container Arcane já está ativo. Acesso: ${ARCANE_APP_URL}"
  exit 0
fi

# Container existe mas está parado: apenas iniciar (preserva a configuração original)
if docker ps -a --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  msg_action "Container ${CONTAINER_NAME} existe e está parado. Iniciando..."
  if ! docker start "${CONTAINER_NAME}" >/dev/null; then
    msg_error "Falha ao iniciar o container ${CONTAINER_NAME}."
    exit 1
  fi
  msg_action "Arcane iniciado. Acesso: ${ARCANE_APP_URL}"
  exit 0
fi

# --- Chave de criptografia ---
# Sem a mesma chave, os dados do volume arcane-data ficam ilegíveis ao recriar o
# container. Por isso ela é persistida fora do .env (que o wizard pode reescrever).
_state_dir="$(_manifest_state_dir 2>/dev/null || true)"
_key_file="${_state_dir:+${_state_dir}/arcane.key}"
ENCRYPTION_KEY="${ARCANE_ENCRYPTION_KEY:-}"
if [ -z "${ENCRYPTION_KEY}" ] && [ -n "${_key_file}" ] && [ -s "${_key_file}" ]; then
  ENCRYPTION_KEY="$(cat "${_key_file}")"
  msg_skip "Reutilizando a chave de criptografia de ${_key_file}"
fi
if [ -z "${ENCRYPTION_KEY}" ]; then
  if command -v openssl &>/dev/null; then
    ENCRYPTION_KEY="$(openssl rand -hex 32)"
  else
    ENCRYPTION_KEY="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  fi
  if [ -n "${_key_file}" ]; then
    ( umask 077 && printf '%s\n' "${ENCRYPTION_KEY}" > "${_key_file}" )
    msg_action "Chave de criptografia gerada e guardada em ${_key_file} (faça backup)."
  else
    msg_error "Não foi possível guardar a chave. Anote: ${ENCRYPTION_KEY}"
  fi
fi

# --- Pasta de projetos Compose ---
if [ ! -d "${ARCANE_PROJECTS_DIR}" ]; then
  msg_action "Criando pasta de projetos ${ARCANE_PROJECTS_DIR}..."
  mkdir -p "${ARCANE_PROJECTS_DIR}" 2>/dev/null || sudo mkdir -p "${ARCANE_PROJECTS_DIR}"
fi
if [ ! -w "${ARCANE_PROJECTS_DIR}" ]; then
  sudo chown "$(id -u):$(id -g)" "${ARCANE_PROJECTS_DIR}"
fi

# --- SELinux: a documentação recomenda desabilitar o label do container e usar :z ---
_projects_mount="${ARCANE_PROJECTS_DIR}:${ARCANE_PROJECTS_DIR}"
_selinux_opts=()
if command -v getenforce &>/dev/null && [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
  _projects_mount="${_projects_mount}:z"
  _selinux_opts=(--security-opt label=disable)
fi

msg_action "Baixando imagem ${ARCANE_IMAGE}..."
if ! docker pull "${ARCANE_IMAGE}"; then
  msg_error "Falha ao baixar a imagem ${ARCANE_IMAGE}."
  exit 1
fi

msg_action "Iniciando container ${CONTAINER_NAME} na porta ${ARCANE_PORT}..."
if ! docker run -d \
  --name "${CONTAINER_NAME}" \
  -p "${ARCANE_PORT}:3552" \
  --cgroupns host \
  ${_selinux_opts[@]+"${_selinux_opts[@]}"} \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "${VOLUME_NAME}:/app/data" \
  -v "${_projects_mount}" \
  -e APP_URL="${ARCANE_APP_URL}" \
  -e PUID="$(id -u)" \
  -e PGID="$(id -g)" \
  -e ENCRYPTION_KEY="${ENCRYPTION_KEY}" \
  -e PROJECTS_DIRECTORY="${ARCANE_PROJECTS_DIR}" \
  --restart unless-stopped \
  "${ARCANE_IMAGE}" >/dev/null; then
  msg_error "Falha ao iniciar o container ${CONTAINER_NAME}."
  exit 1
fi

if ! docker ps --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  msg_error "Container Arcane não está em execução. Verifique os logs com: docker logs ${CONTAINER_NAME}"
  exit 1
fi

msg_action "Arcane iniciado com sucesso! Acesso: ${ARCANE_APP_URL}"
echo ""
echo "  Login inicial:  arcane / arcane-admin (a troca de senha é exigida no primeiro acesso)"
echo "  Projetos:       ${ARCANE_PROJECTS_DIR}"
[ -n "${_key_file}" ] && echo "  Chave:          ${_key_file}"
echo "  Se acessar de outra máquina, libere ${ARCANE_PORT}/tcp no firewall e defina ARCANE_APP_URL."
echo ""
