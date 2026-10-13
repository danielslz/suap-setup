#!/usr/bin/env bats
# tests/unit/test_dev_revert.bats
# Testa o ciclo de reversão do ambiente de desenvolvimento usando um manifesto
# populado como o deb/suap-dev.sh faz, com diretório de estado e comandos
# mockados. Valida a política conservadora específica do dev.

setup() {
    load '../test_helper/common-setup'
    export TERM=xterm

    TEST_TEMP_DIR="$(mktemp -d)"
    MOCK_BIN="${TEST_TEMP_DIR}/bin"
    mkdir -p "$MOCK_BIN"
    export MOCK_LOG="${TEST_TEMP_DIR}/calls.log"; : > "$MOCK_LOG"
    export MANIFEST_TEST_DIR="${TEST_TEMP_DIR}/state"; mkdir -p "$MANIFEST_TEST_DIR"

    # sudo: registra e executa (para rm/cp em tmp funcionarem)
    cat > "${MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
echo "sudo $*" >> "${MOCK_LOG}"
"$@"
EOF
    # dpkg: pacote considerado instalado (para revert_package exercitar confirmação)
    cat > "${MOCK_BIN}/dpkg" <<'EOF'
#!/usr/bin/env bash
echo "ii  swig  1.0  amd64  desc"
EOF
    for cmd in apt-get systemctl; do
        cat > "${MOCK_BIN}/${cmd}" <<EOF
#!/usr/bin/env bash
echo "${cmd} \$*" >> "\${MOCK_LOG}"
EOF
    done
    chmod +x "${MOCK_BIN}"/*
    export PATH="${MOCK_BIN}:${PATH}"

    export DISTRO_TYPE="deb"
    source "$COMMON_SH"
    _manifest_state_dir() { echo "$MANIFEST_TEST_DIR"; }

    # Popular o manifesto como o deb/suap-dev.sh faria
    KEY="suap-dev"
    SUAP_DIR="${TEST_TEMP_DIR}/suap"
    VENV_DIR="${SUAP_DIR}/.venv"
    BIN="${TEST_TEMP_DIR}/wkhtmltopdf"
    mkdir -p "$SUAP_DIR/suap" "$VENV_DIR"
    echo x > "${SUAP_DIR}/suap/settings.py"
    echo x > "${SUAP_DIR}/.env"
    echo x > "$BIN"

    manifest_record "$KEY" package "swig"
    manifest_record "$KEY" binary "$BIN"
    manifest_record "$KEY" dir "$SUAP_DIR" "user-data"
    manifest_record "$KEY" file "${SUAP_DIR}/suap/settings.py"
    manifest_record "$KEY" file "${SUAP_DIR}/.env"
    manifest_record "$KEY" dir "$VENV_DIR"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
    rm -f /tmp/_revert_sort_*
}

@test "dry-run não remove nada e preserva o manifesto" {
    run revert_apply "$KEY" --dry-run
    assert_success
    [ -d "$SUAP_DIR" ]
    [ -d "$VENV_DIR" ]
    [ -e "$BIN" ]
    run manifest_is_empty "$KEY"
    assert_failure
}

@test "recusando confirmações: preserva SUAP_DIR e pacote; remove venv/binário/arquivos" {
    # Responde 'N' a todas as confirmações destrutivas (SUAP_DIR e pacote swig)
    run revert_apply "$KEY" <<< $'N\nN\nN\nN\n'
    assert_success

    # venv, binário e arquivos (não destrutivos) devem ter sido removidos
    [ ! -d "$VENV_DIR" ]
    [ ! -e "$BIN" ]
    [ ! -f "${SUAP_DIR}/.env" ]

    # SUAP_DIR (user-data) preservado por recusa
    [ -d "$SUAP_DIR" ]
    # pacote preservado por recusa
    run cat "$MOCK_LOG"
    refute_output --partial "apt-get remove"
}

@test "assume-yes: remove tudo e esvazia o manifesto" {
    export REVERT_ASSUME_YES=1
    run revert_apply "$KEY"
    assert_success
    [ ! -d "$SUAP_DIR" ]
    [ ! -d "$VENV_DIR" ]
    [ ! -e "$BIN" ]
    run cat "$MOCK_LOG"
    assert_output --partial "apt-get remove"
    run manifest_is_empty "$KEY"
    assert_success
}

@test "confirmacao via stdin ('s') dentro do revert_apply remove o SUAP_DIR" {
    # Regressão: o laço de revert_apply nao pode sequestrar o stdin; a
    # confirmacao deve conseguir ler a resposta 's' alimentada aqui.
    # 's' para SUAP_DIR (dir user-data) e 's' para o pacote swig; demais
    # confirmacoes de pacote tambem recebem 's'. Fornecemos varios 's'.
    run revert_apply "$KEY" <<< $'s\ns\ns\ns\ns\ns\n'
    assert_success
    # SUAP_DIR deve ter sido removido (confirmacao aceita)
    [ ! -d "$SUAP_DIR" ]
    # pacote swig: confirmacao aceita -> apt-get remove chamado
    run cat "$MOCK_LOG"
    assert_output --partial "apt-get remove"
}
