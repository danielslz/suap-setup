#!/bin/bash
set -u

# rpm/install-postgres.sh - Instalação do PostgreSQL (Fedora/RHEL/CentOS/AlmaLinux)
# Instala o PostgreSQL a partir do repositório oficial PGDG, inicializa o cluster,
# e opcionalmente cria banco/usuário de aplicação para o SUAP.

# --- 1. Source lib/common.sh ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

export DISTRO_TYPE="rpm"

# --- 2. Carregar .env se disponível ---
if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

# Versão do PostgreSQL (padrão: 16)
: "${POSTGRES_VERSION:=16}"

# --- 3. Elevar para root se necessário ---
if [ "$EUID" -ne 0 ]; then
  msg_action "Elevando permissões com sudo..."
  exec sudo bash "$0" "$@"
fi

# --- 4. Verificar se PostgreSQL já está instalado ---
PG_INSTALLED=false
if command -v psql &>/dev/null && systemctl is-active --quiet "postgresql-${POSTGRES_VERSION}" 2>/dev/null; then
  PG_INSTALLED=true
  INSTALLED_VERSION=$(psql --version | grep -oP '\d+' | head -1)
  msg_skip "PostgreSQL ${INSTALLED_VERSION} já está instalado e em execução."
fi

if [ "${PG_INSTALLED}" = "false" ]; then
  # --- 5. Adicionar repositório PGDG ---
  msg_action "Adicionando repositório oficial PostgreSQL (PGDG)..."

  # Detectar versão do EL
  EL_VERSION=$(rpm -E %{rhel} 2>/dev/null || echo "9")
  dnf install -y "https://download.postgresql.org/pub/repos/yum/reporpms/EL-${EL_VERSION}-x86_64/pgdg-redhat-repo-latest.noarch.rpm" 2>/dev/null || true

  # Desabilitar módulo postgresql do sistema (se existir)
  dnf -qy module disable postgresql 2>/dev/null || true

  # --- 6. Instalar pacotes ---
  msg_action "Instalando PostgreSQL ${POSTGRES_VERSION}..."
  if ! dnf install -y "postgresql${POSTGRES_VERSION}-server" "postgresql${POSTGRES_VERSION}-contrib"; then
    msg_error "Falha na instalação do PostgreSQL ${POSTGRES_VERSION}."
    exit 1
  fi

  # --- 7. Inicializar cluster e iniciar serviço ---
  PG_DATADIR="/var/lib/pgsql/${POSTGRES_VERSION}/data"
  if [ ! -f "${PG_DATADIR}/PG_VERSION" ]; then
    msg_action "Inicializando cluster de banco de dados..."
    "/usr/pgsql-${POSTGRES_VERSION}/bin/postgresql-${POSTGRES_VERSION}-setup" initdb
  fi

  systemctl enable "postgresql-${POSTGRES_VERSION}"
  systemctl start "postgresql-${POSTGRES_VERSION}"
  msg_action "PostgreSQL ${POSTGRES_VERSION} instalado e em execução."
fi

# --- 8. Perguntar se deseja criar banco/usuário ---
echo ""
read -rp "Deseja criar o banco de dados e o usuário de aplicação do SUAP? [S/n]: " _criar_banco
_criar_banco="${_criar_banco:-S}"

if [[ ! "${_criar_banco}" =~ ^[sS]$ ]]; then
  echo ""
  msg_action "Instalação do PostgreSQL concluída."
  echo ""
  echo "  Versão:  PostgreSQL ${POSTGRES_VERSION}"
  echo "  Serviço: systemctl status postgresql-${POSTGRES_VERSION}"
  echo "  Porta:   5432"
  echo ""
  exit 0
fi

# --- 9. Coletar dados do banco ---
echo ""
read -rp "Nome do banco de dados [suap]: " _db_name
_db_name="${_db_name:-suap}"

read -rp "Nome do usuário de aplicação [suap_app]: " _db_user
_db_user="${_db_user:-suap_app}"

read -srp "Senha do usuário de aplicação (obrigatória): " _db_pass
echo ""

if [ -z "${_db_pass}" ]; then
  msg_error "A senha do usuário é obrigatória. Abortando."
  exit 1
fi

# --- 10. Garantir locale pt_BR.UTF-8 ---
if ! locale -a 2>/dev/null | grep -q "pt_BR.utf8"; then
  msg_action "Gerando locale pt_BR.UTF-8..."
  localedef -i pt_BR -f UTF-8 pt_BR.UTF-8
fi

# --- 11. Criar usuário e banco ---
msg_action "Criando usuário '${_db_user}' e banco '${_db_name}'..."

sudo -u postgres psql -v ON_ERROR_STOP=1 <<EOF
CREATE USER ${_db_user} WITH PASSWORD '${_db_pass}';
CREATE DATABASE ${_db_name} OWNER ${_db_user} ENCODING 'UTF8' LC_COLLATE 'pt_BR.UTF-8' LC_CTYPE 'pt_BR.UTF-8' TEMPLATE template0;
GRANT ALL PRIVILEGES ON DATABASE ${_db_name} TO ${_db_user};
ALTER DATABASE ${_db_name} SET bytea_output TO 'escape';
EOF

if [ $? -ne 0 ]; then
  msg_error "Falha ao criar o banco/usuário. Verifique se já existem."
  exit 1
fi

# --- 12. Configurar pg_hba.conf ---
PG_HBA="/var/lib/pgsql/${POSTGRES_VERSION}/data/pg_hba.conf"
PG_CONF="/var/lib/pgsql/${POSTGRES_VERSION}/data/postgresql.conf"

if ! grep -q "${_db_user}" "${PG_HBA}" 2>/dev/null; then
  msg_action "Configurando pg_hba.conf para acesso do usuário '${_db_user}'..."
  sed -i "/^# TYPE/a host    ${_db_name}     ${_db_user}     127.0.0.1/32          scram-sha-256" "${PG_HBA}"
  sed -i "/^# TYPE/a host    ${_db_name}     ${_db_user}     ::1/128               scram-sha-256" "${PG_HBA}"
else
  msg_skip "Regra para '${_db_user}' já existe em pg_hba.conf."
fi

# --- 13. Configurar password_encryption ---
if ! grep -q "^password_encryption = scram-sha-256" "${PG_CONF}" 2>/dev/null; then
  msg_action "Configurando password_encryption = scram-sha-256..."
  sed -i "s/^#\?password_encryption.*/password_encryption = scram-sha-256/" "${PG_CONF}"
fi

# --- 14. Perguntar sobre listen_addresses ---
echo ""
echo "Em qual endereço o PostgreSQL deve escutar?"
echo "  1) Apenas localhost (127.0.0.1) — padrão, mais seguro"
echo "  2) Todos os endereços (0.0.0.0) — necessário se o banco estiver em VM separada"
echo ""
read -rp "Escolha [1]: " _listen_choice
_listen_choice="${_listen_choice:-1}"

if [ "${_listen_choice}" = "2" ]; then
  msg_action "Configurando listen_addresses = '*'..."
  sed -i "s/^#\?listen_addresses.*/listen_addresses = '*'/" "${PG_CONF}"
  echo ""
  echo "  ${YELLOW}ATENÇÃO: Configure o firewall para restringir acesso à porta 5432${NO_COLOR}"
  echo "  ${YELLOW}apenas à rede interna dos nós de aplicação.${NO_COLOR}"
  echo ""
fi

# --- 15. Recarregar configuração ---
msg_action "Recarregando configuração do PostgreSQL..."
systemctl reload "postgresql-${POSTGRES_VERSION}"

# --- 16. Resumo final ---
echo ""
msg_action "PostgreSQL configurado com sucesso!"
echo ""
echo "  Versão:    PostgreSQL ${POSTGRES_VERSION}"
echo "  Banco:     ${_db_name}"
echo "  Usuário:   ${_db_user}"
echo "  Porta:     5432"
echo "  Datadir:   /var/lib/pgsql/${POSTGRES_VERSION}/data"
echo "  pg_hba:    ${PG_HBA}"
echo ""
echo "  String de conexão:"
echo "    ${GREEN}postgresql://${_db_user}:<senha>@localhost:5432/${_db_name}${NO_COLOR}"
echo ""
