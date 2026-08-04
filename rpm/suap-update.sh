#!/bin/bash
set -u

# rpm/suap-update.sh - Atualização do SUAP em ambiente de produção (Fedora/RHEL/CentOS)
# Para serviços, atualiza código, opcionalmente executa migrate/collectstatic/sync_permissions,
# corrige permissões e reinicia serviços.

# --- 1. Source lib/common.sh ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- 2. Verificar existência do .env ---
require_env_file "${SCRIPT_DIR}/.env"

# --- 3. Carregar variáveis centralizadas ---
load_env_file "${SCRIPT_DIR}/.env"

# Definir valores padrão de produção (caso não estejam no .env)
: "${BASE_DIR:=/opt}"
: "${SUAP_DIR:=$BASE_DIR/suap}"
: "${VENV_DIR:=$BASE_DIR/venv}"

export DISTRO_TYPE="rpm"

# --- 4. Elevar para root se necessário ---
if [ "$EUID" -ne 0 ]; then
  msg_action "Elevando permissões com sudo..."
  exec sudo bash "$0" "$@"
fi

# --- 5. Parar serviços do Supervisor ---
msg_action "Parando serviços do Supervisor..."
supervisorctl stop all
echo ""
msg_action "Serviços parados com sucesso."

# --- 6. Atualizar código-fonte ---
msg_action "Atualizando código-fonte do SUAP..."
cd "${SUAP_DIR}"
if ! git pull; then
  msg_error "Falha ao atualizar o código (git pull). Reiniciando serviços..."
  supervisorctl start all
  exit 1
fi

# --- 7. Instalar/atualizar dependências Python ---
msg_action "Atualizando dependências Python..."

# Verificar UV disponível
if ! command -v uv &>/dev/null; then
  if [ -x "${HOME}/.cargo/bin/uv" ]; then
    export PATH="${HOME}/.cargo/bin:${PATH}"
  elif [ -x "${HOME}/.local/bin/uv" ]; then
    export PATH="${HOME}/.local/bin:${PATH}"
  elif [ -x "/root/.cargo/bin/uv" ]; then
    export PATH="/root/.cargo/bin:${PATH}"
  elif [ -x "/root/.local/bin/uv" ]; then
    export PATH="/root/.local/bin:${PATH}"
  fi
fi

export UV_PROJECT_ENVIRONMENT="${VENV_DIR}"
if [ -f "${SUAP_DIR}/pyproject.toml" ]; then
  if ! uv sync --group prod; then
    msg_error "Falha na atualização de dependências Python. Reiniciando serviços..."
    supervisorctl start all
    exit 1
  fi
elif [ -d "${SUAP_DIR}/requirements" ]; then
  if ! uv pip install --python "${VENV_DIR}/bin/python" -r requirements/production.txt; then
    msg_error "Falha na atualização de dependências Python. Reiniciando serviços..."
    supervisorctl start all
    exit 1
  fi
else
  msg_error "Não foi encontrado o pyproject.toml nem a pasta requirements em ${SUAP_DIR}"
  msg_error "Reiniciando serviços..."
  supervisorctl start all
  exit 1
fi

# --- 8. Migrate (opcional) ---
echo ""
read -rp "Executar migrate (python manage.py migrate)? [S/n]: " _migrate
_migrate="${_migrate:-S}"
if [[ "${_migrate}" =~ ^[sS]$ ]]; then
  msg_action "Executando migrate..."
  if ! "${VENV_DIR}/bin/python" manage.py migrate; then
    msg_error "O migrate falhou! O banco pode estar em estado inconsistente."
    read -rp "Deseja continuar mesmo assim? [s/N]: " _continuar
    _continuar="${_continuar:-N}"
    if [[ ! "${_continuar}" =~ ^[sS]$ ]]; then
      msg_action "Abortando. Reiniciando serviços..."
      supervisorctl start all
      exit 1
    fi
  fi
else
  msg_skip "Migrate pulado pelo usuário."
fi

# --- 9. Collectstatic (opcional) ---
echo ""
read -rp "Executar collectstatic (python manage.py collectstatic --noinput)? [S/n]: " _collectstatic
_collectstatic="${_collectstatic:-S}"
if [[ "${_collectstatic}" =~ ^[sS]$ ]]; then
  msg_action "Executando collectstatic..."
  "${VENV_DIR}/bin/python" manage.py collectstatic --noinput
else
  msg_skip "Collectstatic pulado pelo usuário."
fi

# --- 10. Sync permissions (opcional) ---
echo ""
read -rp "Executar sync_permissions (python manage.py sync_permissions)? [s/N]: " _sync
_sync="${_sync:-N}"
if [[ "${_sync}" =~ ^[sS]$ ]]; then
  msg_action "Executando sync_permissions..."
  "${VENV_DIR}/bin/python" manage.py sync_permissions
else
  msg_skip "sync_permissions pulado pelo usuário."
fi

# --- 11. Corrigir permissões de arquivos ---
echo ""
# Garantir UID/GID 33 para www-data (Requirement 35)
ensure_www_data_uid_gid
msg_action "Corrigindo permissões de acesso aos arquivos..."
chown -R www-data:www-data "${SUAP_DIR}"
chown -R www-data:www-data "${BASE_DIR}/logs"
chown -R www-data:www-data "${VENV_DIR}"

# --- 12. Reiniciar serviços do Supervisor ---
msg_action "Reiniciando serviços do Supervisor..."
supervisorctl start all

# --- 13. Exibir status e resumo ---
echo ""
msg_action "Status dos serviços:"
supervisorctl status
echo ""
msg_action "Atualização do SUAP concluída com sucesso!"
echo ""
echo "Resumo das ações realizadas:"
echo "  ✓ Serviços parados"
echo "  ✓ Código atualizado (git pull)"
echo "  ✓ Dependências Python atualizadas"
if [[ "${_migrate}" =~ ^[sS]$ ]]; then
  echo "  ✓ Migrate executado"
else
  echo "  - Migrate pulado"
fi
if [[ "${_collectstatic}" =~ ^[sS]$ ]]; then
  echo "  ✓ Collectstatic executado"
else
  echo "  - Collectstatic pulado"
fi
if [[ "${_sync}" =~ ^[sS]$ ]]; then
  echo "  ✓ sync_permissions executado"
else
  echo "  - sync_permissions pulado"
fi
echo "  ✓ Permissões corrigidas"
echo "  ✓ Serviços reiniciados"
echo ""
