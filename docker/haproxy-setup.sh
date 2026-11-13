#!/usr/bin/env bash
set -u

# docker/haproxy-setup.sh - Balanceador HAProxy (Docker Compose) para os nós "app" do suap_deploy.
#
# O stack fica em ${DOCKER_STACKS_DIR:-/opt/docker}/haproxy/ (compose.yaml + haproxy.cfg + .env).
# Rode em um servidor SEM Nginx do suap_deploy (que ocupa 80/443/8080): o HAProxy usa 80 e 443.
# Termina o TLS e envia HTTP puro para a porta 80 dos nós, que devem usar SSL_ENABLED=false.
# O health check consulta /ht/ (200 = healthy; 503 = drain) e exige status 200.
#
# Variáveis (ambiente, .env do suap-setup ou .env do stack):
#   HAPROXY_BACKENDS      Nós, separados por vírgula: host[:porta[:peso]] (ex.: 192.0.2.50:80:3,192.0.2.51:80:1)
#   HAPROXY_SERVER_NAME   Nome do site (cabeçalho Host do health check), ex.: suap.instituicao.edu.br
#   HAPROXY_TLS           true (padrão) termina o TLS em 443; false = somente HTTP em 80
#   HAPROXY_CERT_DIR      Pasta do certificado (padrão: /etc/ssl/suap/haproxy); arquivo suap.pem =
#                         certificado (fullchain) + chave privada concatenados. Ausente: gera autoassinado
#   HAPROXY_HTTP_PORT     (padrão 80)    HAPROXY_HTTPS_PORT (padrão 443)    HAPROXY_STATS_PORT (padrão 8404)
#   HAPROXY_STATS_AUTH    usuario:senha da página de estatísticas (gerada se vazia)
#   HAPROXY_IMAGE         (padrão haproxy:lts-alpine)
#   DOCKER_STACKS_DIR     Base dos stacks (padrão /opt/docker)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${SCRIPT_DIR}/lib/common.sh"

if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

check_docker_available

PROJECT="suap-haproxy"
CONTAINER_NAME="suap-haproxy"

stack_init "haproxy"
stack_env_load HAPROXY_BACKENDS HAPROXY_SERVER_NAME HAPROXY_TLS HAPROXY_CERT_DIR HAPROXY_HTTP_PORT \
  HAPROXY_HTTPS_PORT HAPROXY_STATS_PORT HAPROXY_STATS_AUTH HAPROXY_IMAGE
HAPROXY_IMAGE="${HAPROXY_IMAGE:-haproxy:lts-alpine}"
HAPROXY_TLS="${HAPROXY_TLS:-true}"
HAPROXY_CERT_DIR="${HAPROXY_CERT_DIR:-/etc/ssl/suap/haproxy}"
HAPROXY_HTTP_PORT="${HAPROXY_HTTP_PORT:-80}"
HAPROXY_HTTPS_PORT="${HAPROXY_HTTPS_PORT:-443}"
HAPROXY_STATS_PORT="${HAPROXY_STATS_PORT:-8404}"
HAPROXY_BACKENDS="${HAPROXY_BACKENDS:-}"
HAPROXY_SERVER_NAME="${HAPROXY_SERVER_NAME:-}"
HAPROXY_STATS_AUTH="${HAPROXY_STATS_AUTH:-}"

_valid_port() { [[ "${1}" =~ ^[0-9]+$ ]] && [ "${1}" -ge 1 ] && [ "${1}" -le 65535 ]; }

# --- Entradas obrigatórias ---
if [ -z "${HAPROXY_BACKENDS}" ]; then
  if [ -t 0 ]; then
    echo ""
    echo "${GREEN}=== Configuração do HAProxy ===${NO_COLOR}"
    echo "Informe os nós de aplicação (suap_deploy) como host[:porta[:peso]], separados por vírgula."
    echo "Ex.: 192.0.2.50:80:3,192.0.2.51:80:1  (peso proporcional à capacidade de cada nó)"
    read -rp "Nós: " HAPROXY_BACKENDS
  fi
  if [ -z "${HAPROXY_BACKENDS}" ]; then
    msg_error "HAPROXY_BACKENDS não definido (ex.: HAPROXY_BACKENDS=192.0.2.50:80:3,192.0.2.51:80:1)."
    exit 1
  fi
fi
if [ -z "${HAPROXY_SERVER_NAME}" ]; then
  if [ -t 0 ]; then
    read -rp "Nome do site para o health check (Host) [suap.instituicao.edu.br]: " HAPROXY_SERVER_NAME
    HAPROXY_SERVER_NAME="${HAPROXY_SERVER_NAME:-suap.instituicao.edu.br}"
  else
    msg_error "HAPROXY_SERVER_NAME não definido (ex.: suap.instituicao.edu.br)."
    exit 1
  fi
fi

for _p in "${HAPROXY_HTTP_PORT}" "${HAPROXY_HTTPS_PORT}" "${HAPROXY_STATS_PORT}"; do
  _valid_port "${_p}" || { msg_error "Porta inválida: ${_p}"; exit 1; }
done
case "${HAPROXY_TLS}" in true|false) ;; *) msg_error "HAPROXY_TLS aceita apenas true ou false."; exit 1 ;; esac
[[ "${HAPROXY_SERVER_NAME}" =~ ^[A-Za-z0-9.-]+$ ]] || { msg_error "HAPROXY_SERVER_NAME inválido: ${HAPROXY_SERVER_NAME}"; exit 1; }

# --- Servidores do backend ---
SERVER_LINES=""
_n=0
IFS=',' read -ra _items <<< "${HAPROXY_BACKENDS// /}"
for _it in "${_items[@]}"; do
  [ -z "${_it}" ] && continue
  IFS=':' read -r _h _pt _w _extra <<< "${_it}"
  _pt="${_pt:-80}"; _w="${_w:-1}"
  if [ -n "${_extra:-}" ] || ! [[ "${_h}" =~ ^[A-Za-z0-9.-]+$ ]] || ! _valid_port "${_pt}" \
     || ! [[ "${_w}" =~ ^[0-9]+$ ]] || [ "${_w}" -gt 256 ]; then
    msg_error "Nó inválido: '${_it}' (use host[:porta[:peso 0-256]])."
    exit 1
  fi
  _n=$((_n + 1))
  SERVER_LINES+="    server web${_n} ${_h}:${_pt} weight ${_w}"$'\n'
done
if [ "${_n}" -eq 0 ]; then
  msg_error "Nenhum nó válido em HAPROXY_BACKENDS."
  exit 1
fi

# --- Senha das estatísticas ---
if [ -z "${HAPROXY_STATS_AUTH}" ]; then
  HAPROXY_STATS_AUTH="admin:$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)"
  msg_action "Credencial da página de estatísticas gerada (guardada em ${STACK_ENV})."
fi
[[ "${HAPROXY_STATS_AUTH}" == *:* ]] || { msg_error "HAPROXY_STATS_AUTH deve ser usuario:senha."; exit 1; }

# --- Certificado (TLS) ---
CERT_FILE="${HAPROXY_CERT_DIR}/suap.pem"
if [ "${HAPROXY_TLS}" = "true" ] && [ ! -f "${CERT_FILE}" ]; then
  if ! command -v openssl &>/dev/null; then
    msg_error "Certificado ausente (${CERT_FILE}) e o openssl não está instalado para gerar um autoassinado."
    exit 1
  fi
  msg_skip "Certificado ausente em ${CERT_FILE}: gerando um AUTOASSINADO (substitua por um válido em produção)."
  mkdir -p "${HAPROXY_CERT_DIR}" 2>/dev/null || sudo mkdir -p "${HAPROXY_CERT_DIR}" || exit 1
  _tmp="$(mktemp -d)"
  openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
    -keyout "${_tmp}/key.pem" -out "${_tmp}/crt.pem" \
    -subj "/CN=${HAPROXY_SERVER_NAME}" -addext "subjectAltName=DNS:${HAPROXY_SERVER_NAME}" >/dev/null 2>&1 \
    || { rm -rf "${_tmp}"; msg_error "Falha ao gerar o certificado autoassinado."; exit 1; }
  cat "${_tmp}/crt.pem" "${_tmp}/key.pem" > "${_tmp}/suap.pem"
  if [ -w "${HAPROXY_CERT_DIR}" ]; then
    cp "${_tmp}/suap.pem" "${CERT_FILE}"
  else
    sudo cp "${_tmp}/suap.pem" "${CERT_FILE}" || { rm -rf "${_tmp}"; exit 1; }
  fi
  rm -rf "${_tmp}"
  # O HAProxy do container roda como uid/gid 99: grupo 99 lê, outros não (fallback: 644).
  # 'sudo -n' não pede senha (usa o cache do sudo); sem ele, cai no fallback.
  if ! { chgrp 99 "${CERT_FILE}" 2>/dev/null || sudo -n chgrp 99 "${CERT_FILE}" 2>/dev/null; } \
     || ! { chmod 640 "${CERT_FILE}" 2>/dev/null || sudo -n chmod 640 "${CERT_FILE}" 2>/dev/null; }; then
    chmod 644 "${CERT_FILE}" 2>/dev/null || sudo -n chmod 644 "${CERT_FILE}" 2>/dev/null || true
    msg_skip "Permissão 644 em ${CERT_FILE} (chave legível no host): restrinja o acesso ao diretório (chmod 750) ou rode: sudo chgrp 99 ${CERT_FILE} && sudo chmod 640 ${CERT_FILE}"
  fi
elif [ "${HAPROXY_TLS}" = "true" ]; then
  msg_skip "Usando o certificado existente ${CERT_FILE}"
fi

# --- haproxy.cfg ---
# Redirecionamento HTTP -> HTTPS: com a porta padrão (443) basta trocar o esquema;
# com outra porta é preciso reescrever o Host com a porta HTTPS.
if [ "${HAPROXY_HTTPS_PORT}" = "443" ]; then
  REDIRECT_RULE="http-request redirect scheme https code 301"
else
  REDIRECT_RULE="http-request redirect code 301 location https://%[hdr(host),regsub(:[0-9]+\$,)]:${HAPROXY_HTTPS_PORT}%[capture.req.uri]"
fi
CFG_NEW="$(mktemp)"
chmod 644 "${CFG_NEW}"   # o HAProxy do container (uid 99) precisa ler o arquivo
{
  cat <<'EOF'
# Gerado por suap-setup (docker/haproxy-setup.sh). Não edite: rode o script novamente
# para alterar nós, pesos ou portas (variáveis HAPROXY_*).
global
    log stdout format raw local0
    maxconn 4096
    # O container sobe como root só para abrir as portas 80/443 (privilegiadas) e os workers
    # passam a rodar como o usuário haproxy da imagem.
    user haproxy
    group haproxy

defaults
    mode http
    log global
    option httplog
    option dontlognull
    option forwardfor
    option redispatch 1
    retries 3
    timeout connect 5s
    timeout client 10m
    timeout server 10m

EOF
  if [ "${HAPROXY_TLS}" = "true" ]; then
    cat <<EOF
frontend fe_http
    bind :${HAPROXY_HTTP_PORT}
    ${REDIRECT_RULE}

frontend fe_https
    bind :${HAPROXY_HTTPS_PORT} ssl crt /certs/suap.pem alpn h2,http/1.1
    http-request set-header X-Forwarded-Proto https
    default_backend be_suap
EOF
  else
    cat <<EOF
frontend fe_http
    bind :${HAPROXY_HTTP_PORT}
    default_backend be_suap
EOF
  fi
  cat <<EOF

backend be_suap
    balance leastconn
    option httpchk
    http-check send meth GET uri /ht/ ver HTTP/1.1 hdr Host ${HAPROXY_SERVER_NAME}
    http-check expect status 200
    default-server check inter 10000 fastinter 2000 fall 3 rise 2
${SERVER_LINES}
listen stats
    bind :${HAPROXY_STATS_PORT}
    stats enable
    stats uri /
    stats refresh 5s
    stats auth "\${HAPROXY_STATS_AUTH}"
EOF
} > "${CFG_NEW}"

stack_env_write HAPROXY_IMAGE HAPROXY_BACKENDS HAPROXY_SERVER_NAME HAPROXY_TLS HAPROXY_CERT_DIR \
  HAPROXY_HTTP_PORT HAPROXY_HTTPS_PORT HAPROXY_STATS_PORT HAPROXY_STATS_AUTH || exit 1

# --- SELinux: relabel dos mounts ---
_z=""
if command -v getenforce &>/dev/null && [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
  _z=",z"
fi

cat > "${STACK_FILE}" <<EOF
# Gerado por suap-setup (docker/haproxy-setup.sh). Para alterar valores, edite o
# .env ao lado (ou defina variáveis e rode o script novamente).
name: suap-haproxy
services:
  haproxy:
    image: \${HAPROXY_IMAGE}
    container_name: suap-haproxy
    # root apenas para abrir as portas 80/443: com network_mode host valem as regras do host, onde
    # só o root abre portas < 1024 (a imagem roda como usuário comum por padrão). O haproxy.cfg
    # manda os workers para o usuário haproxy (diretivas user/group).
    user: "0:0"
    network_mode: host
    environment:
      HAPROXY_STATS_AUTH: \${HAPROXY_STATS_AUTH}
    volumes:
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro${_z}
      - \${HAPROXY_CERT_DIR}:/certs:ro${_z}
    restart: unless-stopped
EOF

stack_adopt_legacy "${CONTAINER_NAME}" "${PROJECT}" || { rm -f "${CFG_NEW}"; exit 1; }

# --- Valida a configuração antes de aplicar ---
msg_action "Baixando a imagem ${HAPROXY_IMAGE}..."
docker pull "${HAPROXY_IMAGE}" >/dev/null || { rm -f "${CFG_NEW}"; msg_error "Falha ao baixar ${HAPROXY_IMAGE}."; exit 1; }
msg_action "Validando o haproxy.cfg..."
mkdir -p "${HAPROXY_CERT_DIR}" 2>/dev/null || true
if ! docker run --rm -e HAPROXY_STATS_AUTH="${HAPROXY_STATS_AUTH}" \
     -v "${CFG_NEW}:/usr/local/etc/haproxy/haproxy.cfg:ro${_z}" \
     -v "${HAPROXY_CERT_DIR}:/certs:ro${_z}" \
     "${HAPROXY_IMAGE}" haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg; then
  rm -f "${CFG_NEW}"
  msg_error "Configuração inválida. Nada foi alterado."
  exit 1
fi

CFG_CHANGED=1
[ -f "${STACK_DIR}/haproxy.cfg" ] && cmp -s "${CFG_NEW}" "${STACK_DIR}/haproxy.cfg" && CFG_CHANGED=0
cat "${CFG_NEW}" > "${STACK_DIR}/haproxy.cfg"
chmod 644 "${STACK_DIR}/haproxy.cfg"
rm -f "${CFG_NEW}"

WAS_RUNNING=0
docker ps --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" && WAS_RUNNING=1

msg_action "Subindo o stack HAProxy (${STACK_DIR})..."
if ! stack_compose "${PROJECT}" up -d --remove-orphans; then
  msg_error "Falha ao subir o stack HAProxy."
  exit 1
fi

# Mudança apenas no haproxy.cfg não recria o container: recarrega sem derrubar conexões
if [ "${WAS_RUNNING}" = "1" ] && [ "${CFG_CHANGED}" = "1" ]; then
  msg_action "Configuração alterada: recarregando o HAProxy (SIGHUP)..."
  docker kill --signal=HUP "${CONTAINER_NAME}" >/dev/null || msg_error "Falha ao recarregar; rode: docker restart ${CONTAINER_NAME}"
fi

# --- Autoteste: o container só "estar de pé" não basta (ele pode reiniciar em loop) ---
_hp_logs() { docker logs --tail 15 "${CONTAINER_NAME}" 2>&1 | sed 's/^/      /'; }
_hp_fail() {
  msg_error "$1"
  echo "  Últimas linhas do log do HAProxy:"
  _hp_logs
  if docker logs --tail 40 "${CONTAINER_NAME}" 2>&1 | grep -q "Permission denied"; then
    msg_error "Dica: 'Permission denied' ao abrir a porta indica que o container não está como root (o compose gerado define user: \"0:0\"). Rode este script de novo."
  elif docker logs --tail 40 "${CONTAINER_NAME}" 2>&1 | grep -qiE "Address already in use|cannot bind"; then
    msg_error "Dica: a porta já está em uso por outro serviço neste servidor. Veja quem usa: ss -tlnp | grep -E ':(${HAPROXY_HTTP_PORT}|${HAPROXY_HTTPS_PORT}|${HAPROXY_STATS_PORT})\\b' ; ou mude HAPROXY_HTTP_PORT, HAPROXY_HTTPS_PORT ou HAPROXY_STATS_PORT."
  fi
  exit 1
}

msg_action "Verificando o HAProxy..."
sleep 4
_state="$(docker inspect -f '{{.State.Status}} {{.RestartCount}}' "${CONTAINER_NAME}" 2>/dev/null || echo "ausente 0")"
if [ "${_state%% *}" != "running" ] || [ "${_state##* }" != "0" ]; then
  _hp_fail "O container do HAProxy não está estável (estado: ${_state%% *}, reinícios: ${_state##* })."
fi

_code="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "http://127.0.0.1:${HAPROXY_HTTP_PORT}/" 2>/dev/null || true)"
if [ -z "${_code}" ] || [ "${_code}" = "000" ]; then
  _hp_fail "Nenhuma resposta HTTP em 127.0.0.1:${HAPROXY_HTTP_PORT}."
fi
if [ "${HAPROXY_TLS}" = "true" ]; then
  [ "${_code}" = "301" ] && echo "  [ok]    porta ${HAPROXY_HTTP_PORT}: redireciona para HTTPS (301)" \
    || msg_skip "porta ${HAPROXY_HTTP_PORT} respondeu ${_code} (esperado 301)"
  _tcode="$(curl -sk -o /dev/null -m 8 -w '%{http_code}' "https://127.0.0.1:${HAPROXY_HTTPS_PORT}/" 2>/dev/null || true)"
  if [ -z "${_tcode}" ] || [ "${_tcode}" = "000" ]; then
    _hp_fail "Falha no handshake TLS em 127.0.0.1:${HAPROXY_HTTPS_PORT} (verifique o certificado ${CERT_FILE})."
  fi
  echo "  [ok]    porta ${HAPROXY_HTTPS_PORT}: TLS funcionando (HTTP ${_tcode})"
else
  echo "  [ok]    porta ${HAPROXY_HTTP_PORT}: respondendo (HTTP ${_code})"
fi

# Estado dos nós (o primeiro health check leva até ~14 s)
_stats="http://127.0.0.1:${HAPROXY_STATS_PORT}/;csv"
_down=""
for _i in $(seq 1 10); do
  _csv="$(curl -s -m 5 -u "${HAPROXY_STATS_AUTH}" "${_stats}" 2>/dev/null || true)"
  _down="$(awk -F, '$1=="be_suap" && $2 ~ /^web[0-9]+$/ && $18 !~ /^UP/ {print $2}' <<< "${_csv}" | tr '\n' ' ')"
  _up="$(awk -F, '$1=="be_suap" && $2 ~ /^web[0-9]+$/ && $18 ~ /^UP/ {n++} END {print n+0}' <<< "${_csv}")"
  [ -n "${_csv}" ] && [ -z "${_down}" ] && break
  sleep 2
done
if [ -z "${_csv}" ]; then
  msg_skip "Não consegui ler a página de estatísticas (porta ${HAPROXY_STATS_PORT})."
else
  awk -F, '$1=="be_suap" && $2 ~ /^web[0-9]+$/ {printf "  nó %-6s %s\n", $2, $18}' <<< "${_csv}"
  if [ -n "${_down}" ]; then
    msg_skip "Nó(s) fora do pool: ${_down%% }. O nó responde 200 em /ht/? Teste a partir daqui: curl -i -H 'Host: ${HAPROXY_SERVER_NAME}' http://<ip-do-nó>:<porta>/ht/ (503 = drain; 301 = nó com SSL_ENABLED=true; 400 = Host fora do ALLOWED_HOSTS)."
  fi
fi

msg_action "HAProxy em execução!"
echo ""
echo "  Stack:         ${STACK_DIR}"
if [ "${HAPROXY_TLS}" = "true" ]; then
  echo "  Site:          https://${HAPROXY_SERVER_NAME}  (porta ${HAPROXY_HTTPS_PORT}; ${HAPROXY_HTTP_PORT} redireciona)"
else
  echo "  Site:          http://${HAPROXY_SERVER_NAME}  (porta ${HAPROXY_HTTP_PORT})"
fi
echo "  Estatísticas:  http://<ip-deste-servidor>:${HAPROXY_STATS_PORT}/   (usuário/senha em ${STACK_ENV})"
echo "  Nós:           ${HAPROXY_BACKENDS}"
echo ""
echo "  Nos nós do suap_deploy: SSL_ENABLED=false e TRUSTED_PROXIES=<ip deste servidor>."
echo "  Libere ${HAPROXY_HTTP_PORT}/${HAPROXY_HTTPS_PORT} para os clientes; restrinja ${HAPROXY_STATS_PORT} à rede interna."
echo ""
