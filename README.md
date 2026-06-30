# SUAP Setup

## Introdução

Este repositório reúne scripts de automação para preparar ambientes SUAP em sistemas Linux, com suporte para distribuições Debian-like e RPM-like, além de ambientes containerizados com Docker.

Os scripts automatizam a instalação de dependências, configuração de ambiente Python, download/atualização do código SUAP, implantação de serviços de produção via Supervisor e orquestração de containers Docker.

## Pré-requisitos

- Acesso ao repositório GitLab do SUAP
- Conexão com a internet
- Permissões de `sudo`
- Sistema suportado: Debian/Ubuntu ou Fedora/RHEL/CentOS
- Para opções Docker: Docker e Docker Compose instalados

## Organização do repositório

- `setup.sh`: wrapper interativo que detecta a família da distribuição e escolhe o script correto.
- `lib/common.sh`: funções utilitárias compartilhadas (carregamento de .env, detecção de distro, output colorido, verificações idempotentes).
- `.env`: arquivo centralizado com variáveis de configuração compartilhadas entre todos os scripts.
- `deb/`: scripts específicos para Debian/Ubuntu.
- `rpm/`: scripts específicos para Fedora/RHEL/CentOS.
- `docker/dev/`: Dockerfile, Compose e script de setup para ambiente de desenvolvimento Docker.
- `docker/prod/`: Dockerfile, Compose e script de setup para ambiente de produção Docker.
- `docker/dockhand-setup.sh`: script para iniciar o Dockhand (interface web de gerenciamento Docker).
- `nginx/`: configurações Nginx para SUAP (nativo e Docker).
- `supervisor/`: arquivos de configuração e scripts de execução para Supervisor.
- `tests/`: testes automatizados (unitários, propriedade, fumaça e integração).

## Scripts disponíveis

| Script | Ambiente | Descrição |
|--------|----------|-----------|
| `setup.sh` | Wrapper | Detecta a distro e executa o script correto para dev/prod, Redis, Nginx ou Docker |
| `deb/suap-dev.sh` | Desenvolvimento | Configura ambiente de desenvolvimento SUAP em Debian/Ubuntu |
| `rpm/suap-dev.sh` | Desenvolvimento | Configura ambiente de desenvolvimento SUAP em Fedora/RHEL |
| `deb/suap-prod.sh` | Produção | Configura ambiente de produção SUAP em Debian/Ubuntu |
| `rpm/suap-prod.sh` | Produção | Configura ambiente de produção SUAP em Fedora/RHEL |
| `deb/install-redis.sh` | Infraestrutura | Instala e habilita Redis em Debian/Ubuntu |
| `rpm/install-redis.sh` | Infraestrutura | Instala e habilita Redis em Fedora/RHEL |
| `deb/install-nginx.sh` | Infraestrutura | Instala e habilita Nginx e deploya configuração SUAP em Debian/Ubuntu |
| `rpm/install-nginx.sh` | Infraestrutura | Instala e habilita Nginx e deploya configuração SUAP em Fedora/RHEL |
| `docker/dev/docker-setup.sh` | Docker Dev | Constrói e inicia containers para desenvolvimento |
| `docker/prod/docker-setup.sh` | Docker Prod | Constrói e inicia containers para produção |
| `docker/dockhand-setup.sh` | Docker | Inicia o Dockhand para gerenciamento de containers via web |

## Funcionalidades principais

### Wrapper cross-distro

`setup.sh` oferece um menu com as opções:

1. Configurar ambiente de desenvolvimento
2. Configurar ambiente de produção
3. Instalar Redis
4. Instalar Nginx
5. Configurar ambiente dev via Docker
6. Configurar ambiente prod via Docker
7. Iniciar Dockhand

O script detecta automaticamente se o sistema é Debian-like ou RPM-like usando `/etc/os-release` e chama o script equivalente em `deb/` ou `rpm/`. Para as opções Docker (5, 6 e 7), não há dependência de distribuição — os scripts Docker funcionam em qualquer sistema com Docker e Docker Compose instalados.

### Variáveis de ambiente centralizadas (`.env`)

Todas as variáveis compartilhadas entre os scripts são definidas no arquivo `.env` na raiz do repositório. Se o arquivo não existir ao executar `setup.sh`, ele será criado automaticamente com valores padrão.

| Variável | Descrição | Valor padrão |
|----------|-----------|--------------|
| `PYTHON_VERSION` | Versão do Python a ser utilizada | `3.12` |
| `BASE_DIR` | Diretório base para instalação | `/opt` |
| `SUAP_DIR` | Diretório onde o código SUAP será clonado | `${BASE_DIR}/suap` |
| `VENV_DIR` | Diretório do virtualenv | `${BASE_DIR}/venv` |
| `GIT_URL` | URL do repositório Git do SUAP | *(vazio — solicitado na primeira execução)* |

Para ambientes de desenvolvimento, os valores típicos são:

```ini
PYTHON_VERSION=3.12
BASE_DIR=$HOME/Projetos
SUAP_DIR=${BASE_DIR}/suap
VENV_DIR=${SUAP_DIR}/.venv
GIT_URL=
```

### Ambiente de desenvolvimento

Os scripts de desenvolvimento realizam:

- instalação de dependências do sistema
- configuração de locale para `pt_BR.UTF-8`
- configuração de timezone `America/Fortaleza`
- instalação de `uv`
- clone ou atualização do código SUAP
- geração de `settings.py` e `.env` quando necessário
- criação de virtualenv para Python 3.12
- instalação de dependências do grupo `dev`

### Ambiente de produção

Os scripts de produção realizam:

- instalação de dependências do sistema
- configuração de locale para `pt_BR.UTF-8`
- configuração de timezone `America/Fortaleza`
- clone ou atualização do código SUAP
- geração de `settings.py` e `.env` quando necessário
- criação de virtualenv com `python3 -m venv`
- instalação de dependências do grupo `prod`
- menu interativo para configurar Supervisor para:
  - SUAP
  - Celery
  - SUAP + Celery
- deploy dos arquivos de configuração do Supervisor
- recarga do Supervisor
- ajuste de permissões em diretórios importantes

### Docker — Desenvolvimento (opção 5)

O ambiente Docker de desenvolvimento utiliza `docker/dev/docker-compose.yml` e provê os seguintes serviços:

| Serviço | Imagem | Porta | Descrição |
|---------|--------|-------|-----------|
| `suap` | Build local | 8000 | Aplicação SUAP com hot-reload |
| `db` | postgres:16 | 5432 | Banco de dados PostgreSQL |
| `redis` | redis:7-alpine | 6379 | Cache Redis |

O código-fonte é montado como volume, permitindo edição em tempo real no host. Variáveis de ambiente são lidas do `.env` centralizado.

```bash
# Iniciar via wrapper
bash setup.sh  # Selecionar opção 5

# Ou diretamente
bash docker/dev/docker-setup.sh
```

### Docker — Produção (opção 6)

O ambiente Docker de produção utiliza `docker/prod/docker-compose.prod.yml` e provê os seguintes serviços:

| Serviço | Descrição |
|---------|-----------|
| `suap` | Aplicação SUAP (Gunicorn) |
| `celery-worker` | Worker do Celery |
| `celery-beat` | Scheduler do Celery |
| `celery-flower` | Monitor do Celery (porta 5555) |
| `redis` | Cache Redis |
| `nginx` | Proxy reverso (portas 80 e 8001) |

Todos os serviços possuem política de restart `unless-stopped`. Volumes persistentes são configurados para dados estáticos, mídia e logs.

```bash
# Iniciar via wrapper
bash setup.sh  # Selecionar opção 6

# Ou diretamente
bash docker/prod/docker-setup.sh
```

### Dockhand — Gerenciamento de containers (opção 7)

O [Dockhand](https://dockhand.pro/) é uma interface web para gerenciamento de containers Docker. O script `docker/dockhand-setup.sh` automatiza o download e execução do Dockhand como container, sem necessidade de instalação adicional.

| Propriedade | Valor |
|-------------|-------|
| Imagem | `lscr.io/linuxserver/dockhand:latest` |
| Porta de acesso | `http://localhost:9093` |
| Socket Docker | `/var/run/docker.sock` montado como volume |
| Restart policy | `unless-stopped` |

O script é idempotente: se o container Dockhand já estiver em execução, exibe apenas a URL de acesso sem tentar criar outro.

```bash
# Iniciar via wrapper
bash setup.sh  # Selecionar opção 7

# Ou diretamente
bash docker/dockhand-setup.sh
```

### Configuração Nginx para Docker (`nginx/suap.docker`)

O arquivo `nginx/suap.docker` é uma configuração Nginx específica para ambientes Docker. Diferente do `nginx/suap` (que usa `127.0.0.1`), o `nginx/suap.docker` utiliza nomes de serviço do Docker Compose para resolução de upstream:

```nginx
upstream suap_server {
    least_conn;
    server suap:8000;  # Nome do serviço Docker em vez de IP
}
```

Características da configuração Docker:

- Upstream com balanceamento `least_conn` apontando para o container `suap`
- Servidor principal na porta 80 e secundário na porta 8001
- Servição de arquivos estáticos e mídia diretamente via Nginx
- Buffers de proxy aumentados para cabeçalhos HTTP grandes
- Log customizado com tempos de requisição e upstream
- Páginas de erro customizadas (500, 502, 503, 504, 413)

### Infraestrutura

Os scripts de infraestrutura instalam e configuram:

- Redis (`deb/install-redis.sh` e `rpm/install-redis.sh`)
- Nginx e configuração SUAP (`deb/install-nginx.sh` e `rpm/install-nginx.sh`)

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

### 3. Executar um script diretamente

```bash
# Desenvolvimento nativo
bash deb/suap-dev.sh
bash rpm/suap-dev.sh

# Produção nativa (requer root)
sudo bash deb/suap-prod.sh
sudo bash rpm/suap-prod.sh

# Infraestrutura
bash deb/install-redis.sh
bash rpm/install-redis.sh
bash deb/install-nginx.sh
bash rpm/install-nginx.sh

# Docker
bash docker/dev/docker-setup.sh
bash docker/prod/docker-setup.sh
bash docker/dockhand-setup.sh
```

> Observação: os scripts de produção devem ser executados como root. Os scripts Docker requerem Docker e Docker Compose instalados.

## Testes

O projeto utiliza [bats-core](https://github.com/bats-core/bats-core) como framework de testes. Os testes são organizados em categorias e podem ser executados via `tests/run_tests.sh`.

### Executar testes

```bash
# Todos os testes (exceto integração)
./tests/run_tests.sh

# Apenas testes unitários
./tests/run_tests.sh unit

# Apenas testes de propriedade
./tests/run_tests.sh property

# Apenas testes de fumaça (validação estática de configs)
./tests/run_tests.sh smoke

# Apenas testes de integração (requerem Docker)
./tests/run_tests.sh integration

# Todos os testes incluindo integração
./tests/run_tests.sh all
```

### Estrutura de testes

| Diretório | Tipo | Descrição |
|-----------|------|-----------|
| `tests/unit/` | Unitários | Testam funções isoladas (carregamento de .env, detecção de distro, roteamento) |
| `tests/property/` | Propriedade | Validam propriedades com inputs gerados aleatoriamente (mínimo 100 iterações) |
| `tests/smoke/` | Fumaça | Validação estática de configs (nginx, docker-compose, supervisor) |
| `tests/integration/` | Integração | Fluxos completos em containers Docker isolados |

> Pré-requisito: executar `git submodule update --init --recursive` para instalar bats-core e bibliotecas auxiliares.

## Estrutura do repositório

```
suap-setup/
├── .env                              # Variáveis centralizadas
├── setup.sh                          # Wrapper principal
├── lib/
│   └── common.sh                     # Funções utilitárias compartilhadas
├── deb/
│   ├── suap-dev.sh                   # Dev - Debian/Ubuntu
│   ├── suap-prod.sh                  # Prod - Debian/Ubuntu
│   ├── install-redis.sh              # Redis - Debian/Ubuntu
│   └── install-nginx.sh              # Nginx - Debian/Ubuntu
├── rpm/
│   ├── suap-dev.sh                   # Dev - Fedora/RHEL
│   ├── suap-prod.sh                  # Prod - Fedora/RHEL
│   ├── install-redis.sh              # Redis - Fedora/RHEL
│   └── install-nginx.sh              # Nginx - Fedora/RHEL
├── docker/
│   ├── dev/
│   │   ├── Dockerfile                # Imagem dev
│   │   ├── docker-compose.yml        # Compose dev (suap, db, redis)
│   │   └── docker-setup.sh           # Script de setup Docker dev
│   ├── prod/
│   │   ├── Dockerfile                # Imagem prod (multi-stage)
│   │   ├── docker-compose.prod.yml   # Compose prod (suap, celery, redis, nginx)
│   │   └── docker-setup.sh           # Script de setup Docker prod
│   └── dockhand-setup.sh             # Script de setup Dockhand
├── nginx/
│   ├── suap                          # Config Nginx para instalação nativa
│   └── suap.docker                   # Config Nginx para containers Docker
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
│   ├── run_tests.sh                  # Script auxiliar para execução de testes
│   ├── unit/                         # Testes unitários
│   ├── property/                     # Testes de propriedade
│   ├── smoke/                        # Testes de fumaça
│   ├── integration/                  # Testes de integração
│   └── test_helper/                  # bats-core e bibliotecas auxiliares
└── README.md
```

## Exemplos de uso

### Desenvolvimento nativo

```bash
cd $HOME/Projetos/suap
source .venv/bin/activate
uv run python manage.py runserver 0.0.0.0:8000
```

### Desenvolvimento Docker

```bash
# Iniciar ambiente
bash docker/dev/docker-setup.sh

# Ver logs
docker compose -f docker/dev/docker-compose.yml logs -f suap

# Parar
docker compose -f docker/dev/docker-compose.yml down
```

### Produção nativa

```bash
sudo supervisorctl status
sudo supervisorctl start suap
sudo supervisorctl start celery-worker
sudo supervisorctl start celery-beat
sudo supervisorctl start celery-flower
sudo supervisorctl start all
sudo supervisorctl stop all
sudo supervisorctl restart all
sudo supervisorctl tail suap
sudo supervisorctl tail celery-worker
```

### Produção Docker

```bash
# Iniciar ambiente
bash docker/prod/docker-setup.sh

# Ver status dos serviços
docker compose -f docker/prod/docker-compose.prod.yml ps

# Ver logs
docker compose -f docker/prod/docker-compose.prod.yml logs -f

# Parar
docker compose -f docker/prod/docker-compose.prod.yml down
```

## Observações

- `setup.sh` facilita a escolha do script certo para a família de distribuição.
- Os scripts são projetados para serem idempotentes, evitando repetição de etapas quando possível.
- A configuração de Supervisor e Nginx depende dos arquivos em `supervisor/` e `nginx/`.
- Para Docker, o arquivo `nginx/suap.docker` utiliza nomes de serviço do Compose para resolução DNS interna.
- As opções Docker (5, 6 e 7) não dependem da distribuição detectada — funcionam em qualquer sistema com Docker.

## Suporte

Para dúvidas ou sugestões, abra uma issue neste repositório.
