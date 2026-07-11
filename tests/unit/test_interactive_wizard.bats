#!/usr/bin/env bats
# Unit tests for interactive_env_wizard() function
# Validates: Requirements 28.1, 28.2, 28.3, 28.4, 28.5, 28.6, 28.7, 28.8, 28.9, 28.10

setup() {
    load '../test_helper/common-setup'
    TEST_TEMP_DIR="$(mktemp -d)"
    export TERM=xterm
    source "$COMMON_SH"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "interactive_env_wizard creates .env with all defaults when GIT_URL provided" {
    local env_file="${TEST_TEMP_DIR}/.env"

    # Simulate: Enter (default) for all fields, then provide GIT_URL
    printf '\n\n\n\nhttps://github.com/org/suap.git\n' | interactive_env_wizard "$env_file"

    # Verify file was created
    [ -f "$env_file" ]

    # Verify default values
    run grep "^PYTHON_VERSION=3.12$" "$env_file"
    assert_success

    run grep '^BASE_DIR=\$HOME/Projetos$' "$env_file"
    assert_success

    run grep '^SUAP_DIR=\${BASE_DIR}/suap$' "$env_file"
    assert_success

    run grep '^VENV_DIR=\${SUAP_DIR}/\.venv$' "$env_file"
    assert_success

    run grep '^GIT_URL=https://github.com/org/suap.git$' "$env_file"
    assert_success
}

@test "interactive_env_wizard uses custom values when provided" {
    local env_file="${TEST_TEMP_DIR}/.env"

    # Provide custom values for all fields
    printf '3.11\n/opt\n/opt/suap\n/opt/venv/suap\ngit@github.com:myorg/suap.git\n' | interactive_env_wizard "$env_file"

    [ -f "$env_file" ]

    run grep "^PYTHON_VERSION=3.11$" "$env_file"
    assert_success

    run grep "^BASE_DIR=/opt$" "$env_file"
    assert_success

    run grep "^SUAP_DIR=/opt/suap$" "$env_file"
    assert_success

    run grep "^VENV_DIR=/opt/venv/suap$" "$env_file"
    assert_success

    run grep '^GIT_URL=git@github.com:myorg/suap.git$' "$env_file"
    assert_success
}

@test "interactive_env_wizard exits 1 when GIT_URL is empty" {
    local env_file="${TEST_TEMP_DIR}/.env"

    # All defaults, but GIT_URL left empty (just Enter)
    run bash -c "source '$COMMON_SH'; printf '\n\n\n\n\n' | interactive_env_wizard '$env_file'"
    assert_failure
    assert_output --partial "GIT_URL"
}

@test "interactive_env_wizard .env contains descriptive comments" {
    local env_file="${TEST_TEMP_DIR}/.env"

    printf '\n\n\n\nhttps://example.com/suap.git\n' | interactive_env_wizard "$env_file"

    # Verify header comment
    run grep "Configuração centralizada do suap-setup" "$env_file"
    assert_success

    # Verify descriptive comments exist for variables
    run grep "# Versão do Python" "$env_file"
    assert_success

    run grep "# Diretório base para instalação" "$env_file"
    assert_success

    run grep "# Diretório onde o código SUAP" "$env_file"
    assert_success

    run grep "# Diretório do virtualenv" "$env_file"
    assert_success

    run grep "# URL do repositório Git" "$env_file"
    assert_success
}

@test "interactive_env_wizard shows confirmation with configured values" {
    local env_file="${TEST_TEMP_DIR}/.env"

    run bash -c "source '$COMMON_SH'; printf '\n\n\n\nhttps://git.example.com/suap.git\n' | interactive_env_wizard '$env_file'"
    assert_success

    # Verify confirmation output shows the values
    assert_output --partial "Arquivo .env criado com sucesso"
    assert_output --partial "PYTHON_VERSION"
    assert_output --partial "= 3.12"
    assert_output --partial "BASE_DIR"
    assert_output --partial '= $HOME/Projetos'
    assert_output --partial "SUAP_DIR"
    assert_output --partial '= ${BASE_DIR}/suap'
    assert_output --partial "VENV_DIR"
    assert_output --partial '= ${SUAP_DIR}/.venv'
    assert_output --partial "GIT_URL"
    assert_output --partial "= https://git.example.com/suap.git"
}
