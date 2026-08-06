# SUAP Setup

## Introdução

Repositório de scripts de automação para preparar ambientes SUAP em Linux e macOS, com suporte para:

- **Debian/Ubuntu** (apt)
- **Fedora/RHEL/CentOS/AlmaLinux/Rocky Linux** (dnf)
- **Arch/Manjaro/EndeavourOS** (pacman)
- **macOS** (Homebrew)
- **Docker** (qualquer sistema com Docker Engine)

Os scripts automatizam instalação de dependências, configuração de ambiente Python, download/atualização do código SUAP, implantação de serviços de produção via Supervisor e orquestração de containers Docker.

## Pré-requisitos

- Acesso ao repositório Git do SUAP
- Conexão com a internet
- Permissões de `sudo` (para scripts de produção e infraestrutura)
- Para opções Docker: Docker e Docker Compose (o script pode instalar automaticamente)
- Para macOS: Homebrew instalado

## Como usar

### 1. Clonar o repositório

```bash
git clone https://github.com/danielslz/suap-setup.git
cd suap-setup
git submodule update --init --recursive  # Necessário para framework de testes
```

### 2. Executar o wrapper interativo

```bash
bash setup.sh
```

Na primeira execução, um **wizard interativo** guia a criação do arquivo `.env` com prompts descritivos, exemplos e valores padrão para cada variável.

### 3. Executar um script diretamente

```bash
# Desenvolvimento nativo
bash deb/suap-dev.sh      # Debian/Ubuntu
bash rpm/suap-dev.sh      # Fedora/RHEL/Alma/Rocky
bash arch/suap-dev.sh     # Arch Linux
bash macos/suap-dev.sh    # macOS

# Produção nativa (requer root)
sudo bash deb/suap-prod.sh
sudo bash rpm/suap-prod.sh
sudo bash arch/suap-prod.sh

# Atualização de produção (requer root)
sudo bash deb/suap-update.sh
sudo bash rpm/suap-update.sh
sudo bash arch/suap-update.sh

# Infraestrutura
bash deb/install-redis.sh
bash deb/install-nginx.sh
bash deb/install-postgres.sh
bash arch/install-redis.sh
bash arch/install-nginx.sh

# Docker
bash docker/dev/docker-setup.sh
bash docker/prod/docker-setup.sh
bash docker/dockhand-setup.sh
bash docker/install-docker.sh
```

> Scripts individuais exigem que o `.env` já exista. Se não existir, o script encerra com erro orientando a executar `setup.sh` primeiro.

## Menu interativo

O `setup.sh` detecta automaticamente o sistema operacional e exibe apenas as opções disponíveis para a plataforma.

**Linux (Debian/RPM/Arch):**

```
=== SUAP Setup ===
1) Configurar ambiente de desenvolvimento
2) Configurar ambiente de produção
3) Instalar Redis
4) Instalar Nginx
5) Configurar ambiente dev via Docker
6) Configurar ambiente prod via Docker
7) Iniciar Dockhand (via Docker)
8) Atualizar ambiente de produção
9) Instalar PostgreSQL
0) Sair
```

**macOS:**

```
=== SUAP Setup ===
1) Configurar ambiente de desenvolvimento
2) Configurar ambiente dev via Docker
3) Configurar ambiente prod via Docker
4) Iniciar Dockhand (via Docker)
0) Sair
```

No macOS, opções de produção nativa, Redis e Nginx não estão disponíveis (macOS é suportado apenas para desenvolvimento).

## Variáveis de ambiente (`.env`)

Todas as variáveis compartilhadas entre os scripts são definidas no arquivo `.env` na raiz do repositório. O wizard solicita as variáveis conforme a opção escolhida no menu.

| Variável | Descrição | Padrão (dev) | Padrão (prod) |
|----------|-----------|--------------|---------------|
| `PYTHON_VERSION` | Versão do Python (compatível: 3.12+ ou conforme recomendação do IFRN à época) | `3.12` | `3.12` |
| `POSTGRES_VERSION` | Versão do PostgreSQL (compatível: 16+ ou conforme recomendação do IFRN à época) | `16` | `16` |
| `BASE_DIR` | Diretório base para instalação | `$HOME/Projetos` | `/opt` |
| `SUAP_DIR` | Diretório do código SUAP | `${BASE_DIR}/suap` | `${BASE_DIR}/suap` |
| `VENV_DIR` | Diretório do virtualenv | `${SUAP_DIR}/.venv` | `/opt/venv` |
| `SUAP_GIT_URL` | URL do repositório Git | *(obrigatório)* | *(obrigatório)* |
| `GUNICORN_WORKERS` | Workers do Gunicorn | — | `5` |
| `GUNICORN_THREADS` | Threads por worker | — | `1` |
| `CELERY_BROKER_URL` | URL do broker Redis | — | `redis://127.0.0.1:6379/3` |
| `CELERY_FLOWER_AUTH` | Autenticação do Flower | — | `admin:admin` |
| `CELERY_MAX_WORKERS` | Máximo de workers Celery | — | `5` |
| `CELERY_MIN_WORKERS` | Mínimo de workers Celery | — | `2` |
| `SUAP_IMAGE` | Imagem Docker do SUAP no registry | — | *(solicitado pelo wizard)* |
| `SUAP_PDF_IMAGE` | Imagem Docker do serviço de PDF | — | *(solicitado pelo wizard)* |
| `SUAP_AI_IMAGE` | Imagem Docker do serviço de IA | — | *(solicitado pelo wizard)* |
| `SUAP_DEPLOY_DIR` | Diretório do repositório suap_deploy | — | `$HOME/Projetos/suap_deploy` |
| `SUAP_DEPLOY_GIT_URL` | URL Git do suap_deploy | — | *(solicitado pelo wizard)* |

## Scripts disponíveis

| Script | Plataforma | Descrição |
|--------|------------|-----------|
| `setup.sh` | Todas | Wrapper interativo com detecção de OS |
| `deb/suap-dev.sh` | Debian/Ubuntu | Ambiente de desenvolvimento |
| `rpm/suap-dev.sh` | Fedora/RHEL/Alma/Rocky | Ambiente de desenvolvimento |
| `arch/suap-dev.sh` | Arch Linux | Ambiente de desenvolvimento |
| `macos/suap-dev.sh` | macOS | Ambiente de desenvolvimento |
| `deb/suap-prod.sh` | Debian/Ubuntu | Ambiente de produção |
| `rpm/suap-prod.sh` | Fedora/RHEL/Alma/Rocky | Ambiente de produção |
| `arch/suap-prod.sh` | Arch Linux | Ambiente de produção |
| `deb/suap-update.sh` | Debian/Ubuntu | Atualização de ambiente de produção |
| `rpm/suap-update.sh` | Fedora/RHEL/Alma/Rocky | Atualização de ambiente de produção |
| `arch/suap-update.sh` | Arch Linux | Atualização de ambiente de produção |
| `deb/install-redis.sh` | Debian/Ubuntu | Instala e habilita Redis |
| `rpm/install-redis.sh` | Fedora/RHEL/Alma/Rocky | Instala e habilita Redis |
| `arch/install-redis.sh` | Arch Linux | Instala e habilita Redis |
| `deb/install-nginx.sh` | Debian/Ubuntu | Instala Nginx e configura proxy SUAP |
| `deb/install-postgres.sh` | Debian/Ubuntu | Instala PostgreSQL via repositório PGDG |
| `rpm/install-nginx.sh` | Fedora/RHEL/Alma/Rocky | Instala Nginx e configura proxy SUAP |
| `arch/install-nginx.sh` | Arch Linux | Instala Nginx e configura proxy SUAP |
| `docker/install-docker.sh` | Linux | Instala Docker Engine e Compose |
| `docker/dev/docker-setup.sh` | Todas | Ambiente dev via Docker |
| `docker/prod/docker-setup.sh` | Todas | Ambiente prod via Docker |
| `docker/dockhand-setup.sh` | Todas | Interface web para gerenciamento Docker |

## Ambiente de desenvolvimento

Os scripts de desenvolvimento realizam:

- Instalação de dependências do sistema (halt imediato em caso de falha)
- Configuração de locale `pt_BR.UTF-8` (pulado no macOS)
- Configuração de timezone `America/Fortaleza`
- Instalação do [UV](https://docs.astral.sh/uv/) (com detecção em `~/.cargo/bin` e `~/.local/bin`)
- Clone ou atualização do código SUAP
- Geração de `settings.py` e `.env` a partir dos samples
- Criação de virtualenv com Python 3.12+ (versão configurável via `PYTHON_VERSION` no `.env`)
- Instalação de dependências via `uv sync --group dev` ou `uv pip install -r requirements/development.txt`

## Ambiente de produção

Os scripts de produção (requerem root) realizam:

- Instalação de dependências do sistema (halt imediato em caso de falha)
- Configuração de locale e timezone
- Clone com `git clone --depth 1` ou atualização do código
- Criação de virtualenv com `python3 -m venv`
- Instalação de dependências via `pip install . --group prod` ou `pip install -r requirements/production.txt`
- Menu interativo para configurar Supervisor (SUAP / Celery / Ambos)
- Deploy de configurações do Supervisor com recarga condicional
- Garantia de UID/GID 33 para `www-data` (compatibilidade com suap_deploy)
- Ajuste de permissões (`chown www-data`)

### Caminhos do Supervisor por distribuição

| Distribuição | Diretório de configuração |
|-------------|--------------------------|
| Debian/Ubuntu | `/etc/supervisor/conf.d/` |
| Fedora/RHEL/Alma/Rocky | `/etc/supervisord.d/` |
| Arch Linux | `/etc/supervisor.d/` |

## Atualização de produção

Os scripts de atualização (`deb/suap-update.sh`, `rpm/suap-update.sh`, `arch/suap-update.sh`) automatizam o processo de atualização do SUAP em servidores de produção:

1. Parar todos os serviços do Supervisor
2. Atualizar código-fonte (`git pull`)
3. Atualizar dependências Python via UV (`uv sync --group prod` ou `uv pip install`)
4. Executar `migrate` (opcional, pergunta ao usuário)
5. Executar `collectstatic` (opcional, pergunta ao usuário)
6. Executar `sync_permissions` (opcional, pergunta ao usuário)
7. Garantir UID/GID 33 do `www-data` (compatibilidade com suap_deploy)
8. Corrigir permissões dos diretórios (`chown www-data`)
9. Reiniciar serviços do Supervisor
10. Exibir status e resumo das ações realizadas

> **Rollback automático em falhas:** Se o `git pull` ou a instalação de dependências falhar, os serviços são reiniciados automaticamente antes do script encerrar com erro.

## Docker

### Arquitetura de Delegação

Os scripts Docker do suap-setup **não mantêm Dockerfiles nem docker-compose próprios**. Em vez disso, delegam para os repositórios upstream oficiais:

- **Desenvolvimento** → delega para o `docker-compose.dev.yml` nativo do repositório SUAP
- **Produção** → delega para o Makefile do projeto suap_deploy

Isso garante que a configuração de build esteja sempre sincronizada com o upstream.

### Variáveis Docker (solicitadas pelo wizard na opção 5)

| Variável | Descrição | Exemplo |
|----------|-----------|---------|
| `SUAP_IMAGE` | Imagem principal do SUAP no registry | `gitlab.instituicao.edu.br:4567/org/suap` |
| `SUAP_PDF_IMAGE` | Imagem do serviço de PDF | `gitlab.instituicao.edu.br:4567/org/suap-pdf:latest` |
| `SUAP_AI_IMAGE` | Imagem do serviço de IA | `gitlab.instituicao.edu.br:4567/org/suap-ai:latest` |

### Desenvolvimento (Docker)

O script `docker/dev/docker-setup.sh` delega para o `docker-compose.dev.yml` do repositório SUAP:

1. Verifica Docker disponível (oferece instalar se ausente)
2. Clona/verifica o repositório SUAP em `SUAP_DIR`
3. Valida existência do `docker/docker-compose.dev.yml` nativo
4. Gera `.env` e `settings.py` a partir dos samples (se necessário)
5. Exporta variáveis de imagens (SUAP_IMAGE, SUAP_PDF_IMAGE, SUAP_AI_IMAGE)
6. Executa `docker compose -f docker/docker-compose.dev.yml build` + `up`

Serviços típicos fornecidos pelo compose do SUAP:

| Serviço | Porta | Descrição |
|---------|-------|-----------|
| web | 8000 | Aplicação SUAP com hot-reload |
| celery | — | Worker Celery |
| celery-beat | — | Agendador de tarefas |
| celery-flower | 5555 | Monitor do Celery |
| redis | 6379 | Cache e broker |
| db | 5432 | PostgreSQL |

```bash
# Iniciar
bash docker/dev/docker-setup.sh

# Após iniciar, use diretamente no diretório do SUAP:
cd $SUAP_DIR
docker compose -f docker/docker-compose.dev.yml logs -f
docker compose -f docker/docker-compose.dev.yml exec web bash
docker compose -f docker/docker-compose.dev.yml down
```

### Produção (Docker)

O script `docker/prod/docker-setup.sh` delega para o projeto suap_deploy:

1. Verifica Docker disponível
2. Clona/verifica o repositório suap_deploy em `SUAP_DEPLOY_DIR`
3. Garante que `make` está instalado (instala automaticamente se ausente)
4. Configura `.env` de produção via `make setup` (se necessário)
5. Apresenta menu interativo de gerenciamento:

```
1) Fazer pull das imagens e iniciar serviços (modo registry)
2) Fazer build local das imagens e iniciar (modo local)
3) Apenas iniciar serviços (make up)
4) Parar todos os serviços (make down)
5) Reiniciar serviços (make restart)
6) Ver status dos containers
7) Ver logs
8) Acessar shell do container web
9) Executar backup do banco
10) Executar restore do banco
11) Executar setup interativo (make setup)
0) Sair
```

O suap_deploy suporta dois modos de imagem: **registry** (pull de imagens pré-construídas) e **local** (build a partir do código-fonte clonado em `./src/suap`). Os serviços ativos são controlados pela variável `COMPOSE_PROFILES` no `.env` do suap_deploy. Inclui OWASP ModSecurity CRS como WAF no Nginx e resource limits por container.

```bash
# Iniciar
bash docker/prod/docker-setup.sh

# Ou usar diretamente no diretório do suap_deploy:
cd $SUAP_DEPLOY_DIR
make up
make status
make logs
make down
```

### Instalação do Docker

O script `docker/install-docker.sh` instala Docker Engine e Docker Compose automaticamente:

- **Debian/Ubuntu**: adiciona repositório oficial Docker e instala via apt
- **Fedora/RHEL/Alma/Rocky**: adiciona repositório oficial Docker e instala via dnf
- **Arch Linux**: instala via `pacman -S docker docker-compose`
- **macOS**: exibe URL para download do Docker Desktop

Após instalar, o script habilita o serviço e adiciona o usuário ao grupo `docker`.

### Dockhand

O [Dockhand](https://dockhand.pro/) é uma interface web para gerenciamento de containers Docker.

| Propriedade | Valor |
|-------------|-------|
| Imagem | `lscr.io/linuxserver/dockhand:latest` |
| Porta de acesso | `http://localhost:9093` |
| Socket Docker | `/var/run/docker.sock` |
| Restart policy | `unless-stopped` |

O script é idempotente: se o container já estiver em execução, apenas exibe a URL.

## Configuração Nginx

### Instalação nativa (`nginx/suap`)

A configuração provê:

- Upstream com `least_conn` na porta 8000
- `client_max_body_size 100m`
- Servição de arquivos estáticos (`/opt/suap/deploy/static/`)
- Servição de arquivos de mídia (`/opt/suap/deploy/media/`)
- Páginas de erro customizadas (500, 502, 503, 504, 413)
- Servidor secundário na porta 8001
- Log customizado com tempos de requisição e upstream
- Buffers de proxy aumentados

O caminho de destino varia por distribuição:

| Distribuição | Destino |
|-------------|---------|
| Debian/Ubuntu | `/etc/nginx/sites-available/suap` + link em `sites-enabled` |
| Fedora/RHEL/Alma/Rocky | `/etc/nginx/conf.d/suap.conf` |
| Arch Linux | `/etc/nginx/conf.d/suap.conf` |

### Docker (`nginx/suap.docker`)

Mesma configuração, mas com upstream apontando para o nome do serviço Docker (`suap:8000`) em vez de `127.0.0.1:8000`.

## Testes

O projeto utiliza [bats-core](https://github.com/bats-core/bats-core) como framework de testes.

### Executar testes

```bash
./tests/run_tests.sh            # Unitários + propriedade + fumaça
./tests/run_tests.sh unit       # Apenas unitários
./tests/run_tests.sh property   # Apenas propriedade
./tests/run_tests.sh smoke      # Apenas fumaça
./tests/run_tests.sh integration # Apenas integração (requer Docker)
./tests/run_tests.sh all        # Todos
```

### Categorias de teste

| Diretório | Tipo | Descrição |
|-----------|------|-----------|
| `tests/unit/` | Unitários | Funções isoladas (wizard, detecção, roteamento) |
| `tests/property/` | Propriedade | Validação com inputs aleatórios (100+ iterações) |
| `tests/smoke/` | Fumaça | Validação estática de configs (nginx, compose, supervisor) |
| `tests/integration/` | Integração | Fluxos completos em containers Docker isolados |

### Propriedades verificadas

1. **Round-trip do .env** — escrever e carregar pares chave=valor preserva os valores
2. **Classificação de distribuição** — IDs de `/etc/os-release` e `uname` produzem caminhos corretos
3. **Roteamento do menu** — combinações opção + distro/OS geram caminho de script correto
4. **Idempotência** — segunda execução pula etapas com mensagens amarelas
5. **Idempotência do Dockhand** — re-execução não cria segundo container
6. **Round-trip do Wizard** — valores fornecidos ao wizard são preservados no .env
7. **Fallback de .env** — scripts individuais encerram com exit 1 quando .env não existe
8. **Mensagens verdes** — todos os scripts usam `msg_action()` para feedback visual
9. **Delegação Docker** — nenhum Dockerfile ou docker-compose existe em `docker/dev/` ou `docker/prod/`
10. **UID/GID www-data** — `ensure_www_data_uid_gid()` garante UID 33 e GID 33 (compatibilidade com suap_deploy)

## Estrutura do repositório

```
suap-setup/
├── .env                              # Variáveis centralizadas
├── setup.sh                          # Wrapper principal
├── lib/
│   └── common.sh                     # Funções utilitárias compartilhadas
├── deb/                              # Debian/Ubuntu
│   ├── suap-dev.sh
│   ├── suap-prod.sh
│   ├── suap-update.sh
│   ├── install-redis.sh
│   ├── install-nginx.sh
│   └── install-postgres.sh
├── rpm/                              # Fedora/RHEL/CentOS/Alma/Rocky
│   ├── suap-dev.sh
│   ├── suap-prod.sh
│   ├── suap-update.sh
│   ├── install-redis.sh
│   └── install-nginx.sh
├── arch/                             # Arch/Manjaro/EndeavourOS
│   ├── suap-dev.sh
│   ├── suap-prod.sh
│   ├── suap-update.sh
│   ├── install-redis.sh
│   └── install-nginx.sh
├── macos/                            # macOS (apenas dev)
│   └── suap-dev.sh
├── docker/
│   ├── install-docker.sh             # Instalação do Docker
│   ├── dockhand-setup.sh             # Dockhand
│   ├── README.md                     # Documentação da arquitetura de delegação
│   ├── dev/
│   │   └── docker-setup.sh           # Delegação → suap (docker-compose.dev.yml)
│   └── prod/
│       └── docker-setup.sh           # Delegação → suap_deploy (Makefile)
├── nginx/
│   ├── suap                          # Config para instalação nativa
│   └── suap.docker                   # Config para containers Docker
├── supervisor/
│   ├── suap.conf
│   ├── run_suap.sh
│   ├── celery_worker.conf
│   ├── run_celery_worker.sh
│   ├── celery_beat.conf
│   ├── run_celery_beat.sh
│   ├── celery_flower.conf
│   └── run_celery_flower.sh
├── tests/
│   ├── run_tests.sh
│   ├── unit/
│   ├── property/
│   ├── smoke/
│   ├── integration/
│   └── test_helper/
└── README.md
```

## Observações

- As versões compatíveis de **Python** são **3.12+** (ou a que o IFRN recomendar à época). O valor é configurável via `PYTHON_VERSION` no `.env`.
- As versões compatíveis de **PostgreSQL** são **16+** (ou a que o IFRN recomendar à época). O valor é configurável via `POSTGRES_VERSION` no `.env`.
- Scripts são **idempotentes**: etapas já concluídas são puladas com mensagens amarelas.
- **Halt em falhas críticas**: se a instalação de pacotes ou dependências Python falhar, o script encerra imediatamente.
- **Supervisorctl condicional**: `supervisorctl reread/update` só executa quando arquivos foram efetivamente copiados.
- **Remoção condicional do nginx default** (Debian): o link `sites-enabled/default` só é removido após a config do SUAP ser ativada.
- **Detecção inteligente de UV**: verifica `~/.cargo/bin/uv` e `~/.local/bin/uv` antes de baixar.
- **Docker auto-install**: se Docker não estiver disponível, os scripts Docker oferecem instalação automática.
- **Delegação Docker**: scripts Docker não mantêm Dockerfiles locais — delegam para repositórios upstream (suap para dev, suap_deploy para prod).
- **UID/GID 33 do www-data**: scripts de produção e atualização garantem que o usuário `www-data` possui UID/GID 33 para compatibilidade com volumes Docker do suap_deploy. Se outro usuário/grupo ocupa UID/GID 33, o script encerra com erro.
- **Variáveis de imagens Docker** (`SUAP_IMAGE`, `SUAP_PDF_IMAGE`, `SUAP_AI_IMAGE`) são solicitadas pelo wizard do suap-setup para Docker dev (opção 5). Para Docker prod (opção 6), essas variáveis são gerenciadas pelo `.env` do próprio suap_deploy (via `make setup`).
- As opções Docker funcionam em qualquer sistema com Docker, independente da distribuição.

## Licença

Veja o arquivo [LICENSE](LICENSE).
