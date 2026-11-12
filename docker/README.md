# Docker - Arquitetura de Delegação

O suap-setup **não mantém Dockerfiles próprios**. Em vez disso, os scripts
delegam para os projetos oficiais:

## Desenvolvimento (`docker/dev/docker-setup.sh`)

Utiliza o `docker-compose.dev.yml` do repositório **suap** (código-fonte da
aplicação). Isso garante que:

- Os Dockerfiles usados são os mesmos que o CI/CD constrói
- Serviços auxiliares (minio, pdfprinter, ai) estão disponíveis
- Atualizações de dependências do upstream são automaticamente refletidas

**Fluxo:**
1. Verifica/clona o repositório SUAP em `SUAP_DIR`
2. Gera `.env` a partir do sample se necessário
3. Executa `docker compose -f docker/docker-compose.dev.yml up`

**Variáveis necessárias no `.env` do suap-setup:**
- `SUAP_DIR` - Caminho para o repositório suap
- `SUAP_GIT_URL` - URL git do repositório (para clone automático)
- `SUAP_IMAGE` - URL da imagem no registry

## Produção (`docker/prod/docker-setup.sh`)

Utiliza o projeto **suap_deploy** que é o orquestrador oficial de produção.
O suap_deploy:

- Suporta dois modos: **registry** (pull de imagens) e **local** (build a partir do código em `./src/suap`)
- Usa OWASP ModSecurity CRS como WAF no Nginx
- Suporta resource limits por container
- Controla serviços ativos via `COMPOSE_PROFILES` no `.env`
- Inclui serviços auxiliares (pdfprinter, ai, celery-beat, celery-flower)
- Gerencia via Makefile com targets: `setup`, `build`, `up`, `down`, `restart`, `status`, `logs`, `bash`, `backup`, `restore`

**Fluxo:**
1. Verifica/clona o repositório suap_deploy em `SUAP_DEPLOY_DIR`
2. Executa `make setup` (interativo: modo imagem, .env, nginx, certs)
3. Apresenta menu interativo com opções de gerenciamento
4. Delega para os targets do Makefile

**Atalhos (`docker/prod/`):**
- `suap-deploy.sh <comando>`: opera o suap_deploy sem trocar de pasta (build, up, down, restart, `update`,
  logs, scale, exec, backup, restore, `check`…). Camada fina: delega para `make -C` e `docker compose`.
- `configure-node.sh`: define o papel do nó (`single`, `app`, `async-primary`, `async`, `homolog`) e as
  conexões de DB/Redis/SSL/S3 no `.env` do suap_deploy, com backup e `--dry-run`.

**Variáveis necessárias no `.env` do suap-setup:**
- `SUAP_DEPLOY_DIR` - Caminho para o repositório suap_deploy
- `SUAP_DEPLOY_GIT_URL` - URL git do suap_deploy

## Stacks Docker Compose (Redis, PostgreSQL, Dockhand, Arcane, HAProxy)

Os utilitários independentes abaixo usam Docker Compose. Cada um cria
`${DOCKER_STACKS_DIR:-/opt/docker}/<nome>/` com `compose.yaml` (gerado pelo script) e
`.env` (valores e segredos, chmod 600). Rodar o script de novo reconcilia mudanças
(`docker compose up -d`). Containers criados antes por `docker run` são migrados
(com confirmação) e os volumes são reaproveitados. As funções compartilhadas
(`stack_init`, `stack_env_load`, `stack_env_write`, `stack_compose`,
`stack_adopt_legacy`, `stack_revert`) ficam em `lib/common.sh`.

## Dockhand (`docker/dockhand-setup.sh`)

Instala e inicia o Dockhand (interface web para gerenciamento Docker).
Este é um utilitário independente e não depende dos projetos acima.
Reversão em `docker/dockhand-revert.sh`.

## Arcane (`docker/arcane-setup.sh`)

Utilitário independente, alternativa livre (BSD-3-Clause) ao Dockhand. Sobe o
container `arcane` (`ghcr.io/getarcaneapp/manager`) na porta `3552`, com volume
`arcane-data` e pasta de projetos Compose (a mesma dos stacks, `/opt/docker`). A `ENCRYPTION_KEY` é
gerada e guardada no `.env` do stack; faça backup dela. Reversão em
`docker/arcane-revert.sh`.

## Arcane Agent (`docker/arcane-agent-setup.sh`)

Utilitário independente para hosts **remotos**: sobe o `arcane-agent` (`ghcr.io/getarcaneapp/agent`) em
modo Direct (porta `3553`), que o Arcane Manager usa para gerenciar o Docker daquele host. Exige o token
gerado ao criar o environment no Manager (`ARCANE_AGENT_TOKEN`, `ARCANE_MANAGER_URL`). A telemetria do
Arcane fica desligada por padrão (`ARCANE_ANALYTICS_DISABLED=true`). Reversão em `docker/arcane-agent-revert.sh`.

## HAProxy (`docker/haproxy-setup.sh`)

Utilitário independente: balanceador (container `suap-haproxy`, `network_mode: host`) para os nós
`app` do suap_deploy. Termina o TLS (443), redireciona 80 e faz health check em `/ht/` (só `200`
é saudável, então o drain tira o nó do pool). Variáveis `HAPROXY_BACKENDS` (`host:porta:peso`),
`HAPROXY_SERVER_NAME`, `HAPROXY_TLS` e portas. Rode em servidor sem o Nginx do suap_deploy.
Reversão em `docker/haproxy-revert.sh`.

## MinIO (`docker/minio-setup.sh`)

Utiliza o projeto **suap-minio** para provisionar um servidor de object storage
S3-compatível via Docker. O suap-minio:

- Executa MinIO como container Docker com Nginx na frente (proxy)
- Expõe API S3 na porta 80 e console de administração na porta 9001
- Gerencia via Makefile com targets: `up`, `stop`, `status`, `logs`, `update`

**Fluxo:**
1. Verifica/clona o repositório suap-minio em `SUAP_MINIO_DIR`
2. Configura `.env` (credenciais root, URL de redirecionamento)
3. Apresenta menu interativo de gerenciamento
4. Delega para os targets do Makefile

**Variáveis necessárias no `.env` do suap-setup:**
- `SUAP_MINIO_DIR` - Caminho para o repositório suap-minio
- `SUAP_MINIO_GIT_URL` - URL git do suap-minio

**Após iniciar o MinIO:**
1. Acesse o console (`http://servidor:9001`) e crie os buckets `media` e `temp`
2. Crie um Access Key no console
3. Configure no `.env` do suap_deploy:
   - `DEFAULT_FILE_STORAGE=djtools.storages.s3.MediaS3Storage`
   - `AWS_S3_ENDPOINT_URL=http://<ip-do-minio>`
   - `AWS_ACCESS_KEY_ID=<access-key>`
   - `AWS_SECRET_ACCESS_KEY=<secret-key>`

## Redis (`docker/redis-setup.sh`)

Utilitário independente: sobe o container `suap-redis` (`redis:7-alpine`) com a
porta `6379` exposta em `0.0.0.0` e senha obrigatória. Dados no volume
`suap-redis-data`. Reversão em `docker/redis-revert.sh`.

## PostgreSQL (`docker/postgres-setup.sh`)

Utilitário independente: sobe o container `suap-postgres` (`postgres:<versão>`)
com a porta `5432` exposta, senha obrigatória e `bytea_output=escape`. Dados no
volume `suap-postgres-data`. Reversão em `docker/postgres-revert.sh`.

## Reversões

Cada setup Docker tem um `*-revert.sh` correspondente (acionado por `R` no `setup.sh`):
`install-docker-revert.sh`, `dockhand-revert.sh`, `arcane-revert.sh`, `arcane-agent-revert.sh`, `haproxy-revert.sh`, `minio-revert.sh`, `redis-revert.sh`,
`postgres-revert.sh`, `dev/docker-setup-revert.sh` e `prod/docker-setup-revert.sh`.
Todos usam `confirm_destructive` para volumes, imagens e diretórios, e aceitam
`REVERT_DRY_RUN=1` e `REVERT_ASSUME_YES=1`.

## Por que não manter Dockerfiles locais?

1. **Evita drift**: Quando o upstream muda dependências (ex: nova lib Python),
   os Dockerfiles locais ficariam desatualizados silenciosamente
2. **Single source of truth**: Os Dockerfiles do suap são os que o CI/CD
   constrói e publica — são os "oficiais"
3. **Completude**: O compose do suap inclui todos os serviços necessários
   (minio, ai, pdf) que um setup local precisaria duplicar
4. **Produção real**: O suap_deploy tem configurações battle-tested (WAF, limits,
   Vault, SSL) que não fazem sentido recriar
