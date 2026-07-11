#!/usr/bin/env bash
set -u

# docker/install-docker.sh - Instalação automatizada do Docker
# Detecta a distribuição e instala Docker + Docker Compose conforme o OS.

# Determinar diretório do script e source da biblioteca compartilhada
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- Detectar distribuição ---
detect_distro

# --- Funções de instalação por distribuição ---

install_docker_debian() {
  msg_action "Instalando Docker em distribuição Debian-like (${DISTRO_NAME})..."

  # Instalar dependências para adicionar repositório
  apt-get update
  apt-get install -y ca-certificates curl gnupg

  # Adicionar chave GPG oficial do Docker
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  # Adicionar repositório Docker ao sources.list
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${DISTRO_NAME} \
    $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Instalar pacotes Docker
  apt-get update
  if ! apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin; then
    msg_error "Falha ao instalar pacotes Docker via apt."
    exit 1
  fi
}

install_docker_rpm() {
  msg_action "Instalando Docker em distribuição RPM-like (${DISTRO_NAME})..."

  # Adicionar repositório oficial Docker
  dnf -y install dnf-plugins-core
  dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

  # Instalar pacotes Docker
  if ! dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin; then
    msg_error "Falha ao instalar pacotes Docker via dnf."
    exit 1
  fi
}

install_docker_arch() {
  msg_action "Instalando Docker em distribuição Arch-like (${DISTRO_NAME})..."

  if ! pacman -S --needed --noconfirm docker docker-compose; then
    msg_error "Falha ao instalar pacotes Docker via pacman."
    exit 1
  fi
}

# --- Execução principal ---

case "${DISTRO_TYPE}" in
  deb)
    install_docker_debian
    ;;
  rpm)
    install_docker_rpm
    ;;
  arch)
    install_docker_arch
    ;;
  macos)
    msg_action "No macOS, o Docker Desktop é obrigatório."
    msg_action "Faça o download e instale manualmente:"
    msg_action "https://docs.docker.com/desktop/install/mac-install/"
    exit 0
    ;;
  *)
    msg_error "Instalação automática do Docker não é suportada para a distribuição detectada: ${DISTRO_NAME:-desconhecida}"
    exit 1
    ;;
esac

# --- Pós-instalação: iniciar e habilitar serviço ---
msg_action "Iniciando e habilitando serviço Docker..."
systemctl start docker
systemctl enable docker

# --- Adicionar usuário atual ao grupo docker ---
msg_action "Adicionando usuário '${USER}' ao grupo docker..."
usermod -aG docker "${USER}"

# --- Verificação pós-instalação ---
msg_action "Verificando instalação do Docker..."

if ! docker --version; then
  msg_error "Verificação falhou: 'docker --version' retornou erro. A instalação não foi concluída com sucesso."
  exit 1
fi

if ! docker compose version; then
  msg_error "Verificação falhou: 'docker compose version' retornou erro. A instalação não foi concluída com sucesso."
  exit 1
fi

# --- Mensagem de sucesso ---
DOCKER_VERSION=$(docker --version)
COMPOSE_VERSION=$(docker compose version)

msg_action "Docker instalado com sucesso!"
msg_action "  Docker:  ${DOCKER_VERSION}"
msg_action "  Compose: ${COMPOSE_VERSION}"
echo ""
msg_action "AVISO: Pode ser necessário fazer logout e login novamente para que"
msg_action "       a adição ao grupo 'docker' tenha efeito (execução sem sudo)."
