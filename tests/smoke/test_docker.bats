#!/usr/bin/env bats
# tests/smoke/test_docker.bats - Testes de fumaça para scripts Docker
# Valida a arquitetura de delegação (suap-setup → suap / suap_deploy)

setup() {
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    DEV_SCRIPT="$PROJECT_ROOT/docker/dev/docker-setup.sh"
    PROD_SCRIPT="$PROJECT_ROOT/docker/prod/docker-setup.sh"
    COMMON_LIB="$PROJECT_ROOT/lib/common.sh"
}

# ============================================================
# Validação de existência e permissões dos scripts
# ============================================================

@test "docker/dev/docker-setup.sh existe" {
    [ -f "$DEV_SCRIPT" ]
}

@test "docker/prod/docker-setup.sh existe" {
    [ -f "$PROD_SCRIPT" ]
}

@test "docker/dev/docker-setup.sh é bash válido" {
    run bash -n "$DEV_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "docker/prod/docker-setup.sh é bash válido" {
    run bash -n "$PROD_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================
# Validação de que os scripts NÃO mantêm Dockerfiles locais
# (princípio de delegação — sem duplicação)
# ============================================================

@test "NÃO existe Dockerfile local em docker/dev/" {
    [ ! -f "$PROJECT_ROOT/docker/dev/Dockerfile" ]
}

@test "NÃO existe Dockerfile local em docker/prod/" {
    [ ! -f "$PROJECT_ROOT/docker/prod/Dockerfile" ]
}

@test "NÃO existe docker-compose.yml local em docker/dev/" {
    [ ! -f "$PROJECT_ROOT/docker/dev/docker-compose.yml" ]
}

@test "NÃO existe docker-compose.prod.yml local em docker/prod/" {
    [ ! -f "$PROJECT_ROOT/docker/prod/docker-compose.prod.yml" ]
}

# ============================================================
# Validação de que os scripts sourcam lib/common.sh
# ============================================================

@test "docker/dev/docker-setup.sh faz source de lib/common.sh" {
    run grep -q 'source.*lib/common.sh' "$DEV_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "docker/prod/docker-setup.sh faz source de lib/common.sh" {
    run grep -q 'source.*lib/common.sh' "$PROD_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================
# Validação de delegação: dev → suap (docker-compose.dev.yml)
# ============================================================

@test "docker/dev/docker-setup.sh referencia docker-compose.dev.yml do SUAP" {
    run grep -q 'docker-compose.dev.yml' "$DEV_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "docker/dev/docker-setup.sh usa SUAP_DIR como base" {
    run grep -q 'SUAP_DIR' "$DEV_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "docker/dev/docker-setup.sh exporta SUAP_IMAGE" {
    run grep -q 'export SUAP_IMAGE' "$DEV_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "docker/dev/docker-setup.sh verifica check_docker_available" {
    run grep -q 'check_docker_available' "$DEV_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================
# Validação de delegação: prod → suap_deploy (Makefile)
# ============================================================

@test "docker/prod/docker-setup.sh referencia DEPLOY_DIR" {
    run grep -q 'DEPLOY_DIR' "$PROD_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "docker/prod/docker-setup.sh referencia Makefile do suap_deploy" {
    run grep -q 'Makefile' "$PROD_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "docker/prod/docker-setup.sh usa make para gerenciar serviços" {
    run grep -q 'make start-web' "$PROD_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "docker/prod/docker-setup.sh usa make pull-image" {
    run grep -q 'make pull-image' "$PROD_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "docker/prod/docker-setup.sh usa make build" {
    run grep -q 'make build' "$PROD_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "docker/prod/docker-setup.sh verifica check_docker_available" {
    run grep -q 'check_docker_available' "$PROD_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "docker/prod/docker-setup.sh suporta clone com --recurse-submodules" {
    run grep -q '\-\-recurse-submodules' "$PROD_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================
# Validação de variáveis Docker no .env e common.sh
# ============================================================

@test "lib/common.sh suporta variável SUAP_IMAGE no wizard" {
    run grep -q 'SUAP_IMAGE' "$COMMON_LIB"
    [ "$status" -eq 0 ]
}

@test "lib/common.sh suporta variável DEPLOY_DIR no wizard" {
    run grep -q 'DEPLOY_DIR' "$COMMON_LIB"
    [ "$status" -eq 0 ]
}

@test "lib/common.sh suporta variável DEPLOY_GIT_URL no wizard" {
    run grep -q 'DEPLOY_GIT_URL' "$COMMON_LIB"
    [ "$status" -eq 0 ]
}

@test "lib/common.sh grava SUAP_IMAGE no _write_env" {
    run grep -q "SUAP_IMAGE" "$COMMON_LIB"
    [ "$status" -eq 0 ]
}

@test "lib/common.sh grava DEPLOY_DIR no _write_env" {
    run grep -q "DEPLOY_DIR" "$COMMON_LIB"
    [ "$status" -eq 0 ]
}
