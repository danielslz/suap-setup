#!/usr/bin/env bash
set -u

# docker/dev/docker-setup.sh - Script de setup Docker para desenvolvimento
# Verifica pré-requisitos, resolve URL do repositório e inicia containers.

# Determinar diretório raiz do repositório (dois níveis acima deste script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# 1. Source da biblioteca compartilhada
source "${SCRIPT_DIR}/lib/common.sh"

# 2. Carregar variáveis do .env centralizado
load_env_file "${SCRIPT_DIR}/.env"

# 3. Verificar se Docker e Docker Compose estão disponíveis
check_docker_available

# 4. Garantir que GIT_URL está configurada
resolve_git_url "${SCRIPT_DIR}/.env"

# 5. Executar docker compose up --build
msg_action "Iniciando containers Docker de desenvolvimento..."
docker compose -f "${SCRIPT_DIR}/docker/dev/docker-compose.yml" up --build

# 6. Exibir mensagem com URL de acesso e comandos úteis
echo ""
msg_action "=== Ambiente Docker de Desenvolvimento ==="
echo ""
echo "  Acesso à aplicação: http://localhost:8000"
echo "  PostgreSQL:          localhost:5432 (usuário: suap, senha: suap, banco: suap)"
echo "  Redis:               localhost:6379"
echo ""
echo "  Comandos úteis:"
echo "    Parar containers:      docker compose -f ${SCRIPT_DIR}/docker/dev/docker-compose.yml down"
echo "    Ver logs:              docker compose -f ${SCRIPT_DIR}/docker/dev/docker-compose.yml logs -f"
echo "    Reiniciar containers:  docker compose -f ${SCRIPT_DIR}/docker/dev/docker-compose.yml restart"
echo "    Acessar shell do app:  docker compose -f ${SCRIPT_DIR}/docker/dev/docker-compose.yml exec suap bash"
echo ""
