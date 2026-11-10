#!/usr/bin/env bash
set -u

# docker/install-docker-revert.sh - Reverte docker/install-docker.sh
#
# Remove o que a instalação do Docker adicionou, nesta ordem:
#   1. Para e desabilita os serviços (docker, docker.socket, containerd)
#   2. Desinstala os pacotes Docker
#   3. Remove o repositório/keyring adicionado (deb/rpm)
#   4. Remove o usuário do grupo 'docker' (o grupo em si é preservado)
#   5. (opcional, confirmação separada) apaga /var/lib/docker e /var/lib/containerd
#
# ATENÇÃO: derruba TODOS os containers em execução na máquina (inclusive os de
# outras aplicações). Imagens, volumes e redes só são apagados no passo 5.
# Suporta REVERT_DRY_RUN=1 e REVERT_ASSUME_YES=1.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

detect_distro

# --- Pacotes e fontes por distribuição (espelham install-docker.sh) ---
case "${DISTRO_TYPE}" in
  deb)
    DOCKER_PKGS=(docker-ce docker-ce-cli containerd.io docker-compose-plugin)
    DOCKER_REPO_FILES=(/etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.asc)
    ;;
  rpm)
    DOCKER_PKGS=(docker-ce docker-ce-cli containerd.io docker-compose-plugin)
    DOCKER_REPO_FILES=(/etc/yum.repos.d/docker-ce.repo)
    ;;
  arch)
    DOCKER_PKGS=(docker docker-compose)
    DOCKER_REPO_FILES=()
    ;;
  macos)
    msg_skip "No macOS o Docker Desktop é instalado manualmente. Remova-o pelo próprio aplicativo."
    exit 0
    ;;
  *)
    msg_error "Reversão não suportada para a distribuição detectada: ${DISTRO_NAME:-desconhecida}"
    exit 1
    ;;
esac

# --- Verificar se há algo a reverter ---
_has_pkg=false
for _pkg in "${DOCKER_PKGS[@]}"; do
  if is_pkg_installed "${_pkg}"; then
    _has_pkg=true
    break
  fi
done

_has_repo=false
for _f in "${DOCKER_REPO_FILES[@]}"; do
  [ -e "${_f}" ] && _has_repo=true
done

if [ "${_has_pkg}" = "false" ] && [ "${_has_repo}" = "false" ]; then
  msg_skip "Docker não está instalado e nenhum repositório Docker foi encontrado. Nada a reverter."
  exit 0
fi

# --- Confirmação geral (operação pesada) ---
if ! confirm_destructive "REMOVER o Docker desta máquina (todos os containers em execução serão parados)"; then
  if _dry; then
    echo "  ${YELLOW}[dry-run]${NO_COLOR} etapas que seriam executadas: parar serviços, desinstalar ${DOCKER_PKGS[*]}, remover repositório, remover usuário do grupo docker"
    exit 0
  fi
  msg_skip "Reversão cancelada. Nada foi alterado."
  exit 0
fi

# --- 1. Serviços ---
for _svc in docker.socket docker containerd; do
  revert_service "${_svc}" "started enabled"
done

# --- 2. Pacotes (já confirmado acima; não perguntar um a um) ---
for _pkg in "${DOCKER_PKGS[@]}"; do
  REVERT_ASSUME_YES=1 revert_package "${_pkg}"
done

# --- 3. Repositório / keyring ---
for _f in "${DOCKER_REPO_FILES[@]}"; do
  revert_repo_added "${_f}"
done

# --- 4. Usuário no grupo docker ---
_REAL_USER="${SUDO_USER:-${USER}}"
if id -nG "${_REAL_USER}" 2>/dev/null | tr ' ' '\n' | grep -qx "docker"; then
  if _dry; then
    echo "  ${YELLOW}[dry-run]${NO_COLOR} removeria '${_REAL_USER}' do grupo docker"
  else
    msg_action "Removendo '${_REAL_USER}' do grupo docker..."
    sudo gpasswd -d "${_REAL_USER}" docker >/dev/null || msg_error "Não foi possível remover '${_REAL_USER}' do grupo docker."
  fi
else
  msg_skip "Usuário '${_REAL_USER}' não está no grupo docker."
fi

# --- 5. Dados (confirmação separada) ---
for _dir in /var/lib/docker /var/lib/containerd; do
  revert_dir "${_dir}" --destructive
done

msg_action "Reversão da instalação do Docker concluída."
