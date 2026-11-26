#!/usr/bin/env bats
# tests/unit/test_self_update.bats
# Testes de `suap-setup self-update` contra releases locais (file://).
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
    unset SUAP_SETUP_DRY_RUN SUAP_SETUP_ENV_FILE
    export HOME="${TD}/home"
    mkdir -p "${HOME}"
    export SUAP_SETUP_CONFIG_DIR="${TD}/cfg" SUAP_SETUP_STATE_DIR="${TD}/state"
    P="${TD}/opt" ; BIN="${TD}/bin"
    REL="${TD}/rel"
    cp -R "${FIX}/releases" "${REL}"
    export SUAP_SETUP_RELEASES_URL="file://${REL}"
    export SUAP_SETUP_LATEST_TAG=v0.0.2
    TREE="$(extract_fixture_release "${FIX}" v0.0.1)"
    bash "${TREE}/install.sh" --from-dir "${TREE}" --prefix "${P}" --bin-dir "${BIN}" --config-dir "${TD}/cfg" --state-dir "${TD}/state" --no-completion >/dev/null
}
teardown() {
    rm -rf "${TD}"
}
@test "atualiza: current vai para v0.0.2 e previous guarda v0.0.1" {
    run "${BIN}/suap-setup" self-update
    assert_success
    assert_output --partial "v0.0.1 -> v0.0.2"
    assert_output --partial "self-update --rollback"
    [ "$(readlink "${P}/current")" = "releases/v0.0.2" ]
    [ "$(cat "${P}/previous")" = "v0.0.1" ]
    run "${BIN}/suap-setup" version
    assert_output --partial "0.0.2"
}
@test "mesma versão: informa que já está atualizado" {
    export SUAP_SETUP_LATEST_TAG=v0.0.1
    run "${BIN}/suap-setup" self-update
    assert_success
    assert_output --partial "já está na versão mais recente"
}
@test "--check informa sem alterar" {
    run "${BIN}/suap-setup" self-update --check
    assert_success
    assert_output --partial "v0.0.2"
    [ "$(readlink "${P}/current")" = "releases/v0.0.1" ]
    [ ! -e "${P}/releases/v0.0.2" ]
}
@test "--version fixa uma versão" {
    export SUAP_SETUP_LATEST_TAG=v9.9.9
    run "${BIN}/suap-setup" self-update --version v0.0.2
    assert_success
    [ "$(readlink "${P}/current")" = "releases/v0.0.2" ]
}
@test "--version inválida falha" {
    run "${BIN}/suap-setup" self-update --version 1.2
    assert_failure
}
@test "checksum divergente: falha, current intacto, sem release órfã" {
    echo "0000000000000000000000000000000000000000000000000000000000000000  suap-setup-v0.0.2.tar.gz" > "${REL}/download/v0.0.2/SHA256SUMS"
    run "${BIN}/suap-setup" self-update
    assert_failure
    assert_output --partial "Checksum divergente"
    [ "$(readlink "${P}/current")" = "releases/v0.0.1" ]
    [ ! -e "${P}/releases/v0.0.2" ]
    [ ! -e "${P}/previous" ]
    run ls -A "${P}/releases"
    assert_output "v0.0.1"
}
@test "asset ausente: falha com a URL e nada muda" {
    rm "${REL}/download/v0.0.2/suap-setup-v0.0.2.tar.gz"
    run "${BIN}/suap-setup" self-update
    assert_failure
    assert_output --partial "${REL}/download/v0.0.2/suap-setup-v0.0.2.tar.gz"
    [ "$(readlink "${P}/current")" = "releases/v0.0.1" ]
    [ ! -e "${P}/releases/v0.0.2" ]
}
@test "rollback volta à versão anterior" {
    run "${BIN}/suap-setup" self-update
    assert_success
    run "${BIN}/suap-setup" self-update --rollback
    assert_success
    [ "$(readlink "${P}/current")" = "releases/v0.0.1" ]
    [ "$(cat "${P}/previous")" = "v0.0.2" ]
    run "${BIN}/suap-setup" version
    assert_output --partial "0.0.1"
}
@test "rollback sem previous falha" {
    run "${BIN}/suap-setup" self-update --rollback
    assert_failure
    assert_output --partial "Não há versão anterior"
}
@test "recusa em clone e explica a migração" {
    cd "${PROJECT_ROOT}"
    run bash "${PROJECT_ROOT}/bin/suap-setup" self-update
    assert_failure
    assert_output --partial "clone"
    assert_output --partial "config migrate"
}
@test "mantém no máximo 3 releases (nunca current/previous)" {
    local t
    for t in v0.0.3 v0.0.4 v0.0.5; do
        mkdir -p "${REL}/download/${t}"
        cp -R "${FIX}/repo" "${TD}/r-${t}" 2>/dev/null
        git -C "${TD}/r-${t}" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m x
        bash "${TD}/r-${t}/scripts/build-release.sh" "${t}" --out "${REL}/download/${t}" >/dev/null
        SUAP_SETUP_LATEST_TAG="${t}" run "${BIN}/suap-setup" self-update
        assert_success
    done
    run ls -1 "${P}/releases"
    assert_output "$(printf 'v0.0.3\nv0.0.4\nv0.0.5')"
}
