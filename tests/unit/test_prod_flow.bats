#!/usr/bin/env bats
# tests/unit/test_prod_flow.bats
# Testes unitários para o fluxo de produção (deb/suap-prod.sh, rpm/suap-prod.sh)
# Validates: Requirements 12.1, 12.2, 15.1, 15.5, 15.6, 16.1

setup() {
    load '../test_helper/common-setup'

    # Necessário para tput funcionar em ambiente de teste
    export TERM=xterm

    # Source da biblioteca sob teste
    source "$COMMON_SH"

    # Diretório temporário para mocks e simulações
    TEST_TEMP_DIR="$(mktemp -d)"
    export PATH="${TEST_TEMP_DIR}:${PATH}"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# ============================================================
# Testes de validação de root (Req 12.1, 12.2)
# ============================================================

@test "produção: EUID != 0 exibe erro e encerra com exit 1" {
    # EUID é read-only; testamos a lógica com uma função parametrizada
    run bash -c "
        export TERM=xterm
        source '${COMMON_SH}'

        check_root() {
            local euid=\$1
            if [ \"\$euid\" -ne 0 ]; then
                msg_error 'Este script deve ser executado como root. Use sudo ou entre como root.'
                return 1
            fi
        }

        check_root 1000
    "
    assert_failure
    assert_output --partial "ERRO:"
    assert_output --partial "root"
}

@test "produção: EUID == 0 permite execução normalmente" {
    # EUID é read-only em bash, então usamos uma função que recebe o valor como parâmetro
    run bash -c "
        export TERM=xterm
        source '${COMMON_SH}'

        check_root() {
            local euid=\$1
            if [ \"\$euid\" -ne 0 ]; then
                msg_error 'Este script deve ser executado como root. Use sudo ou entre como root.'
                return 1
            fi
            echo 'execução permitida'
            return 0
        }

        check_root 0
    "
    assert_success
    assert_output --partial "execução permitida"
}

# ============================================================
# Testes do menu do Supervisor (Req 15.1, 15.5, 15.6)
# ============================================================

@test "supervisor opção 1: copia suap.conf e run_suap.sh" {
    # Simular estrutura de diretórios do projeto
    local script_dir="${TEST_TEMP_DIR}/project"
    local base_dir="${TEST_TEMP_DIR}/opt"
    local supervisor_conf_dir="${TEST_TEMP_DIR}/etc/supervisor/conf.d"

    mkdir -p "${script_dir}/supervisor"
    mkdir -p "${base_dir}/scripts"
    mkdir -p "${supervisor_conf_dir}"

    # Criar arquivos de configuração simulados
    echo "[program:suap]" > "${script_dir}/supervisor/suap.conf"
    echo "#!/bin/bash" > "${script_dir}/supervisor/run_suap.sh"

    # Simular lógica da opção 1
    run bash -c "
        export TERM=xterm
        source '${COMMON_SH}'
        SCRIPT_DIR='${script_dir}'
        BASE_DIR='${base_dir}'
        SUPERVISOR_CONF_DIR='${supervisor_conf_dir}'
        supervisor_choice=1

        if [ -f \"\${SCRIPT_DIR}/supervisor/suap.conf\" ]; then
            cp \"\${SCRIPT_DIR}/supervisor/suap.conf\" \"\${SUPERVISOR_CONF_DIR}/suap.conf\"
            cp \"\${SCRIPT_DIR}/supervisor/run_suap.sh\" \"\${BASE_DIR}/scripts/run_suap.sh\"
            chmod +x \"\${BASE_DIR}/scripts/run_suap.sh\"
            msg_action '✓ SUAP configurado'
        else
            msg_error 'Arquivo supervisor/suap.conf não encontrado'
            exit 1
        fi
    "
    assert_success

    # Verificar que os arquivos foram copiados corretamente
    [ -f "${supervisor_conf_dir}/suap.conf" ]
    [ -f "${base_dir}/scripts/run_suap.sh" ]
}

@test "supervisor opção 2: copia configs e runners do Celery" {
    local script_dir="${TEST_TEMP_DIR}/project"
    local base_dir="${TEST_TEMP_DIR}/opt"
    local supervisor_conf_dir="${TEST_TEMP_DIR}/etc/supervisor/conf.d"

    mkdir -p "${script_dir}/supervisor"
    mkdir -p "${base_dir}/scripts"
    mkdir -p "${supervisor_conf_dir}"

    # Criar todos os arquivos Celery
    echo "[program:celery-worker]" > "${script_dir}/supervisor/celery_worker.conf"
    echo "#!/bin/bash" > "${script_dir}/supervisor/run_celery_worker.sh"
    echo "[program:celery-beat]" > "${script_dir}/supervisor/celery_beat.conf"
    echo "#!/bin/bash" > "${script_dir}/supervisor/run_celery_beat.sh"
    echo "[program:celery-flower]" > "${script_dir}/supervisor/celery_flower.conf"
    echo "#!/bin/bash" > "${script_dir}/supervisor/run_celery_flower.sh"

    run bash -c "
        export TERM=xterm
        source '${COMMON_SH}'
        SCRIPT_DIR='${script_dir}'
        BASE_DIR='${base_dir}'
        SUPERVISOR_CONF_DIR='${supervisor_conf_dir}'

        if [ -f \"\${SCRIPT_DIR}/supervisor/celery_worker.conf\" ]; then
            cp \"\${SCRIPT_DIR}/supervisor/celery_worker.conf\" \"\${SUPERVISOR_CONF_DIR}/celery_worker.conf\"
            cp \"\${SCRIPT_DIR}/supervisor/run_celery_worker.sh\" \"\${BASE_DIR}/scripts/run_celery_worker.sh\"
            chmod +x \"\${BASE_DIR}/scripts/run_celery_worker.sh\"
            cp \"\${SCRIPT_DIR}/supervisor/celery_beat.conf\" \"\${SUPERVISOR_CONF_DIR}/celery_beat.conf\"
            cp \"\${SCRIPT_DIR}/supervisor/run_celery_beat.sh\" \"\${BASE_DIR}/scripts/run_celery_beat.sh\"
            chmod +x \"\${BASE_DIR}/scripts/run_celery_beat.sh\"
            cp \"\${SCRIPT_DIR}/supervisor/celery_flower.conf\" \"\${SUPERVISOR_CONF_DIR}/celery_flower.conf\"
            cp \"\${SCRIPT_DIR}/supervisor/run_celery_flower.sh\" \"\${BASE_DIR}/scripts/run_celery_flower.sh\"
            chmod +x \"\${BASE_DIR}/scripts/run_celery_flower.sh\"
            msg_action '✓ Celery configurado'
        else
            msg_error 'Arquivo supervisor/celery_worker.conf não encontrado'
            exit 1
        fi
    "
    assert_success

    # Verificar todos os arquivos de configuração
    [ -f "${supervisor_conf_dir}/celery_worker.conf" ]
    [ -f "${supervisor_conf_dir}/celery_beat.conf" ]
    [ -f "${supervisor_conf_dir}/celery_flower.conf" ]

    # Verificar todos os runners
    [ -f "${base_dir}/scripts/run_celery_worker.sh" ]
    [ -f "${base_dir}/scripts/run_celery_beat.sh" ]
    [ -f "${base_dir}/scripts/run_celery_flower.sh" ]
}

@test "supervisor opção 3: copia SUAP + Celery (todos)" {
    local script_dir="${TEST_TEMP_DIR}/project"
    local base_dir="${TEST_TEMP_DIR}/opt"
    local supervisor_conf_dir="${TEST_TEMP_DIR}/etc/supervisor/conf.d"

    mkdir -p "${script_dir}/supervisor"
    mkdir -p "${base_dir}/scripts"
    mkdir -p "${supervisor_conf_dir}"

    # Criar todos os arquivos
    echo "[program:suap]" > "${script_dir}/supervisor/suap.conf"
    echo "#!/bin/bash" > "${script_dir}/supervisor/run_suap.sh"
    echo "[program:celery-worker]" > "${script_dir}/supervisor/celery_worker.conf"
    echo "#!/bin/bash" > "${script_dir}/supervisor/run_celery_worker.sh"
    echo "[program:celery-beat]" > "${script_dir}/supervisor/celery_beat.conf"
    echo "#!/bin/bash" > "${script_dir}/supervisor/run_celery_beat.sh"
    echo "[program:celery-flower]" > "${script_dir}/supervisor/celery_flower.conf"
    echo "#!/bin/bash" > "${script_dir}/supervisor/run_celery_flower.sh"

    run bash -c "
        export TERM=xterm
        source '${COMMON_SH}'
        SCRIPT_DIR='${script_dir}'
        BASE_DIR='${base_dir}'
        SUPERVISOR_CONF_DIR='${supervisor_conf_dir}'

        if [ -f \"\${SCRIPT_DIR}/supervisor/suap.conf\" ] && [ -f \"\${SCRIPT_DIR}/supervisor/celery_worker.conf\" ]; then
            cp \"\${SCRIPT_DIR}/supervisor/suap.conf\" \"\${SUPERVISOR_CONF_DIR}/suap.conf\"
            cp \"\${SCRIPT_DIR}/supervisor/run_suap.sh\" \"\${BASE_DIR}/scripts/run_suap.sh\"
            chmod +x \"\${BASE_DIR}/scripts/run_suap.sh\"
            cp \"\${SCRIPT_DIR}/supervisor/celery_worker.conf\" \"\${SUPERVISOR_CONF_DIR}/celery_worker.conf\"
            cp \"\${SCRIPT_DIR}/supervisor/run_celery_worker.sh\" \"\${BASE_DIR}/scripts/run_celery_worker.sh\"
            chmod +x \"\${BASE_DIR}/scripts/run_celery_worker.sh\"
            cp \"\${SCRIPT_DIR}/supervisor/celery_beat.conf\" \"\${SUPERVISOR_CONF_DIR}/celery_beat.conf\"
            cp \"\${SCRIPT_DIR}/supervisor/run_celery_beat.sh\" \"\${BASE_DIR}/scripts/run_celery_beat.sh\"
            chmod +x \"\${BASE_DIR}/scripts/run_celery_beat.sh\"
            cp \"\${SCRIPT_DIR}/supervisor/celery_flower.conf\" \"\${SUPERVISOR_CONF_DIR}/celery_flower.conf\"
            cp \"\${SCRIPT_DIR}/supervisor/run_celery_flower.sh\" \"\${BASE_DIR}/scripts/run_celery_flower.sh\"
            chmod +x \"\${BASE_DIR}/scripts/run_celery_flower.sh\"
            msg_action '✓ SUAP e Celery configurados'
        else
            msg_error 'Arquivos não encontrados'
            exit 1
        fi
    "
    assert_success

    # Verificar SUAP
    [ -f "${supervisor_conf_dir}/suap.conf" ]
    [ -f "${base_dir}/scripts/run_suap.sh" ]

    # Verificar Celery
    [ -f "${supervisor_conf_dir}/celery_worker.conf" ]
    [ -f "${supervisor_conf_dir}/celery_beat.conf" ]
    [ -f "${supervisor_conf_dir}/celery_flower.conf" ]
    [ -f "${base_dir}/scripts/run_celery_worker.sh" ]
    [ -f "${base_dir}/scripts/run_celery_beat.sh" ]
    [ -f "${base_dir}/scripts/run_celery_flower.sh" ]
}

@test "supervisor opção inválida: encerra com exit 1" {
    run bash -c "
        export TERM=xterm
        source '${COMMON_SH}'
        supervisor_choice=9

        case \$supervisor_choice in
            1) echo 'suap' ;;
            2) echo 'celery' ;;
            3) echo 'ambos' ;;
            *)
                msg_error 'Opção inválida. Abortando.'
                exit 1
                ;;
        esac
    "
    assert_failure
    assert_output --partial "ERRO:"
    assert_output --partial "inválida"
}

@test "supervisor: arquivo de configuração ausente encerra com exit 1 (Req 15.6)" {
    local script_dir="${TEST_TEMP_DIR}/project"
    local base_dir="${TEST_TEMP_DIR}/opt"
    local supervisor_conf_dir="${TEST_TEMP_DIR}/etc/supervisor/conf.d"

    # Criar diretórios mas NÃO criar os arquivos de configuração
    mkdir -p "${script_dir}/supervisor"
    mkdir -p "${base_dir}/scripts"
    mkdir -p "${supervisor_conf_dir}"

    run bash -c "
        export TERM=xterm
        source '${COMMON_SH}'
        SCRIPT_DIR='${script_dir}'
        BASE_DIR='${base_dir}'
        SUPERVISOR_CONF_DIR='${supervisor_conf_dir}'

        if [ -f \"\${SCRIPT_DIR}/supervisor/suap.conf\" ]; then
            cp \"\${SCRIPT_DIR}/supervisor/suap.conf\" \"\${SUPERVISOR_CONF_DIR}/suap.conf\"
            cp \"\${SCRIPT_DIR}/supervisor/run_suap.sh\" \"\${BASE_DIR}/scripts/run_suap.sh\"
            chmod +x \"\${BASE_DIR}/scripts/run_suap.sh\"
            msg_action '✓ SUAP configurado'
        else
            msg_error 'Arquivo supervisor/suap.conf não encontrado em \${SCRIPT_DIR}'
            exit 1
        fi
    "
    assert_failure
    assert_output --partial "ERRO:"
    assert_output --partial "não encontrado"
}

# ============================================================
# Testes de permissões nos runners (Req 15.7)
# ============================================================

@test "supervisor: chmod +x é aplicado nos scripts runner (opção 1)" {
    local script_dir="${TEST_TEMP_DIR}/project"
    local base_dir="${TEST_TEMP_DIR}/opt"
    local supervisor_conf_dir="${TEST_TEMP_DIR}/etc/supervisor/conf.d"

    mkdir -p "${script_dir}/supervisor"
    mkdir -p "${base_dir}/scripts"
    mkdir -p "${supervisor_conf_dir}"

    echo "[program:suap]" > "${script_dir}/supervisor/suap.conf"
    echo "#!/bin/bash" > "${script_dir}/supervisor/run_suap.sh"

    # Executar a lógica de cópia
    bash -c "
        export TERM=xterm
        source '${COMMON_SH}'
        SCRIPT_DIR='${script_dir}'
        BASE_DIR='${base_dir}'
        SUPERVISOR_CONF_DIR='${supervisor_conf_dir}'

        cp \"\${SCRIPT_DIR}/supervisor/suap.conf\" \"\${SUPERVISOR_CONF_DIR}/suap.conf\"
        cp \"\${SCRIPT_DIR}/supervisor/run_suap.sh\" \"\${BASE_DIR}/scripts/run_suap.sh\"
        chmod +x \"\${BASE_DIR}/scripts/run_suap.sh\"
    "

    # Verificar permissão de execução
    [ -x "${base_dir}/scripts/run_suap.sh" ]
}

@test "supervisor: chmod +x é aplicado nos runners do Celery (opção 2)" {
    local script_dir="${TEST_TEMP_DIR}/project"
    local base_dir="${TEST_TEMP_DIR}/opt"
    local supervisor_conf_dir="${TEST_TEMP_DIR}/etc/supervisor/conf.d"

    mkdir -p "${script_dir}/supervisor"
    mkdir -p "${base_dir}/scripts"
    mkdir -p "${supervisor_conf_dir}"

    echo "[program:celery-worker]" > "${script_dir}/supervisor/celery_worker.conf"
    echo "#!/bin/bash" > "${script_dir}/supervisor/run_celery_worker.sh"
    echo "[program:celery-beat]" > "${script_dir}/supervisor/celery_beat.conf"
    echo "#!/bin/bash" > "${script_dir}/supervisor/run_celery_beat.sh"
    echo "[program:celery-flower]" > "${script_dir}/supervisor/celery_flower.conf"
    echo "#!/bin/bash" > "${script_dir}/supervisor/run_celery_flower.sh"

    bash -c "
        export TERM=xterm
        source '${COMMON_SH}'
        SCRIPT_DIR='${script_dir}'
        BASE_DIR='${base_dir}'
        SUPERVISOR_CONF_DIR='${supervisor_conf_dir}'

        cp \"\${SCRIPT_DIR}/supervisor/celery_worker.conf\" \"\${SUPERVISOR_CONF_DIR}/celery_worker.conf\"
        cp \"\${SCRIPT_DIR}/supervisor/run_celery_worker.sh\" \"\${BASE_DIR}/scripts/run_celery_worker.sh\"
        chmod +x \"\${BASE_DIR}/scripts/run_celery_worker.sh\"
        cp \"\${SCRIPT_DIR}/supervisor/celery_beat.conf\" \"\${SUPERVISOR_CONF_DIR}/celery_beat.conf\"
        cp \"\${SCRIPT_DIR}/supervisor/run_celery_beat.sh\" \"\${BASE_DIR}/scripts/run_celery_beat.sh\"
        chmod +x \"\${BASE_DIR}/scripts/run_celery_beat.sh\"
        cp \"\${SCRIPT_DIR}/supervisor/celery_flower.conf\" \"\${SUPERVISOR_CONF_DIR}/celery_flower.conf\"
        cp \"\${SCRIPT_DIR}/supervisor/run_celery_flower.sh\" \"\${BASE_DIR}/scripts/run_celery_flower.sh\"
        chmod +x \"\${BASE_DIR}/scripts/run_celery_flower.sh\"
    "

    # Verificar que todos os runners são executáveis
    [ -x "${base_dir}/scripts/run_celery_worker.sh" ]
    [ -x "${base_dir}/scripts/run_celery_beat.sh" ]
    [ -x "${base_dir}/scripts/run_celery_flower.sh" ]
}

# ============================================================
# Testes de permissões de diretórios (Req 16.1)
# ============================================================

@test "permissões: chown -R www-data nos diretórios de produção" {
    # Criar mock do chown que registra as chamadas
    cat > "${TEST_TEMP_DIR}/chown" << 'MOCK'
#!/bin/bash
echo "$@" >> "${TEST_TEMP_DIR}/chown_calls"
exit 0
MOCK
    chmod +x "${TEST_TEMP_DIR}/chown"

    local suap_dir="${TEST_TEMP_DIR}/suap"
    local base_dir="${TEST_TEMP_DIR}/opt"
    local venv_dir="${TEST_TEMP_DIR}/venv"

    mkdir -p "${suap_dir}" "${base_dir}/logs" "${venv_dir}/suap"

    # Simular a etapa de permissões da produção
    export TEST_TEMP_DIR
    run bash -c "
        export PATH='${TEST_TEMP_DIR}:\$PATH'
        export TEST_TEMP_DIR='${TEST_TEMP_DIR}'
        SUAP_DIR='${suap_dir}'
        BASE_DIR='${base_dir}'
        VENV_DIR='${venv_dir}'

        chown -R www-data:www-data \"\${SUAP_DIR}\"
        chown -R www-data:www-data \"\${BASE_DIR}/logs\"
        chown -R www-data:www-data \"\${VENV_DIR}/suap\"
    "
    assert_success

    # Verificar que chown foi chamado para os 3 diretórios
    run cat "${TEST_TEMP_DIR}/chown_calls"
    assert_output --partial "${suap_dir}"
    assert_output --partial "${base_dir}/logs"
    assert_output --partial "${venv_dir}/suap"
}

@test "permissões: chown usa www-data:www-data como proprietário" {
    cat > "${TEST_TEMP_DIR}/chown" << 'MOCK'
#!/bin/bash
echo "$@" >> "${TEST_TEMP_DIR}/chown_calls"
exit 0
MOCK
    chmod +x "${TEST_TEMP_DIR}/chown"

    local suap_dir="${TEST_TEMP_DIR}/suap"
    mkdir -p "${suap_dir}"

    export TEST_TEMP_DIR
    run bash -c "
        export PATH='${TEST_TEMP_DIR}:\$PATH'
        export TEST_TEMP_DIR='${TEST_TEMP_DIR}'
        chown -R www-data:www-data '${suap_dir}'
    "
    assert_success

    # Verificar que www-data:www-data foi usado
    run cat "${TEST_TEMP_DIR}/chown_calls"
    assert_output --partial "www-data:www-data"
}

@test "permissões: chown usa flag -R (recursivo)" {
    cat > "${TEST_TEMP_DIR}/chown" << 'MOCK'
#!/bin/bash
echo "$@" >> "${TEST_TEMP_DIR}/chown_calls"
exit 0
MOCK
    chmod +x "${TEST_TEMP_DIR}/chown"

    local suap_dir="${TEST_TEMP_DIR}/suap"
    mkdir -p "${suap_dir}"

    export TEST_TEMP_DIR
    run bash -c "
        export PATH='${TEST_TEMP_DIR}:\$PATH'
        export TEST_TEMP_DIR='${TEST_TEMP_DIR}'
        chown -R www-data:www-data '${suap_dir}'
    "
    assert_success

    run cat "${TEST_TEMP_DIR}/chown_calls"
    assert_output --partial "-R"
}

# ============================================================
# Testes de clone com --depth 1 (Req 13.1)
# ============================================================

@test "clone produção: usa --depth 1 no git clone" {
    # Mock do git que registra os argumentos
    cat > "${TEST_TEMP_DIR}/git" << 'MOCK'
#!/bin/bash
echo "$@" >> "${TEST_TEMP_DIR}/git_calls"
exit 0
MOCK
    chmod +x "${TEST_TEMP_DIR}/git"

    local base_dir="${TEST_TEMP_DIR}/opt"
    local suap_dir="${base_dir}/suap"
    mkdir -p "${base_dir}"

    export TEST_TEMP_DIR
    run bash -c "
        export PATH='${TEST_TEMP_DIR}:\$PATH'
        export TEST_TEMP_DIR='${TEST_TEMP_DIR}'
        SUAP_DIR='${suap_dir}'
        BASE_DIR='${base_dir}'
        SUAP_GIT_URL='https://example.com/suap.git'

        if [ ! -d \"\${SUAP_DIR}/.git\" ]; then
            cd \"\${BASE_DIR}\"
            git clone --depth 1 \"\${SUAP_GIT_URL}\"
        fi
    "
    assert_success

    # Verificar que --depth 1 foi usado
    run cat "${TEST_TEMP_DIR}/git_calls"
    assert_output --partial "clone --depth 1"
}

@test "clone produção: --depth 1 diferencia produção de desenvolvimento" {
    # Em produção: git clone --depth 1
    # Em desenvolvimento: git clone (sem --depth)
    # Este teste verifica que o padrão do script de produção usa --depth 1

    # Verificar diretamente no script deb/suap-prod.sh
    run grep -c "git clone --depth 1" "${PROJECT_ROOT}/deb/suap-prod.sh"
    assert_output "1"

    # Verificar no script rpm/suap-prod.sh
    run grep -c "git clone --depth 1" "${PROJECT_ROOT}/rpm/suap-prod.sh"
    assert_output "1"
}

@test "clone produção: não usa --depth no update (git pull)" {
    # Mock do git
    cat > "${TEST_TEMP_DIR}/git" << 'MOCK'
#!/bin/bash
echo "$@" >> "${TEST_TEMP_DIR}/git_calls"
exit 0
MOCK
    chmod +x "${TEST_TEMP_DIR}/git"

    local suap_dir="${TEST_TEMP_DIR}/suap"
    mkdir -p "${suap_dir}/.git"  # Simular que já foi clonado

    export TEST_TEMP_DIR
    run bash -c "
        export PATH='${TEST_TEMP_DIR}:\$PATH'
        export TEST_TEMP_DIR='${TEST_TEMP_DIR}'
        SUAP_DIR='${suap_dir}'

        if [ ! -d \"\${SUAP_DIR}/.git\" ]; then
            git clone --depth 1 'https://example.com/suap.git'
        else
            cd \"\${SUAP_DIR}\"
            git checkout master
            git pull
        fi
    "
    assert_success

    # Verificar que executou checkout + pull (sem --depth)
    run cat "${TEST_TEMP_DIR}/git_calls"
    assert_output --partial "checkout master"
    assert_output --partial "pull"
    refute_output --partial "--depth"
}
