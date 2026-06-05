#!/usr/bin/env bash
set -u

# Detectar tipo de distribuição
if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO_FAMILY="${ID_LIKE:-$ID}"
else
  echo "Erro: não foi possível detectar a distribuição."
  exit 3
fi

# Determinar tipo de package manager
if echo "$DISTRO_FAMILY" | grep -q "debian"; then
  DISTRO_TYPE="deb"
  DISTRO_NAME="Debian-like"
elif echo "$DISTRO_FAMILY" | grep -qE "rhel|fedora|centos"; then
  DISTRO_TYPE="rpm"
  DISTRO_NAME="RPM-like"
else
  echo "Distribuição não suportada: $DISTRO_FAMILY"
  exit 3
fi

echo "Distribuição detectada: $DISTRO_NAME"
echo "Qual ambiente deseja configurar? (dev/prod)"
read -r ENV

case "${ENV,,}" in
  dev|d)
    SCRIPT="$DISTRO_TYPE/suap-dev.sh"
    ;;
  prod|p)
    SCRIPT="$DISTRO_TYPE/suap-prod.sh"
    ;;
  *)
    echo "Opção inválida: use 'dev' ou 'prod'."
    exit 1
    ;;
esac

if [ -f "$SCRIPT" ]; then
  echo "Executando $SCRIPT..."
  bash "$SCRIPT"
else
  echo "Arquivo '$SCRIPT' não encontrado no diretório atual."
  exit 2
fi
