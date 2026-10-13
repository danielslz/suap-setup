#!/usr/bin/env bats
# Feature: suap-setup, roteamento do submenu de reversão
#
# Replica a lógica do submenu de reversão do setup.sh numa função testável e
# valida: a lista de reversões por plataforma, o mapeamento índice -> script,
# a rejeição de índices inválidos e o "voltar" (0).
#
# **Validates: Requirements 4.1, 4.2, 4.3, 4.5**

setup() {
    load '../test_helper/common-setup'
    export TERM=xterm
    source "$COMMON_SH"
}

# --- Função sob teste: replica a montagem de items do submenu ---
# Ecoa, uma por linha, as entradas "rótulo|script" conforme a plataforma.
_revert_items() {
    local distro_type="$1"
    if [ "$distro_type" = "macos" ]; then
        echo "Reverter ambiente de desenvolvimento|${distro_type}/suap-dev-revert.sh"
        echo "Reverter ambiente dev via Docker|docker/dev/docker-setup-revert.sh"
        echo "Reverter ambiente prod via Docker|docker/prod/docker-setup-revert.sh"
        echo "Reverter Dockhand|docker/dockhand-revert.sh"
        echo "Reverter MinIO|docker/minio-revert.sh"
    else
        echo "Reverter ambiente de desenvolvimento|${distro_type}/suap-dev-revert.sh"
        echo "Reverter ambiente de produção|${distro_type}/suap-prod-revert.sh"
        echo "Reverter Redis|${distro_type}/install-redis-revert.sh"
        echo "Reverter Nginx|${distro_type}/install-nginx-revert.sh"
        echo "Reverter ambiente dev via Docker|docker/dev/docker-setup-revert.sh"
        echo "Reverter ambiente prod via Docker|docker/prod/docker-setup-revert.sh"
        echo "Reverter Dockhand|docker/dockhand-revert.sh"
        echo "Reverter PostgreSQL|${distro_type}/install-postgres-revert.sh"
        echo "Reverter MinIO|docker/minio-revert.sh"
    fi
}

# Resolve o script a partir do índice (1-based); retorna 1 se inválido.
_revert_resolve() {
    local idx="$1" distro_type="$2"
    local -a items=()
    mapfile -t items < <(_revert_items "$distro_type")
    if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -lt 1 ] || [ "$idx" -gt "${#items[@]}" ]; then
        return 1
    fi
    local selected="${items[$((idx - 1))]}"
    echo "${selected#*|}"
}

# --- Testes de contagem por plataforma ---

@test "Linux (deb) oferece 9 reversões" {
    run _revert_items "deb"
    assert_success
    [ "${#lines[@]}" -eq 9 ]
}

@test "macOS oferece 5 reversões (sem prod/redis/nginx/postgres)" {
    run _revert_items "macos"
    assert_success
    [ "${#lines[@]}" -eq 5 ]
    refute_output --partial "suap-prod-revert"
    refute_output --partial "install-redis-revert"
    refute_output --partial "install-postgres-revert"
}

# --- Mapeamento índice -> script ---

@test "deb: opção 1 -> suap-dev-revert.sh" {
    run _revert_resolve 1 deb
    assert_success
    assert_output "deb/suap-dev-revert.sh"
}

@test "rpm: opção 1 -> suap-dev-revert.sh" {
    run _revert_resolve 1 rpm
    assert_success
    assert_output "rpm/suap-dev-revert.sh"
}

@test "deb: opção 2 -> suap-prod-revert.sh" {
    run _revert_resolve 2 deb
    assert_success
    assert_output "deb/suap-prod-revert.sh"
}

@test "deb: opção 8 -> install-postgres-revert.sh" {
    run _revert_resolve 8 deb
    assert_success
    assert_output "deb/install-postgres-revert.sh"
}

@test "macOS: opção 1 -> suap-dev-revert.sh" {
    run _revert_resolve 1 macos
    assert_success
    assert_output "macos/suap-dev-revert.sh"
}

@test "macOS: opção 2 -> docker dev (não é prod)" {
    run _revert_resolve 2 macos
    assert_success
    assert_output "docker/dev/docker-setup-revert.sh"
}

# --- Índices inválidos ---

@test "índice 0 é inválido (seria 'voltar' no menu)" {
    run _revert_resolve 0 deb
    assert_failure
}

@test "índice acima do máximo é inválido (deb tem 9)" {
    run _revert_resolve 10 deb
    assert_failure
}

@test "índice não numérico é inválido" {
    run _revert_resolve "abc" deb
    assert_failure
}

@test "macOS: índice 6 é inválido (só tem 5)" {
    run _revert_resolve 6 macos
    assert_failure
}
