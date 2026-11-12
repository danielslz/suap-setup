#!/usr/bin/env bash
set -u

# docker/arcane-setup.sh - Setup do Arcane (gerenciador Docker via web) com Docker Compose.
# Referência: https://getarcane.app/docs/get-started/installation
# O stack fica em ${DOCKER_STACKS_DIR:-/opt/docker}/arcane/ (compose.yaml + .env).
#
# Variáveis opcionais (ambiente, .env do suap-setup ou .env do stack):
#   ARCANE_PORT            Porta exposta no host (padrão: 3552)
#   ARCANE_IMAGE           Imagem (padrão: ghcr.io/getarcaneapp/manager:latest)
#   ARCANE_PROJECTS_DIR    Pasta dos projetos Compose (padrão: DOCKER_STACKS_DIR, ou /opt/docker)
#   ARCANE_APP_URL         URL pública (padrão: http://localhost:<porta>)
#   ARCANE_ENCRYPTION_KEY  Chave de 32 bytes (hex). Se vazia, é gerada e guardada
#                          no .env do stack (chmod 600)
#   ARCANE_ANALYTICS_DISABLED  true (padrão) desliga o heartbeat de telemetria do Arcane (checkin.getarcane.app);
#                          false o mantém ligado
#   DOCKER_STACKS_DIR      Base dos stacks (padrão: /opt/docker)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${SCRIPT_DIR}/lib/common.sh"

# Carregar .env se existir (opcional)
if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

check_docker_available

PROJECT="suap-arcane"
CONTAINER_NAME="arcane"

stack_init "arcane"
stack_env_load ARCANE_PORT ARCANE_IMAGE ARCANE_PROJECTS_DIR ARCANE_APP_URL ARCANE_ENCRYPTION_KEY ARCANE_PUID ARCANE_PGID ARCANE_ANALYTICS_DISABLED
ARCANE_ANALYTICS_DISABLED="${ARCANE_ANALYTICS_DISABLED:-true}"
case "${ARCANE_ANALYTICS_DISABLED}" in true|false) ;; *) msg_error "ARCANE_ANALYTICS_DISABLED aceita apenas true ou false."; exit 1 ;; esac
ARCANE_PORT="${ARCANE_PORT:-3552}"
ARCANE_IMAGE="${ARCANE_IMAGE:-ghcr.io/getarcaneapp/manager:latest}"
ARCANE_PROJECTS_DIR="${ARCANE_PROJECTS_DIR:-${DOCKER_STACKS_DIR:-/opt/docker}}"
ARCANE_APP_URL="${ARCANE_APP_URL:-http://localhost:${ARCANE_PORT}}"
ARCANE_PUID="${ARCANE_PUID:-$(id -u)}"
ARCANE_PGID="${ARCANE_PGID:-$(id -g)}"

# --- Chave de criptografia ---
# Sem a mesma chave, os dados do volume arcane-data ficam ilegíveis ao recriar o
# container. Ela é guardada no .env do stack; a versão antiga do script a gravava
# em <state>/arcane.key, que ainda é aceita como origem.
if [ -z "${ARCANE_ENCRYPTION_KEY:-}" ]; then
  _state_dir="$(_manifest_state_dir 2>/dev/null || true)"
  _old_key="${_state_dir:+${_state_dir}/arcane.key}"
  if [ -n "${_old_key}" ] && [ -s "${_old_key}" ]; then
    ARCANE_ENCRYPTION_KEY="$(cat "${_old_key}")"
    msg_skip "Reutilizando a chave de criptografia de ${_old_key}"
  elif command -v openssl &>/dev/null; then
    ARCANE_ENCRYPTION_KEY="$(openssl rand -hex 32)"
    msg_action "Chave de criptografia gerada (guardada em ${STACK_ENV}; faça backup)."
  else
    ARCANE_ENCRYPTION_KEY="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    msg_action "Chave de criptografia gerada (guardada em ${STACK_ENV}; faça backup)."
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
_selinux_opt=""
_projects_suffix=""
if command -v getenforce &>/dev/null && [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
  _selinux_opt=$'    security_opt:\n      - label=disable'
  _projects_suffix=":z"
fi

stack_adopt_legacy "${CONTAINER_NAME}" "${PROJECT}" || exit 1

stack_env_write ARCANE_PORT ARCANE_IMAGE ARCANE_PROJECTS_DIR ARCANE_APP_URL ARCANE_ENCRYPTION_KEY ARCANE_PUID ARCANE_PGID ARCANE_ANALYTICS_DISABLED || exit 1

{
  cat <<'EOF'
# Gerado por suap-setup (docker/arcane-setup.sh). Para alterar valores, edite o
# .env ao lado (ou defina variáveis e rode o script novamente).
name: suap-arcane
services:
  arcane:
    image: ${ARCANE_IMAGE}
    container_name: arcane
    ports:
      - "${ARCANE_PORT}:3552"
    cgroup: host
EOF
  [ -n "${_selinux_opt}" ] && printf '%s\n' "${_selinux_opt}"
  cat <<EOF
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - arcane-data:/app/data
      - \${ARCANE_PROJECTS_DIR}:\${ARCANE_PROJECTS_DIR}${_projects_suffix}
EOF
  cat <<'EOF'
    environment:
      APP_URL: ${ARCANE_APP_URL}
      PUID: ${ARCANE_PUID}
      PGID: ${ARCANE_PGID}
      ENCRYPTION_KEY: ${ARCANE_ENCRYPTION_KEY}
      PROJECTS_DIRECTORY: ${ARCANE_PROJECTS_DIR}
      ANALYTICS_DISABLED: ${ARCANE_ANALYTICS_DISABLED}
    restart: unless-stopped
volumes:
  arcane-data:
    name: arcane-data
EOF
} > "${STACK_FILE}"

msg_action "Subindo o stack Arcane (${STACK_DIR})..."
if ! stack_compose "${PROJECT}" pull; then
  msg_error "Falha ao baixar a imagem ${ARCANE_IMAGE}."
  exit 1
fi
if ! stack_compose "${PROJECT}" up -d --remove-orphans; then
  msg_error "Falha ao subir o stack Arcane."
  exit 1
fi

if ! docker ps --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  msg_error "Container Arcane não está em execução. Verifique os logs com: docker logs ${CONTAINER_NAME}"
  exit 1
fi

msg_action "Arcane em execução! Acesso: ${ARCANE_APP_URL}"
echo ""
echo "  Login inicial:  arcane / arcane-admin (a troca de senha é exigida no primeiro acesso)"
echo "  Stack:          ${STACK_DIR}"
echo "  Projetos:       ${ARCANE_PROJECTS_DIR}"
echo "  Chave:          ${STACK_ENV}"
echo "  Se acessar de outra máquina, libere ${ARCANE_PORT}/tcp no firewall e defina ARCANE_APP_URL."
echo ""
