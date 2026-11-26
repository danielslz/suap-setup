#!/usr/bin/env bats
# tests/unit/test_config_migrate.bats
# Testes de `suap-setup config migrate` (cópia sem sobrescrever, dry-run, idempotência).
setup() {
    load '../test_helper/common-setup'
    TD="$(mktemp -d)"
    unset SUAP_SETUP_DRY_RUN SUAP_SETUP_ENV_FILE
    export HOME="${TD}/home"
    mkdir -p "${HOME}"
    export SUAP_SETUP_CONFIG_DIR="${TD}/cfg" SUAP_SETUP_STATE_DIR="${TD}/state"
    CLONE="${TD}/clone"
    mkdir -p "${CLONE}/.state"
    echo "A=1" > "${CLONE}/.env"
    chmod 644 "${CLONE}/.env"
    echo "segredo" > "${CLONE}/.state/arcane.key"
    chmod 644 "${CLONE}/.state/arcane.key"
    echo "m" > "${CLONE}/.state/redis.manifest"
    # Raiz de "instalação por tarball" falsa (com VERSION), para não depender do worktree
    ROOT="${TD}/root"
    mkdir -p "${ROOT}"
    cp -R "${PROJECT_ROOT}/bin" "${PROJECT_ROOT}/lib" "${PROJECT_ROOT}/completions" "${ROOT}/"
    echo "0.0.1" > "${ROOT}/VERSION"
    BIN="${ROOT}/bin/suap-setup"
}
teardown() {
    rm -rf "${TD}"
}
mode_of() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
@test "copia .env e estado com modo 600 no .env e arcane.key" {
    run "${BIN}" config migrate --from "${CLONE}"
    assert_success
    [ "$(cat "${SUAP_SETUP_CONFIG_DIR}/.env")" = "A=1" ]
    [ "$(mode_of "${SUAP_SETUP_CONFIG_DIR}/.env")" = "600" ]
    [ "$(cat "${SUAP_SETUP_STATE_DIR}/arcane.key")" = "segredo" ]
    [ "$(mode_of "${SUAP_SETUP_STATE_DIR}/arcane.key")" = "600" ]
    [ -f "${SUAP_SETUP_STATE_DIR}/redis.manifest" ]
}
@test "não sobrescreve destinos existentes" {
    mkdir -p "${SUAP_SETUP_CONFIG_DIR}" "${SUAP_SETUP_STATE_DIR}"
    echo "NOVO=1" > "${SUAP_SETUP_CONFIG_DIR}/.env"
    echo "outro" > "${SUAP_SETUP_STATE_DIR}/arcane.key"
    run "${BIN}" config migrate --from "${CLONE}"
    assert_success
    [ "$(cat "${SUAP_SETUP_CONFIG_DIR}/.env")" = "NOVO=1" ]
    [ "$(cat "${SUAP_SETUP_STATE_DIR}/arcane.key")" = "outro" ]
}
@test "dry-run não escreve nada" {
    run "${BIN}" config migrate --from "${CLONE}" --dry-run
    assert_success
    assert_output --partial "dry-run"
    [ ! -e "${SUAP_SETUP_CONFIG_DIR}" ]
    [ ! -e "${SUAP_SETUP_STATE_DIR}" ]
}
@test "é idempotente e não altera o clone" {
    run "${BIN}" config migrate --from "${CLONE}"
    assert_success
    run "${BIN}" config migrate --from "${CLONE}"
    assert_success
    assert_output --partial "mantido"
    [ "$(cat "${CLONE}/.env")" = "A=1" ]
    [ "$(mode_of "${CLONE}/.env")" = "644" ]
    [ "$(cat "${CLONE}/.state/arcane.key")" = "segredo" ]
}
@test "origem sem dados falha" {
    mkdir "${TD}/vazio"
    run "${BIN}" config migrate --from "${TD}/vazio"
    assert_failure
}
@test "sem --from sugere o clone em ~/suap-setup sem copiar" {
    cp -R "${CLONE}" "${HOME}/suap-setup"
    run "${BIN}" config migrate
    assert_success
    assert_output --partial "--from ${HOME}/suap-setup"
    [ ! -e "${SUAP_SETUP_CONFIG_DIR}/.env" ]
}
@test "sem --from e sem clone falha" {
    run "${BIN}" config migrate
    assert_failure
}
