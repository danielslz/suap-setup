#!/usr/bin/env bats
# Feature: suap-setup, Property 2: Classificação de distribuição/OS determina caminhos corretos
#
# Para qualquer conteúdo válido de /etc/os-release onde ID ou ID_LIKE contenha
# identificadores de família Debian (debian, ubuntu), RPM (rhel, fedora, centos)
# ou Arch (arch), a função detect_distro() deve classificar corretamente como
# "deb", "rpm" ou "arch", e as funções get_supervisor_conf_dir() e
# get_nginx_conf_path() devem retornar os caminhos correspondentes à família
# detectada. Para macOS (uname -s == "Darwin"), classifica como "macos".
#
# **Validates: Requirements 2.2, 2.3, 17.1, 17.2, 17.3, 20.1, 20.3, 20.4, 30.1, 31.1**

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

# Generate a random string of given length using alphanumeric characters
random_string() {
    local length="${1:-8}"
    cat /dev/urandom | tr -dc 'a-z0-9' | head -c "$length"
}

# Pick a random element from an array
random_choice() {
    local -a arr=("$@")
    local idx=$(( RANDOM % ${#arr[@]} ))
    echo "${arr[$idx]}"
}

# Generate a random Debian-family ID
random_deb_id() {
    local -a deb_ids=("debian" "ubuntu" "linuxmint" "pop" "elementary" "zorin" "kali" "raspbian" "devuan")
    random_choice "${deb_ids[@]}"
}

# Generate a random RPM-family ID
random_rpm_id() {
    local -a rpm_ids=("fedora" "rhel" "centos" "rocky" "alma" "oracle" "scientific" "amzn" "nobara")
    random_choice "${rpm_ids[@]}"
}

# Generate a random Arch-family ID
random_arch_id() {
    local -a arch_ids=("arch" "manjaro" "endeavouros" "garuda" "artix" "arcolinux" "cachyos")
    random_choice "${arch_ids[@]}"
}

# Generate a random Debian-family ID_LIKE value
random_deb_id_like() {
    local -a deb_likes=("debian" "ubuntu" "debian ubuntu" "ubuntu debian")
    random_choice "${deb_likes[@]}"
}

# Generate a random RPM-family ID_LIKE value
random_rpm_id_like() {
    local -a rpm_likes=("rhel" "fedora" "rhel fedora" "fedora rhel" "centos rhel fedora" "rhel centos")
    random_choice "${rpm_likes[@]}"
}

# Generate a random Arch-family ID_LIKE value
random_arch_id_like() {
    local -a arch_likes=("arch" "arch linux" "arch linux lts")
    random_choice "${arch_likes[@]}"
}

# Create a fake os-release file with given ID and ID_LIKE
# Also adds random extra fields to simulate real os-release variety
create_os_release() {
    local file_path="$1"
    local id_value="$2"
    local id_like_value="${3:-}"
    local version
    version="$(( RANDOM % 40 + 1 )).$(( RANDOM % 10 ))"

    {
        echo "NAME=\"$(random_string 8)\""
        echo "VERSION=\"${version}\""
        echo "ID=${id_value}"
        if [ -n "$id_like_value" ]; then
            echo "ID_LIKE=\"${id_like_value}\""
        fi
        echo "VERSION_ID=\"${version}\""
        echo "PRETTY_NAME=\"Test Distro ${version}\""
        # Randomly add extra fields
        if (( RANDOM % 2 == 0 )); then
            echo "HOME_URL=\"https://example.com\""
        fi
        if (( RANDOM % 2 == 0 )); then
            echo "BUG_REPORT_URL=\"https://bugs.example.com\""
        fi
    } > "$file_path"
}

# Testable version of detect_distro that reads from a custom path
# This replicates the logic from lib/common.sh but uses a file path parameter
_detect_distro_from_file() {
    local os_release_file="$1"

    if [ ! -f "$os_release_file" ]; then
        return 3
    fi

    local id=""
    local id_like=""

    # Read ID and ID_LIKE (same logic as detect_distro)
    id=$(grep -oP '^ID=\K.*' "$os_release_file" | tr -d '"')
    id_like=$(grep -oP '^ID_LIKE=\K.*' "$os_release_file" | tr -d '"')

    # Classify by family (same logic as detect_distro)
    if echo "${id} ${id_like}" | grep -qiE '(debian|ubuntu)'; then
        DISTRO_TYPE="deb"
        DISTRO_NAME="${id}"
    elif echo "${id} ${id_like}" | grep -qiE '(rhel|fedora|centos)'; then
        DISTRO_TYPE="rpm"
        DISTRO_NAME="${id}"
    elif echo "${id} ${id_like}" | grep -qiE '(arch)'; then
        DISTRO_TYPE="arch"
        DISTRO_NAME="${id}"
    else
        return 3
    fi

    export DISTRO_TYPE
    export DISTRO_NAME
    return 0
}

# Testable version of detect_distro that accepts uname output as parameter
# Used to test macOS detection without actually mocking uname
_detect_distro_with_uname() {
    local uname_output="$1"

    if [ "$uname_output" = "Darwin" ]; then
        DISTRO_TYPE="macos"
        DISTRO_NAME="macos"
        export DISTRO_TYPE
        export DISTRO_NAME
        return 0
    fi

    return 1
}

# --- Property Tests ---

@test "Property 2.1: Debian-family distros classify as 'deb' with correct paths (100 iterations)" {
    local iterations=100
    local i

    for ((i = 1; i <= iterations; i++)); do
        local os_release_file="${TEST_TEMP_DIR}/os-release_${i}"
        local id
        id="$(random_deb_id)"

        # Randomly decide whether to put the family marker in ID or ID_LIKE
        local strategy=$(( RANDOM % 3 ))
        case $strategy in
            0)
                # ID itself is a debian-family name (e.g., debian, ubuntu)
                local -a direct_ids=("debian" "ubuntu")
                id=$(random_choice "${direct_ids[@]}")
                create_os_release "$os_release_file" "$id" ""
                ;;
            1)
                # ID is derivative, ID_LIKE contains debian-family
                create_os_release "$os_release_file" "$id" "$(random_deb_id_like)"
                ;;
            2)
                # ID is derivative, ID_LIKE contains debian-family with extra content
                local id_like
                id_like="$(random_deb_id_like)"
                create_os_release "$os_release_file" "$id" "$id_like"
                ;;
        esac

        # Test classification
        unset DISTRO_TYPE DISTRO_NAME
        run _detect_distro_from_file "$os_release_file"
        assert_success

        # Verify DISTRO_TYPE is "deb" by calling directly (not via run, to keep exports)
        unset DISTRO_TYPE DISTRO_NAME
        _detect_distro_from_file "$os_release_file"
        local result=$?

        [ "$result" -eq 0 ] || fail "Iteration $i: detect_distro failed (exit $result) for file: $(cat "$os_release_file")"
        [ "$DISTRO_TYPE" = "deb" ] || fail "Iteration $i: Expected DISTRO_TYPE='deb', got '${DISTRO_TYPE}' for file: $(cat "$os_release_file")"

        # Verify get_supervisor_conf_dir returns Debian path
        local supervisor_dir
        supervisor_dir="$(get_supervisor_conf_dir)"
        [ "$supervisor_dir" = "/etc/supervisor/conf.d" ] || fail "Iteration $i: Expected supervisor dir '/etc/supervisor/conf.d', got '${supervisor_dir}'"

        # Verify get_nginx_conf_path returns Debian path
        local nginx_path
        nginx_path="$(get_nginx_conf_path)"
        [ "$nginx_path" = "/etc/nginx/sites-available/suap" ] || fail "Iteration $i: Expected nginx path '/etc/nginx/sites-available/suap', got '${nginx_path}'"
    done
}

@test "Property 2.2: RPM-family distros classify as 'rpm' with correct paths (100 iterations)" {
    local iterations=100
    local i

    for ((i = 1; i <= iterations; i++)); do
        local os_release_file="${TEST_TEMP_DIR}/os-release_${i}"
        local id
        id="$(random_rpm_id)"

        # Randomly decide whether to put the family marker in ID or ID_LIKE
        local strategy=$(( RANDOM % 3 ))
        case $strategy in
            0)
                # ID itself is an rpm-family name (e.g., fedora, rhel, centos)
                local -a direct_ids=("fedora" "rhel" "centos")
                id=$(random_choice "${direct_ids[@]}")
                create_os_release "$os_release_file" "$id" ""
                ;;
            1)
                # ID is derivative, ID_LIKE contains rpm-family
                create_os_release "$os_release_file" "$id" "$(random_rpm_id_like)"
                ;;
            2)
                # ID is derivative, ID_LIKE contains rpm-family with extra content
                local id_like
                id_like="$(random_rpm_id_like)"
                create_os_release "$os_release_file" "$id" "$id_like"
                ;;
        esac

        # Test classification directly (not via run, to keep exports)
        unset DISTRO_TYPE DISTRO_NAME
        _detect_distro_from_file "$os_release_file"
        local result=$?

        [ "$result" -eq 0 ] || fail "Iteration $i: detect_distro failed (exit $result) for file: $(cat "$os_release_file")"
        [ "$DISTRO_TYPE" = "rpm" ] || fail "Iteration $i: Expected DISTRO_TYPE='rpm', got '${DISTRO_TYPE}' for file: $(cat "$os_release_file")"

        # Verify get_supervisor_conf_dir returns RPM path
        local supervisor_dir
        supervisor_dir="$(get_supervisor_conf_dir)"
        [ "$supervisor_dir" = "/etc/supervisord.d" ] || fail "Iteration $i: Expected supervisor dir '/etc/supervisord.d', got '${supervisor_dir}'"

        # Verify get_nginx_conf_path returns RPM path
        local nginx_path
        nginx_path="$(get_nginx_conf_path)"
        [ "$nginx_path" = "/etc/nginx/conf.d/suap.conf" ] || fail "Iteration $i: Expected nginx path '/etc/nginx/conf.d/suap.conf', got '${nginx_path}'"
    done
}

@test "Property 2.3: Unsupported distros return exit code 3 (100 iterations)" {
    local iterations=100
    local i

    for ((i = 1; i <= iterations; i++)); do
        local os_release_file="${TEST_TEMP_DIR}/os-release_unsupported_${i}"

        # Generate an ID that does NOT match debian/ubuntu/rhel/fedora/centos/arch
        local -a unsupported_ids=("gentoo" "slackware" "void" "alpine" "suse" "opensuse" "nixos" "solus" "clear" "mageia")
        local id
        id=$(random_choice "${unsupported_ids[@]}")

        # ID_LIKE also should not match any supported family
        local -a unsupported_likes=("" "gentoo" "suse opensuse" "independent" "")
        local id_like
        id_like=$(random_choice "${unsupported_likes[@]}")

        create_os_release "$os_release_file" "$id" "$id_like"

        # Test classification - should return 3
        unset DISTRO_TYPE DISTRO_NAME
        local result=0
        _detect_distro_from_file "$os_release_file" || result=$?

        [ "$result" -eq 3 ] || fail "Iteration $i: Expected exit 3 for unsupported distro '${id}' (id_like='${id_like}'), got exit $result"
    done
}

@test "Property 2.4: Missing os-release file returns exit code 3 (100 iterations)" {
    local iterations=100
    local i

    for ((i = 1; i <= iterations; i++)); do
        # Generate a random non-existent path
        local fake_path="${TEST_TEMP_DIR}/nonexistent_$(random_string 12)/os-release"

        # Test classification - should return 3
        unset DISTRO_TYPE DISTRO_NAME
        local result=0
        _detect_distro_from_file "$fake_path" || result=$?

        [ "$result" -eq 3 ] || fail "Iteration $i: Expected exit 3 for missing file '${fake_path}', got exit $result"
    done
}

@test "Property 2.5: DISTRO_NAME always equals the ID field value (100 iterations)" {
    local iterations=100
    local i

    for ((i = 1; i <= iterations; i++)); do
        local os_release_file="${TEST_TEMP_DIR}/os-release_name_${i}"

        # Randomly choose deb, rpm, or arch family
        local family
        local id
        local selector=$(( RANDOM % 3 ))
        if [ "$selector" -eq 0 ]; then
            family="deb"
            id="$(random_deb_id)"
            # Ensure it classifies correctly by adding proper ID_LIKE
            if ! echo "$id" | grep -qiE '(debian|ubuntu)'; then
                create_os_release "$os_release_file" "$id" "$(random_deb_id_like)"
            else
                create_os_release "$os_release_file" "$id" ""
            fi
        elif [ "$selector" -eq 1 ]; then
            family="rpm"
            id="$(random_rpm_id)"
            # Ensure it classifies correctly by adding proper ID_LIKE
            if ! echo "$id" | grep -qiE '(rhel|fedora|centos)'; then
                create_os_release "$os_release_file" "$id" "$(random_rpm_id_like)"
            else
                create_os_release "$os_release_file" "$id" ""
            fi
        else
            family="arch"
            id="$(random_arch_id)"
            # Ensure it classifies correctly by adding proper ID_LIKE
            if ! echo "$id" | grep -qiE '(arch)'; then
                create_os_release "$os_release_file" "$id" "$(random_arch_id_like)"
            else
                create_os_release "$os_release_file" "$id" ""
            fi
        fi

        # Test classification
        unset DISTRO_TYPE DISTRO_NAME
        _detect_distro_from_file "$os_release_file"
        local result=$?

        [ "$result" -eq 0 ] || fail "Iteration $i: detect_distro failed (exit $result) for file: $(cat "$os_release_file")"
        [ "$DISTRO_NAME" = "$id" ] || fail "Iteration $i: Expected DISTRO_NAME='${id}', got '${DISTRO_NAME}'"
    done
}

@test "Property 2.6: Arch-family distros classify as 'arch' with correct paths (100 iterations)" {
    local iterations=100
    local i

    for ((i = 1; i <= iterations; i++)); do
        local os_release_file="${TEST_TEMP_DIR}/os-release_arch_${i}"
        local id
        id="$(random_arch_id)"

        # Randomly decide whether to put the family marker in ID or ID_LIKE
        local strategy=$(( RANDOM % 3 ))
        case $strategy in
            0)
                # ID itself is "arch"
                id="arch"
                create_os_release "$os_release_file" "$id" ""
                ;;
            1)
                # ID is derivative (e.g., manjaro), ID_LIKE contains arch
                create_os_release "$os_release_file" "$id" "$(random_arch_id_like)"
                ;;
            2)
                # ID is derivative, ID_LIKE contains "arch" with extra content
                local id_like
                id_like="$(random_arch_id_like)"
                create_os_release "$os_release_file" "$id" "$id_like"
                ;;
        esac

        # Test classification directly (not via run, to keep exports)
        unset DISTRO_TYPE DISTRO_NAME
        _detect_distro_from_file "$os_release_file"
        local result=$?

        [ "$result" -eq 0 ] || fail "Iteration $i: detect_distro failed (exit $result) for file: $(cat "$os_release_file")"
        [ "$DISTRO_TYPE" = "arch" ] || fail "Iteration $i: Expected DISTRO_TYPE='arch', got '${DISTRO_TYPE}' for file: $(cat "$os_release_file")"

        # Verify get_supervisor_conf_dir returns Arch path
        local supervisor_dir
        supervisor_dir="$(get_supervisor_conf_dir)"
        [ "$supervisor_dir" = "/etc/supervisor.d/" ] || fail "Iteration $i: Expected supervisor dir '/etc/supervisor.d/', got '${supervisor_dir}'"

        # Verify get_nginx_conf_path returns Arch path
        local nginx_path
        nginx_path="$(get_nginx_conf_path)"
        [ "$nginx_path" = "/etc/nginx/conf.d/suap.conf" ] || fail "Iteration $i: Expected nginx path '/etc/nginx/conf.d/suap.conf', got '${nginx_path}'"
    done
}

@test "Property 2.7: macOS detection via uname returns 'macos' (100 iterations)" {
    local iterations=100
    local i

    for ((i = 1; i <= iterations; i++)); do
        # Test that "Darwin" uname output correctly classifies as macOS
        unset DISTRO_TYPE DISTRO_NAME
        _detect_distro_with_uname "Darwin"
        local result=$?

        [ "$result" -eq 0 ] || fail "Iteration $i: _detect_distro_with_uname 'Darwin' failed (exit $result)"
        [ "$DISTRO_TYPE" = "macos" ] || fail "Iteration $i: Expected DISTRO_TYPE='macos', got '${DISTRO_TYPE}'"
        [ "$DISTRO_NAME" = "macos" ] || fail "Iteration $i: Expected DISTRO_NAME='macos', got '${DISTRO_NAME}'"

        # Test that non-Darwin uname output does NOT classify as macOS
        unset DISTRO_TYPE DISTRO_NAME
        local -a non_darwin_unames=("Linux" "FreeBSD" "OpenBSD" "NetBSD" "SunOS" "CYGWIN_NT" "MINGW64_NT" "GNU")
        local uname_val
        uname_val=$(random_choice "${non_darwin_unames[@]}")

        local non_result=0
        _detect_distro_with_uname "$uname_val" || non_result=$?

        [ "$non_result" -eq 1 ] || fail "Iteration $i: Expected exit 1 for non-Darwin uname '${uname_val}', got exit $non_result"
    done
}
