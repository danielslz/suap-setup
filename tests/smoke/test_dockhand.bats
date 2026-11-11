#!/usr/bin/env bats
# tests/smoke/test_dockhand.bats - Testes de fumaça para Dockhand
# Valida: Requisitos 27.1, 27.2, 27.7, 27.8
# Feature: suap-setup, Property 5: Idempotência do Dockhand

setup() {
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    DOCKHAND_SCRIPT="$PROJECT_ROOT/docker/dockhand-setup.sh"
}

# ============================================================
# Validação de existência e permissões do script
# ============================================================

@test "dockhand-setup.sh existe" {
    [ -f "$DOCKHAND_SCRIPT" ]
}

@test "dockhand-setup.sh é executável" {
    [ -x "$DOCKHAND_SCRIPT" ]
}

# ============================================================
# Validação de source da biblioteca compartilhada
# Requisito 27.1: script deve usar lib/common.sh
# ============================================================

@test "dockhand-setup.sh faz source de lib/common.sh" {
    run grep -q 'source.*lib/common.sh' "$DOCKHAND_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================
# Validação de verificação do Docker
# Requisito 27.2: verificar disponibilidade do Docker
# ============================================================

@test "dockhand-setup.sh chama check_docker_available" {
    run grep -q 'check_docker_available' "$DOCKHAND_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================
# Validação de idempotência (Property 5)
# Requisito 27.7: não tenta criar container se já existe
# ============================================================

@test "dockhand-setup.sh verifica container existente com docker ps --filter" {
    run grep -q 'docker ps --filter' "$DOCKHAND_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "dockhand-setup.sh filtra por nome exato do container dockhand" {
    run grep -q 'name=.*CONTAINER_NAME\|name=.*dockhand' "$DOCKHAND_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "dockhand-setup.sh é idempotente via docker compose up -d" {
    run grep -q 'up -d' "$DOCKHAND_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "dockhand-setup.sh assume container legado (docker run) via stack_adopt_legacy" {
    run grep -q 'stack_adopt_legacy' "$DOCKHAND_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================
# Validação de mapeamento de porta
# Requisito 27.8: porta 9093 (padrão, configurável via DOCKHAND_PORT) -> 3000
# ============================================================

@test "dockhand-setup.sh mapeia porta configurável (padrão 9093) para 3000" {
    run grep -q 'DOCKHAND_PORT:-9093' "$DOCKHAND_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================
# Validação de montagem do socket Docker
# Requisito 27.1: acesso ao Docker socket
# ============================================================

@test "dockhand-setup.sh monta /var/run/docker.sock" {
    run grep -q '/var/run/docker.sock:/var/run/docker.sock' "$DOCKHAND_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================
# Validação de política de reinício
# Requisito 27.2: container deve reiniciar automaticamente
# ============================================================

@test "dockhand-setup.sh usa restart: unless-stopped no compose" {
    run grep -q 'restart: unless-stopped' "$DOCKHAND_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================
# Validação de imagem utilizada
# ============================================================

@test "dockhand-setup.sh usa imagem fnsys/dockhand:latest" {
    run grep -q 'fnsys/dockhand:latest' "$DOCKHAND_SCRIPT"
    [ "$status" -eq 0 ]
}
