#!/usr/bin/env bats
# tests/unit/test_clean_tmp.bats
# Testes do comando clean-tmp de docker/prod/suap-deploy.sh (limpeza de deploy/media/tmp)
setup() {
    load '../test_helper/common-setup'
    export TERM=xterm
    TEST_TEMP_DIR="$(mktemp -d)"
    export SUAP_DEPLOY_DIR="${TEST_TEMP_DIR}/suap_deploy"
    export SUAP_SUDO=""
    export CLEAN_TMP_CRON_FILE="${TEST_TEMP_DIR}/cron.d/suap-media-tmp"
    mkdir -p "${SUAP_DEPLOY_DIR}/deploy/media/tmp/sub" "${SUAP_DEPLOY_DIR}/deploy/media/uploads" "${TEST_TEMP_DIR}/cron.d"
    touch "${SUAP_DEPLOY_DIR}/Makefile"
    TMPD="${SUAP_DEPLOY_DIR}/deploy/media/tmp"
    echo velho > "${TMPD}/velho.pdf";        touch -d '10 days ago' "${TMPD}/velho.pdf"
    echo velho > "${TMPD}/sub/velho2.docx";  touch -d '10 days ago' "${TMPD}/sub/velho2.docx"
    touch -d '10 days ago' "${TMPD}/sub"
    echo novo > "${TMPD}/novo.pdf"
    echo perm > "${SUAP_DEPLOY_DIR}/deploy/media/uploads/foto.jpg"
    touch -d '30 days ago' "${SUAP_DEPLOY_DIR}/deploy/media/uploads/foto.jpg"
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
@test "clean-tmp --dry-run conta os arquivos antigos e não apaga nada" {
    run bash "$SCRIPT" clean-tmp --dry-run
    assert_success
    assert_output --partial "Encontrados: 2 arquivo(s)"
    assert_output --partial "nada foi apagado"
    [ -f "${TMPD}/velho.pdf" ]
    [ -f "${TMPD}/sub/velho2.docx" ]
}
@test "clean-tmp --yes apaga só arquivos antigos de tmp e pastas vazias antigas" {
    run bash "$SCRIPT" clean-tmp --yes
    assert_success
    [ ! -e "${TMPD}/velho.pdf" ]
    [ ! -e "${TMPD}/sub/velho2.docx" ]
    [ -f "${TMPD}/novo.pdf" ]
    [ -d "${TMPD}" ]
    [ -f "${SUAP_DEPLOY_DIR}/deploy/media/uploads/foto.jpg" ]
}
@test "clean-tmp --days respeita a idade informada" {
    run bash "$SCRIPT" clean-tmp --days 20 --yes
    assert_success
    assert_output --partial "Nada a apagar"
    [ -f "${TMPD}/velho.pdf" ]
}
@test "clean-tmp sem terminal e sem --yes recusa apagar" {
    run bash "$SCRIPT" clean-tmp < /dev/null
    assert_failure
    assert_output --partial "--yes"
    [ -f "${TMPD}/velho.pdf" ]
}
@test "clean-tmp rejeita --days inválido" {
    run bash "$SCRIPT" clean-tmp --days 0
    assert_failure
    run bash "$SCRIPT" clean-tmp --days abc
    assert_failure
}
@test "clean-tmp falha se deploy/media/tmp não existe" {
    rm -rf "${TMPD}"
    run bash "$SCRIPT" clean-tmp --dry-run
    assert_failure
    assert_output --partial "não encontrada"
}
@test "clean-tmp recusa operar se tmp é um link para fora (ex.: /tmp)" {
    rm -rf "${TMPD}"
    ln -s /tmp "${TMPD}"
    run bash "$SCRIPT" clean-tmp --dry-run
    assert_failure
}
@test "clean-tmp --install-cron grava a linha com o caminho real e a idade" {
    run bash "$SCRIPT" clean-tmp --install-cron --days 5 --hour 4
    assert_success
    [ -f "${CLEAN_TMP_CRON_FILE}" ]
    run cat "${CLEAN_TMP_CRON_FILE}"
    assert_output --partial "30 4 * * * root find $(readlink -f "${TMPD}") -xdev -mindepth 1 -type f -mtime +5 -delete"
    [ -f "${TMPD}/velho.pdf" ]
}
@test "clean-tmp --remove-cron remove o cron instalado" {
    bash "$SCRIPT" clean-tmp --install-cron
    run bash "$SCRIPT" clean-tmp --remove-cron
    assert_success
    [ ! -e "${CLEAN_TMP_CRON_FILE}" ]
}
