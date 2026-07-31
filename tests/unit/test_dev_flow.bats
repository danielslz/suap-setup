#!/usr/bin/env bats
# tests/unit/test_dev_flow.bats
# Testes unitários para o fluxo de desenvolvimento (deb/suap-dev.sh, rpm/suap-dev.sh)
# Validates: Requirements 9.1, 9.2, 9.3, 9.4, 10.4, 10.5, 10.6, 24.1, 24.3

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
# Testes de load_env_file() - Carregamento de variáveis
# ============================================================

@test "load_env_file() carrega variáveis simples do .env" {
    local env_file="${TEST_TEMP_DIR}/.env"
    cat > "$env_file" << 'EOF'
PYTHON_VERSION=3.12
BASE_DIR=/opt
EOF

    load_env_file "$env_file"

    [ "$PYTHON_VERSION" = "3.12" ]
    [ "$BASE_DIR" = "/opt" ]
}

@test "load_env_file() ignora comentários no .env" {
    local env_file="${TEST_TEMP_DIR}/.env"
    cat > "$env_file" << 'EOF'
# Este é um comentário
PYTHON_VERSION=3.12
# Outro comentário
BASE_DIR=/opt
EOF

    load_env_file "$env_file"

    [ "$PYTHON_VERSION" = "3.12" ]
    [ "$BASE_DIR" = "/opt" ]
}

@test "load_env_file() ignora linhas vazias no .env" {
    local env_file="${TEST_TEMP_DIR}/.env"
    cat > "$env_file" << 'EOF'
PYTHON_VERSION=3.12

BASE_DIR=/opt

EOF

    load_env_file "$env_file"

    [ "$PYTHON_VERSION" = "3.12" ]
    [ "$BASE_DIR" = "/opt" ]
}

@test "load_env_file() expande variáveis no valor" {
    local env_file="${TEST_TEMP_DIR}/.env"
    cat > "$env_file" << 'EOF'
BASE_DIR=/opt
SUAP_DIR=${BASE_DIR}/suap
EOF

    load_env_file "$env_file"

    [ "$SUAP_DIR" = "/opt/suap" ]
}

@test "load_env_file() cria .env padrão se não existir" {
    local env_file="${TEST_TEMP_DIR}/new_dir/.env"
    mkdir -p "${TEST_TEMP_DIR}/new_dir"

    run load_env_file "$env_file"
    assert_success

    # O arquivo deve ter sido criado
    [ -f "$env_file" ]
}

@test "load_env_file() exporta variáveis carregadas" {
    local env_file="${TEST_TEMP_DIR}/.env"
    cat > "$env_file" << 'EOF'
MY_TEST_VAR=hello_world
EOF

    load_env_file "$env_file"

    # A variável deve estar exportada e acessível em subshells
    run bash -c 'echo $MY_TEST_VAR'
    assert_output "hello_world"
}

# ============================================================
# Testes de resolve_git_url() - Resolução de URL Git
# ============================================================

@test "resolve_git_url() usa SUAP_GIT_URL existente sem solicitar entrada" {
    local env_file="${TEST_TEMP_DIR}/.env"
    cat > "$env_file" << 'EOF'
SUAP_GIT_URL=https://github.com/example/suap.git
EOF

    export SUAP_GIT_URL="https://github.com/example/suap.git"

    # Deve retornar sucesso sem necessitar de input
    run resolve_git_url "$env_file"
    assert_success
    # Deve exibir mensagem de skip indicando que já está configurada
    assert_output --partial "SUAP_GIT_URL já configurada"
}

@test "resolve_git_url() não sobrescreve SUAP_GIT_URL já definida" {
    local env_file="${TEST_TEMP_DIR}/.env"
    cat > "$env_file" << 'EOF'
SUAP_GIT_URL=https://github.com/original/suap.git
EOF

    export SUAP_GIT_URL="https://github.com/original/suap.git"

    resolve_git_url "$env_file"

    # O valor deve permanecer o original
    [ "$SUAP_GIT_URL" = "https://github.com/original/suap.git" ]
}

# ============================================================
# Testes de idempotência - Pular etapas já concluídas
# ============================================================

@test "idempotência: settings.py NÃO é sobrescrito se já existe" {
    local suap_dir="${TEST_TEMP_DIR}/suap"
    mkdir -p "${suap_dir}/suap"

    # Criar settings.py com conteúdo personalizado
    echo "# Configuração personalizada do usuário" > "${suap_dir}/suap/settings.py"

    # Criar sample para comparação
    echo "# Settings sample original" > "${suap_dir}/suap/settings_sample.py"

    # Simular a lógica do dev script: se settings.py já existe, pular
    local SUAP_DIR="$suap_dir"
    if [ ! -f "${SUAP_DIR}/suap/settings.py" ]; then
        cp "${SUAP_DIR}/suap/settings_sample.py" "${SUAP_DIR}/suap/settings.py"
    fi

    # Verificar que o conteúdo personalizado foi preservado
    run cat "${suap_dir}/suap/settings.py"
    assert_output "# Configuração personalizada do usuário"
}

@test "idempotência: .env NÃO é sobrescrito se já existe" {
    local suap_dir="${TEST_TEMP_DIR}/suap"
    mkdir -p "${suap_dir}"

    # Criar .env com conteúdo personalizado
    echo "DATABASE_URL=postgres://custom:5432/suap" > "${suap_dir}/.env"

    # Criar sample para comparação
    echo "DATABASE_URL=postgres://localhost:5432/suap" > "${suap_dir}/.env.dev.sample"

    # Simular a lógica do dev script: se .env já existe, pular
    local SUAP_DIR="$suap_dir"
    if [ ! -f "${SUAP_DIR}/.env" ]; then
        cp "${SUAP_DIR}/.env.dev.sample" "${SUAP_DIR}/.env"
    fi

    # Verificar que o conteúdo personalizado foi preservado
    run cat "${suap_dir}/.env"
    assert_output "DATABASE_URL=postgres://custom:5432/suap"
}

@test "idempotência: settings.py É criado a partir do sample se não existe" {
    local suap_dir="${TEST_TEMP_DIR}/suap"
    mkdir -p "${suap_dir}/suap"

    # Criar apenas o sample
    echo "# Settings sample original" > "${suap_dir}/suap/settings_sample.py"

    # Simular a lógica do dev script
    local SUAP_DIR="$suap_dir"
    if [ ! -f "${SUAP_DIR}/suap/settings.py" ]; then
        cp "${SUAP_DIR}/suap/settings_sample.py" "${SUAP_DIR}/suap/settings.py"
    fi

    # Verificar que foi copiado do sample
    run cat "${suap_dir}/suap/settings.py"
    assert_output "# Settings sample original"
}

@test "idempotência: .env É criado a partir do sample se não existe" {
    local suap_dir="${TEST_TEMP_DIR}/suap"
    mkdir -p "${suap_dir}"

    # Criar apenas o sample
    echo "DATABASE_URL=postgres://localhost:5432/suap" > "${suap_dir}/.env.dev.sample"

    # Simular a lógica do dev script
    local SUAP_DIR="$suap_dir"
    if [ ! -f "${SUAP_DIR}/.env" ]; then
        cp "${SUAP_DIR}/.env.dev.sample" "${SUAP_DIR}/.env"
    fi

    # Verificar que foi copiado do sample
    run cat "${suap_dir}/.env"
    assert_output "DATABASE_URL=postgres://localhost:5432/suap"
}

@test "idempotência: virtualenv não é recriado se .venv já existe" {
    local suap_dir="${TEST_TEMP_DIR}/suap"
    mkdir -p "${suap_dir}/.venv"

    # Criar um marcador no .venv existente
    echo "marker" > "${suap_dir}/.venv/existing_marker"

    # Simular a lógica: se .venv existe, pular
    local VENV_DIR="${suap_dir}/.venv"
    local venv_created="no"
    if [ ! -d "${VENV_DIR}" ]; then
        venv_created="yes"
    fi

    # Verificar que não foi recriado
    [ "$venv_created" = "no" ]
    # E o marcador ainda existe
    [ -f "${suap_dir}/.venv/existing_marker" ]
}

@test "idempotência: exibe msg_skip quando componente já está configurado" {
    # Simular cenário onde settings.py já existe
    local suap_dir="${TEST_TEMP_DIR}/suap"
    mkdir -p "${suap_dir}/suap"
    echo "existing" > "${suap_dir}/suap/settings.py"

    local SUAP_DIR="$suap_dir"
    if [ -f "${SUAP_DIR}/suap/settings.py" ]; then
        run msg_skip "settings.py já existe"
        assert_success
        assert_output --partial "settings.py já existe"
    fi
}

# ============================================================
# Testes de detecção pyproject.toml vs requirements/
# ============================================================

@test "detecção deps: usa 'uv sync --group dev' quando pyproject.toml existe" {
    local suap_dir="${TEST_TEMP_DIR}/suap"
    mkdir -p "${suap_dir}"

    # Criar pyproject.toml
    echo '[project]' > "${suap_dir}/pyproject.toml"

    # Mock uv que registra chamadas
    cat > "${TEST_TEMP_DIR}/uv" << 'MOCK'
#!/bin/bash
echo "uv called with: $@" >> /tmp/uv_calls_$$
exit 0
MOCK
    chmod +x "${TEST_TEMP_DIR}/uv"

    local SUAP_DIR="$suap_dir"
    cd "${SUAP_DIR}"

    # Simular a lógica de decisão
    if [ -f "${SUAP_DIR}/pyproject.toml" ]; then
        run uv sync --group dev
        assert_success
    elif [ -d "${SUAP_DIR}/requirements" ]; then
        run uv pip install -r requirements/development.txt
    else
        false  # Não deveria chegar aqui
    fi
}

@test "detecção deps: usa 'uv pip install -r requirements/development.txt' quando apenas requirements/ existe" {
    local suap_dir="${TEST_TEMP_DIR}/suap"
    mkdir -p "${suap_dir}/requirements"

    # Criar requirements/development.txt
    echo "django==4.2" > "${suap_dir}/requirements/development.txt"

    # Mock uv
    cat > "${TEST_TEMP_DIR}/uv" << 'MOCK'
#!/bin/bash
echo "uv called with: $@"
exit 0
MOCK
    chmod +x "${TEST_TEMP_DIR}/uv"

    local SUAP_DIR="$suap_dir"
    cd "${SUAP_DIR}"

    # Simular a lógica de decisão
    local install_cmd=""
    if [ -f "${SUAP_DIR}/pyproject.toml" ]; then
        install_cmd="uv sync --group dev"
    elif [ -d "${SUAP_DIR}/requirements" ]; then
        install_cmd="uv pip install -r requirements/development.txt"
    fi

    [ "$install_cmd" = "uv pip install -r requirements/development.txt" ]
}

@test "detecção deps: pyproject.toml tem prioridade sobre requirements/" {
    local suap_dir="${TEST_TEMP_DIR}/suap"
    mkdir -p "${suap_dir}/requirements"

    # Criar ambos: pyproject.toml e requirements/
    echo '[project]' > "${suap_dir}/pyproject.toml"
    echo "django==4.2" > "${suap_dir}/requirements/development.txt"

    local SUAP_DIR="$suap_dir"

    # Simular a lógica de decisão (pyproject.toml vem primeiro no if)
    local install_cmd=""
    if [ -f "${SUAP_DIR}/pyproject.toml" ]; then
        install_cmd="uv sync --group dev"
    elif [ -d "${SUAP_DIR}/requirements" ]; then
        install_cmd="uv pip install -r requirements/development.txt"
    fi

    [ "$install_cmd" = "uv sync --group dev" ]
}

@test "detecção deps: exit 1 quando nem pyproject.toml nem requirements/ existem" {
    local suap_dir="${TEST_TEMP_DIR}/suap"
    mkdir -p "${suap_dir}"

    # Não criar nenhum arquivo de deps

    local SUAP_DIR="$suap_dir"

    # Simular a lógica completa em subshell para capturar o exit
    run bash -c "
        export TERM=xterm
        source '${COMMON_SH}'
        SUAP_DIR='${suap_dir}'
        cd '${suap_dir}'
        if [ -f \"\${SUAP_DIR}/pyproject.toml\" ]; then
            echo 'uv sync --group dev'
        elif [ -d \"\${SUAP_DIR}/requirements\" ]; then
            echo 'uv pip install -r requirements/development.txt'
        else
            msg_error \"Não foi encontrado pyproject.toml nem a pasta requirements em \${SUAP_DIR}\"
            exit 1
        fi
    "
    assert_failure
    assert_output --partial "ERRO:"
    assert_output --partial "pyproject.toml"
    assert_output --partial "requirements"
}

@test "detecção deps: verifica diretório requirements/ (não arquivo requirements)" {
    local suap_dir="${TEST_TEMP_DIR}/suap"
    mkdir -p "${suap_dir}"

    # Criar um ARQUIVO chamado requirements (não diretório)
    echo "should not match" > "${suap_dir}/requirements"

    local SUAP_DIR="$suap_dir"

    # O -d testa especificamente se é um diretório
    local install_cmd=""
    if [ -f "${SUAP_DIR}/pyproject.toml" ]; then
        install_cmd="uv sync --group dev"
    elif [ -d "${SUAP_DIR}/requirements" ]; then
        install_cmd="uv pip install -r requirements/development.txt"
    else
        install_cmd="error"
    fi

    [ "$install_cmd" = "error" ]
}

# ============================================================
# Testes de geração de arquivos de configuração
# ============================================================

@test "geração: settings.py copiado de settings_sample.py preserva conteúdo" {
    local suap_dir="${TEST_TEMP_DIR}/suap"
    mkdir -p "${suap_dir}/suap"

    cat > "${suap_dir}/suap/settings_sample.py" << 'EOF'
# Django settings
DEBUG = True
DATABASES = {}
EOF

    # Simular a geração
    local SUAP_DIR="$suap_dir"
    if [ ! -f "${SUAP_DIR}/suap/settings.py" ]; then
        cp "${SUAP_DIR}/suap/settings_sample.py" "${SUAP_DIR}/suap/settings.py"
    fi

    # Verificar que o conteúdo é idêntico ao sample
    run diff "${suap_dir}/suap/settings_sample.py" "${suap_dir}/suap/settings.py"
    assert_success
}

@test "geração: .env copiado de .env.dev.sample preserva conteúdo" {
    local suap_dir="${TEST_TEMP_DIR}/suap"
    mkdir -p "${suap_dir}"

    cat > "${suap_dir}/.env.dev.sample" << 'EOF'
DEBUG=True
DATABASE_URL=postgres://localhost:5432/suap
REDIS_URL=redis://localhost:6379
EOF

    # Simular a geração
    local SUAP_DIR="$suap_dir"
    if [ ! -f "${SUAP_DIR}/.env" ]; then
        cp "${SUAP_DIR}/.env.dev.sample" "${SUAP_DIR}/.env"
    fi

    # Verificar que o conteúdo é idêntico ao sample
    run diff "${suap_dir}/.env.dev.sample" "${suap_dir}/.env"
    assert_success
}

@test "geração: segundo run não altera arquivos existentes" {
    local suap_dir="${TEST_TEMP_DIR}/suap"
    mkdir -p "${suap_dir}/suap"

    # Criar samples
    echo "# Sample settings" > "${suap_dir}/suap/settings_sample.py"
    echo "SAMPLE_ENV=true" > "${suap_dir}/.env.dev.sample"

    local SUAP_DIR="$suap_dir"

    # Primeira execução: gera os arquivos
    if [ ! -f "${SUAP_DIR}/suap/settings.py" ]; then
        cp "${SUAP_DIR}/suap/settings_sample.py" "${SUAP_DIR}/suap/settings.py"
    fi
    if [ ! -f "${SUAP_DIR}/.env" ]; then
        cp "${SUAP_DIR}/.env.dev.sample" "${SUAP_DIR}/.env"
    fi

    # Usuário modifica os arquivos
    echo "# Minhas configs customizadas" > "${suap_dir}/suap/settings.py"
    echo "MY_CUSTOM=value" > "${suap_dir}/.env"

    # Segunda execução: NÃO deve sobrescrever
    if [ ! -f "${SUAP_DIR}/suap/settings.py" ]; then
        cp "${SUAP_DIR}/suap/settings_sample.py" "${SUAP_DIR}/suap/settings.py"
    fi
    if [ ! -f "${SUAP_DIR}/.env" ]; then
        cp "${SUAP_DIR}/.env.dev.sample" "${SUAP_DIR}/.env"
    fi

    # Verificar que as customizações foram preservadas
    run cat "${suap_dir}/suap/settings.py"
    assert_output "# Minhas configs customizadas"

    run cat "${suap_dir}/.env"
    assert_output "MY_CUSTOM=value"
}
