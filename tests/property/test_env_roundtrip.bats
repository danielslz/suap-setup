#!/usr/bin/env bats
# Feature: suap-setup, Property 1: Round-trip do arquivo .env
#
# Para qualquer conjunto de pares chave=valor válidos (sem caracteres especiais
# de shell não-escapados), escrever esses pares no arquivo .env e depois
# carregá-los com load_env_file() deve resultar em variáveis de shell com
# exatamente os mesmos valores originais.
#
# **Validates: Requirements 1.2, 1.3, 1.4, 1.5, 4.1, 4.3, 4.5**

setup() {
    load '../test_helper/common-setup'
    TEST_TEMP_DIR="$(mktemp -d)"

    # Source common.sh with TERM set to support tput
    export TERM=xterm
    source "$COMMON_SH"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# --- Helper Functions ---

# Generate a random alphanumeric string of given length
random_string() {
    local length="${1:-8}"
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c "$length"
}

# Generate a random key name (starts with letter, alphanumeric + underscore)
random_key() {
    local prefix
    prefix="$(cat /dev/urandom | tr -dc 'A-Z' | head -c 1)"
    local suffix
    suffix="$(cat /dev/urandom | tr -dc 'A-Z0-9_' | head -c 7)"
    echo "${prefix}${suffix}"
}

# Generate a random simple value (alphanumeric, dots, slashes, hyphens - no shell special chars)
random_value() {
    local length="${1:-12}"
    cat /dev/urandom | tr -dc 'a-zA-Z0-9/._-' | head -c "$length"
}

# --- Property Tests ---

@test "Property 1.1: Round-trip of random key=value pairs via load_env_file (100 iterations)" {
    local iterations=100
    local i

    for ((i = 1; i <= iterations; i++)); do
        # Generate a random number of key=value pairs (1 to 5)
        local num_pairs=$(( (RANDOM % 5) + 1 ))
        local env_file="${TEST_TEMP_DIR}/env_${i}"
        local -a keys=()
        local -a values=()

        # Generate random pairs and write to .env file
        > "$env_file"
        local j
        for ((j = 0; j < num_pairs; j++)); do
            local gen_key
            gen_key="TEST_$(random_key)_${i}_${j}"
            local gen_val
            gen_val="$(random_value)"
            keys+=("$gen_key")
            values+=("$gen_val")
            echo "${gen_key}=${gen_val}" >> "$env_file"
        done

        # Load the env file using load_env_file
        load_env_file "$env_file"

        # Verify each variable matches the original value
        for ((j = 0; j < num_pairs; j++)); do
            local actual_value
            actual_value="${!keys[$j]}"
            if [ "$actual_value" != "${values[$j]}" ]; then
                fail "Iteration $i, pair $j: Expected '${keys[$j]}=${values[$j]}' but got '${keys[$j]}=${actual_value}'"
            fi
        done

        # Unset variables to avoid pollution between iterations
        for ((j = 0; j < num_pairs; j++)); do
            unset "${keys[$j]}"
        done
    done
}

@test "Property 1.2: Round-trip preserves values with dots, slashes and hyphens (100 iterations)" {
    local iterations=100
    local i

    for ((i = 1; i <= iterations; i++)); do
        local env_file="${TEST_TEMP_DIR}/env_paths_${i}"
        local var_name="PATH_VAR_${i}"
        # Generate path-like values with slashes, dots, and hyphens
        local segment1 segment2 segment3
        segment1="$(random_string 5)"
        segment2="$(random_string 4)"
        segment3="$(random_string 6)"
        local expected_val="/opt/${segment1}/${segment2}-${segment3}.d"

        echo "${var_name}=${expected_val}" > "$env_file"

        load_env_file "$env_file"

        local actual_value="${!var_name}"
        if [ "$actual_value" != "$expected_val" ]; then
            fail "Iteration $i: Expected '${var_name}=${expected_val}' but got '${var_name}=${actual_value}'"
        fi

        unset "$var_name"
    done
}

@test "Property 1.3: Round-trip ignores comments and empty lines (100 iterations)" {
    local iterations=100
    local i

    for ((i = 1; i <= iterations; i++)); do
        local env_file="${TEST_TEMP_DIR}/env_comments_${i}"
        local var_name="COMMENT_TEST_${i}"
        local expected_val
        expected_val="$(random_value 10)"

        # Write env file with random comments and blank lines interspersed
        {
            echo "# This is a comment $(random_string 10)"
            echo ""
            echo "  # Indented comment"
            echo "${var_name}=${expected_val}"
            echo ""
            echo "# Another trailing comment"
        } > "$env_file"

        load_env_file "$env_file"

        local actual_value="${!var_name}"
        if [ "$actual_value" != "$expected_val" ]; then
            fail "Iteration $i: Expected '${var_name}=${expected_val}' but got '${var_name}=${actual_value}'"
        fi

        unset "$var_name"
    done
}

@test "Property 1.4: Round-trip with variable expansion in values (100 iterations)" {
    local iterations=100
    local i

    for ((i = 1; i <= iterations; i++)); do
        local env_file="${TEST_TEMP_DIR}/env_expand_${i}"
        local base_key="BASE_${i}"
        local derived_key="DERIVED_${i}"
        local base_value
        base_value="/opt/$(random_string 6)"

        # Write env with a base variable and a derived one using ${VAR} expansion
        {
            echo "${base_key}=${base_value}"
            echo "${derived_key}=\${${base_key}}/subdir"
        } > "$env_file"

        load_env_file "$env_file"

        local actual_base="${!base_key}"
        local actual_derived="${!derived_key}"
        local expected_derived="${base_value}/subdir"

        if [ "$actual_base" != "$base_value" ]; then
            fail "Iteration $i: Base - Expected '${base_value}' but got '${actual_base}'"
        fi

        if [ "$actual_derived" != "$expected_derived" ]; then
            fail "Iteration $i: Derived - Expected '${expected_derived}' but got '${actual_derived}'"
        fi

        unset "$base_key" "$derived_key"
    done
}

# --- Property 7: Fallback de .env em scripts individuais ---
# Feature: suap-setup, Property 7: Fallback de .env em scripts individuais
#
# Para qualquer script individual (Script_Dev, Script_Prod, Script_Docker_Dev,
# Script_Docker_Prod), quando executado diretamente em um ambiente onde o
# Arquivo_Env_Central não existe, o script deve encerrar com código de saída 1
# sem realizar nenhuma operação de instalação ou configuração.
#
# **Validates: Requirements 1.7**

@test "Property 7.1: require_env_file exits 1 for random non-existent paths (100 iterations)" {
    local iterations=100
    local i

    for ((i = 1; i <= iterations; i++)); do
        # Generate a random non-existent path
        local rand_segment1 rand_segment2 rand_segment3
        rand_segment1="$(random_string 8)"
        rand_segment2="$(random_string 6)"
        rand_segment3="$(random_string 10)"
        local fake_path="${TEST_TEMP_DIR}/nonexistent_${rand_segment1}/${rand_segment2}/${rand_segment3}/.env"

        # Ensure the path truly does not exist
        if [ -f "$fake_path" ]; then
            fail "Iteration $i: Generated path unexpectedly exists: $fake_path"
        fi

        # Run require_env_file in a subshell and capture exit code
        local exit_code=0
        (require_env_file "$fake_path") 2>/dev/null || exit_code=$?

        if [ "$exit_code" -ne 1 ]; then
            fail "Iteration $i: require_env_file('$fake_path') exited with $exit_code, expected 1"
        fi
    done
}

@test "Property 7.2: require_env_file does not execute any install operation when .env is missing" {
    local iterations=100
    local i

    for ((i = 1; i <= iterations; i++)); do
        local rand_name
        rand_name="$(random_string 12)"
        local fake_path="/tmp/nonexistent_${rand_name}_${i}/.env"

        # Capture all output from require_env_file to verify no install commands are attempted
        local output=""
        local exit_code=0
        output=$( (require_env_file "$fake_path") 2>&1 ) || exit_code=$?

        # Verify exit code is 1
        if [ "$exit_code" -ne 1 ]; then
            fail "Iteration $i: Expected exit 1, got $exit_code for path '$fake_path'"
        fi

        # Verify output contains error message (not install commands)
        if [[ "$output" != *"não encontrado"* ]] && [[ "$output" != *"setup.sh"* ]]; then
            fail "Iteration $i: Output did not contain expected error messages. Got: $output"
        fi

        # Verify no installation-related keywords in output
        if [[ "$output" == *"apt install"* ]] || [[ "$output" == *"dnf install"* ]] || \
           [[ "$output" == *"pip install"* ]] || [[ "$output" == *"docker compose"* ]]; then
            fail "Iteration $i: Detected install operation in output when .env is missing: $output"
        fi
    done
}

# Feature: suap-setup, Property 6: Round-trip do Wizard_Env
#
# Para qualquer conjunto de valores de entrada (PYTHON_VERSION, BASE_DIR,
# SUAP_DIR, VENV_DIR como strings não-vazias, e GIT_URL como string não-vazia),
# quando esses valores são fornecidos como stdin ao interactive_env_wizard(),
# o arquivo .env resultante, ao ser carregado com load_env_file(), deve produzir
# variáveis de shell com exatamente os mesmos valores fornecidos.
#
# **Validates: Requirements 28.3, 28.4, 28.5, 28.6, 28.8, 28.9**

@test "Property 6: Round-trip do Wizard_Env com valores aleatórios (100 iterações)" {
    local iterations=100
    local i

    for ((i = 1; i <= iterations; i++)); do
        local env_file="${TEST_TEMP_DIR}/wizard_env_${i}"

        # Generate random values for each wizard field
        local rand_python_version
        rand_python_version="3.$(( (RANDOM % 5) + 10 ))"  # e.g., 3.10, 3.11, 3.12, 3.13, 3.14

        local rand_git_url
        rand_git_url="https://github.com/$(random_string 5)/$(random_string 8).git"

        local rand_base_dir
        rand_base_dir="/opt/$(random_string 6)"

        local rand_suap_dir
        rand_suap_dir="/srv/$(random_string 5)/suap"

        local rand_venv_dir
        rand_venv_dir="/var/venvs/$(random_string 7)"

        # ensure_env_for_option with option "1" (dev) asks in this order:
        # 1. PYTHON_VERSION, 2. BASE_DIR, 3. SUAP_DIR, 4. VENV_DIR, 5. GIT_URL
        printf '%s\n%s\n%s\n%s\n%s\n' \
            "$rand_python_version" \
            "$rand_base_dir" \
            "$rand_suap_dir" \
            "$rand_venv_dir" \
            "$rand_git_url" \
            | interactive_env_wizard "$env_file" > /dev/null 2>&1

        # Verify .env file was created
        [ -f "$env_file" ] || fail "Iteration $i: .env file was not created at $env_file"

        # Unset variables before loading to ensure clean state
        unset PYTHON_VERSION BASE_DIR SUAP_DIR VENV_DIR GIT_URL 2>/dev/null || true

        # Load the generated .env using load_env_file
        load_env_file "$env_file"

        # Verify each variable matches the original input
        if [ "$PYTHON_VERSION" != "$rand_python_version" ]; then
            fail "Iteration $i: PYTHON_VERSION expected '$rand_python_version' but got '$PYTHON_VERSION'"
        fi

        if [ "$GIT_URL" != "$rand_git_url" ]; then
            fail "Iteration $i: GIT_URL expected '$rand_git_url' but got '$GIT_URL'"
        fi

        if [ "$BASE_DIR" != "$rand_base_dir" ]; then
            fail "Iteration $i: BASE_DIR expected '$rand_base_dir' but got '$BASE_DIR'"
        fi

        if [ "$SUAP_DIR" != "$rand_suap_dir" ]; then
            fail "Iteration $i: SUAP_DIR expected '$rand_suap_dir' but got '$SUAP_DIR'"
        fi

        if [ "$VENV_DIR" != "$rand_venv_dir" ]; then
            fail "Iteration $i: VENV_DIR expected '$rand_venv_dir' but got '$VENV_DIR'"
        fi

        # Clean up variables for next iteration
        unset PYTHON_VERSION BASE_DIR SUAP_DIR VENV_DIR GIT_URL
    done
}
