#!/usr/bin/env bash
set -u

# docker/minio-setup.sh - Setup do MinIO (object storage S3-compatível) via Docker
# Delega para o projeto suap-minio, que fornece MinIO + Nginx como proxy.
#
# O suap-minio:
#   - Executa MinIO como container Docker com Nginx na frente
#   - Expõe a API S3 na porta 80 e o console de administração na porta 9001
#   - Gerencia via Makefile com targets: up, stop, down, status, logs, pull, update
#
# Este script automatiza o clone/configuração do suap-minio e delega
# o gerenciamento dos containers para o Makefile dele.

# Determinar diretório raiz do repositório suap-setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Source da biblioteca compartilhada
source "${SCRIPT_DIR}/lib/common.sh"

# 2. Verificar existência do .env
require_env_file "${SCRIPT_DIR}/.env"

# 3. Carregar variáveis do .env centralizado
load_env_file "${SCRIPT_DIR}/.env"

# 4. Verificar se Docker e Docker Compose estão disponíveis
check_docker_available

# 5. Garantir que SUAP_MINIO_DIR está configurado
if [ -z "${SUAP_MINIO_DIR:-}" ]; then
  SUAP_MINIO_DIR="/opt/suap-minio"
fi
SUAP_MINIO_DIR=$(eval echo "${SUAP_MINIO_DIR}")

# 6. Garantir que SUAP_MINIO_GIT_URL está configurado
SUAP_MINIO_GIT_URL="${SUAP_MINIO_GIT_URL:-}"
if [ -z "${SUAP_MINIO_GIT_URL}" ]; then
  msg_error "SUAP_MINIO_GIT_URL não está definido no .env"
  msg_error "Execute setup.sh e escolha a opção 10 para configurar."
  exit 1
fi

# 7. Se SUAP_MINIO_DIR não existe, clonar o repositório
if [ ! -d "${SUAP_MINIO_DIR}" ]; then
  msg_action "Repositório suap-minio não encontrado em ${SUAP_MINIO_DIR}. Clonando..."
  _parent_dir="$(dirname "${SUAP_MINIO_DIR}")"
  # Criar diretório pai se não existir
  if [ ! -d "${_parent_dir}" ]; then
    mkdir -p "${_parent_dir}" 2>/dev/null || sudo mkdir -p "${_parent_dir}"
  fi
  if [ ! -w "${_parent_dir}" ]; then
    sudo chown "${USER}:${USER}" "${_parent_dir}"
  fi
  if ! git clone "${SUAP_MINIO_GIT_URL}" "${SUAP_MINIO_DIR}"; then
    msg_error "Falha ao clonar o repositório suap-minio."
    msg_error "Verifique se você tem acesso a: ${SUAP_MINIO_GIT_URL}"
    exit 1
  fi
  msg_action "Repositório clonado com sucesso em ${SUAP_MINIO_DIR}"
elif [ -d "${SUAP_MINIO_DIR}/.git" ]; then
  msg_skip "Repositório suap-minio já existe em ${SUAP_MINIO_DIR}"
fi

# 8. Verificar que o Makefile existe
if [ ! -f "${SUAP_MINIO_DIR}/Makefile" ]; then
  msg_error "Makefile não encontrado em ${SUAP_MINIO_DIR}."
  msg_error "Verifique se o repositório suap-minio está correto."
  exit 1
fi

# 8.1 Garantir que 'make' está instalado
if ! command -v make &>/dev/null; then
  msg_action "Comando 'make' não encontrado. Instalando..."
  case "${DISTRO_TYPE:-}" in
    deb)
      sudo apt-get update && sudo apt-get install -y make
      ;;
    rpm)
      sudo dnf install -y make
      ;;
    arch)
      sudo pacman -S --needed --noconfirm make
      ;;
    *)
      msg_error "'make' não está instalado e não foi possível instalar automaticamente."
      msg_error "Instale o pacote 'make' manualmente e tente novamente."
      exit 1
      ;;
  esac
  if ! command -v make &>/dev/null; then
    msg_error "Falha ao instalar 'make'. Verifique os erros acima."
    exit 1
  fi
fi

# 9. Configurar .env do suap-minio se não existir
if [ ! -f "${SUAP_MINIO_DIR}/.env" ]; then
  if [ -f "${SUAP_MINIO_DIR}/env.sample" ]; then
    msg_action "Copiando env.sample -> .env em ${SUAP_MINIO_DIR}..."
    cp "${SUAP_MINIO_DIR}/env.sample" "${SUAP_MINIO_DIR}/.env"

    # Solicitar credenciais ao usuário
    echo ""
    echo "${GREEN}=== Configuração do MinIO ===${NO_COLOR}"
    echo ""
    read -rp "Usuário root do MinIO [admin]: " _minio_user
    _minio_user="${_minio_user:-admin}"

    read -srp "Senha root do MinIO (mín. 8 caracteres): " _minio_pass
    echo ""
    if [ ${#_minio_pass} -lt 8 ]; then
      _minio_pass="miniopassword"
      echo "  ${YELLOW}Senha muito curta. Usando valor padrão: miniopassword${NO_COLOR}"
      echo "  ${YELLOW}ALTERE em produção! Edite ${SUAP_MINIO_DIR}/.env${NO_COLOR}"
    fi

    read -rp "URL de redirecionamento do browser (MINIO_BROWSER_REDIRECT_URL) [https://suap.instituicao.edu.br]: " _minio_redirect
    _minio_redirect="${_minio_redirect:-https://suap.instituicao.edu.br}"

    # Atualizar .env com os valores
    sed -i "s|^MINIO_ROOT_USER=.*|MINIO_ROOT_USER=${_minio_user}|" "${SUAP_MINIO_DIR}/.env"
    sed -i "s|^MINIO_ROOT_PASSWORD=.*|MINIO_ROOT_PASSWORD=${_minio_pass}|" "${SUAP_MINIO_DIR}/.env"
    sed -i "s|^MINIO_BROWSER_REDIRECT_URL=.*|MINIO_BROWSER_REDIRECT_URL=${_minio_redirect}|" "${SUAP_MINIO_DIR}/.env"

    msg_action ".env do MinIO configurado."
  else
    msg_error "Arquivo env.sample não encontrado em ${SUAP_MINIO_DIR}."
    msg_error "Crie o .env manualmente antes de prosseguir."
    exit 1
  fi
else
  msg_skip ".env já existe em ${SUAP_MINIO_DIR}"
fi

# 10. Menu de ações
cd "${SUAP_MINIO_DIR}"

echo ""
echo "${GREEN}=== Gerenciamento do MinIO (suap-minio) ===${NO_COLOR}"
echo ""
echo "  Diretório: ${SUAP_MINIO_DIR}"
echo "  API S3:    http://localhost:80"
echo "  Console:   http://localhost:9001"
echo ""
echo "  1) Iniciar MinIO (make up)"
echo "  2) Parar MinIO (make stop)"
echo "  3) Ver status dos containers"
echo "  4) Ver logs"
echo "  5) Atualizar imagem do MinIO (make update)"
echo "  0) Sair"
echo ""
read -rp "Escolha uma opção [0-5]: " MINIO_CHOICE

case "${MINIO_CHOICE}" in
  1)
    msg_action "Iniciando MinIO..."
    make up
    echo ""
    msg_action "MinIO iniciado."
    make status
    echo ""
    echo "  ${GREEN}API S3:${NO_COLOR}   http://localhost:80"
    echo "  ${GREEN}Console:${NO_COLOR}  http://localhost:9001"
    echo ""
    echo "  Próximos passos:"
    echo "    1. Acesse o console e crie os buckets: media, temp"
    echo "    2. Crie um Access Key no console"
    echo "    3. Configure no .env do suap_deploy:"
    echo "       DEFAULT_FILE_STORAGE=djtools.storages.s3.MediaS3Storage"
    echo "       AWS_S3_ENDPOINT_URL=http://<ip-deste-servidor>"
    echo "       AWS_ACCESS_KEY_ID=<access-key>"
    echo "       AWS_SECRET_ACCESS_KEY=<secret-key>"
    ;;
  2)
    msg_action "Parando MinIO..."
    make stop
    msg_action "MinIO parado."
    ;;
  3)
    make status
    ;;
  4)
    make logs
    ;;
  5)
    msg_action "Atualizando imagem do MinIO..."
    make update
    msg_action "MinIO atualizado."
    make status
    ;;
  0)
    echo "Saindo..."
    exit 0
    ;;
  *)
    msg_error "Opção inválida."
    exit 1
    ;;
esac

echo ""
msg_action "=== Comandos úteis (executar dentro de ${SUAP_MINIO_DIR}) ==="
echo ""
echo "  make up              Iniciar MinIO"
echo "  make stop            Parar MinIO"
echo "  make status          Ver status dos containers"
echo "  make logs            Ver logs"
echo "  make update          Atualizar imagem do MinIO"
echo "  make bash            Acessar shell do container MinIO"
echo ""
echo "  Configuração do SUAP (no .env do suap_deploy):"
echo "    DEFAULT_FILE_STORAGE=djtools.storages.s3.MediaS3Storage"
echo "    AWS_S3_ENDPOINT_URL=http://<ip-deste-servidor>"
echo "    AWS_ACCESS_KEY_ID=<sua-access-key>"
echo "    AWS_SECRET_ACCESS_KEY=<sua-secret-key>"
echo ""
