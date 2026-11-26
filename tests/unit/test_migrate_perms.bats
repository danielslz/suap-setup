#!/usr/bin/env bats
# tests/unit/test_migrate_perms.bats
# Testes dos comandos migrate, sync-permissions e update --migrate/--sync-permissions
# de docker/prod/suap-deploy.sh, com docker e make falsos que registram as chamadas.
setup() {
    load '../test_helper/common-setup'
    export TERM=xterm
    TEST_TEMP_DIR="$(mktemp -d)"
    export SUAP_DEPLOY_DIR="${TEST_TEMP_DIR}/suap_deploy"
    mkdir -p "${SUAP_DEPLOY_DIR}/deploy" "${TEST_TEMP_DIR}/bin"
    touch "${SUAP_DEPLOY_DIR}/Makefile"
    printf 'SUAP_IMAGE=suap:latest\nCOMPOSE_PROFILES=default\n' > "${SUAP_DEPLOY_DIR}/.env"
    export CALLS="${TEST_TEMP_DIR}/calls.log"
    export FAKE_PLAN="${FAKE_PLAN:-pending}"
    cat > "${TEST_TEMP_DIR}/bin/docker" <<'EOF'
#!/usr/bin/env bash
echo "docker $*" >> "${CALLS}"
case "$*" in
  "compose version"*) exit 0 ;;
  *"migrate --plan"*)
    if [ "${FAKE_PLAN}" = "none" ]; then echo "Planned operations:"; echo "  No planned migration operations."
    else echo "Planned operations:"; echo "app.0002_nova"; echo "    Add field x to y"; fi
    exit 0 ;;
  *"migrate --noinput"*) [ "${FAKE_MIGRATE_FAIL:-0}" = "1" ] && exit 1; exit 0 ;;
  *"compose ps"*) exit 0 ;;
  "image inspect"*) exit 0 ;;
  *) exit 0 ;;
esac
EOF
    cat > "${TEST_TEMP_DIR}/bin/make" <<'EOF'
#!/usr/bin/env bash
echo "make $*" >> "${CALLS}"
exit 0
EOF
    chmod +x "${TEST_TEMP_DIR}/bin/docker" "${TEST_TEMP_DIR}/bin/make"
    export PATH="${TEST_TEMP_DIR}/bin:${PATH}"
    # Cópia do script fora do repositório: o .env local do suap-setup (se existir)
    # sobrescreveria o SUAP_DEPLOY_DIR do teste.
    mkdir -p "${TEST_TEMP_DIR}/repo/docker/prod"
    cp -r "${PROJECT_ROOT}/lib" "${TEST_TEMP_DIR}/repo/"
    cp "${PROJECT_ROOT}/docker/prod/suap-deploy.sh" "${TEST_TEMP_DIR}/repo/docker/prod/"
    SCRIPT="${TEST_TEMP_DIR}/repo/docker/prod/suap-deploy.sh"
}
teardown() {
    rm -rf "$TEST_TEMP_DIR"
}
@test "migrate --plan mostra o plano e não aplica" {
    run bash "$SCRIPT" migrate --plan
    assert_success
    assert_output --partial "app.0002_nova"
    assert_output --partial "nada foi aplicado"
    run grep -c "migrate --noinput" "$CALLS"
    assert_output "0"
}
@test "migrate usa container descartável do web (run --rm -T --no-deps)" {
    run bash "$SCRIPT" migrate --yes
    assert_success
    run grep "migrate --noinput" "$CALLS"
    assert_output --partial "compose run --rm -T --no-deps web python manage.py migrate --noinput"
}
@test "migrate sem pendências não aplica nada" {
    FAKE_PLAN=none run bash "$SCRIPT" migrate --yes
    assert_success
    assert_output --partial "Nenhuma migração pendente"
    run grep -c "migrate --noinput" "$CALLS"
    assert_output "0"
}
@test "migrate sem terminal e sem --yes não aplica" {
    run bash "$SCRIPT" migrate < /dev/null
    assert_output --partial "--yes"
    run grep -c "migrate --noinput" "$CALLS"
    assert_output "0"
}
@test "sync-permissions --yes chama manage.py sync_permissions (não o _ifb)" {
    run bash "$SCRIPT" sync-permissions --yes
    assert_success
    run grep "manage.py sync_permissions" "$CALLS"
    assert_output --partial "web python manage.py sync_permissions"
    refute_output --partial "sync_permissions_ifb"
}
@test "sync-permissions sem terminal e sem --yes não executa" {
    run bash "$SCRIPT" sync-permissions < /dev/null
    run grep -c "manage.py sync_permissions" "$CALLS"
    assert_output "0"
}
@test "update --no-build --migrate --sync-permissions roda os dois antes do restart/up" {
    run bash "$SCRIPT" update --no-build --migrate --sync-permissions
    assert_success
    mig=$(grep -n "migrate --noinput" "$CALLS" | cut -d: -f1)
    perm=$(grep -n "manage.py sync_permissions" "$CALLS" | cut -d: -f1)
    up=$(grep -nE "^make .* (up|restart)$" "$CALLS" | head -1 | cut -d: -f1)
    [ -n "$mig" ] && [ -n "$perm" ] && [ -n "$up" ]
    [ "$mig" -lt "$up" ]
    [ "$perm" -lt "$up" ]
}
@test "update --migrate: falha na migração impede o restart" {
    FAKE_MIGRATE_FAIL=1 run bash "$SCRIPT" update --no-build --migrate
    assert_failure
    assert_output --partial "restart NÃO foi feito"
    run grep -cE "^make .* (up|restart)$" "$CALLS"
    assert_output "0"
}
@test "update sem --migrate não roda migrações" {
    run bash "$SCRIPT" update --no-build
    assert_success
    run grep -c "manage.py" "$CALLS"
    assert_output "0"
}
