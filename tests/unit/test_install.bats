#!/usr/bin/env bats
# tests/unit/test_install.bats
# Testes de install.sh em prefixos temporários (nunca toca /etc, /opt, /usr/local).
setup_file() {
    load '../test_helper/common-setup'
    load '../test_helper/release-fixture'
    export FIX="${BATS_FILE_TMPDIR}/fix"
    build_fixture_releases "${FIX}"
}
setup() {
    load '../test_helper/common-setup'
    load '../test_helper/release-fixture'
    export FIX="${BATS_FILE_TMPDIR}/fix"
    TD="$(mktemp -d)"
    unset SUAP_SETUP_DRY_RUN SUAP_SETUP_ENV_FILE SUAP_SETUP_CONFIG_DIR SUAP_SETUP_STATE_DIR
    export HOME="${TD}/home"
    mkdir -p "${HOME}"
    P="${TD}/opt" ; BIN="${TD}/bin" ; CFG="${TD}/cfg" ; ST="${TD}/state" ; COMP="${TD}/comp"
    TREE="$(extract_fixture_release "${FIX}" v0.0.1)"
    ARGS=(--from-dir "${TREE}" --prefix "${P}" --bin-dir "${BIN}" --config-dir "${CFG}" --state-dir "${ST}" --completion-dir "${COMP}")
}
teardown() {
    rm -rf "${TD}"
}
@test "instala release, current, comando e version" {
    run bash "${TREE}/install.sh" "${ARGS[@]}"
    assert_success
    [ -d "${P}/releases/v0.0.1" ]
    [ "$(readlink "${P}/current")" = "releases/v0.0.1" ]
    [ -L "${BIN}/suap-setup" ]
    run "${BIN}/suap-setup" version
    assert_success
    assert_output --partial "0.0.1"
}
@test "cria symlink de completion e diretórios 700" {
    run bash "${TREE}/install.sh" "${ARGS[@]}"
    assert_success
    [ -L "${COMP}/suap-setup" ]
    [ -f "${COMP}/suap-setup" ]
    [ "$(stat -c %a "${CFG}" 2>/dev/null || stat -f %Lp "${CFG}")" = "700" ]
    [ "$(stat -c %a "${ST}" 2>/dev/null || stat -f %Lp "${ST}")" = "700" ]
}
@test "--no-completion não cria o symlink" {
    run bash "${TREE}/install.sh" "${ARGS[@]}" --no-completion
    assert_success
    [ ! -e "${COMP}/suap-setup" ]
}
@test "reexecução é idempotente e preserva .env e estado" {
    run bash "${TREE}/install.sh" "${ARGS[@]}"
    assert_success
    echo "X=1" > "${CFG}/.env"
    echo "k" > "${ST}/arcane.key"
    run bash "${TREE}/install.sh" "${ARGS[@]}"
    assert_success
    [ "$(cat "${CFG}/.env")" = "X=1" ]
    [ "$(cat "${ST}/arcane.key")" = "k" ]
    [ "$(readlink "${P}/current")" = "releases/v0.0.1" ]
    [ ! -e "${P}/previous" ]
}
@test "sem árvore local baixa, verifica e instala (latest via SUAP_SETUP_LATEST_TAG)" {
    export SUAP_SETUP_RELEASES_URL="file://${FIX}/releases"
    export SUAP_SETUP_LATEST_TAG=v0.0.2
    run bash "${PROJECT_ROOT}/install.sh" --prefix "${P}" --bin-dir "${BIN}" --config-dir "${CFG}" --state-dir "${ST}" --completion-dir "${COMP}"
    assert_success
    run "${BIN}/suap-setup" version
    assert_output --partial "0.0.2"
}
@test "download com checksum adulterado não instala nada" {
    local rel="${TD}/rel"
    cp -R "${FIX}/releases" "${rel}"
    echo "0000000000000000000000000000000000000000000000000000000000000000  suap-setup-v0.0.1.tar.gz" > "${rel}/download/v0.0.1/SHA256SUMS"
    export SUAP_SETUP_RELEASES_URL="file://${rel}"
    run bash "${PROJECT_ROOT}/install.sh" --version v0.0.1 --prefix "${P}" --bin-dir "${BIN}" --config-dir "${CFG}" --state-dir "${ST}" --completion-dir "${COMP}"
    assert_failure
    [ ! -e "${P}" ]
    [ ! -e "${BIN}/suap-setup" ]
}
@test "--migrate-from copia .env do clone" {
    mkdir -p "${TD}/clone"
    echo "A=1" > "${TD}/clone/.env"
    run bash "${TREE}/install.sh" "${ARGS[@]}" --migrate-from "${TD}/clone"
    assert_success
    [ "$(cat "${CFG}/.env")" = "A=1" ]
    [ "$(cat "${TD}/clone/.env")" = "A=1" ]
}
@test "opção desconhecida falha" {
    run bash "${TREE}/install.sh" --foo
    assert_failure
}
