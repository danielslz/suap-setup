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
echo ""
echo "O que você deseja fazer?"
echo "1) Configurar ambiente dev do SUAP"
echo "2) Configurar ambiente prod do SUAP"
echo "3) Instalar Redis"
echo "4) Instalar Nginx"
read -r CHOICE

case "${CHOICE}" in
  1)
    SCRIPT="$DISTRO_TYPE/suap-dev.sh"
    if [ -f "$SCRIPT" ]; then
      echo "Executando $SCRIPT..."
      bash "$SCRIPT"
    else
      echo "Arquivo '$SCRIPT' não encontrado no diretório atual."
      exit 2
    fi
    ;;
  2)
    SCRIPT="$DISTRO_TYPE/suap-prod.sh"
    if [ -f "$SCRIPT" ]; then
      echo "Executando $SCRIPT..."
      sudo bash "$SCRIPT"
    else
      echo "Arquivo '$SCRIPT' não encontrado no diretório atual."
      exit 2
    fi
    ;;
  3)
    REDIS_SCRIPT="$DISTRO_TYPE/install-redis.sh"
    if [ -f "$REDIS_SCRIPT" ]; then
      echo "Executando $REDIS_SCRIPT..."
      bash "$REDIS_SCRIPT"
    else
      echo "Arquivo '$REDIS_SCRIPT' não encontrado no diretório atual."
      exit 2
    fi
    ;;
  4)
    NGINX_SCRIPT="$DISTRO_TYPE/install-nginx.sh"
    if [ -f "$NGINX_SCRIPT" ]; then
      echo "Executando $NGINX_SCRIPT..."
      bash "$NGINX_SCRIPT"
    else
      echo "Arquivo '$NGINX_SCRIPT' não encontrado no diretório atual."
      exit 2
    fi
    ;;
  *)
    echo "Opção inválida: use 1, 2, 3 ou 4."
    exit 1
    ;;
esac
