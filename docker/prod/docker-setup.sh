#!/usr/bin/env bash
set -u

# docker/prod/docker-setup.sh - Script de setup Docker para produção
# Verifica pré-requisitos, resolve URL do repositório e inicia containers em modo detached.

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

# 5. Executar docker compose up -d --build (modo detached para produção)
msg_action "Iniciando containers Docker de produção..."
docker compose -f "${SCRIPT_DIR}/docker/prod/docker-compose.prod.yml" up -d --build

# 6. Exibir status dos serviços
echo ""
msg_action "=== Status dos Serviços ==="
echo ""
docker compose -f "${SCRIPT_DIR}/docker/prod/docker-compose.prod.yml" ps

# 7. Exibir instruções de gerenciamento dos containers
echo ""
msg_action "=== Ambiente Docker de Produção ==="
echo ""
echo "  Acesso à aplicação:   http://localhost (porta 80)"
echo "  Celery Flower:        http://localhost:5555"
echo ""
echo "  Comandos de gerenciamento:"
echo "    Parar containers:       docker compose -f ${SCRIPT_DIR}/docker/prod/docker-compose.prod.yml down"
echo "    Ver logs:               docker compose -f ${SCRIPT_DIR}/docker/prod/docker-compose.prod.yml logs -f"
echo "    Reiniciar containers:   docker compose -f ${SCRIPT_DIR}/docker/prod/docker-compose.prod.yml restart"
echo "    Escalar workers:        docker compose -f ${SCRIPT_DIR}/docker/prod/docker-compose.prod.yml up -d --scale celery-worker=3"
echo "    Acessar shell do app:   docker compose -f ${SCRIPT_DIR}/docker/prod/docker-compose.prod.yml exec suap bash"
echo ""
