#!/usr/bin/env bats
# Feature: suap-setup, Property 3: Roteamento do menu produz caminho de script correto
#
# Para qualquer combinação válida de opção do menu (1-7) e tipo de distribuição/OS
# detectado (deb/rpm/arch/macos), o wrapper deve construir o caminho correto do script
# de acordo com a tabela de roteamento; opções não suportadas na plataforma (2, 3, 4
# no macOS) devem ser rejeitadas; e opções fora do intervalo válido devem resultar em
# código de saída 1.
#
# **Validates: Requirements 3.2, 3.3, 30.11, 31.10**

setup() {
    load '../test_helper/common-setup'
    TEST_TEMP_DIR="$(mktemp -d)"

    export TERM=xterm
    source "$COMMON_SH"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# --- Routing Function Under Test ---
# Replicates the case statement from setup.sh in a testable function.
# Takes CHOICE and DISTRO_TYPE, echoes the relative script path or returns 1 for invalid.
# macOS restrictions: options 2, 3, 4 are not supported and return exit 1.

_resolve_target_script() {
    local choice="$1"
    local distro_type="$2"

    # Reject unsupported options on macOS
    if [ "$distro_type" = "macos" ]; then
        case "${choice}" in
            2|3|4) return 1 ;;
        esac
    fi

    case "${choice}" in
        1)
            echo "${distro_type}/suap-dev.sh"
            ;;
        2)
            echo "${distro_type}/suap-prod.sh"
            ;;
        3)
            echo "${distro_type}/install-redis.sh"
            ;;
        4)
            echo "${distro_type}/install-nginx.sh"
            ;;
        5)
            echo "docker/dev/docker-setup.sh"
            ;;
        6)
            echo "docker/prod/docker-setup.sh"
            ;;
        7)
            echo "docker/dockhand-setup.sh"
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

# --- Helper Functions ---

# Pick a random element from an array
random_choice() {
    local -a arr=("$@")
    local idx=$(( RANDOM % ${#arr[@]} ))
    echo "${arr[$idx]}"
}

# Generate a random invalid option (not 1-7)
random_invalid_option() {
    local category=$(( RANDOM % 4 ))
    case $category in
        0)
            # Numbers outside 1-7 (0, 8-99, negative)
            local -a nums=("0" "8" "9" "10" "42" "99" "-1" "-5" "100" "255")
            random_choice "${nums[@]}"
            ;;
        1)
            # Letters and words
            local -a letters=("a" "b" "z" "abc" "dev" "prod" "exit" "quit" "X" "Q")
            random_choice "${letters[@]}"
            ;;
        2)
            # Special characters
            local -a specials=("" " " "!" "@" "#" "*" "1a" "2b" "." ",")
            random_choice "${specials[@]}"
            ;;
        3)
            # Multi-digit or mixed strings
            local -a mixed=("11" "66" "12" "00" "01" " 1" "1 " "1.0" "6.0" "1\n")
            random_choice "${mixed[@]}"
            ;;
    esac
}

# --- Property Tests ---

@test "Property 3.1: Valid options (1-4) with deb/rpm/arch produce correct distro-prefixed path (100 iterations)" {
    local iterations=100
    local i

    local -a valid_options=("1" "2" "3" "4")
    local -a distro_types=("deb" "rpm" "arch")

    # Expected script names for options 1-4
    local -a script_names=("suap-dev.sh" "suap-prod.sh" "install-redis.sh" "install-nginx.sh")

    for ((i = 1; i <= iterations; i++)); do
        local option
        option=$(random_choice "${valid_options[@]}")
        local distro
        distro=$(random_choice "${distro_types[@]}")

        local result
        result=$(_resolve_target_script "$option" "$distro")
        local exit_code=$?

        # Should succeed
        [ "$exit_code" -eq 0 ] || fail "Iteration $i: Expected exit 0 for option=$option distro=$distro, got $exit_code"

        # Build expected path
        local idx=$(( option - 1 ))
        local expected="${distro}/${script_names[$idx]}"

        [ "$result" = "$expected" ] || fail "Iteration $i: option=$option distro=$distro → expected '$expected', got '$result'"
    done
}

@test "Property 3.2: Docker options (5, 6, 7) produce fixed paths regardless of distro (100 iterations)" {
    local iterations=100
    local i

    local -a docker_options=("5" "6" "7")
    local -a distro_types=("deb" "rpm" "arch" "macos")
    local -a expected_paths=("docker/dev/docker-setup.sh" "docker/prod/docker-setup.sh" "docker/dockhand-setup.sh")

    for ((i = 1; i <= iterations; i++)); do
        local option
        option=$(random_choice "${docker_options[@]}")
        local distro
        distro=$(random_choice "${distro_types[@]}")

        local result
        result=$(_resolve_target_script "$option" "$distro")
        local exit_code=$?

        # Should succeed
        [ "$exit_code" -eq 0 ] || fail "Iteration $i: Expected exit 0 for option=$option distro=$distro, got $exit_code"

        # Determine expected path
        local expected
        if [ "$option" = "5" ]; then
            expected="${expected_paths[0]}"
        elif [ "$option" = "6" ]; then
            expected="${expected_paths[1]}"
        else
            expected="${expected_paths[2]}"
        fi

        [ "$result" = "$expected" ] || fail "Iteration $i: option=$option distro=$distro → expected '$expected', got '$result'"
    done
}

@test "Property 3.3: Invalid options return exit code 1 (100 iterations)" {
    local iterations=100
    local i

    local -a distro_types=("deb" "rpm" "arch" "macos")

    for ((i = 1; i <= iterations; i++)); do
        local invalid_opt
        invalid_opt=$(random_invalid_option)
        local distro
        distro=$(random_choice "${distro_types[@]}")

        local result=""
        local exit_code=0
        result=$(_resolve_target_script "$invalid_opt" "$distro") || exit_code=$?

        # Should fail with exit 1
        [ "$exit_code" -eq 1 ] || fail "Iteration $i: Expected exit 1 for invalid option='$invalid_opt' distro=$distro, got exit $exit_code (output='$result')"

        # Should produce no output
        [ -z "$result" ] || fail "Iteration $i: Expected no output for invalid option='$invalid_opt', got '$result'"
    done
}

@test "Property 3.4: All valid options (1-7) produce paths that match existing project scripts (100 iterations)" {
    local iterations=100
    local i

    # For deb/rpm/arch, all options 1-7 are valid
    local -a all_options=("1" "2" "3" "4" "5" "6" "7")
    local -a linux_distros=("deb" "rpm" "arch")
    # For macOS, only options 1, 5, 6, 7 are valid
    local -a macos_options=("1" "5" "6" "7")

    for ((i = 1; i <= iterations; i++)); do
        # Randomly decide if we test Linux distro or macOS
        local use_macos=$(( RANDOM % 4 ))  # ~25% chance macOS

        local option distro
        if [ "$use_macos" -eq 0 ]; then
            distro="macos"
            option=$(random_choice "${macos_options[@]}")
        else
            distro=$(random_choice "${linux_distros[@]}")
            option=$(random_choice "${all_options[@]}")
        fi

        local result
        result=$(_resolve_target_script "$option" "$distro")
        local exit_code=$?

        # Should succeed
        [ "$exit_code" -eq 0 ] || fail "Iteration $i: Expected exit 0 for option=$option distro=$distro, got $exit_code"

        # Verify the script exists in the project
        local full_path="${PROJECT_ROOT}/${result}"
        [ -f "$full_path" ] || fail "Iteration $i: option=$option distro=$distro → script '$full_path' does not exist"
    done
}

@test "Property 3.5: macOS restricts options 2, 3, 4 with exit code 1 (100 iterations)" {
    local iterations=100
    local i

    local -a restricted_options=("2" "3" "4")

    for ((i = 1; i <= iterations; i++)); do
        local option
        option=$(random_choice "${restricted_options[@]}")

        local result=""
        local exit_code=0
        result=$(_resolve_target_script "$option" "macos") || exit_code=$?

        # Should fail with exit 1
        [ "$exit_code" -eq 1 ] || fail "Iteration $i: Expected exit 1 for macOS option=$option, got exit $exit_code (output='$result')"

        # Should produce no output
        [ -z "$result" ] || fail "Iteration $i: Expected no output for macOS restricted option=$option, got '$result'"
    done
}
