#!/usr/bin/env bats
# tests/unit/test_release_build.bats
# Testes de scripts/build-release.sh (tarball, exclusões, SHA256SUMS, reprodutibilidade).
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
    TARBALL="${FIX}/releases/download/v0.0.1/suap-setup-v0.0.1.tar.gz"
}
@test "tarball exclui tests, .github, .kiro e scripts" {
    run tar -tzf "${TARBALL}"
    assert_success
    refute_output --regexp '/(tests|\.github|\.kiro|scripts)(/|$)'
    refute_output --partial '.gitattributes'
}
@test "tarball inclui VERSION, bin, lib, completions e install.sh" {
    run tar -tzf "${TARBALL}"
    assert_output --partial 'suap-setup-v0.0.1/VERSION'
    assert_output --partial 'suap-setup-v0.0.1/bin/suap-setup'
    assert_output --partial 'suap-setup-v0.0.1/lib/common.sh'
    assert_output --partial 'suap-setup-v0.0.1/completions/suap-setup.bash'
    assert_output --partial 'suap-setup-v0.0.1/install.sh'
}
@test "VERSION não tem o prefixo v" {
    run tar -xzOf "${TARBALL}" suap-setup-v0.0.1/VERSION
    assert_output "0.0.1"
}
@test "SHA256SUMS cobre tarball e install.sh e confere" {
    cd "${FIX}/releases/download/v0.0.1"
    run grep -c . SHA256SUMS
    assert_output "2"
    run grep -E 'suap-setup-v0.0.1.tar.gz|install.sh' SHA256SUMS
    assert_success
    if command -v sha256sum >/dev/null 2>&1; then
        run sha256sum -c SHA256SUMS
    else
        run shasum -a 256 -c SHA256SUMS
    fi
    assert_success
}
@test "rejeita versão inválida" {
    run bash "${FIX}/repo/scripts/build-release.sh" 1.0 --out "${BATS_TEST_TMPDIR}/o"
    assert_failure
    run bash "${FIX}/repo/scripts/build-release.sh" --out "${BATS_TEST_TMPDIR}/o"
    assert_failure
}
@test "tarball é reprodutível" {
    run bash "${FIX}/repo/scripts/build-release.sh" v0.0.1 --out "${BATS_TEST_TMPDIR}/o"
    assert_success
    run cmp "${BATS_TEST_TMPDIR}/o/suap-setup-v0.0.1.tar.gz" "${TARBALL}"
    assert_success
}
