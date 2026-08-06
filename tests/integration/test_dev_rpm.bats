#!/usr/bin/env bats
# tests/integration/test_dev_rpm.bats
# Testes de integração: fluxo de desenvolvimento completo em RPM (Fedora)
# Executado dentro de container Docker (Dockerfile.fedora)

setup() {
    load '../test_helper/common-setup'

    # Diretório temporário para simulação do ambiente
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR

    # Configurar variáveis de ambiente para o teste
    export HOME="${TEST_TEMP_DIR}/home"
    mkdir -p "${HOME}"

    # Simular .env para os testes
    export TEST_ENV_FILE="${TEST_TEMP_DIR}/.env"
}

teardown() {
    rm -rf "${TEST_TEMP_DIR}"
}

# --- Testes de verificação do ambiente RPM ---

@test "[rpm-dev] ambiente de teste tem bash disponível" {
    run bash --version
    assert_success
}

@test "[rpm-dev] ambiente de teste tem git instalado" {
    run git --version
    assert_success
}

@test "[rpm-dev] ambiente de teste tem python3 instalado" {
    run python3 --version
    assert_success
}

@test "[rpm-dev] ambiente de teste tem curl disponível" {
    run curl --version
    assert_success
}

@test "[rpm-dev] sistema detectado como família RPM" {
    run grep -i "fedora\|rhel\|centos\|alma\|rocky" /etc/os-release
    assert_success
}

# --- Testes da biblioteca compartilhada em ambiente real ---

@test "[rpm-dev] lib/common.sh pode ser carregado sem erro" {
    run bash -c "source '${PROJECT_ROOT}/lib/common.sh'"
    assert_success
}

@test "[rpm-dev] detect_distro() classifica como 'rpm' em Fedora" {
    run bash -c "source '${PROJECT_ROOT}/lib/common.sh' && detect_distro && echo \${DISTRO_TYPE}"
    assert_success
    assert_output "rpm"
}

@test "[rpm-dev] create_default_env() cria arquivo .env com conteúdo válido" {
    run bash -c "source '${PROJECT_ROOT}/lib/common.sh' && create_default_env '${TEST_ENV_FILE}'"
    assert_success
    [ -f "${TEST_ENV_FILE}" ]

    run grep "PYTHON_VERSION" "${TEST_ENV_FILE}"
    assert_success

    run grep "BASE_DIR" "${TEST_ENV_FILE}"
    assert_success

    run grep "SUAP_GIT_URL" "${TEST_ENV_FILE}"
    assert_success
}

@test "[rpm-dev] load_env_file() carrega variáveis do .env" {
    # Criar .env de teste
    cat > "${TEST_ENV_FILE}" << 'EOF'
PYTHON_VERSION=3.12
BASE_DIR=/tmp/test
SUAP_GIT_URL=https://example.com/suap.git
EOF

    run bash -c "source '${PROJECT_ROOT}/lib/common.sh' && load_env_file '${TEST_ENV_FILE}' && echo \${PYTHON_VERSION}"
    assert_success
    assert_output "3.12"
}

@test "[rpm-dev] is_pkg_installed() detecta pacote instalado em RPM" {
    run bash -c "source '${PROJECT_ROOT}/lib/common.sh' && detect_distro && is_pkg_installed bash"
    assert_success
}

@test "[rpm-dev] is_pkg_installed() retorna falha para pacote não instalado" {
    run bash -c "source '${PROJECT_ROOT}/lib/common.sh' && detect_distro && is_pkg_installed pacote-inexistente-xyz"
    assert_failure
}

# --- Testes de fluxo do script de desenvolvimento ---

@test "[rpm-dev] rpm/suap-dev.sh existe e é executável" {
    [ -f "${PROJECT_ROOT}/rpm/suap-dev.sh" ]
    [ -x "${PROJECT_ROOT}/rpm/suap-dev.sh" ]
}

@test "[rpm-dev] setup.sh existe e é executável" {
    [ -f "${PROJECT_ROOT}/setup.sh" ]
    [ -x "${PROJECT_ROOT}/setup.sh" ]
}

@test "[rpm-dev] setup.sh exibe menu quando executado com opção inválida" {
    run bash -c "echo '99' | bash '${PROJECT_ROOT}/setup.sh'"
    assert_failure
    # Deve mencionar opção inválida
    assert_output --partial "inválida"
}
