#!/usr/bin/env bats
# tests/smoke/test_install_docker.bats - Testes de fumaça para docker/install-docker.sh
# Valida: Requisitos 29.4, 29.5, 29.6, 29.8, 29.9, 29.10, 29.11

setup() {
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    INSTALL_DOCKER_SCRIPT="$PROJECT_ROOT/docker/install-docker.sh"
}

# ============================================================
# Validação de existência e permissões do script
# ============================================================

@test "install-docker.sh existe" {
    [ -f "$INSTALL_DOCKER_SCRIPT" ]
}

@test "install-docker.sh é executável" {
    [ -x "$INSTALL_DOCKER_SCRIPT" ]
}

# ============================================================
# Validação de source da biblioteca compartilhada
# Requisito 29.4: script deve usar lib/common.sh
# ============================================================

@test "install-docker.sh faz source de lib/common.sh" {
    run grep -q 'source.*lib/common.sh' "$INSTALL_DOCKER_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================
# Validação de cases por distribuição
# Requisito 29.5: suportar deb, rpm, arch, macos
# ============================================================

@test "install-docker.sh contém case para deb" {
    run grep -q 'deb)' "$INSTALL_DOCKER_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "install-docker.sh contém case para rpm" {
    run grep -q 'rpm)' "$INSTALL_DOCKER_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "install-docker.sh contém case para arch" {
    run grep -q 'arch)' "$INSTALL_DOCKER_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "install-docker.sh contém case para macos" {
    run grep -q 'macos)' "$INSTALL_DOCKER_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================
# Validação de pacotes Docker instalados (deb/rpm)
# Requisito 29.6: instalar docker-ce, docker-ce-cli, containerd.io, docker-compose-plugin
# ============================================================

@test "install-docker.sh instala docker-ce" {
    run grep -q 'docker-ce' "$INSTALL_DOCKER_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "install-docker.sh instala docker-ce-cli" {
    run grep -q 'docker-ce-cli' "$INSTALL_DOCKER_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "install-docker.sh instala containerd.io" {
    run grep -q 'containerd.io' "$INSTALL_DOCKER_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "install-docker.sh instala docker-compose-plugin" {
    run grep -q 'docker-compose-plugin' "$INSTALL_DOCKER_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================
# Validação de instalação Arch via pacman
# Requisito 29.8: Arch usa pacman -S --needed --noconfirm docker docker-compose
# ============================================================

@test "install-docker.sh usa pacman -S --needed --noconfirm docker docker-compose para Arch" {
    run grep -q 'pacman -S --needed --noconfirm docker docker-compose' "$INSTALL_DOCKER_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================
# Validação de início e habilitação do serviço Docker
# Requisito 29.9: systemctl start docker e systemctl enable docker
# ============================================================

@test "install-docker.sh executa systemctl start docker" {
    run grep -q 'systemctl start docker' "$INSTALL_DOCKER_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "install-docker.sh executa systemctl enable docker" {
    run grep -q 'systemctl enable docker' "$INSTALL_DOCKER_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================
# Validação de adição do usuário ao grupo docker
# Requisito 29.10: usermod -aG docker
# ============================================================

@test "install-docker.sh adiciona usuário ao grupo docker com usermod -aG" {
    run grep -q 'usermod -aG docker' "$INSTALL_DOCKER_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================
# Validação de verificação pós-instalação
# Requisito 29.11: docker --version e docker compose version
# ============================================================

@test "install-docker.sh verifica instalação com docker --version" {
    run grep -q 'docker --version' "$INSTALL_DOCKER_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "install-docker.sh verifica instalação com docker compose version" {
    run grep -q 'docker compose version' "$INSTALL_DOCKER_SCRIPT"
    [ "$status" -eq 0 ]
}
