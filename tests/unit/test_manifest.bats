#!/usr/bin/env bats
# tests/unit/test_manifest.bats
# Testes unitários para as funções de manifesto de estado em lib/common.sh.
# O diretório de estado é redirecionado para um tmp isolado sobrescrevendo
# _manifest_state_dir(), de modo que nenhum manifesto real do repo seja tocado.

setup() {
    load '../test_helper/common-setup'
    export TERM=xterm

    TEST_TEMP_DIR="$(mktemp -d)"
    export MANIFEST_TEST_DIR="${TEST_TEMP_DIR}/state"
    mkdir -p "$MANIFEST_TEST_DIR"

    source "$COMMON_SH"

    # Redireciona o diretório de estado para o tmp isolado
    _manifest_state_dir() { echo "$MANIFEST_TEST_DIR"; }
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# ============================================================
# manifest_path
# ============================================================

@test "manifest_path retorna caminho dentro do diretório de estado" {
    run manifest_path "suap-dev"
    assert_success
    assert_output "${MANIFEST_TEST_DIR}/suap-dev.manifest"
}

# ============================================================
# manifest_record + manifest_has
# ============================================================

@test "manifest_record grava entrada e manifest_has a encontra" {
    manifest_record "suap-dev" dir "/opt/suap"
    run manifest_has "suap-dev" dir "/opt/suap"
    assert_success
}

@test "manifest_has retorna falha para entrada inexistente" {
    manifest_record "suap-dev" dir "/opt/suap"
    run manifest_has "suap-dev" dir "/opt/outro"
    assert_failure
}

@test "manifest_record é idempotente (não duplica)" {
    manifest_record "suap-dev" package "git"
    manifest_record "suap-dev" package "git"
    manifest_record "suap-dev" package "git"

    local file
    file="$(manifest_path "suap-dev")"
    run grep -c $'^package\tgit' "$file"
    assert_output "1"
}

@test "manifest_record grava metadado opcional" {
    manifest_record "redis" service "redis-server" "enabled"
    local file
    file="$(manifest_path "redis")"
    run cat "$file"
    assert_output --partial $'service\tredis-server\tenabled'
}

@test "entradas de tipos diferentes com mesmo id coexistem" {
    manifest_record "x" dir "/opt/suap"
    manifest_record "x" file "/opt/suap"
    run manifest_has "x" dir "/opt/suap"
    assert_success
    run manifest_has "x" file "/opt/suap"
    assert_success
}

# ============================================================
# manifest_entries
# ============================================================

@test "manifest_entries emite todas as entradas gravadas" {
    manifest_record "suap-dev" dir "/opt/suap"
    manifest_record "suap-dev" binary "/usr/local/bin/wkhtmltopdf"
    manifest_record "suap-dev" package "swig"

    run manifest_entries "suap-dev"
    assert_success
    assert_line --partial "/opt/suap"
    assert_line --partial "/usr/local/bin/wkhtmltopdf"
    assert_line --partial "swig"
}

@test "manifest_entries não emite nada quando manifesto não existe" {
    run manifest_entries "inexistente"
    assert_success
    assert_output ""
}

# ============================================================
# manifest_remove_entry
# ============================================================

@test "manifest_remove_entry remove apenas a entrada alvo" {
    manifest_record "suap-dev" dir "/opt/suap"
    manifest_record "suap-dev" dir "/opt/venv"

    manifest_remove_entry "suap-dev" dir "/opt/suap"

    run manifest_has "suap-dev" dir "/opt/suap"
    assert_failure
    run manifest_has "suap-dev" dir "/opt/venv"
    assert_success
}

@test "manifest_remove_entry é seguro quando a entrada não existe" {
    manifest_record "suap-dev" dir "/opt/venv"
    run manifest_remove_entry "suap-dev" dir "/nao/existe"
    assert_success
    run manifest_has "suap-dev" dir "/opt/venv"
    assert_success
}

# ============================================================
# manifest_is_empty
# ============================================================

@test "manifest_is_empty verdadeiro quando manifesto não existe" {
    run manifest_is_empty "nunca-criado"
    assert_success
}

@test "manifest_is_empty falso após registrar entrada" {
    manifest_record "suap-dev" dir "/opt/suap"
    run manifest_is_empty "suap-dev"
    assert_failure
}

@test "manifest_is_empty verdadeiro após remover todas as entradas" {
    manifest_record "suap-dev" dir "/opt/suap"
    manifest_remove_entry "suap-dev" dir "/opt/suap"
    run manifest_is_empty "suap-dev"
    assert_success
}

# ============================================================
# Isolamento por chave
# ============================================================

@test "manifestos de chaves diferentes são independentes" {
    manifest_record "suap-dev" dir "/opt/suap"
    manifest_record "postgres" pg_db "suap"

    run manifest_has "suap-dev" pg_db "suap"
    assert_failure
    run manifest_has "postgres" pg_db "suap"
    assert_success
}
