#!/usr/bin/env bats
# Feature: suap-setup, Property 10: Garantia de UID/GID 33 para www-data
#
# Para qualquer estado do sistema em relação ao usuário www-data (inexistente,
# existente com UID/GID correto, existente com UID/GID incorreto, ou conflito
# com outro usuário/grupo), a função ensure_www_data_uid_gid() deve:
# (a) se não há conflito, garantir que www-data termina com UID 33 e GID 33;
# (b) se o UID/GID foi alterado, executar find nos diretórios SUAP_DIR, VENV_DIR
#     e logs para atualizar a propriedade dos arquivos;
# (c) se há conflito (outro usuário com UID 33 ou outro grupo com GID 33),
#     exibir mensagem de erro e encerrar com exit 1.
#
# **Validates: Requirements 35.1, 35.2, 35.3, 35.6, 35.7, 35.8**

setup() {
    load '../test_helper/common-setup'
    TEST_TEMP_DIR="$(mktemp -d)"

    # Source common.sh with TERM set to support tput
    export TERM=xterm
    source "$COMMON_SH"

    # Set required environment variables
    export SUAP_DIR="${TEST_TEMP_DIR}/suap"
    export VENV_DIR="${TEST_TEMP_DIR}/venv"
    export BASE_DIR="${TEST_TEMP_DIR}/base"
    mkdir -p "${SUAP_DIR}" "${VENV_DIR}" "${BASE_DIR}/logs"

    # Track mock calls for verification
    export MOCK_LOG="${TEST_TEMP_DIR}/mock_calls.log"
    : > "$MOCK_LOG"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# --- Mock Infrastructure ---
# Since ensure_www_data_uid_gid() calls system commands (getent, id, groupadd,
# useradd, usermod, groupmod, find) that require root, we override them as
# bash functions in a subshell wrapper that sources common.sh and calls
# the function under test.

# Run ensure_www_data_uid_gid in a subshell with custom mocks.
# Arguments:
#   $1 - scenario name (determines mock behavior)
#   $2 - optional: uid_owner for getent passwd 33 (default: empty)
#   $3 - optional: gid_owner for getent group 33 (default: empty)
#   $4 - optional: www-data exists? "yes"/"no" (default: "no")
#   $5 - optional: current_uid of www-data (default: 33)
#   $6 - optional: current_gid of www-data (default: 33)
run_ensure_www_data() {
    local distro_type="$1"
    local uid_owner="${2:-}"
    local gid_owner="${3:-}"
    local www_data_exists="${4:-no}"
    local current_uid="${5:-33}"
    local current_gid="${6:-33}"

    run bash -c "
        export TERM=xterm
        export DISTRO_TYPE='${distro_type}'
        export SUAP_DIR='${SUAP_DIR}'
        export VENV_DIR='${VENV_DIR}'
        export BASE_DIR='${BASE_DIR}'
        export MOCK_LOG='${MOCK_LOG}'

        # Source the library
        source '${COMMON_SH}'

        # Override system commands with mocks
        getent() {
            local db=\"\$1\"
            local key=\"\$2\"
            if [ \"\$db\" = \"passwd\" ]; then
                if [ \"\$key\" = \"33\" ]; then
                    if [ -n '${uid_owner}' ]; then
                        echo '${uid_owner}:x:33:33::/nonexistent:/usr/sbin/nologin'
                        return 0
                    else
                        return 2
                    fi
                elif [ \"\$key\" = \"www-data\" ]; then
                    if [ '${www_data_exists}' = 'yes' ]; then
                        echo 'www-data:x:${current_uid}:${current_gid}::/nonexistent:/usr/sbin/nologin'
                        return 0
                    else
                        return 2
                    fi
                fi
            elif [ \"\$db\" = \"group\" ]; then
                if [ \"\$key\" = \"33\" ]; then
                    if [ -n '${gid_owner}' ]; then
                        echo '${gid_owner}:x:33:'
                        return 0
                    else
                        return 2
                    fi
                fi
            fi
            return 2
        }

        id() {
            if [ \"\$1\" = \"-u\" ] && [ \"\$2\" = \"www-data\" ]; then
                echo '${current_uid}'
                return 0
            elif [ \"\$1\" = \"-g\" ] && [ \"\$2\" = \"www-data\" ]; then
                echo '${current_gid}'
                return 0
            fi
            return 1
        }

        groupadd() { echo \"MOCK_CALL: groupadd \$*\" >> \"\$MOCK_LOG\"; return 0; }
        useradd() { echo \"MOCK_CALL: useradd \$*\" >> \"\$MOCK_LOG\"; return 0; }
        usermod() { echo \"MOCK_CALL: usermod \$*\" >> \"\$MOCK_LOG\"; return 0; }
        groupmod() { echo \"MOCK_CALL: groupmod \$*\" >> \"\$MOCK_LOG\"; return 0; }
        find() { echo \"MOCK_CALL: find \$*\" >> \"\$MOCK_LOG\"; return 0; }

        export -f getent id groupadd useradd usermod groupmod find

        ensure_www_data_uid_gid
    "
}

# --- Helper Functions ---

# Generate a random UID != 33
random_uid_not_33() {
    local uid
    while true; do
        uid=$(( RANDOM % 65000 + 100 ))
        [ "$uid" -ne 33 ] && break
    done
    echo "$uid"
}

# Generate a random GID != 33
random_gid_not_33() {
    local gid
    while true; do
        gid=$(( RANDOM % 65000 + 100 ))
        [ "$gid" -ne 33 ] && break
    done
    echo "$gid"
}

# Generate a random username (not www-data)
random_username() {
    local -a names=("nginx" "apache" "httpd" "nobody" "daemon" "mysql" "postgres" "redis" "node" "git" "deploy" "app")
    local idx=$(( RANDOM % ${#names[@]} ))
    echo "${names[$idx]}"
}

# Generate a random group name (not www-data)
random_groupname() {
    local -a names=("nginx" "apache" "httpd" "nogroup" "daemon" "mysql" "postgres" "redis" "staff" "docker" "wheel")
    local idx=$(( RANDOM % ${#names[@]} ))
    echo "${names[$idx]}"
}

# --- Property Tests ---

@test "Property 10.1: www-data inexistente → criação com UID/GID 33 (10 iterations)" {
    local iterations=10
    local i

    for ((i = 1; i <= iterations; i++)); do
        : > "$MOCK_LOG"

        # Scenario: www-data does not exist, no UID/GID 33 conflicts
        run_ensure_www_data "deb" "" "" "no" "33" "33"

        # Should succeed
        assert_success

        # Should show creation message
        assert_output --partial "Usuário www-data criado com UID/GID 33"

        # Verify groupadd and useradd were called with correct params
        assert [ -f "$MOCK_LOG" ]
        run grep "groupadd -g 33 www-data" "$MOCK_LOG"
        assert_success
        run grep "useradd -u 33 -g www-data" "$MOCK_LOG"
        assert_success
    done
}

@test "Property 10.2: www-data existente com UID/GID correto → msg_skip (10 iterations)" {
    local iterations=10
    local i

    for ((i = 1; i <= iterations; i++)); do
        : > "$MOCK_LOG"

        # Scenario: www-data exists with UID 33 and GID 33
        # No conflicting users/groups on UID/GID 33 (owner IS www-data)
        run_ensure_www_data "deb" "www-data" "www-data" "yes" "33" "33"

        # Should succeed
        assert_success

        # Should show skip message
        assert_output --partial "www-data já possui UID/GID 33"

        # No modification commands should be called
        run grep -c "MOCK_CALL" "$MOCK_LOG"
        [ "${output}" = "0" ] || [ "${status}" -ne 0 ]
    done
}

@test "Property 10.3: www-data existente com UID/GID incorreto → correção + find (10 iterations)" {
    local iterations=10
    local i

    for ((i = 1; i <= iterations; i++)); do
        : > "$MOCK_LOG"

        local wrong_uid
        local wrong_gid
        wrong_uid=$(random_uid_not_33)
        wrong_gid=$(random_gid_not_33)

        # Scenario: www-data exists but has wrong UID/GID
        # No conflicts (nobody else has UID/GID 33)
        run_ensure_www_data "deb" "" "" "yes" "$wrong_uid" "$wrong_gid"

        # Should succeed
        assert_success

        # Should show correction message
        assert_output --partial "UID/GID do www-data corrigido para 33"

        # Verify groupmod and usermod were called
        run grep "groupmod -g 33 www-data" "$MOCK_LOG"
        assert_success
        run grep "usermod -u 33 www-data" "$MOCK_LOG"
        assert_success

        # Verify find was called to update file ownership
        run grep "find" "$MOCK_LOG"
        assert_success
    done
}

@test "Property 10.4: conflito de UID 33 com outro usuário → exit 1 (10 iterations)" {
    local iterations=10
    local i

    for ((i = 1; i <= iterations; i++)); do
        : > "$MOCK_LOG"

        local conflicting_user
        conflicting_user=$(random_username)

        # Scenario: Another user (not www-data) holds UID 33
        run_ensure_www_data "deb" "$conflicting_user" "" "no" "33" "33"

        # Should fail with exit 1
        assert_failure

        # Should show error about UID conflict
        assert_output --partial "UID 33 já está em uso pelo usuário '${conflicting_user}'"

        # No modification commands should be called
        run grep -E "(groupadd|useradd|usermod|groupmod)" "$MOCK_LOG"
        assert_failure
    done
}

@test "Property 10.5: conflito de GID 33 com outro grupo → exit 1 (10 iterations)" {
    local iterations=10
    local i

    for ((i = 1; i <= iterations; i++)); do
        : > "$MOCK_LOG"

        local conflicting_group
        conflicting_group=$(random_groupname)

        # Scenario: Another group (not www-data) holds GID 33
        # UID 33 is free (or owned by www-data), but GID 33 conflicts
        run_ensure_www_data "deb" "" "$conflicting_group" "no" "33" "33"

        # Should fail with exit 1
        assert_failure

        # Should show error about GID conflict
        assert_output --partial "GID 33 já está em uso pelo grupo '${conflicting_group}'"

        # No modification commands should be called
        run grep -E "(groupadd|useradd|usermod|groupmod)" "$MOCK_LOG"
        assert_failure
    done
}

@test "Property 10.6: macOS → msg_skip sem alterações (10 iterations)" {
    local iterations=10
    local i

    for ((i = 1; i <= iterations; i++)); do
        : > "$MOCK_LOG"

        # Scenario: DISTRO_TYPE is macos - should skip without any system changes
        run_ensure_www_data "macos" "" "" "no" "33" "33"

        # Should succeed
        assert_success

        # Should show skip message about macOS
        assert_output --partial "UID/GID 33 não se aplica ao macOS"

        # No system commands should be called at all
        run grep -c "MOCK_CALL" "$MOCK_LOG"
        [ "${output}" = "0" ] || [ "${status}" -ne 0 ]
    done
}

@test "Property 10.7: www-data com apenas UID incorreto → corrige apenas UID (10 iterations)" {
    local iterations=10
    local i

    for ((i = 1; i <= iterations; i++)); do
        : > "$MOCK_LOG"

        local wrong_uid
        wrong_uid=$(random_uid_not_33)

        # Scenario: www-data exists with wrong UID but correct GID
        run_ensure_www_data "deb" "" "" "yes" "$wrong_uid" "33"

        # Should succeed
        assert_success

        # Should show correction message
        assert_output --partial "UID/GID do www-data corrigido para 33"

        # usermod should be called (UID correction)
        run grep "usermod -u 33 www-data" "$MOCK_LOG"
        assert_success

        # groupmod should NOT be called (GID is already correct)
        run grep "groupmod" "$MOCK_LOG"
        assert_failure
    done
}

@test "Property 10.8: www-data com apenas GID incorreto → corrige apenas GID (10 iterations)" {
    local iterations=10
    local i

    for ((i = 1; i <= iterations; i++)); do
        : > "$MOCK_LOG"

        local wrong_gid
        wrong_gid=$(random_gid_not_33)

        # Scenario: www-data exists with correct UID but wrong GID
        run_ensure_www_data "deb" "" "" "yes" "33" "$wrong_gid"

        # Should succeed
        assert_success

        # Should show correction message
        assert_output --partial "UID/GID do www-data corrigido para 33"

        # groupmod should be called (GID correction)
        run grep "groupmod -g 33 www-data" "$MOCK_LOG"
        assert_success

        # usermod should NOT be called (UID is already correct)
        run grep "usermod" "$MOCK_LOG"
        assert_failure
    done
}
