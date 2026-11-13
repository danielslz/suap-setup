#!/usr/bin/env bash
set -u

# docker/prod/suap-deploy.sh - Atalho não interativo para operar o suap_deploy
# sem precisar entrar no diretório dele.
#
# É uma camada FINA sobre o Makefile e o docker compose do suap_deploy: não
# duplica a lógica deles, só resolve o diretório (SUAP_DEPLOY_DIR), valida
# pré-requisitos e encadeia as sequências corretas (ex.: 'update' respeita o
# drain protocol). Serve para uso por SSH, cron e automações.
#
# Uso: bash docker/prod/suap-deploy.sh <comando> [argumentos]
# Ajuda: bash docker/prod/suap-deploy.sh help

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

if [ -f "${SCRIPT_DIR}/.env" ]; then
  load_env_file "${SCRIPT_DIR}/.env"
fi

DEPLOY_DIR="$(resolve_suap_deploy_dir)"

usage() {
  cat <<EOF
${GREEN}suap-deploy.sh${NO_COLOR} - opera o suap_deploy em ${DEPLOY_DIR}

Uso: bash docker/prod/suap-deploy.sh <comando> [argumentos]

Ciclo de vida
  setup                 Bootstrap do suap_deploy (make setup, interativo)
  build                 Builda as imagens (modo local)
  pull                  Baixa as imagens (modo registry)
  up                    Sobe os serviços (respeita COMPOSE_PROFILES)
  down                  Para os serviços (dispara o drain automático)
  restart               down + up (caminho de deploy sem downtime)
  update [--git-pull|--no-build]
                        Atualiza: build (local) ou pull (registry) e depois
                        restart se o stack estiver no ar, ou up se estiver parado.
                        --git-pull atualiza src/suap e src/suap-pdf antes (modo local)
                        --no-build  não compila nem baixa: usa a imagem que já está neste nó
                        (ex.: copiada de outro nó com image-copy) e só reinicia
  image-copy <[usuario@]host> [--with-pdf] [--with-ai] [--dry-run]
                        Copia a imagem do SUAP deste nó para outro (docker save | ssh | docker load).
                        Para modo local em vários nós: compile em UM nó e distribua
  fix-perms             Recria os diretórios de deploy/ e ajusta o dono (33:33, www-data)
  status                Estado dos containers
  logs [serviço...]     Logs em tempo real (ex.: logs web nginx)
  scale <n>             Número de workers celery (ex.: scale 3)

Operação no container web
  bash                  Shell no web (www-data)
  shell                 manage.py shell
  exec <comando...>     Comando arbitrário (ex.: exec python manage.py migrate)

Banco
  begin                 create_db + carga_inicial (banco novo)
  psql                  psql com as credenciais do .env
  backup                Dump em deploy/backup/
  restore <arquivo>     Restaura um dump

Multi-nó
  node [opções]         Configura o papel deste nó (ver configure-node.sh --help)
  profiles              Mostra os profiles ativos e o papel inferido deste nó
  check                 Valida a configuração (.env, TLS, DB/Redis, drain, profiles)
  drain                 Tira este nó do pool do balanceador (sem derrubar containers)
  healthy               Devolve este nó ao pool

Outros
  dir                   Imprime o diretório do suap_deploy
  compose <args...>     docker compose no diretório do suap_deploy

Exemplos
  bash docker/prod/suap-deploy.sh update --git-pull
  bash docker/prod/suap-deploy.sh logs web nginx
  bash docker/prod/suap-deploy.sh exec python manage.py createsuperuser
EOF
}

# --- Pré-requisitos ---
_require_deploy_dir() {
  if [ ! -f "${DEPLOY_DIR}/Makefile" ]; then
    msg_suap_deploy_missing "${DEPLOY_DIR}"
    exit 1
  fi
}

_require_make() {
  if ! command -v make &>/dev/null; then
    msg_error "'make' não está instalado. Instale o pacote 'make' e tente novamente."
    exit 1
  fi
}

_require_docker() {
  if ! command -v docker &>/dev/null || ! docker compose version &>/dev/null; then
    msg_error "Docker e Docker Compose v2 são necessários."
    exit 1
  fi
}

_require_env() {
  if [ ! -f "${DEPLOY_DIR}/.env" ]; then
    msg_error "Arquivo ${DEPLOY_DIR}/.env não encontrado. Rode: bash docker/prod/suap-deploy.sh setup"
    exit 1
  fi
}

# _mk <alvo> [VAR=valor...]: make -C no suap_deploy
_mk() {
  make -C "${DEPLOY_DIR}" "$@"
}

# _dc <args...>: docker compose no suap_deploy
_dc() {
  (cd "${DEPLOY_DIR}" && docker compose "$@")
}

# _env_get <CHAVE>: lê um valor do .env do suap_deploy (sem aspas)
_env_get() {
  local key="${1}" val
  [ -f "${DEPLOY_DIR}/.env" ] || return 0
  val="$(grep -E "^${key}=" "${DEPLOY_DIR}/.env" | tail -n1 | cut -d= -f2-)"
  val="${val%\"}"; val="${val#\"}"; val="${val%\'}"; val="${val#\'}"
  printf '%s' "${val}"
}

# Modo de imagem: local (SUAP_IMAGE vazio ou suap:latest) ou registry
_image_mode() {
  local img
  img="$(_env_get SUAP_IMAGE)"
  if [ -z "${img}" ] || [ "${img}" = "suap:latest" ]; then
    echo "local"
  else
    echo "registry"
  fi
}

# Retorna 0 se há containers do stack em execução
_stack_running() {
  [ -n "$(cd "${DEPLOY_DIR}" && docker compose ps -q --status running 2>/dev/null)" ]
}

# Antes de subir/reiniciar: evita o crash loop do Celery por falta de escrita em deploy/media/tmp
_preflight_perms() {
  local d="${DEPLOY_DIR}/deploy" sub
  for sub in media/tmp logs/suap sessions; do
    if [ -d "${d}/${sub}" ] && ! _writable_by_www "${d}/${sub}"; then
      msg_error "deploy/${sub} não é gravável pelo www-data (UID 33): o Celery/web falhariam com PermissionError."
      msg_error "Corrija com: bash docker/prod/suap-deploy.sh fix-perms"
      exit 1
    fi
  done
}

# Papel inferido a partir de COMPOSE_PROFILES
_infer_role() {
  local p=",$(_env_get COMPOSE_PROFILES),"
  local beat=0
  [[ "${p}" == *,celery-beat,* || "${p}" == *,celery-flower,* ]] && beat=1
  case "${p}" in
    *,default,*)
      if [[ "${p}" == *,local-db,* || "${p}" == *,local-redis,* ]]; then
        echo "homolog (nó único com DB/Redis locais)"
      elif [ "${beat}" = "1" ]; then
        echo "single (nó único)"
      else
        echo "full (web + pdfprinter + celery, sem beat/flower)"
      fi
      ;;
    *,web,*)
      if [ "${beat}" = "1" ] && [[ "${p}" == *,celery,* ]]; then
        echo "web-celery-beat (web + workers + beat/flower)"
      elif [ "${beat}" = "1" ]; then
        echo "web-beat (web + beat/flower)"
      else
        echo "app (web + nginx)"
      fi
      ;;
    *,celery,*)
      if [ "${beat}" = "1" ] || [[ "${p}" == *,pdfprinter,* ]]; then
        echo "async-primary (workers + beat/flower/pdfprinter)"
      else
        echo "async (somente workers)"
      fi
      ;;
    *) echo "personalizado" ;;
  esac
}

# --- Comandos ---
cmd_update() {
  local git_pull=0 no_build=0 arg
  for arg in "$@"; do
    case "${arg}" in
      --git-pull) git_pull=1 ;;
      --no-build) no_build=1 ;;
      *) msg_error "Opção desconhecida para update: ${arg}"; exit 1 ;;
    esac
  done
  if [ "${git_pull}" = "1" ] && [ "${no_build}" = "1" ]; then
    msg_error "--git-pull e --no-build são incompatíveis: atualizar o código sem recompilar deixaria o src/ diferente da imagem."
    exit 1
  fi
  _require_deploy_dir; _require_make; _require_docker; _require_env
  _preflight_perms

  local mode
  mode="$(_image_mode)"
  msg_action "Modo de imagem: ${mode}"
  if [ "${no_build}" = "1" ]; then
    local _img
    _img="$(_env_get SUAP_IMAGE)"; _img="${_img:-suap:latest}"
    if ! docker image inspect "${_img}" &>/dev/null; then
      msg_error "--no-build: a imagem ${_img} não existe neste nó. Copie-a de outro nó (image-copy) ou rode sem --no-build."
      exit 1
    fi
    msg_skip "--no-build: usando a imagem ${_img} já presente (sem build nem pull)."
  elif [ "${mode}" = "local" ]; then
    if [ "${git_pull}" = "1" ]; then
      local repo
      for repo in src/suap src/suap-pdf; do
        if [ -d "${DEPLOY_DIR}/${repo}/.git" ]; then
          msg_action "Atualizando ${repo} (git pull)..."
          git -C "${DEPLOY_DIR}/${repo}" pull --ff-only || { msg_error "git pull falhou em ${repo}."; exit 1; }
        fi
      done
    fi
    msg_action "Buildando imagens..."
    if ! _mk build; then
      msg_error "O build falhou. Se o erro é de dependência do SUAP (ex.: compilação de um pacote Python), compile em OUTRO nó que já tenha a imagem e copie para este: bash docker/prod/suap-deploy.sh image-copy <usuario@este-host> (no nó de origem), depois use: update --no-build"
      exit 1
    fi
  else
    [ "${git_pull}" = "1" ] && msg_skip "--git-pull é ignorado no modo registry."
    msg_action "Baixando imagens..."
    _dc pull || exit 1
  fi

  if _stack_running; then
    msg_action "Stack em execução: restart (down com drain + up)..."
    _mk restart || exit 1
  else
    msg_action "Stack parado: up..."
    _mk up || exit 1
  fi
  _mk status
}

cmd_image_copy() {
  local target="" with_pdf=0 with_ai=0 dry=0 arg
  for arg in "$@"; do
    case "${arg}" in
      --with-pdf) with_pdf=1 ;;
      --with-ai) with_ai=1 ;;
      --dry-run) dry=1 ;;
      -*) msg_error "Opção desconhecida para image-copy: ${arg}"; exit 1 ;;
      *)
        if [ -n "${target}" ]; then msg_error "Informe apenas um destino."; exit 1; fi
        target="${arg}"
        ;;
    esac
  done
  if [ -z "${target}" ]; then
    msg_error "Uso: image-copy <[usuario@]host> [--with-pdf] [--with-ai] [--dry-run]"
    exit 1
  fi
  if ! [[ "${target}" =~ ^([A-Za-z0-9._-]+@)?[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then
    msg_error "Destino inválido: ${target} (use usuario@host ou host)."
    exit 1
  fi
  _require_deploy_dir; _require_docker

  # Imagens a copiar (nomes do .env do suap_deploy)
  local -a images=()
  local img
  img="$(_env_get SUAP_IMAGE)"; images+=("${img:-suap:latest}")
  if [ "${with_pdf}" = "1" ]; then img="$(_env_get SUAP_PDF_IMAGE)"; images+=("${img:-suap-pdf:latest}"); fi
  if [ "${with_ai}" = "1" ]; then img="$(_env_get SUAP_AI_IMAGE)"; images+=("${img:-suap-ai:latest}"); fi
  for img in "${images[@]}"; do
    if ! [[ "${img}" =~ ^[A-Za-z0-9._/:@-]+$ ]]; then msg_error "Nome de imagem inválido no .env: ${img}"; exit 1; fi
    if ! docker image inspect "${img}" &>/dev/null; then
      msg_error "A imagem ${img} não existe neste nó. Este deve ser o nó que compilou (ou baixou) a imagem."
      exit 1
    fi
  done

  [ "$(_image_mode)" = "registry" ] && msg_skip "Modo registry: normalmente cada nó baixa a imagem com 'pull'. Copiando mesmo assim."

  # Opções do ssh (ex.: SUAP_SSH_OPTS="-p 2222 -i ~/.ssh/id_deploy")
  local -a ssh_opts=()
  [ -n "${SUAP_SSH_OPTS:-}" ] && read -ra ssh_opts <<< "${SUAP_SSH_OPTS}"

  # Commit do código local (modo local monta src/suap por cima do código da imagem)
  local src="${DEPLOY_DIR}/src/suap" commit="" dirty=""
  if [ -d "${src}/.git" ]; then
    commit="$(git -C "${src}" rev-parse HEAD 2>/dev/null || true)"
    dirty="$(git -C "${src}" status --short 2>/dev/null || true)"
  fi

  echo ""
  echo "${GREEN}=== Cópia de imagem para ${target} ===${NO_COLOR}"
  for img in "${images[@]}"; do
    echo "  Imagem:  ${img}  ($(docker image inspect -f '{{.Size}}' "${img}" | awk '{ if ($1 >= 1073741824) printf "%.1f GB", $1/1073741824; else printf "%.0f MB", $1/1048576 }'), ID $(docker image inspect -f '{{.Id}}' "${img}" | cut -c8-19))"
  done
  [ -n "${commit}" ] && echo "  Código:  src/suap no commit ${commit}"
  if [ -n "${dirty}" ]; then
    msg_skip "src/suap tem alterações não commitadas: o destino não terá como reproduzi-las. Commite ou descarte antes de copiar."
  fi
  if [ "${dry}" = "1" ]; then
    echo ""
    msg_skip "Dry-run: nada foi copiado. Seria executado, para cada imagem: docker save | gzip | ssh ${target} 'gunzip | docker load'"
    return 0
  fi

  msg_action "Testando SSH e Docker em ${target}..."
  if ! ssh "${ssh_opts[@]+"${ssh_opts[@]}"}" -o BatchMode=yes -o ConnectTimeout=10 -- "${target}" 'docker version --format "{{.Server.Version}}"' >/dev/null 2>&1; then
    msg_error "Não foi possível executar 'docker' em ${target} por SSH (sem senha). Verifique: chave SSH autorizada, usuário no grupo docker e Docker rodando no destino."
    msg_error "Sem SSH entre os nós, copie por arquivo: docker save <imagem> | gzip > suap.tar.gz  ->  gunzip -c suap.tar.gz | docker load"
    exit 1
  fi

  for img in "${images[@]}"; do
    msg_action "Copiando ${img} (pode levar alguns minutos)..."
    if ! ( set -o pipefail; docker save "${img}" | gzip | ssh "${ssh_opts[@]+"${ssh_opts[@]}"}" -o BatchMode=yes -- "${target}" 'gunzip | docker load' ); then
      msg_error "Falha ao copiar ${img} para ${target}."
      exit 1
    fi
    local lid rid
    lid="$(docker image inspect -f '{{.Id}}' "${img}")"
    rid="$(ssh "${ssh_opts[@]+"${ssh_opts[@]}"}" -o BatchMode=yes -- "${target}" "docker image inspect -f '{{.Id}}' '${img}'" 2>/dev/null || true)"
    if [ "${lid}" = "${rid}" ]; then
      _ok "${img} presente em ${target} com o mesmo ID (${lid:7:12})"
    else
      msg_error "O ID de ${img} no destino (${rid:-ausente}) difere do local (${lid})."
      exit 1
    fi
  done

  echo ""
  msg_action "Próximos passos no destino (${target}):"
  if [ -n "${commit}" ]; then
    echo "  1. Deixar o código no MESMO commit da imagem (o modo local monta src/suap por cima dela):"
    echo "       git -C <SUAP_DEPLOY_DIR>/src/suap fetch && git -C <SUAP_DEPLOY_DIR>/src/suap checkout ${commit}"
  fi
  echo "  2. Subir sem compilar:  bash docker/prod/suap-deploy.sh update --no-build"
  echo "     (ou 'up'/'restart'). Não use 'update' sem --no-build nem 'build' no destino: eles recompilam."
  echo ""
}

cmd_scale() {
  local n="${1:-}"
  if ! [[ "${n}" =~ ^[0-9]+$ ]] || [ "${n}" -lt 1 ]; then
    msg_error "Uso: scale <n> (inteiro >= 1)"
    exit 1
  fi
  _require_deploy_dir; _require_docker; _require_env
  msg_action "Escalando celery para ${n} instância(s)..."
  _dc up -d --scale "celery=${n}" --no-recreate
}

cmd_profiles() {
  _require_deploy_dir
  echo "COMPOSE_PROFILES=$(_env_get COMPOSE_PROFILES)"
  echo "Papel inferido:  $(_infer_role)"
  echo "Modo de imagem:  $(_image_mode)"
  echo "SSL_ENABLED=$(_env_get SSL_ENABLED)"
}

cmd_node() {
  bash "${SCRIPT_DIR}/docker/prod/configure-node.sh" "$@"
}

cmd_drain() {
  _require_deploy_dir
  bash "${DEPLOY_DIR}/contrib/multi-node/drain.sh"
}

cmd_healthy() {
  _require_deploy_dir
  bash "${DEPLOY_DIR}/contrib/multi-node/healthy.sh"
}

# --- check ---
_CHECK_FAIL=0
_CHECK_WARN=0
_ok()   { echo "  ${GREEN}[ok]${NO_COLOR}    $1"; }
_warn() { echo "  ${YELLOW}[aviso]${NO_COLOR} $1"; _CHECK_WARN=$((_CHECK_WARN + 1)); }
_fail() { echo "  ${RED}[falha]${NO_COLOR} $1"; _CHECK_FAIL=$((_CHECK_FAIL + 1)); }

# _writable_by_www <diretório>: o UID 33 consegue criar arquivos aqui?
# Verdadeiro se o dono é 33 com permissão de escrita, ou se "outros" têm escrita.
_writable_by_www() {
  local path="${1}" owner mode
  owner="$(stat -c '%u' "${path}" 2>/dev/null)" || return 1
  mode="$(stat -c '%a' "${path}" 2>/dev/null)" || return 1
  mode="${mode: -3}"
  if [ "${owner}" = "33" ]; then
    [ $(( 8#${mode:0:1} & 2 )) -ne 0 ] && return 0
  fi
  [ $(( 8#${mode:2:1} & 2 )) -ne 0 ]
}

# _tcp <host> <porta>: testa conexão TCP com timeout de 3s
_tcp() {
  timeout 3 bash -c "exec 3<>/dev/tcp/${1}/${2}" 2>/dev/null
}

# _redis_probe <host> <porta> <senha> -> ok | recusada | exige-senha | sem-resposta
# Fala RESP direto por /dev/tcp (sem redis-cli): AUTH (se houver senha) + PING.
_redis_probe() {
  local out
  out="$(REDIS_PW="${3}" timeout 6 bash -c '
    exec 3<>"/dev/tcp/$0/$1" || exit 9
    if [ -n "$REDIS_PW" ]; then
      printf "*2\r\n\$4\r\nAUTH\r\n\$%d\r\n%s\r\n" "${#REDIS_PW}" "$REDIS_PW" >&3
      read -r -t 3 -u 3 a; echo "$a"
    fi
    printf "*1\r\n\$4\r\nPING\r\n" >&3
    read -r -t 3 -u 3 p; echo "$p"
  ' "${1}" "${2}" 2>/dev/null)"
  case "${out}" in
    *WRONGPASS*|*"invalid username-password"*) echo "recusada" ;;
    *NOAUTH*) echo "exige-senha" ;;
    *PONG*) echo "ok" ;;
    *) echo "sem-resposta" ;;
  esac
}

# _url_userinfo <url> -> trecho entre :// e @ (vazio se não houver)
_url_userinfo() {
  local rest="${1#*://}"
  [[ "${rest%%/*}" == *@* ]] || return 0
  printf '%s' "${rest%%@*}"
}

# _urldecode <texto>
_urldecode() {
  local t="${1//+/ }"
  printf '%b' "${t//%/\\x}"
}

# _host_port_from_url <url> <porta-padrão> -> "host porta"
_host_port_from_url() {
  local url="${1}" def="${2}" rest hostport
  rest="${url#*://}"; rest="${rest#*@}"; hostport="${rest%%/*}"
  if [[ "${hostport}" == *:* ]]; then
    echo "${hostport%%:*} ${hostport##*:}"
  else
    echo "${hostport} ${def}"
  fi
}

_check_reach() {
  local label="${1}" host="${2}" port="${3}" target="${2}"
  if [ "${host}" = "host.docker.internal" ]; then
    target="127.0.0.1"
  fi
  if _tcp "${target}" "${port}"; then
    _ok "${label} acessível em ${target}:${port}"
  elif [ "${host}" = "host.docker.internal" ]; then
    _warn "${label}: nada escutando em ${target}:${port} (host.docker.internal = este host). Pode estar ouvindo só na interface do Docker."
  else
    _fail "${label}: sem conexão com ${host}:${port}"
  fi
}

cmd_check() {
  _require_deploy_dir
  echo ""
  echo "${GREEN}=== Verificação do suap_deploy (${DEPLOY_DIR}) ===${NO_COLOR}"

  echo ""
  echo "Ambiente"
  if command -v docker &>/dev/null && docker compose version &>/dev/null; then
    local cv
    cv="$(docker compose version --short 2>/dev/null | sed 's/^v//')"
    if [ "$(printf '%s\n2.30.0\n' "${cv}" | sort -V | head -n1)" = "2.30.0" ]; then
      _ok "Docker Compose ${cv} (>= 2.30, necessário para o drain protocol)"
    else
      _warn "Docker Compose ${cv} (< 2.30): o drain automático (pre_stop/post_start) não funciona"
    fi
  else
    _fail "Docker/Docker Compose v2 não encontrado"
  fi
  command -v make &>/dev/null && _ok "make instalado" || _fail "make não instalado"

  if [ ! -f "${DEPLOY_DIR}/.env" ]; then
    _fail ".env ausente em ${DEPLOY_DIR} (rode: setup)"
    echo ""
    echo "${RED}Resultado: ${_CHECK_FAIL} falha(s), ${_CHECK_WARN} aviso(s).${NO_COLOR}"
    return 1
  fi
  _ok ".env presente"

  echo ""
  echo "Configuração"
  local v
  for v in SECRET_KEY DATABASE_PASSWORD; do
    [ -n "$(_env_get "${v}")" ] && _ok "${v} definido" || _fail "${v} está vazio"
  done
  [ -n "$(_env_get SUAP_PDF_ACCESS_TOKEN)" ] && _ok "SUAP_PDF_ACCESS_TOKEN definido" \
    || _warn "SUAP_PDF_ACCESS_TOKEN vazio: o pdfprinter recusa todas as chamadas"
  case "$(_env_get SITE_URL)" in
    ""|*minhainstituicao*) _warn "SITE_URL ainda com o valor de exemplo" ;;
    *) _ok "SITE_URL = $(_env_get SITE_URL)" ;;
  esac
  local ah ah_profiles
  ah="$(_env_get ALLOWED_HOSTS)"; ah="${ah// /}"
  ah_profiles=",$(_env_get COMPOSE_PROFILES),"
  case "${ah}" in
    *minhainstituicao*) _warn "ALLOWED_HOSTS ainda com o valor de exemplo" ;;
  esac
  # Os health checks do compose acessam o web por "web:8000" e o nginx por "nginx:80": o Django
  # precisa aceitar esses hosts, senão responde 400 (DisallowedHost) e o nó fica unhealthy.
  if [ -n "${ah}" ] && [[ ",${ah}," != *,'*',* ]] && [[ "${ah_profiles}" == *,default,* || "${ah_profiles}" == *,web,* ]]; then
    if [[ ",${ah}," != *,web,* ]]; then
      _fail "ALLOWED_HOSTS sem 'web': o health check do container web (Host web:8000) recebe 400 DisallowedHost, o web fica unhealthy e o nginx não sobe. Rode: node --site-url <url> --yes (mescla web,nginx) ou acrescente web e nginx à lista"
    fi
    if [[ ",${ah}," != *,nginx,* ]]; then
      _warn "ALLOWED_HOSTS sem 'nginx': o health check do container nginx (Host nginx) recebe 400 e ele aparece como unhealthy"
    fi
  fi
  [ "$(_env_get DEBUG)" = "True" ] && _warn "DEBUG=True (não use em produção)"

  echo ""
  echo "Profiles / papel do nó"
  local profiles p known
  profiles="$(_env_get COMPOSE_PROFILES)"
  echo "         COMPOSE_PROFILES=${profiles}"
  echo "         Papel inferido: $(_infer_role)"
  known=" default web pdfprinter celery celery-beat celery-flower ai cron local-db local-redis "
  for p in ${profiles//,/ }; do
    [[ "${known}" == *" ${p} "* ]] || _warn "Profile desconhecido: ${p}"
  done
  [[ ",${profiles}," == *,cron,* ]] && _warn "Profile 'cron' é legado: use celery-beat"
  if [[ ",${profiles}," == *,celery-beat,* ]]; then
    _warn "celery-beat ativo neste nó: garanta que NENHUM outro nó do cluster o execute (duplica tarefas agendadas)"
  fi
  if [[ ",${profiles}," == *,celery-flower,* ]]; then
    _warn "celery-flower ativo neste nó: apenas UM nó do cluster deve rodá-lo"
    [ "$(_env_get FLOWER_BASIC_AUTH)" = "admin:senha" ] && _fail "FLOWER_BASIC_AUTH ainda com o valor padrão (admin:senha)"
  fi
  if [[ ",${profiles}," == *,local-db,* || ",${profiles}," == *,local-redis,* ]]; then
    _warn "local-db/local-redis ativos: indicados só para homologação"
  fi

  echo ""
  echo "TLS / Nginx"
  local ssl link
  ssl="$(_env_get SSL_ENABLED)"; ssl="${ssl:-true}"
  link="$(readlink "${DEPLOY_DIR}/nginx/active/server.conf.template" 2>/dev/null || true)"
  if [ -z "${link}" ]; then
    if [[ ",${profiles}," == *,web,* || ",${profiles}," == *,default,* ]]; then
      _fail "nginx/active/server.conf.template ausente: o nginx não sobe (rode setup ou node --ssl ${ssl})"
    fi
  elif [ "${ssl}" = "true" ] && [[ "${link}" == *20-http* ]]; then
    _fail "SSL_ENABLED=true mas o nginx está com o template HTTP (${link})"
  elif [ "${ssl}" != "true" ] && [[ "${link}" == *30-https* ]]; then
    _fail "SSL_ENABLED=${ssl} mas o nginx está com o template HTTPS (${link})"
  else
    _ok "Template nginx coerente com SSL_ENABLED=${ssl} (${link##*/})"
  fi
  if [ "${ssl}" = "true" ]; then
    if [ -f /etc/ssl/suap/nginx/fullchain.crt ] && [ -f /etc/ssl/suap/nginx/privkey.key ]; then
      _ok "Certificado em /etc/ssl/suap/nginx/"
    else
      _fail "Certificado ausente em /etc/ssl/suap/nginx/ (fullchain.crt e privkey.key)"
    fi
  elif [[ ",${profiles}," == *,web,* ]]; then
    _ok "SSL desligado neste nó (TLS deve terminar no balanceador)"
  fi
  if [ "${ssl}" != "true" ] && [[ ",${profiles}," == *,web,* || ",${profiles}," == *,default,* ]]; then
    if [ -z "$(_env_get SECURE_PROXY_SSL_HEADER)" ]; then
      _warn "SSL_ENABLED=false (TLS no balanceador) mas SECURE_PROXY_SSL_HEADER está vazio: o Django ignora o X-Forwarded-Proto e trata tudo como HTTP (links e redirecionamentos com http://). Rode: node --ssl false --yes"
    else
      _ok "SECURE_PROXY_SSL_HEADER = $(_env_get SECURE_PROXY_SSL_HEADER)"
    fi
  fi
  if [[ ",${profiles}," == *,web,* && "${ssl}" = "true" ]]; then
    _warn "Nó 'web' com SSL_ENABLED=true: o health check do balanceador na porta 80 recebe 301 e nunca vê o drain"
  fi

  echo ""
  echo "Dependências externas"
  if [[ ",${profiles}," != *,local-db,* ]]; then
    _check_reach "PostgreSQL" "$(_env_get DATABASE_HOST)" "$(_env_get DATABASE_PORT)"
  fi
  if [[ ",${profiles}," != *,local-redis,* ]]; then
    local hp rhost rport rpw bu bu_info bu_pw reach
    hp="$(_host_port_from_url "$(_env_get REDIS_URL)" 6379)"
    rhost="${hp% *}"; rport="${hp#* }"
    _check_reach "Redis" "${rhost}" "${rport}"
    rpw="$(_env_get REDIS_PASSWORD)"
    reach="${rhost}"; [ "${rhost}" = "host.docker.internal" ] && reach="127.0.0.1"

    # Celery lê o broker só da URL: a senha precisa estar nela (redis://:SENHA@host)
    bu="$(_env_get CELERY_BROKER_URL)"
    bu_info="$(_url_userinfo "${bu}")"
    if [ -n "${bu_info}" ] && [[ "${bu_info}" != *:* ]]; then
      _fail "CELERY_BROKER_URL sem ':' antes da senha: use redis://:SENHA@host:porta/1. Sem o ':' o Redis lê a senha como NOME DE USUÁRIO e recusa (invalid username-password pair)"
    elif [ -n "${rpw}" ] && [ -z "${bu_info}" ]; then
      _fail "REDIS_PASSWORD definido, mas CELERY_BROKER_URL não leva senha: o Celery não consegue autenticar. Use redis://:SENHA@host:porta/1 (rode: node --redis-host <host>)"
    else
      _ok "CELERY_BROKER_URL coerente com a senha do Redis"
    fi

    if _tcp "${reach}" "${rport}"; then
      case "$(_redis_probe "${reach}" "${rport}" "${rpw}")" in
        ok) _ok "Redis aceitou a senha de REDIS_PASSWORD (cache/sessão do Django)" ;;
        recusada) _fail "Redis RECUSOU a senha de REDIS_PASSWORD (cache/sessão do Django)" ;;
        exige-senha) _fail "Redis exige senha, mas REDIS_PASSWORD está vazio" ;;
        *) _warn "Redis não respondeu ao PING (verifique firewall/bind)" ;;
      esac
      bu_pw="${bu_info#*:}"
      [[ "${bu_info}" == *:* ]] && bu_pw="$(_urldecode "${bu_pw}")" || bu_pw=""
      case "$(_redis_probe "${reach}" "${rport}" "${bu_pw}")" in
        ok) _ok "Redis aceitou a credencial de CELERY_BROKER_URL" ;;
        recusada) _fail "Redis RECUSOU a credencial de CELERY_BROKER_URL (Celery não conecta)" ;;
        exige-senha) _fail "Redis exige senha e CELERY_BROKER_URL não a informa" ;;
        *) : ;;
      esac
    fi
  fi
  echo ""
  echo "Runtime (deploy/)"
  local d="${DEPLOY_DIR}/deploy" sub bad=0
  if [ -d "${d}" ]; then
    # O www-data (UID 33) precisa gravar nestes diretórios (web, celery e pdfprinter)
    for sub in "" media media/tmp logs logs/suap logs/nginx sessions pdf pdf/tmp; do
      if [ ! -d "${d}/${sub}" ]; then
        _warn "deploy/${sub} ausente (rode: fix-perms)"
        continue
      fi
      if ! _writable_by_www "${d}/${sub}"; then
        _fail "deploy/${sub} não é gravável pelo www-data (UID 33): dono $(stat -c '%U(%u)' "${d}/${sub}"), modo $(stat -c '%a' "${d}/${sub}"). O Celery falha com PermissionError. Rode: fix-perms"
        bad=1
      fi
    done
    [ "${bad}" = "0" ] && _ok "deploy/ gravável pelo www-data (UID 33)"
    [ -f "${d}/status.txt" ] && _ok "deploy/status.txt = $(cat "${d}/status.txt")" || _warn "deploy/status.txt ausente (rode: fix-perms)"
  else
    _warn "diretório deploy/ ausente (rode: fix-perms)"
  fi
  local ds
  ds="$(_env_get DRAIN_SECONDS)"
  if [ -n "${ds}" ] && ! [[ "${ds}" =~ ^[0-9]+$ ]]; then
    _fail "DRAIN_SECONDS inválido: ${ds}"
  fi

  echo ""
  if [ "${_CHECK_FAIL}" -gt 0 ]; then
    echo "${RED}Resultado: ${_CHECK_FAIL} falha(s), ${_CHECK_WARN} aviso(s).${NO_COLOR}"
    return 1
  fi
  echo "${GREEN}Resultado: nenhuma falha, ${_CHECK_WARN} aviso(s).${NO_COLOR}"
}

# --- Despacho ---
cmd="${1:-help}"
[ "$#" -gt 0 ] && shift

case "${cmd}" in
  help|-h|--help) usage ;;
  dir) echo "${DEPLOY_DIR}" ;;
  setup)    _require_deploy_dir; _require_make; _mk setup ;;
  build)    _require_deploy_dir; _require_make; _require_docker; _mk build ;;
  pull)     _require_deploy_dir; _require_docker; _require_env; _dc pull ;;
  up)       _require_deploy_dir; _require_make; _require_docker; _require_env; _preflight_perms; _mk up ;;
  down)     _require_deploy_dir; _require_make; _require_docker; _mk down ;;
  restart)  _require_deploy_dir; _require_make; _require_docker; _require_env; _preflight_perms; _mk restart ;;
  status)   _require_deploy_dir; _require_make; _require_docker; _mk status ;;
  logs)     _require_deploy_dir; _require_make; _require_docker; _mk logs SERVICES="$*" ;;
  update)   cmd_update "$@" ;;
  image-copy) cmd_image_copy "$@" ;;
  fix-perms) _require_deploy_dir; ensure_suap_deploy_dirs "${DEPLOY_DIR}" ;;
  scale)    cmd_scale "$@" ;;
  bash)     _require_deploy_dir; _require_make; _require_docker; _mk bash ;;
  shell)    _require_deploy_dir; _require_make; _require_docker; _mk shell ;;
  exec)
    if [ "$#" -eq 0 ]; then msg_error "Uso: exec <comando...>"; exit 1; fi
    _require_deploy_dir; _require_make; _require_docker; _mk exec COMMAND="$*"
    ;;
  begin)    _require_deploy_dir; _require_make; _require_docker; _require_env; _mk begin ;;
  psql)     _require_deploy_dir; _require_make; _require_docker; _require_env; _mk psql ;;
  backup)   _require_deploy_dir; _require_make; _require_docker; _require_env; _mk backup ;;
  restore)
    if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then msg_error "Uso: restore <arquivo.sql> (arquivo deve existir)"; exit 1; fi
    _require_deploy_dir; _require_make; _require_docker; _require_env
    _mk restore DUMP="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
    ;;
  node)     cmd_node "$@" ;;
  profiles) cmd_profiles ;;
  check)    cmd_check ;;
  drain)    cmd_drain ;;
  healthy)  cmd_healthy ;;
  compose)  _require_deploy_dir; _require_docker; _dc "$@" ;;
  *)
    msg_error "Comando desconhecido: ${cmd}"
    echo ""
    usage
    exit 1
    ;;
esac
