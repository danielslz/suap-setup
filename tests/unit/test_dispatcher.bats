#!/usr/bin/env bats
# tests/unit/test_dispatcher.bats
# Testes do dispatcher bin/suap-setup usando SUAP_SETUP_DRY_RUN=1 (imprime EXEC: <script> <args>).

setup() {
    load '../test_helper/common-setup'
    export TERM=xterm
    TEST_TEMP_DIR="$(mktemp -d)"
    export SUAP_SETUP_DRY_RUN=1
    export SUAP_SETUP_CONFIG_DIR="${TEST_TEMP_DIR}/cfg"
    export SUAP_SETUP_STATE_DIR="${TEST_TEMP_DIR}/state"
    BIN="${PROJECT_ROOT}/bin/suap-setup"
    DISTRO="$(bash -c 'source "$1"; detect_distro; echo "$DISTRO_TYPE"' _ "$COMMON_SH")"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "deploy update --migrate roteia para suap-deploy.sh com argumentos" {
    run "$BIN" deploy update --migrate
    assert_success
    assert_output "EXEC: ${PROJECT_ROOT}/docker/prod/suap-deploy.sh update --migrate"
}

@test "node configure --role full" {
    run "$BIN" node configure --role full
    assert_success
    assert_output "EXEC: ${PROJECT_ROOT}/docker/prod/configure-node.sh --role full"
}

@test "stack haproxy" {
    run "$BIN" stack haproxy
    assert_output "EXEC: ${PROJECT_ROOT}/docker/haproxy-setup.sh"
}

@test "revert redis resolve para o stack Docker" {
    run "$BIN" revert redis
    assert_output "EXEC: ${PROJECT_ROOT}/docker/redis-revert.sh"
}

@test "revert host redis sem script de reversão: erro e exit 2" {
    run "$BIN" revert host redis
    assert_failure 2
    assert_output --partial "Script não encontrado"
}

@test "revert host dev usa o diretório da distro" {
    run "$BIN" revert host dev
    assert_output "EXEC: ${PROJECT_ROOT}/${DISTRO}/suap-dev-revert.sh"
}

@test "menu roteia para setup.sh" {
    run "$BIN" menu
    assert_output "EXEC: ${PROJECT_ROOT}/setup.sh"
}

@test "host dev conforme detect_distro" {
    run "$BIN" host dev
    assert_output "EXEC: ${PROJECT_ROOT}/${DISTRO}/suap-dev.sh"
}

@test "todas as rotas documentadas apontam para scripts existentes" {
    local routes=(
        "host dev" "host prod" "host update" "host redis" "host nginx" "host postgres"
        "docker dev" "docker prod" "docker install"
        "stack redis" "stack postgres" "stack dockhand" "stack arcane" "stack arcane-agent" "stack haproxy" "stack minio"
        "deploy status" "node configure" "menu"
        "revert redis" "revert postgres" "revert dockhand" "revert arcane" "revert arcane-agent" "revert haproxy" "revert minio"
        "revert host dev" "revert docker dev" "revert docker prod" "revert docker install"
        "revert stack redis" "revert stack minio"
    )
    # macOS não tem prod/update/redis/nginx/postgres no host
    local r
    for r in "${routes[@]}"; do
        if [ "$DISTRO" = "macos" ]; then
            case "$r" in "host prod" | "host update" | "host redis" | "host nginx" | "host postgres") continue ;; esac
        fi
        run "$BIN" $r
        [ "$status" -eq 0 ] || { echo "falhou: $r -> $output"; return 1; }
        local script="${output#EXEC: }"
        script="${script%% *}"
        [ -f "$script" ] || { echo "inexistente: $r -> $script"; return 1; }
    done
}

@test "subcomando desconhecido: exit 2 com ajuda" {
    run "$BIN" xpto
    assert_failure 2
    assert_output --partial "Subcomando desconhecido"
    assert_output --partial "Uso: suap-setup"
}

@test "alvo desconhecido em grupo: exit 2" {
    run "$BIN" stack nada
    assert_failure 2
    run "$BIN" revert nada
    assert_failure 2
}

@test "help, -h e sem argumentos mostram o uso" {
    run "$BIN" help
    assert_success
    assert_output --partial "Uso: suap-setup"
    run "$BIN" --help
    assert_output --partial "Uso: suap-setup"
    run "$BIN"
    assert_output --partial "Uso: suap-setup"
}

@test "version imprime a versão" {
    run "$BIN" version
    assert_success
    assert_output --regexp '^suap-setup .+'
}

@test "config path imprime .env e diretório de estado" {
    run "$BIN" config path
    assert_success
    assert_line --index 1 "${SUAP_SETUP_STATE_DIR}"
}

@test "self-update e config migrate avisam quando o arquivo não existe" {
    [ -f "${PROJECT_ROOT}/lib/cmd-self-update.sh" ] && skip "já implementado"
    run "$BIN" self-update
    assert_failure 2
    assert_output --partial "não disponível"
}

@test "completion bash imprime a função de autocompletar" {
    run "$BIN" completion bash
    assert_success
    assert_output --partial "_suap_setup"
    assert_output --partial "--rollback"
    assert_output --partial "--check"
    assert_output --partial "--from"
    bash -n "${PROJECT_ROOT}/completions/suap-setup.bash"
}

@test "invocação via symlink resolve a raiz física" {
    ln -s "$BIN" "${TEST_TEMP_DIR}/suap-setup"
    run "${TEST_TEMP_DIR}/suap-setup" deploy status
    assert_success
    assert_output "EXEC: ${PROJECT_ROOT}/docker/prod/suap-deploy.sh status"
}

@test "SUAP_SETUP_ENV_FILE é exportado para o script alvo" {
    unset SUAP_SETUP_DRY_RUN
    mkdir -p "${TEST_TEMP_DIR}/fake/lib" "${TEST_TEMP_DIR}/fake/bin" "${TEST_TEMP_DIR}/fake/docker/prod"
    cp "${PROJECT_ROOT}/lib/common.sh" "${PROJECT_ROOT}/lib/paths.sh" "${TEST_TEMP_DIR}/fake/lib/"
    cp "$BIN" "${TEST_TEMP_DIR}/fake/bin/suap-setup"
    printf '#!/bin/bash\necho "ENV=${SUAP_SETUP_ENV_FILE}"\n' > "${TEST_TEMP_DIR}/fake/docker/prod/suap-deploy.sh"
    mkdir -p "$SUAP_SETUP_CONFIG_DIR"; touch "${SUAP_SETUP_CONFIG_DIR}/.env"
    run "${TEST_TEMP_DIR}/fake/bin/suap-setup" deploy
    assert_success
    assert_output "ENV=${SUAP_SETUP_CONFIG_DIR}/.env"
}
