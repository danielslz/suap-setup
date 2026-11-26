#!/usr/bin/env bats
# tests/unit/test_paths.bats
# Testes de lib/paths.sh e da integração com lib/common.sh (precedência de .env e estado).
# Usa raízes temporárias: copia lib/paths.sh para <tmp>/<raiz>/lib/ (a raiz é derivada
# da localização do arquivo). Nada em /etc, /opt ou /usr/local é tocado.

setup() {
    load '../test_helper/common-setup'
    export TERM=xterm
    TEST_TEMP_DIR="$(mktemp -d)"
    ROOT="${TEST_TEMP_DIR}/raiz"
    mkdir -p "${ROOT}/lib"
    cp "${LIB_DIR}/paths.sh" "${ROOT}/lib/paths.sh"
    export SUAP_SETUP_CONFIG_DIR="${TEST_TEMP_DIR}/cfg"
    unset SUAP_SETUP_ENV_FILE SUAP_SETUP_STATE_DIR
    HOME="${TEST_TEMP_DIR}/home"
    mkdir -p "$HOME"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# Executa uma função de paths.sh a partir da raiz temporária
_paths() {
    bash -c 'source "$1/lib/paths.sh"; shift; "$@"' _ "$ROOT" "$@"
}

@test "suap_setup_root devolve a raiz física" {
    run _paths suap_setup_root
    assert_success
    assert_output "$(cd "$ROOT" && pwd -P)"
}

@test "versão: dev quando não há VERSION nem git" {
    run _paths suap_setup_version
    assert_output "dev"
}

@test "versão: lê o arquivo VERSION" {
    echo "1.2.3" > "${ROOT}/VERSION"
    run _paths suap_setup_version
    assert_output "1.2.3"
}

@test "suap_setup_is_release_install depende do VERSION" {
    run _paths suap_setup_is_release_install
    assert_failure
    echo "1.0.0" > "${ROOT}/VERSION"
    run _paths suap_setup_is_release_install
    assert_success
}

@test "dirs padrão no Linux e sobrescrita por variável" {
    [ "$(uname -s)" = "Darwin" ] && skip "padrões do Linux"
    unset SUAP_SETUP_CONFIG_DIR
    run _paths suap_setup_default_config_dir
    assert_output "/etc/suap-setup"
    run _paths suap_setup_default_state_dir
    assert_output "/var/lib/suap-setup"
    SUAP_SETUP_STATE_DIR="/tmp/x" run _paths suap_setup_default_state_dir
    assert_output "/tmp/x"
}

@test "env: SUAP_SETUP_ENV_FILE vence tudo" {
    mkdir -p "$SUAP_SETUP_CONFIG_DIR"; touch "${SUAP_SETUP_CONFIG_DIR}/.env" "${ROOT}/.env"
    SUAP_SETUP_ENV_FILE="/tmp/outro.env" run _paths suap_setup_resolve_env_file
    assert_output "/tmp/outro.env"
}

@test "env: config dir existente vence o legado" {
    mkdir -p "$SUAP_SETUP_CONFIG_DIR"; touch "${SUAP_SETUP_CONFIG_DIR}/.env" "${ROOT}/.env"
    run _paths suap_setup_resolve_env_file
    assert_output "${SUAP_SETUP_CONFIG_DIR}/.env"
}

@test "env: clone com .env legado e sem dir novo usa <raiz>/.env" {
    touch "${ROOT}/.env"
    run _paths suap_setup_resolve_env_file
    assert_output "$(cd "$ROOT" && pwd -P)/.env"
}

@test "env: criação em clone vai para <raiz>/.env e em tarball para o config dir" {
    run _paths suap_setup_resolve_env_file
    assert_output "$(cd "$ROOT" && pwd -P)/.env"
    echo "1.0.0" > "${ROOT}/VERSION"
    run _paths suap_setup_resolve_env_file
    assert_output "${SUAP_SETUP_CONFIG_DIR}/.env"
}

@test "estado: SUAP_SETUP_STATE_DIR vence" {
    SUAP_SETUP_STATE_DIR="/tmp/estado-x" run _paths suap_setup_resolve_state_dir
    assert_output "/tmp/estado-x"
}

@test "estado: dir novo com arquivos vence o legado" {
    [ "$(uname -s)" = "Darwin" ] || skip "usa o padrão do macOS (HOME temporário)"
    mkdir -p "${HOME}/.local/state/suap-setup" "${ROOT}/.state"
    touch "${HOME}/.local/state/suap-setup/a.manifest" "${ROOT}/.state/b.manifest"
    run _paths suap_setup_resolve_state_dir
    assert_output "${HOME}/.local/state/suap-setup"
}

@test "estado: legado <raiz>/.state com arquivos é usado no clone" {
    mkdir -p "${ROOT}/.state"; touch "${ROOT}/.state/b.manifest"
    run _paths suap_setup_resolve_state_dir
    assert_output "$(cd "$ROOT" && pwd -P)/.state"
}

@test "estado: criação em clone usa <raiz>/.state e em tarball o dir novo" {
    run _paths suap_setup_resolve_state_dir
    assert_output "$(cd "$ROOT" && pwd -P)/.state"
    echo "1.0.0" > "${ROOT}/VERSION"
    run _paths suap_setup_resolve_state_dir
    if [ "$(uname -s)" = "Darwin" ]; then
        assert_output "${HOME}/.local/state/suap-setup"
    else
        assert_output "/var/lib/suap-setup"
    fi
}

@test "resolução não cria nada" {
    run _paths suap_setup_resolve_env_file
    run _paths suap_setup_resolve_state_dir
    [ ! -e "${ROOT}/.state" ]
    [ ! -e "$SUAP_SETUP_CONFIG_DIR" ]
}

@test "create_default_env cria o diretório pai e o arquivo com modo 600" {
    run bash -c 'source "$1"; create_default_env "$2"' _ "$COMMON_SH" "${TEST_TEMP_DIR}/novo/sub/.env"
    assert_success
    [ -f "${TEST_TEMP_DIR}/novo/sub/.env" ]
    run stat -c '%a' "${TEST_TEMP_DIR}/novo/sub/.env"
    [ "$status" -eq 0 ] || run stat -f '%Lp' "${TEST_TEMP_DIR}/novo/sub/.env"
    assert_output "600"
}

@test "common.sh exporta SUAP_SETUP_ENV_FILE a partir do config dir" {
    mkdir -p "$SUAP_SETUP_CONFIG_DIR"; touch "${SUAP_SETUP_CONFIG_DIR}/.env"
    run bash -c 'source "$1"; echo "$SUAP_SETUP_ENV_FILE"; bash -c "echo \$SUAP_SETUP_ENV_FILE"' _ "$COMMON_SH"
    assert_line --index 0 "${SUAP_SETUP_CONFIG_DIR}/.env"
    assert_line --index 1 "${SUAP_SETUP_CONFIG_DIR}/.env"
}

@test "_manifest_state_dir usa SUAP_SETUP_STATE_DIR e cria o diretório" {
    run bash -c 'source "$1"; _manifest_state_dir' _ "$COMMON_SH"
    SUAP_SETUP_STATE_DIR="${TEST_TEMP_DIR}/st" run bash -c 'source "$1"; _manifest_state_dir' _ "$COMMON_SH"
    assert_success
    assert_output "${TEST_TEMP_DIR}/st"
    [ -d "${TEST_TEMP_DIR}/st" ]
}
