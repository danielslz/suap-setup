#!/usr/bin/env bash
# tests/run_tests.sh - Script auxiliar para execução de testes
# Uso:
#   ./tests/run_tests.sh          # Executa todos os testes (exceto integração)
#   ./tests/run_tests.sh unit     # Apenas testes unitários
#   ./tests/run_tests.sh property # Apenas testes de propriedade
#   ./tests/run_tests.sh smoke    # Apenas testes de fumaça
#   ./tests/run_tests.sh all      # Todos incluindo integração
#
# Dependências (bats-core, bats-support, bats-assert) são resolvidas assim:
#   1. Se estiverem instaladas no sistema (bats no PATH e libs em caminhos
#      padrão), elas são usadas diretamente.
#   2. Caso contrário, são baixadas automaticamente para tests/.cache/
#      (diretório ignorado pelo git) via git clone --depth 1.
# Não há submódulos nem código de terceiros versionado neste repositório.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${SCRIPT_DIR}/.cache"

# Versões fixadas para o bootstrap (usadas apenas quando baixamos as deps).
BATS_CORE_REF="v1.11.0"
BATS_SUPPORT_REF="v0.3.0"
BATS_ASSERT_REF="v2.1.0"

# --- Resolve o executável do bats ---------------------------------------
# Preferência: bats do sistema (PATH). Fallback: clone em tests/.cache/.
resolve_bats() {
    if command -v bats >/dev/null 2>&1; then
        BATS="$(command -v bats)"
        return
    fi

    local core_dir="${CACHE_DIR}/bats-core"
    if [[ ! -x "${core_dir}/bin/bats" ]]; then
        echo "==> bats-core não encontrado no sistema; baixando para ${core_dir}..."
        mkdir -p "${CACHE_DIR}"
        git -c advice.detachedHead=false clone --quiet --depth 1 \
            --branch "${BATS_CORE_REF}" \
            https://github.com/bats-core/bats-core.git "${core_dir}"
    fi
    BATS="${core_dir}/bin/bats"
}

# --- Resolve as bibliotecas auxiliares (support/assert) -----------------
# Define BATS_LIB_PATH com os diretórios onde o bats encontra as libs via
# `bats_load_library`. Procura primeiro em caminhos de sistema conhecidos;
# o que faltar é baixado para tests/.cache/.
resolve_libs() {
    local -a lib_roots=()

    # Caminhos de sistema comuns onde distros/brew instalam as libs.
    local candidate
    for candidate in \
        /usr/lib \
        /usr/local/lib \
        /opt/homebrew/lib \
        "${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}/lib"; do
        if [[ -d "${candidate}/bats-support" && -d "${candidate}/bats-assert" ]]; then
            lib_roots+=("${candidate}")
            break
        fi
    done

    # Se não achou um root de sistema com AMBAS as libs, usa o cache local.
    if [[ ${#lib_roots[@]} -eq 0 ]]; then
        local support_dir="${CACHE_DIR}/bats-support"
        local assert_dir="${CACHE_DIR}/bats-assert"
        mkdir -p "${CACHE_DIR}"
        if [[ ! -f "${support_dir}/load.bash" ]]; then
            echo "==> bats-support não encontrado; baixando para ${support_dir}..."
            git -c advice.detachedHead=false clone --quiet --depth 1 \
                --branch "${BATS_SUPPORT_REF}" \
                https://github.com/bats-core/bats-support.git "${support_dir}"
        fi
        if [[ ! -f "${assert_dir}/load.bash" ]]; then
            echo "==> bats-assert não encontrado; baixando para ${assert_dir}..."
            git -c advice.detachedHead=false clone --quiet --depth 1 \
                --branch "${BATS_ASSERT_REF}" \
                https://github.com/bats-core/bats-assert.git "${assert_dir}"
        fi
        lib_roots+=("${CACHE_DIR}")
    fi

    # BATS_LIB_PATH é a variável nativa do bats para localizar libraries.
    export BATS_LIB_PATH="${lib_roots[0]}${BATS_LIB_PATH:+:${BATS_LIB_PATH}}"
}

resolve_bats
resolve_libs

run() {
    "$BATS" "$@"
}

case "${1:-default}" in
    unit)
        echo "==> Executando testes unitários..."
        run "${SCRIPT_DIR}/unit/"
        ;;
    property)
        echo "==> Executando testes de propriedade..."
        run "${SCRIPT_DIR}/property/"
        ;;
    smoke)
        echo "==> Executando testes de fumaça..."
        run "${SCRIPT_DIR}/smoke/"
        ;;
    integration)
        echo "==> Executando testes de integração..."
        run "${SCRIPT_DIR}/integration/"
        ;;
    all)
        echo "==> Executando todos os testes..."
        run "${SCRIPT_DIR}/unit/" "${SCRIPT_DIR}/property/" "${SCRIPT_DIR}/smoke/" "${SCRIPT_DIR}/integration/"
        ;;
    default)
        echo "==> Executando testes unitários, de propriedade e de fumaça..."
        run "${SCRIPT_DIR}/unit/" "${SCRIPT_DIR}/property/" "${SCRIPT_DIR}/smoke/"
        ;;
    *)
        echo "Uso: $0 [unit|property|smoke|integration|all]"
        exit 1
        ;;
esac
