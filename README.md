# SUAP Setup

## Introdução

Repositório de scripts de automação para preparar ambientes SUAP em Linux e macOS, com suporte para:

- **Debian/Ubuntu** (apt)
- **Fedora/RHEL/CentOS** (dnf)
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
bash rpm/suap-dev.sh      # Fedora/RHEL
bash arch/suap-dev.sh     # Arch Linux
bash macos/suap-dev.sh    # macOS

# Produção nativa (requer root)
sudo bash deb/suap-prod.sh
sudo bash rpm/suap-prod.sh
sudo bash arch/suap-prod.sh

# Infraestrutura
bash deb/install-redis.sh
bash deb/install-nginx.sh
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
| `PYTHON_VERSION` | Versão do Python | `3.12` | `3.12` |
| `BASE_DIR` | Diretório base para instalação | `$HOME/Projetos` | `/opt` |
| `SUAP_DIR` | Diretório do código SUAP | `${BASE_DIR}/suap` | `${BASE_DIR}/suap` |
| `VENV_DIR` | Diretório do virtualenv | `${SUAP_DIR}/.venv` | `/opt/venv` |
| `GIT_URL` | URL do repositório Git | *(obrigatório)* | *(obrigatório)* |
| `GUNICORN_WORKERS` | Workers do Gunicorn | — | `5` |
| `GUNICORN_THREADS` | Threads por worker | — | `1` |
| `CELERY_BROKER_URL` | URL do broker Redis | — | `redis://127.0.0.1:6379/3` |
| `CELERY_FLOWER_AUTH` | Autenticação do Flower | — | `admin:admin` |
| `CELERY_MAX_WORKERS` | Máximo de workers Celery | — | `5` |
| `CELERY_MIN_WORKERS` | Mínimo de workers Celery | — | `2` |

## Scripts disponíveis

| Script | Plataforma | Descrição |
|--------|------------|-----------|
| `setup.sh` | Todas | Wrapper interativo com detecção de OS |
| `deb/suap-dev.sh` | Debian/Ubuntu | Ambiente de desenvolvimento |
| `rpm/suap-dev.sh` | Fedora/RHEL | Ambiente de desenvolvimento |
| `arch/suap-dev.sh` | Arch Linux | Ambiente de desenvolvimento |
| `macos/suap-dev.sh` | macOS | Ambiente de desenvolvimento |
| `deb/suap-prod.sh` | Debian/Ubuntu | Ambiente de produção |
| `rpm/suap-prod.sh` | Fedora/RHEL | Ambiente de produção |
| `arch/suap-prod.sh` | Arch Linux | Ambiente de produção |
| `deb/install-redis.sh` | Debian/Ubuntu | Instala e habilita Redis |
| `rpm/install-redis.sh` | Fedora/RHEL | Instala e habilita Redis |
| `arch/install-redis.sh` | Arch Linux | Instala e habilita Redis |
| `deb/install-nginx.sh` | Debian/Ubuntu | Instala Nginx e configura proxy SUAP |
| `rpm/install-nginx.sh` | Fedora/RHEL | Instala Nginx e configura proxy SUAP |
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
- Criação de virtualenv com Python 3.12
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
- Ajuste de permissões (`chown www-data`)

### Caminhos do Supervisor por distribuição

| Distribuição | Diretório de configuração |
|-------------|--------------------------|
| Debian/Ubuntu | `/etc/supervisor/conf.d/` |
| Fedora/RHEL | `/etc/supervisord.d/` |
| Arch Linux | `/etc/supervisor.d/` |

## Docker

### Desenvolvimento (Docker)

Serviços em `docker/dev/docker-compose.yml`:

| Serviço | Imagem | Porta | Descrição |
|---------|--------|-------|-----------|
| `suap` | Build local | 8000 | Aplicação SUAP com hot-reload |
| `db` | postgres:16 | 5432 | Banco de dados PostgreSQL |
| `redis` | redis:7-alpine | 6379 | Cache Redis |

O código-fonte é montado como volume para edição em tempo real.

```bash
# Iniciar
bash docker/dev/docker-setup.sh

# Logs
docker compose -f docker/dev/docker-compose.yml logs -f suap

# Parar
docker compose -f docker/dev/docker-compose.yml down
```

### Produção (Docker)

Serviços em `docker/prod/docker-compose.prod.yml`:

| Serviço | Descrição |
|---------|-----------|
| `suap` | Aplicação SUAP (Gunicorn) |
| `celery-worker` | Worker do Celery |
| `celery-beat` | Scheduler do Celery |
| `celery-flower` | Monitor do Celery (porta 5555) |
| `redis` | Cache Redis |
| `nginx` | Proxy reverso (portas 80 e 8001) |

Todos os serviços possuem `restart: unless-stopped`. Volumes persistentes para static, media e logs.

```bash
# Iniciar
bash docker/prod/docker-setup.sh

# Status
docker compose -f docker/prod/docker-compose.prod.yml ps

# Parar
docker compose -f docker/prod/docker-compose.prod.yml down
```

### Instalação do Docker

O script `docker/install-docker.sh` instala Docker Engine e Docker Compose automaticamente:

- **Debian/Ubuntu**: adiciona repositório oficial Docker e instala via apt
- **Fedora/RHEL**: adiciona repositório oficial Docker e instala via dnf
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
| Fedora/RHEL | `/etc/nginx/conf.d/suap.conf` |
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
│   ├── install-redis.sh
│   └── install-nginx.sh
├── rpm/                              # Fedora/RHEL/CentOS
│   ├── suap-dev.sh
│   ├── suap-prod.sh
│   ├── install-redis.sh
│   └── install-nginx.sh
├── arch/                             # Arch/Manjaro/EndeavourOS
│   ├── suap-dev.sh
│   ├── suap-prod.sh
│   ├── install-redis.sh
│   └── install-nginx.sh
├── macos/                            # macOS (apenas dev)
│   └── suap-dev.sh
├── docker/
│   ├── install-docker.sh             # Instalação do Docker
│   ├── dockhand-setup.sh             # Dockhand
│   ├── dev/
│   │   ├── Dockerfile
│   │   ├── docker-compose.yml
│   │   └── docker-setup.sh
│   └── prod/
│       ├── Dockerfile
│       ├── docker-compose.prod.yml
│       └── docker-setup.sh
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

- Scripts são **idempotentes**: etapas já concluídas são puladas com mensagens amarelas.
- **Halt em falhas críticas**: se a instalação de pacotes ou dependências Python falhar, o script encerra imediatamente.
- **Supervisorctl condicional**: `supervisorctl reread/update` só executa quando arquivos foram efetivamente copiados.
- **Remoção condicional do nginx default** (Debian): o link `sites-enabled/default` só é removido após a config do SUAP ser ativada.
- **Detecção inteligente de UV**: verifica `~/.cargo/bin/uv` e `~/.local/bin/uv` antes de baixar.
- **Docker auto-install**: se Docker não estiver disponível, os scripts Docker oferecem instalação automática.
- As opções Docker funcionam em qualquer sistema com Docker, independente da distribuição.

## Licença

Veja o arquivo [LICENSE](LICENSE).
