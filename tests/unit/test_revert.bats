#!/usr/bin/env bats
# tests/unit/test_revert.bats
# Testes das funções revert_* e revert_apply em lib/common.sh.
# Comandos de sistema são mockados; o diretório de estado é isolado em tmp.
# Nenhuma alteração real de sistema é feita.

setup() {
    load '../test_helper/common-setup'
    export TERM=xterm

    TEST_TEMP_DIR="$(mktemp -d)"
    MOCK_BIN="${TEST_TEMP_DIR}/bin"
    mkdir -p "$MOCK_BIN"
    export MOCK_LOG="${TEST_TEMP_DIR}/calls.log"
    : > "$MOCK_LOG"

    export MANIFEST_TEST_DIR="${TEST_TEMP_DIR}/state"
    mkdir -p "$MANIFEST_TEST_DIR"

    # sudo: registra e executa o restante (para capturar o comando real)
    cat > "${MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
echo "sudo $*" >> "${MOCK_LOG}"
# executa o comando real (sem o sudo) para que rm/cp em tmp funcionem nos testes
"$@"
EOF
    # systemctl, userdel, psql, apt-get, dnf, pacman: apenas registram
    for cmd in systemctl userdel psql apt-get dnf pacman; do
        cat > "${MOCK_BIN}/${cmd}" <<EOF
#!/usr/bin/env bash
echo "${cmd} \$*" >> "\${MOCK_LOG}"
exit 0
EOF
    done
    chmod +x "${MOCK_BIN}"/*
    export PATH="${MOCK_BIN}:${PATH}"

    export DISTRO_TYPE="deb"
    source "$COMMON_SH"

    # Isola o diretório de estado do manifesto
    _manifest_state_dir() { echo "$MANIFEST_TEST_DIR"; }
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
    rm -f /tmp/_revert_sort_*
}

# ============================================================
# revert_file / revert_binary / revert_dir
# ============================================================

@test "revert_file remove arquivo existente" {
    local f="${TEST_TEMP_DIR}/alvo.txt"
    echo x > "$f"
    run revert_file "$f"
    assert_success
    [ ! -e "$f" ]
}

@test "revert_file é idempotente (arquivo ausente)" {
    run revert_file "${TEST_TEMP_DIR}/nao-existe.txt"
    assert_success
    assert_output --partial "já ausente"
}

@test "revert_binary remove binário" {
    local b="${TEST_TEMP_DIR}/wkhtmltopdf"
    echo x > "$b"
    run revert_binary "$b"
    assert_success
    [ ! -e "$b" ]
}

@test "revert_dir remove diretório não destrutivo" {
    local d="${TEST_TEMP_DIR}/venv"
    mkdir -p "$d"
    run revert_dir "$d"
    assert_success
    [ ! -d "$d" ]
}

@test "revert_dir --destructive preserva quando usuário recusa" {
    local d="${TEST_TEMP_DIR}/suap"
    mkdir -p "$d"
    # confirm_destructive lê stdin: 'N'
    run revert_dir "$d" --destructive <<< $'N\n'
    assert_success
    assert_output --partial "preservado"
    [ -d "$d" ]
}

@test "revert_dir --destructive remove quando REVERT_ASSUME_YES=1" {
    local d="${TEST_TEMP_DIR}/suap"
    mkdir -p "$d"
    export REVERT_ASSUME_YES=1
    run revert_dir "$d" --destructive
    assert_success
    [ ! -d "$d" ]
}

# ============================================================
# revert_package (preserva pré-existente / exige confirmação)
# ============================================================

@test "revert_package pula pacote não instalado (preserva pré-existente)" {
    # is_pkg_installed usa dpkg; mock para dizer que NÃO está instalado
    cat > "${MOCK_BIN}/dpkg" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "${MOCK_BIN}/dpkg"
    # dpkg -l | grep "^ii pkg" não encontra -> não instalado
    run revert_package "algum-pkg"
    assert_success
    assert_output --partial "já ausente"
    run cat "$MOCK_LOG"
    refute_output --partial "apt-get remove"
}

@test "revert_package exige confirmação (recusa não desinstala)" {
    # dpkg diz que ESTÁ instalado
    cat > "${MOCK_BIN}/dpkg" <<'EOF'
#!/usr/bin/env bash
echo "ii  meu-pkg  1.0  amd64  desc"
EOF
    chmod +x "${MOCK_BIN}/dpkg"
    run revert_package "meu-pkg" <<< $'N\n'
    assert_success
    assert_output --partial "preservado"
    run cat "$MOCK_LOG"
    refute_output --partial "apt-get remove"
}

# ============================================================
# revert_user (www-data protegido)
# ============================================================

@test "revert_user protege www-data por padrão" {
    # getent diz que www-data existe
    cat > "${MOCK_BIN}/getent" <<'EOF'
#!/usr/bin/env bash
echo "www-data:x:33:33:::"
EOF
    chmod +x "${MOCK_BIN}/getent"
    run revert_user "www-data"
    assert_success
    assert_output --partial "preservado por padrão"
    run cat "$MOCK_LOG"
    refute_output --partial "userdel"
}

@test "revert_user remove www-data com REVERT_ALLOW_WWW_DATA=1 e confirmação" {
    cat > "${MOCK_BIN}/getent" <<'EOF'
#!/usr/bin/env bash
echo "www-data:x:33:33:::"
EOF
    chmod +x "${MOCK_BIN}/getent"
    export REVERT_ALLOW_WWW_DATA=1
    export REVERT_ASSUME_YES=1
    run revert_user "www-data"
    assert_success
    run cat "$MOCK_LOG"
    assert_output --partial "userdel www-data"
}

# ============================================================
# revert_service (preserva serviço, só para/desabilita)
# ============================================================

@test "revert_service para e desabilita conforme meta" {
    export REVERT_ASSUME_YES=1
    run revert_service "redis-server" "started enabled"
    assert_success
    run cat "$MOCK_LOG"
    assert_output --partial "systemctl stop redis-server"
    assert_output --partial "systemctl disable redis-server"
}

# ============================================================
# dry-run
# ============================================================

@test "revert_apply --dry-run não altera nada nem o manifesto" {
    local f="${TEST_TEMP_DIR}/arq.conf"
    echo x > "$f"
    manifest_record "x" file "$f"

    run revert_apply "x" --dry-run
    assert_success
    assert_output --partial "dry-run"
    # arquivo preservado
    [ -e "$f" ]
    # manifesto intacto
    run manifest_has "x" file "$f"
    assert_success
}

# ============================================================
# revert_apply: ordem, remoção do manifesto e manifesto vazio
# ============================================================

@test "revert_apply reverte artefatos e esvazia o manifesto" {
    export REVERT_ASSUME_YES=1
    local d="${TEST_TEMP_DIR}/dir1"
    local f="${TEST_TEMP_DIR}/f1"
    mkdir -p "$d"; echo x > "$f"
    manifest_record "k" dir "$d"
    manifest_record "k" file "$f"

    run revert_apply "k"
    assert_success
    [ ! -d "$d" ]
    [ ! -e "$f" ]
    run manifest_is_empty "k"
    assert_success
}

@test "revert_apply em manifesto vazio sai sem erro" {
    run revert_apply "inexistente"
    assert_success
    assert_output --partial "Nada registrado para reverter"
}

@test "revert_apply é idempotente (segunda execução não falha)" {
    export REVERT_ASSUME_YES=1
    local f="${TEST_TEMP_DIR}/f2"
    echo x > "$f"
    manifest_record "k2" file "$f"
    revert_apply "k2"
    run revert_apply "k2"
    assert_success
}
