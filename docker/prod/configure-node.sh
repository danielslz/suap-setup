#!/usr/bin/env bash
set -u

# docker/prod/configure-node.sh - Configura o PAPEL de um nó do suap_deploy
# (multi-servidor / multi-nó) editando o .env do suap_deploy de forma segura.
#
# O que faz:
#   - define COMPOSE_PROFILES conforme o papel do nó;
#   - aponta DATABASE_* e REDIS/CELERY/SESSION para o DB e o Redis externos;
#   - liga/desliga SSL_ENABLED e atualiza o symlink do nginx;
#   - ajusta SITE_URL/NGINX_SERVER_NAME/ALLOWED_HOSTS, TRUSTED_PROXIES e DRAIN_SECONDS;
#   - configura storage S3/MinIO e a senha do Flower.
# Sempre faz backup do .env (.env.bak-<data>) antes de alterar e mostra o que mudou.
#
# Uso interativo:      bash docker/prod/configure-node.sh
# Uso não interativo:  bash docker/prod/configure-node.sh --role app --db-host 10.0.1.5 --yes
# Ajuda:               bash docker/prod/configure-node.sh --help

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

DEPLOY_DIR="$(resolve_suap_deploy_dir)"
ENV_FILE="${DEPLOY_DIR}/.env"

usage() {
  cat <<'EOF'
configure-node.sh - configura o papel de um nó do suap_deploy

Papéis (--role):
  single         Nó único: tudo junto                     default,celery-beat,celery-flower
  full           Nó completo SEM beat/flower              default
                 (web + nginx + pdfprinter + celery)
  web-beat       Web + beat + flower (UM nó do cluster)   web,celery-beat,celery-flower
  web-celery-beat Web + workers + beat + flower (UM nó)   web,celery,celery-beat,celery-flower
  app            Servidor de aplicação (web + nginx)      web
  async-primary  Async com beat/flower/pdfprinter (UM nó) celery,celery-beat,celery-flower,pdfprinter
  async          Async adicional (somente workers)        celery
  homolog        Homologação com DB/Redis em container    default,celery-beat,celery-flower,local-db,local-redis
  custom         Lista própria via --profiles

Opções:
  --role <papel>            Papel do nó
  --profiles <lista>        Profiles separados por vírgula (com --role custom)
  --db-host <host>          Servidor PostgreSQL (padrão do compose: host.docker.internal)
  --db-port <porta>         Porta do PostgreSQL
  --db-name <nome>          Nome do banco
  --db-user <usuário>       Usuário do banco
  --redis-host <host>       Servidor Redis (sobrescreve REDIS_URL, REDIS_LOCATION,
                            SESSION_LOCATION, CELERY_BROKER_URL e CELERY_RESULT_BACKEND).
                            Com senha, o Celery recebe redis://:SENHA@host:porta/1 (a senha
                            vai na URL, codificada); o Django usa REDIS_PASSWORD/SESSION_PASSWORD
  --redis-port <porta>      Porta do Redis (padrão 6379)
  --ssl <true|false>        SSL_ENABLED + template do nginx (use false atrás de balanceador)
  --site-url <url>          SITE_URL (ajusta NGINX_SERVER_NAME e MESCLA o host em ALLOWED_HOSTS: mantém
                            as entradas atuais e garante localhost, 127.0.0.1, web e nginx — os dois
                            últimos são os hosts dos health checks dos containers)
  --trusted-proxies <ips>   TRUSTED_PROXIES (IP/CIDR do balanceador)
  --drain-seconds <n>       DRAIN_SECONDS (>= tempo que o balanceador leva para tirar o nó)
  --s3-endpoint <url>       Usa MinIO/S3 como storage de mídia (AWS_S3_ENDPOINT_URL)
  --s3-access-key <chave>   AWS_ACCESS_KEY_ID
  --flower-auth <u:senha>   FLOWER_BASIC_AUTH
  --yes                     Não pergunta; aplica só o que foi informado nas opções
  --dry-run                 Mostra as alterações sem gravar
  -h, --help                Esta ajuda

Senhas NÃO são aceitas por argumento (ficariam no histórico do shell). Informe pelo
prompt silencioso ou pelas variáveis de ambiente:
  NODE_DB_PASSWORD, NODE_REDIS_PASSWORD, NODE_S3_SECRET_KEY

Sem opções e em terminal interativo, o script pergunta cada item mostrando o valor atual.
EOF
}

# --- Parse de argumentos ---
ROLE=""; PROFILES_ARG=""
DB_HOST=""; DB_PORT=""; DB_NAME=""; DB_USER=""
REDIS_HOST=""; REDIS_PORT=""
SSL=""; SITE_URL_ARG=""; TRUSTED=""; DRAIN=""
S3_ENDPOINT=""; S3_ACCESS=""; FLOWER=""
ASSUME_YES=0; DRY_RUN=0; ANY_OPT=0

while [ "$#" -gt 0 ]; do
  case "${1}" in
    -h|--help) usage; exit 0 ;;
    --yes) ASSUME_YES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --role|--profiles|--db-host|--db-port|--db-name|--db-user|--redis-host|--redis-port|--ssl|--site-url|--trusted-proxies|--drain-seconds|--s3-endpoint|--s3-access-key|--flower-auth)
      if [ "$#" -lt 2 ]; then msg_error "A opção ${1} exige um valor."; exit 1; fi
      ANY_OPT=1
      case "${1}" in
        --role) ROLE="${2}" ;;
        --profiles) PROFILES_ARG="${2}" ;;
        --db-host) DB_HOST="${2}" ;;
        --db-port) DB_PORT="${2}" ;;
        --db-name) DB_NAME="${2}" ;;
        --db-user) DB_USER="${2}" ;;
        --redis-host) REDIS_HOST="${2}" ;;
        --redis-port) REDIS_PORT="${2}" ;;
        --ssl) SSL="${2}" ;;
        --site-url) SITE_URL_ARG="${2}" ;;
        --trusted-proxies) TRUSTED="${2}" ;;
        --drain-seconds) DRAIN="${2}" ;;
        --s3-endpoint) S3_ENDPOINT="${2}" ;;
        --s3-access-key) S3_ACCESS="${2}" ;;
        --flower-auth) FLOWER="${2}" ;;
      esac
      shift
      ;;
    *) msg_error "Opção desconhecida: ${1}"; echo ""; usage; exit 1 ;;
  esac
  shift
done

# --- Pré-requisitos ---
if [ ! -f "${DEPLOY_DIR}/Makefile" ]; then
  msg_error "suap_deploy não encontrado em ${DEPLOY_DIR}."
  msg_error "Rode 'bash docker/prod/docker-setup.sh' primeiro ou defina SUAP_DEPLOY_DIR no .env."
  exit 1
fi
if [ ! -f "${ENV_FILE}" ]; then
  msg_error "Arquivo ${ENV_FILE} não encontrado. Rode 'make setup' (bash docker/prod/suap-deploy.sh setup) antes."
  exit 1
fi

INTERACTIVE=0
if [ "${ANY_OPT}" = "0" ] && [ "${ASSUME_YES}" = "0" ] && [ -t 0 ]; then
  INTERACTIVE=1
fi

# --- Helpers ---
_get() {
  local val
  val="$(grep -E "^${1}=" "${ENV_FILE}" | tail -n1 | cut -d= -f2-)"
  val="${val%\"}"; val="${val#\"}"; val="${val%\'}"; val="${val#\'}"
  printf '%s' "${val}"
}

# Alterações pendentes: arrays paralelos chave/valor (ordem de aplicação)
CHG_KEYS=()
CHG_VALS=()
_set() {
  local key="${1}" val="${2}"
  if [[ "${val}" == *$'\n'* ]]; then
    msg_error "Valor inválido para ${key} (quebra de linha)."
    exit 1
  fi
  # Segredos vão para um .env lido pelo make e pelo docker compose: evite caracteres
  # que eles interpretam ($ para interpolação, # para comentário, aspas, espaços).
  case "${key}" in
    *PASSWORD*|*SECRET*|FLOWER_BASIC_AUTH)
      if [[ "${val}" =~ [[:space:]\$\#\'\"\`\\] ]]; then
        msg_error "O valor de ${key} não pode conter espaço, \$, #, aspas, crase ou barra invertida (o make/compose os interpretariam)."
        exit 1
      fi
      ;;
  esac
  CHG_KEYS+=("${key}")
  CHG_VALS+=("${val}")
}

# _pending <chave> -> valor pendente mais recente (ou vazio)
_pending() {
  local i val=""
  for i in "${!CHG_KEYS[@]}"; do
    [ "${CHG_KEYS[$i]}" = "${1}" ] && val="${CHG_VALS[$i]}"
  done
  printf '%s' "${val}"
}

_ask() {
  # _ask <rótulo> <atual> -> imprime a resposta (ou o atual)
  local label="${1}" current="${2}" ans
  read -rp "  ${label} [${current}]: " ans >&2
  printf '%s' "${ans:-${current}}"
}

_ask_secret() {
  local label="${1}" ans
  read -srp "  ${label} (Enter mantém o atual): " ans >&2
  echo "" >&2
  printf '%s' "${ans}"
}

_mask() {
  case "${1}" in
    *PASSWORD*|*SECRET*|*FLOWER*|SECRET_KEY|*TOKEN*) echo "********" ;;
    # URLs com credenciais (redis://:senha@host): oculta o trecho antes do @
    *) printf '%s' "${2}" | sed -E 's#(://)[^/@]*@#\1***@#' ;;
  esac
}

# _urlencode <texto>: codifica para uso em userinfo de URL (senha com @ : / % etc.)
_urlencode() {
  local LC_ALL=C s="${1}" out="" c h i
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    case "${c}" in
      [a-zA-Z0-9.~_-]) out+="${c}" ;;
      *) printf -v h '%%%02X' "'${c}"; out+="${h}" ;;
    esac
  done
  printf '%s' "${out}"
}

_profiles_for_role() {
  case "${1}" in
    single)        echo "default,celery-beat,celery-flower" ;;
    full)          echo "default" ;;
    web-beat)      echo "web,celery-beat,celery-flower" ;;
    web-celery-beat) echo "web,celery,celery-beat,celery-flower" ;;
    app)           echo "web" ;;
    async-primary) echo "celery,celery-beat,celery-flower,pdfprinter" ;;
    async)         echo "celery" ;;
    homolog)       echo "default,celery-beat,celery-flower,local-db,local-redis" ;;
    *) return 1 ;;
  esac
}

# Host do Redis atual (extraído de REDIS_URL)
_redis_host_now() {
  local u
  u="$(_get REDIS_URL)"; u="${u#*://}"; u="${u#*@}"; u="${u%%/*}"
  printf '%s' "${u%%:*}"
}

# _merge_allowed_hosts <host-do-site> <ALLOWED_HOSTS atual>
# Mantém as entradas existentes (exceto o valor de exemplo do env.sample), acrescenta o host do
# site e garante os hosts que os health checks do compose usam (web:8000 e nginx:80). Sem eles o
# Django responde 400 (DisallowedHost) ao health check, o web fica unhealthy e o nginx não sobe.
# Se a lista já tem "*", ela é mantida como está.
_merge_allowed_hosts() {
  local host="${1}" cur="${2// /}" out="" h
  if [[ ",${cur}," == *,'*',* ]]; then printf '%s' "${cur}"; return; fi
  local -a items=()
  IFS=',' read -ra _cur_items <<< "${cur}"
  [[ ",${cur}," == *",${host},"* ]] || items+=("${host}")
  for h in "${_cur_items[@]}"; do
    [ -z "${h}" ] && continue
    [ "${h}" = "suap.minhainstituicao.edu.br" ] && continue
    items+=("${h}")
  done
  items+=(localhost 127.0.0.1 web nginx)
  for h in "${items[@]}"; do
    [[ ",${out}," == *",${h},"* ]] || out+="${out:+,}${h}"
  done
  printf '%s' "${out}"
}

_valid_port() { [[ "${1}" =~ ^[0-9]+$ ]] && [ "${1}" -ge 1 ] && [ "${1}" -le 65535 ]; }

# --- Coleta interativa ---
if [ "${INTERACTIVE}" = "1" ]; then
  echo ""
  echo "${GREEN}=== Configuração do nó (suap_deploy: ${DEPLOY_DIR}) ===${NO_COLOR}"
  echo "Enter mantém o valor atual entre colchetes."
  echo ""
  echo "Papéis: single | full | web-beat | web-celery-beat | app | async-primary | async | homolog | custom"
  ROLE="$(_ask "Papel deste nó" "single")"
  if [ "${ROLE}" = "custom" ]; then
    PROFILES_ARG="$(_ask "Profiles (separados por vírgula)" "$(_get COMPOSE_PROFILES)")"
  fi
  if [ "${ROLE}" != "homolog" ]; then
    echo ""
    echo "Banco de dados e Redis (deixe como está para usar host.docker.internal = este servidor)"
    DB_HOST="$(_ask "Servidor PostgreSQL" "$(_get DATABASE_HOST)")"
    DB_PORT="$(_ask "Porta do PostgreSQL" "$(_get DATABASE_PORT)")"
    DB_NAME="$(_ask "Nome do banco" "$(_get DATABASE_NAME)")"
    DB_USER="$(_ask "Usuário do banco" "$(_get DATABASE_USER)")"
    NODE_DB_PASSWORD="${NODE_DB_PASSWORD:-$(_ask_secret "Senha do banco")}"
    REDIS_HOST="$(_ask "Servidor Redis" "$(_redis_host_now)")"
    REDIS_PORT="$(_ask "Porta do Redis" "6379")"
    NODE_REDIS_PASSWORD="${NODE_REDIS_PASSWORD:-$(_ask_secret "Senha do Redis")}"
  fi
  echo ""
  SSL="$(_ask "SSL_ENABLED (true no nó único; false atrás de balanceador que termina o TLS)" "$(_get SSL_ENABLED)")"
  SITE_URL_ARG="$(_ask "SITE_URL" "$(_get SITE_URL)")"
  if [ "${ROLE}" = "app" ] || [ "${ROLE}" = "single" ] || [ "${ROLE}" = "full" ] || [ "${ROLE}" = "web-beat" ] || [ "${ROLE}" = "web-celery-beat" ]; then
    TRUSTED="$(_ask "TRUSTED_PROXIES (IP/CIDR do balanceador)" "$(_get TRUSTED_PROXIES)")"
    DRAIN="$(_ask "DRAIN_SECONDS" "$(_get DRAIN_SECONDS)")"
  fi
  case "${ROLE}" in
    single|web-beat|web-celery-beat|async-primary|homolog)
      FLOWER="$(_ask "FLOWER_BASIC_AUTH (usuario:senha)" "$(_get FLOWER_BASIC_AUTH)")"
      ;;
  esac
fi

# --- Montagem das alterações ---
if [ -n "${ROLE}" ]; then
  if [ "${ROLE}" = "custom" ]; then
    if [ -z "${PROFILES_ARG}" ]; then msg_error "--role custom exige --profiles."; exit 1; fi
    _set COMPOSE_PROFILES "${PROFILES_ARG}"
  elif p="$(_profiles_for_role "${ROLE}")"; then
    _set COMPOSE_PROFILES "${p}"
  else
    msg_error "Papel inválido: ${ROLE} (use single, full, web-beat, web-celery-beat, app, async-primary, async, homolog ou custom)."
    exit 1
  fi
elif [ -n "${PROFILES_ARG}" ]; then
  _set COMPOSE_PROFILES "${PROFILES_ARG}"
fi

[ -n "${DB_HOST}" ] && _set DATABASE_HOST "${DB_HOST}"
if [ -n "${DB_PORT}" ]; then
  _valid_port "${DB_PORT}" || { msg_error "Porta do PostgreSQL inválida: ${DB_PORT}"; exit 1; }
  _set DATABASE_PORT "${DB_PORT}"
fi
[ -n "${DB_NAME}" ] && _set DATABASE_NAME "${DB_NAME}"
[ -n "${DB_USER}" ] && _set DATABASE_USER "${DB_USER}"
[ -n "${NODE_DB_PASSWORD:-}" ] && _set DATABASE_PASSWORD "${NODE_DB_PASSWORD}"

# Redis: o Django lê a senha de REDIS_PASSWORD/SESSION_PASSWORD (variáveis separadas),
# mas o Celery só conhece CELERY_BROKER_URL e CELERY_RESULT_BACKEND: a senha precisa
# estar DENTRO da URL, no formato redis://:SENHA@host:porta/db (note o ":" antes da senha).
_redis_pw="${NODE_REDIS_PASSWORD:-}"
[ -z "${_redis_pw}" ] && _redis_pw="$(_get REDIS_PASSWORD)"

if [ -n "${REDIS_PORT}" ] && [ -z "${REDIS_HOST}" ]; then
  msg_error "--redis-port exige --redis-host."
  exit 1
fi

_rhost="${REDIS_HOST}"; _rport="${REDIS_PORT:-}"
if [ -z "${_rhost}" ] && [ -n "${NODE_REDIS_PASSWORD:-}" ]; then
  # Nova senha sem novo host: reaproveita host e porta atuais de REDIS_URL
  _cur="$(_get REDIS_URL)"; _cur="${_cur#*://}"; _cur="${_cur#*@}"; _cur="${_cur%%/*}"
  _rhost="${_cur%%:*}"
  [[ "${_cur}" == *:* ]] && _rport="${_cur##*:}"
fi
_rport="${_rport:-6379}"

if [ -n "${_rhost}" ]; then
  _valid_port "${_rport}" || { msg_error "Porta do Redis inválida: ${_rport}"; exit 1; }
  _base="redis://${_rhost}:${_rport}"
  _auth=""
  [ -n "${_redis_pw}" ] && _auth=":$(_urlencode "${_redis_pw}")@"
  _cbase="redis://${_auth}${_rhost}:${_rport}"
  if [ -n "${REDIS_HOST}" ]; then
    _set REDIS_URL "${_base}/2"
    _set REDIS_LOCATION "${_base}/2"
    _set SESSION_LOCATION "${_base}/3"
  fi
  _set CELERY_BROKER_URL "${_cbase}/1"
  _set CELERY_RESULT_BACKEND "${_cbase}/1"
fi
if [ -n "${NODE_REDIS_PASSWORD:-}" ]; then
  _set REDIS_PASSWORD "${NODE_REDIS_PASSWORD}"
  _set SESSION_PASSWORD "${NODE_REDIS_PASSWORD}"
fi

SSL_CHANGE=""
if [ -n "${SSL}" ]; then
  case "${SSL}" in
    true|false) _set SSL_ENABLED "${SSL}"; SSL_CHANGE="${SSL}" ;;
    *) msg_error "--ssl aceita apenas true ou false."; exit 1 ;;
  esac
fi

if [ -n "${SITE_URL_ARG}" ]; then
  _host="${SITE_URL_ARG#*://}"; _host="${_host%%/*}"; _host="${_host%%:*}"
  if [ -z "${_host}" ]; then msg_error "SITE_URL inválida: ${SITE_URL_ARG}"; exit 1; fi
  _set SITE_URL "${SITE_URL_ARG}"
  _set NGINX_SERVER_NAME "${_host}"
  _set ALLOWED_HOSTS "$(_merge_allowed_hosts "${_host}" "$(_get ALLOWED_HOSTS)")"
fi

[ -n "${TRUSTED}" ] && _set TRUSTED_PROXIES "${TRUSTED}"
if [ -n "${DRAIN}" ]; then
  [[ "${DRAIN}" =~ ^[0-9]+$ ]] || { msg_error "--drain-seconds deve ser inteiro."; exit 1; }
  _set DRAIN_SECONDS "${DRAIN}"
fi

if [ -n "${S3_ENDPOINT}" ]; then
  _set DEFAULT_FILE_STORAGE "djtools.storages.s3.MediaS3Storage"
  _set AWS_S3_ENDPOINT_URL "${S3_ENDPOINT}"
  [ -n "${S3_ACCESS}" ] && _set AWS_ACCESS_KEY_ID "${S3_ACCESS}"
  [ -n "${NODE_S3_SECRET_KEY:-}" ] && _set AWS_SECRET_ACCESS_KEY "${NODE_S3_SECRET_KEY}"
fi

if [ -n "${FLOWER}" ]; then
  [[ "${FLOWER}" == *:* ]] || { msg_error "--flower-auth deve ser no formato usuario:senha."; exit 1; }
  _set FLOWER_BASIC_AUTH "${FLOWER}"
fi

# --- Filtrar o que realmente muda ---
APPLY_KEYS=()
APPLY_VALS=()
for i in "${!CHG_KEYS[@]}"; do
  k="${CHG_KEYS[$i]}"
  v="$(_pending "${k}")"
  # Evita duplicatas (o valor pendente mais recente prevalece)
  dup=0
  for a in "${APPLY_KEYS[@]+"${APPLY_KEYS[@]}"}"; do [ "${a}" = "${k}" ] && dup=1; done
  [ "${dup}" = "1" ] && continue
  if [ "$(_get "${k}")" != "${v}" ]; then
    APPLY_KEYS+=("${k}")
    APPLY_VALS+=("${v}")
  fi
done

if [ "${#APPLY_KEYS[@]}" -eq 0 ] && [ -z "${SSL_CHANGE}" ]; then
  msg_skip "Nada a alterar: o .env já está com os valores informados."
  exit 0
fi

echo ""
echo "${GREEN}Alterações em ${ENV_FILE}:${NO_COLOR}"
for i in "${!APPLY_KEYS[@]}"; do
  k="${APPLY_KEYS[$i]}"
  printf '  %-26s %s  ->  %s\n' "${k}" "$(_mask "${k}" "$(_get "${k}")")" "$(_mask "${k}" "${APPLY_VALS[$i]}")"
done
[ -n "${SSL_CHANGE}" ] && echo "  (symlink do nginx será ajustado conforme SSL_ENABLED=${SSL_CHANGE})"

# --- Avisos de coerência ---
_final_profiles="$(_pending COMPOSE_PROFILES)"; _final_profiles="${_final_profiles:-$(_get COMPOSE_PROFILES)}"
_final_ssl="${SSL_CHANGE:-$(_get SSL_ENABLED)}"
echo ""
if [[ ",${_final_profiles}," == *,web,* && "${_final_ssl}" = "true" ]]; then
  msg_skip "Atenção: nó 'web' com SSL_ENABLED=true. Atrás de balanceador que termina o TLS use --ssl false (o health check na porta 80 receberia 301)."
fi
if [[ ",${_final_profiles}," == *,celery-beat,* ]]; then
  msg_skip "Lembrete: celery-beat deve rodar em UM único nó do cluster (duplicar executa tarefas agendadas 2x)."
fi
if [[ ",${_final_profiles}," == *,celery-flower,* ]]; then
  _fl="$(_pending FLOWER_BASIC_AUTH)"; _fl="${_fl:-$(_get FLOWER_BASIC_AUTH)}"
  [ "${_fl}" = "admin:senha" ] && msg_skip "Atenção: FLOWER_BASIC_AUTH ainda no valor padrão (admin:senha). Troque com --flower-auth."
fi

if [ "${DRY_RUN}" = "1" ]; then
  msg_skip "Dry-run: nada foi gravado."
  exit 0
fi

if [ "${INTERACTIVE}" = "1" ]; then
  read -rp "Aplicar as alterações? [s/N]: " _ok
  [[ "${_ok:-N}" =~ ^[sS]$ ]] || { msg_skip "Cancelado. Nada foi alterado."; exit 0; }
fi

# --- Aplicar ---
_backup="${ENV_FILE}.bak-$(date +%Y%m%d-%H%M%S)"
cp -p "${ENV_FILE}" "${_backup}"
msg_action "Backup do .env em ${_backup}"

# Mesma semântica do set_env_var do setup.sh do suap_deploy: troca (ou descomenta) a chave; senão acrescenta.
_write() {
  local key="${1}" val="${2}" esc
  esc="$(printf '%s' "${val}" | sed -e 's/[\/&|\\]/\\&/g')"
  if grep -qE "^#?[[:space:]]*${key}=" "${ENV_FILE}"; then
    sed -i -E "s|^#?[[:space:]]*${key}=.*|${key}=${esc}|" "${ENV_FILE}"
  else
    printf '%s=%s\n' "${key}" "${val}" >> "${ENV_FILE}"
  fi
}
for i in "${!APPLY_KEYS[@]}"; do
  _write "${APPLY_KEYS[$i]}" "${APPLY_VALS[$i]}"
done
chmod 600 "${ENV_FILE}" 2>/dev/null || true

if [ -n "${SSL_CHANGE}" ]; then
  mkdir -p "${DEPLOY_DIR}/nginx/active"
  if [ "${SSL_CHANGE}" = "true" ]; then
    ln -sfn "../templates/30-https.conf.template" "${DEPLOY_DIR}/nginx/active/server.conf.template"
    msg_action "nginx: ativado 30-https.conf.template"
    if [ ! -f /etc/ssl/suap/nginx/fullchain.crt ]; then
      msg_skip "Certificado ausente em /etc/ssl/suap/nginx/. Coloque fullchain.crt e privkey.key (ou: sudo ${DEPLOY_DIR}/scripts/gen-cert.sh para um autoassinado)."
    fi
  else
    ln -sfn "../templates/20-http.conf.template" "${DEPLOY_DIR}/nginx/active/server.conf.template"
    msg_action "nginx: ativado 20-http.conf.template"
  fi
fi

msg_action "Configuração do nó aplicada."

# Serviços que saíram dos profiles continuam rodando até serem removidos: o 'down'/'up' só
# enxerga os profiles ativos. beat/flower duplicados executam tarefas agendadas 2x.
if command -v docker &>/dev/null; then
  for _svc in celery-beat celery-flower; do
    if [[ ",$(_get COMPOSE_PROFILES)," != *",${_svc},"* ]] && \
       [ -n "$(docker ps -q --filter "label=com.docker.compose.service=${_svc}" \
               --filter "label=com.docker.compose.project.working_dir=${DEPLOY_DIR}" 2>/dev/null)" ]; then
      msg_skip "O container '${_svc}' continua em execução, mas saiu dos profiles deste nó."
      echo "  Remova-o (evita tarefas agendadas duplicadas): bash docker/prod/suap-deploy.sh compose rm -sf ${_svc}"
    fi
  done
fi
echo ""
echo "  Próximos passos:"
echo "    bash docker/prod/suap-deploy.sh check       # valida a configuração"
echo "    bash docker/prod/suap-deploy.sh update      # build/pull e sobe (ou reinicia com drain)"
echo ""
