#!/usr/bin/env bats
# tests/unit/test_locale_timezone.bats
# Testes unitários para ensure_locale_timezone() em lib/common.sh.
#
# A função é interativa e aplica mudanças no sistema; aqui todos os comandos de
# sistema (locale, timedatectl, sudo, locale-gen, update-locale, localectl, dnf,
# systemsetup) são mockados no PATH, e as respostas do prompt são alimentadas via
# stdin. Nenhuma mudança real é feita no sistema.

setup() {
    load '../test_helper/common-setup'
    export TERM=xterm

    TEST_TEMP_DIR="$(mktemp -d)"
    MOCK_BIN="${TEST_TEMP_DIR}/bin"
    mkdir -p "$MOCK_BIN"
    # Log onde os mocks registram suas chamadas
    export MOCK_LOG="${TEST_TEMP_DIR}/calls.log"
    : > "$MOCK_LOG"

    # Variáveis controláveis por teste (valores "atuais" do sistema)
    export FAKE_LANG="en_US.UTF-8"
    export FAKE_TZ="UTC"

    # mock: locale -> imprime LANG=$FAKE_LANG
    cat > "${MOCK_BIN}/locale" <<'EOF'
#!/usr/bin/env bash
echo "LANG=${FAKE_LANG}"
EOF

    # mock: timedatectl -> responde ao "show -p Timezone --value" com $FAKE_TZ
    cat > "${MOCK_BIN}/timedatectl" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"show -p Timezone --value"* ]]; then
  echo "${FAKE_TZ}"
else
  echo "set-timezone $*" >> "${MOCK_LOG}"
fi
EOF

    # mock: sudo -> apenas registra e executa o restante (para capturar o comando)
    cat > "${MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
echo "sudo $*" >> "${MOCK_LOG}"
EOF

    # mocks que apenas registram a chamada
    for cmd in locale-gen update-locale localectl dnf systemsetup; do
        cat > "${MOCK_BIN}/${cmd}" <<EOF
#!/usr/bin/env bash
echo "${cmd} \$*" >> "\${MOCK_LOG}"
EOF
    done

    chmod +x "${MOCK_BIN}"/*
    export PATH="${MOCK_BIN}:${PATH}"

    source "$COMMON_SH"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# ============================================================
# Já no padrão → pula sem perguntar
# ============================================================

@test "locale/tz já no padrão: pula ambos sem perguntar (deb)" {
    export DISTRO_TYPE="deb"
    export FAKE_LANG="pt_BR.UTF-8"
    export FAKE_TZ="America/Fortaleza"

    run ensure_locale_timezone </dev/null

    assert_success
    assert_output --partial "Locale já está no padrão"
    assert_output --partial "Timezone já está no padrão"
    # Não deve ter aplicado nada
    run cat "$MOCK_LOG"
    refute_output --partial "locale-gen"
    refute_output --partial "set-timezone"
}

# ============================================================
# Diferente + usuário aceita (Enter = sim) → aplica
# ============================================================

@test "locale/tz diferentes + Enter (sim): aplica no deb" {
    export DISTRO_TYPE="deb"
    export FAKE_LANG="en_US.UTF-8"
    export FAKE_TZ="UTC"

    # Duas perguntas (locale e timezone); Enter aceita ambas
    run ensure_locale_timezone <<< $'\n\n'

    assert_success
    assert_output --partial "Configurando locale para pt_BR.UTF-8"
    assert_output --partial "Configurando timezone para America/Fortaleza"

    run cat "$MOCK_LOG"
    assert_output --partial "locale-gen pt_BR.UTF-8"
    assert_output --partial "update-locale LANG=pt_BR.UTF-8"
    assert_output --partial "set-timezone America/Fortaleza"
}

# ============================================================
# Diferente + usuário recusa (n) → preserva
# ============================================================

@test "locale/tz diferentes + 'n' (não): preserva, não aplica (deb)" {
    export DISTRO_TYPE="deb"
    export FAKE_LANG="en_US.UTF-8"
    export FAKE_TZ="UTC"

    run ensure_locale_timezone <<< $'n\nn\n'

    assert_success
    assert_output --partial "Locale mantido como está"
    assert_output --partial "Timezone mantido como está"

    run cat "$MOCK_LOG"
    refute_output --partial "locale-gen"
    refute_output --partial "set-timezone"
}

# ============================================================
# macOS: locale não se aplica; timezone via systemsetup
# ============================================================

@test "macOS: locale não se aplica; timezone perguntado" {
    export DISTRO_TYPE="macos"
    export FAKE_TZ="UTC"

    # mock systemsetup para -gettimezone retornar o FAKE_TZ no formato esperado
    cat > "${MOCK_BIN}/systemsetup" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-gettimezone" ]]; then
  echo "Time Zone: ${FAKE_TZ}"
else
  echo "systemsetup $*" >> "${MOCK_LOG}"
fi
EOF
    chmod +x "${MOCK_BIN}/systemsetup"

    run ensure_locale_timezone <<< $'\n'

    assert_success
    assert_output --partial "Locale não se aplica ao macOS"
    assert_output --partial "Configurando timezone para America/Fortaleza"

    run cat "$MOCK_LOG"
    assert_output --partial "systemsetup -settimezone America/Fortaleza"
}

# ============================================================
# Padrão configurável via variáveis SUAP_LOCALE / SUAP_TIMEZONE
# ============================================================

@test "respeita SUAP_LOCALE/SUAP_TIMEZONE customizados" {
    export DISTRO_TYPE="deb"
    export SUAP_LOCALE="en_GB.UTF-8"
    export SUAP_TIMEZONE="Europe/London"
    export FAKE_LANG="en_GB.UTF-8"
    export FAKE_TZ="Europe/London"

    run ensure_locale_timezone </dev/null

    assert_success
    assert_output --partial "Locale já está no padrão (en_GB.UTF-8)"
    assert_output --partial "Timezone já está no padrão (Europe/London)"
}
