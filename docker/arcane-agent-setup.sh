#!/usr/bin/env bash
set -u

# docker/arcane-agent-setup.sh - Arcane Agent (modo Direct) em um host REMOTO, via Docker Compose.
# O agent expõe o Docker deste host ao Arcane Manager (porta 3553); o Manager conecta nele.
# Referência: https://getarcane.app/docs/remote/environments
#
# Ordem: 1) suba o Manager (docker/arcane-setup.sh) com ARCANE_APP_URL alcançável pelos agents;
#        2) na interface: Environments > Add Environment (Direct), URL http://<ip deste host>:3553,
#           e copie o token gerado (arc_...);  3) rode este script neste host com o token.
#
# O stack fica em ${DOCKER_STACKS_DIR:-/opt/docker}/arcane-agent/ (compose.yaml + .env).
#
# Variáveis (ambiente, .env do suap-setup ou .env do stack):
#   ARCANE_AGENT_TOKEN         Token do environment (gerado no Manager). Se vazio, será solicitado.
#   ARCANE_MANAGER_URL         URL do Manager acessível a partir deste host (ex.: http://192.0.2.52:3552)
#   ARCANE_AGENT_PORT          Porta exposta neste host (padrão: 3553)
#   ARCANE_AGENT_IMAGE         Imagem (padrão: ghcr.io/getarcaneapp/agent:latest)
#   ARCANE_AGENT_PROJECTS_DIR  Opcional: pasta de projetos Compose que o Manager poderá gerenciar neste host
#                              (montada no mesmo caminho). Sem ela o agent só inspeciona (containers, logs, estatísticas)
#   ARCANE_TZ                  Fuso horário do container (padrão: o do host; UTC se não detectar)
#   ARCANE_ANALYTICS_DISABLED  true (padrão) desliga o heartbeat de telemetria do Arcane (checkin.getarcane.app);
#                              false o mantém ligado
#   DOCKER_STACKS_DIR          Base dos stacks (padrão: /opt/docker)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${SCRIPT_DIR}/lib/common.sh"

# Carregar .env se existir (opcional)
if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

check_docker_available

PROJECT="suap-arcane-agent"
CONTAINER_NAME="arcane-agent"

stack_init "arcane-agent"
stack_env_load ARCANE_AGENT_TOKEN ARCANE_MANAGER_URL ARCANE_AGENT_PORT ARCANE_AGENT_IMAGE ARCANE_AGENT_PROJECTS_DIR ARCANE_ANALYTICS_DISABLED ARCANE_TZ
ARCANE_TZ="${ARCANE_TZ:-$(host_timezone)}"
[[ "${ARCANE_TZ}" =~ ^[A-Za-z0-9_+/-]+$ ]] || { msg_error "ARCANE_TZ inválido: ${ARCANE_TZ}"; exit 1; }
ARCANE_ANALYTICS_DISABLED="${ARCANE_ANALYTICS_DISABLED:-true}"
ARCANE_AGENT_PORT="${ARCANE_AGENT_PORT:-3553}"
ARCANE_AGENT_IMAGE="${ARCANE_AGENT_IMAGE:-ghcr.io/getarcaneapp/agent:latest}"
ARCANE_AGENT_TOKEN="${ARCANE_AGENT_TOKEN:-}"
ARCANE_MANAGER_URL="${ARCANE_MANAGER_URL:-}"
ARCANE_AGENT_PROJECTS_DIR="${ARCANE_AGENT_PROJECTS_DIR:-}"

_valid_port() { [[ "${1}" =~ ^[0-9]+$ ]] && [ "${1}" -ge 1 ] && [ "${1}" -le 65535 ]; }

# --- Entradas obrigatórias ---
if [ -z "${ARCANE_MANAGER_URL}" ]; then
  if [ -t 0 ]; then
    echo ""
    echo "${GREEN}=== Arcane Agent (modo Direct) ===${NO_COLOR}"
    echo "Crie antes o environment no Manager (Environments > Add Environment > Direct) para obter o token."
    read -rp "URL do Arcane Manager visível deste host (ex.: http://192.0.2.52:3552): " ARCANE_MANAGER_URL
  fi
  if [ -z "${ARCANE_MANAGER_URL}" ]; then
    msg_error "ARCANE_MANAGER_URL não definido (ex.: http://192.0.2.52:3552)."
    exit 1
  fi
fi
if [ -z "${ARCANE_AGENT_TOKEN}" ]; then
  if [ -t 0 ]; then
    read -srp "Token do agent (gerado no Manager, começa com arc_): " ARCANE_AGENT_TOKEN
    echo ""
  fi
  if [ -z "${ARCANE_AGENT_TOKEN}" ]; then
    msg_error "ARCANE_AGENT_TOKEN não definido. Crie o environment no Manager e copie o token."
    exit 1
  fi
fi

[[ "${ARCANE_MANAGER_URL}" =~ ^https?://[A-Za-z0-9._:-]+(/.*)?$ ]] || { msg_error "ARCANE_MANAGER_URL inválida: ${ARCANE_MANAGER_URL}"; exit 1; }
case "${ARCANE_ANALYTICS_DISABLED}" in true|false) ;; *) msg_error "ARCANE_ANALYTICS_DISABLED aceita apenas true ou false."; exit 1 ;; esac
_valid_port "${ARCANE_AGENT_PORT}" || { msg_error "Porta inválida: ${ARCANE_AGENT_PORT}"; exit 1; }
[[ "${ARCANE_AGENT_TOKEN}" =~ ^[A-Za-z0-9_.-]+$ ]] || { msg_error "Token inválido (esperado apenas letras, números, '_', '.' e '-')."; exit 1; }
[[ "${ARCANE_AGENT_TOKEN}" == arc_* ]] || msg_skip "O token não começa com 'arc_': confira se copiou o token do environment."
if [ -n "${ARCANE_AGENT_PROJECTS_DIR}" ]; then
  [[ "${ARCANE_AGENT_PROJECTS_DIR}" =~ ^/[A-Za-z0-9._/-]*$ ]] || { msg_error "ARCANE_AGENT_PROJECTS_DIR deve ser um caminho absoluto simples."; exit 1; }
  if [ ! -d "${ARCANE_AGENT_PROJECTS_DIR}" ]; then
    msg_error "Pasta de projetos não existe: ${ARCANE_AGENT_PROJECTS_DIR}"
    exit 1
  fi
fi

# O Manager precisa ser alcançável a partir deste host (o agent se registra nele)
if command -v curl &>/dev/null; then
  if curl -s -m 5 -o /dev/null "${ARCANE_MANAGER_URL}"; then
    msg_action "Manager alcançável em ${ARCANE_MANAGER_URL}"
  else
    msg_skip "Sem resposta do Manager em ${ARCANE_MANAGER_URL}. Confira a URL e o firewall (porta 3552 do Manager liberada para este host)."
  fi
fi

stack_adopt_legacy "${CONTAINER_NAME}" "${PROJECT}" || exit 1

stack_env_write ARCANE_AGENT_TOKEN ARCANE_MANAGER_URL ARCANE_AGENT_PORT ARCANE_AGENT_IMAGE ARCANE_AGENT_PROJECTS_DIR ARCANE_ANALYTICS_DISABLED ARCANE_TZ || exit 1

# --- SELinux: o agent precisa acessar o socket do Docker ---
_selinux_opt=""
_z=""
if command -v getenforce &>/dev/null && [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
  _selinux_opt=$'    security_opt:\n      - label=disable'
  _z=":z"
fi

{
  cat <<'EOF'
# Gerado por suap-setup (docker/arcane-agent-setup.sh). Para alterar valores, edite o
# .env ao lado (ou defina variáveis e rode o script novamente).
name: suap-arcane-agent
services:
  arcane-agent:
    image: ${ARCANE_AGENT_IMAGE}
    container_name: arcane-agent
    ports:
      - "${ARCANE_AGENT_PORT}:3553"
EOF
  [ -n "${_selinux_opt}" ] && printf '%s\n' "${_selinux_opt}"
  cat <<'EOF'
    environment:
      AGENT_MODE: "true"
      AGENT_TOKEN: ${ARCANE_AGENT_TOKEN}
      MANAGER_API_URL: ${ARCANE_MANAGER_URL}
      ANALYTICS_DISABLED: ${ARCANE_ANALYTICS_DISABLED}
      TZ: ${ARCANE_TZ}
EOF
  [ -n "${ARCANE_AGENT_PROJECTS_DIR}" ] && printf '      PROJECTS_DIRECTORY: ${ARCANE_AGENT_PROJECTS_DIR}\n'
  cat <<'EOF'
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - arcane-agent-data:/app/data
EOF
  [ -n "${ARCANE_AGENT_PROJECTS_DIR}" ] && printf '      - ${ARCANE_AGENT_PROJECTS_DIR}:${ARCANE_AGENT_PROJECTS_DIR}%s\n' "${_z}"
  cat <<'EOF'
    restart: unless-stopped
volumes:
  arcane-agent-data:
    name: arcane-agent-data
EOF
} > "${STACK_FILE}"

msg_action "Subindo o stack Arcane Agent (${STACK_DIR})..."
if ! stack_compose "${PROJECT}" pull; then
  msg_error "Falha ao baixar a imagem ${ARCANE_AGENT_IMAGE}."
  exit 1
fi
if ! stack_compose "${PROJECT}" up -d --remove-orphans; then
  msg_error "Falha ao subir o stack Arcane Agent."
  exit 1
fi

sleep 3
if ! docker ps --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  msg_error "Container do agent não está em execução. Verifique: docker logs ${CONTAINER_NAME}"
  exit 1
fi

msg_action "Arcane Agent em execução!"
echo ""
echo "  Stack:       ${STACK_DIR}"
echo "  Agent API:   http://<ip-deste-host>:${ARCANE_AGENT_PORT}   (use esta URL no environment, no Manager)"
echo "  Manager:     ${ARCANE_MANAGER_URL}"
echo "  Token:       guardado em ${STACK_ENV} (chmod 600)"
echo "  Libere ${ARCANE_AGENT_PORT}/tcp neste host SOMENTE para o IP do Manager: o agent controla o Docker daqui."
echo "  Depois, no Manager: Environments > o environment criado > Test Connection."
echo ""
