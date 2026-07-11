# Documentação Técnica — SUAP Setup

## Índice

1. [Visão Geral da Arquitetura](#visão-geral-da-arquitetura)
2. [Biblioteca Compartilhada (lib/common.sh)](#biblioteca-compartilhada)
3. [Wrapper Principal (setup.sh)](#wrapper-principal)
4. [Ambiente de Desenvolvimento — Nativo](#ambiente-de-desenvolvimento-nativo)
5. [Ambiente de Produção — Nativo](#ambiente-de-produção-nativo)
6. [Instalação de Redis](#instalação-de-redis)
7. [Instalação de Nginx](#instalação-de-nginx)
8. [Ambiente Docker — Desenvolvimento](#ambiente-docker-desenvolvimento)
9. [Ambiente Docker — Produção](#ambiente-docker-produção)
10. [Instalação do Docker](#instalação-do-docker)
11. [Dockhand — Gerenciamento Docker via Web](#dockhand)
12. [Configuração Nginx Detalhada](#configuração-nginx-detalhada)
13. [Configuração Supervisor Detalhada](#configuração-supervisor-detalhada)
14. [Variáveis de Ambiente](#variáveis-de-ambiente)
15. [Testes Automatizados](#testes-automatizados)

---

## Visão Geral da Arquitetura

O projeto suap-setup é uma coleção de scripts Bash que automatizam a configuração
completa do ambiente SUAP em múltiplas plataformas. A arquitetura segue o princípio
de separação de responsabilidades:

```
┌─────────────────────────────────────────────────────────────────────┐
│                        setup.sh (Wrapper)                           │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ 1. Carrega lib/common.sh                                     │  │
│  │ 2. Detecta OS/distribuição                                   │  │
│  │ 3. Exibe menu adaptativo                                     │  │
│  │ 4. Coleta variáveis via wizard interativo                    │  │
│  │ 5. Roteia para o script correto                              │  │
│  └───────────────────────────────────────────────────────────────┘  │
└───────────┬──────────┬──────────┬───────────┬───────────┬───────────┘
            │          │          │           │           │
      ┌─────▼───┐ ┌───▼───┐ ┌───▼───┐  ┌────▼────┐ ┌───▼──────┐
      │  deb/   │ │ rpm/  │ │ arch/ │  │ macos/  │ │ docker/  │
      │(Debian) │ │(RHEL) │ │(Arch) │  │(macOS)  │ │(Docker)  │
      └─────────┘ └───────┘ └───────┘  └─────────┘ └──────────┘
```

**Princípios de design:**

- **Detecção automática**: o wrapper identifica a plataforma e exibe apenas opções disponíveis
- **Idempotência**: toda etapa verifica o estado antes de agir; re-execuções são seguras
- **Centralização**: variáveis em `.env` único, funções em `lib/common.sh`
- **Feedback visual**: verde para ações, amarelo para pulos, vermelho para erros
- **Halt em falhas**: falhas críticas encerram imediatamente (sem estado inconsistente)

### Plataformas Suportadas

| Plataforma | Desenvolvimento | Produção | Redis | Nginx | Docker |
|------------|:-:|:-:|:-:|:-:|:-:|
| Debian/Ubuntu | ✅ | ✅ | ✅ | ✅ | ✅ |
| Fedora/RHEL/CentOS | ✅ | ✅ | ✅ | ✅ | ✅ |
| Arch/Manjaro/EndeavourOS | ✅ | ✅ | ✅ | ✅ | ✅ |
| macOS (Homebrew) | ✅ | ❌ | ❌ | ❌ | ✅ |

---

## Biblioteca Compartilhada

**Arquivo:** `lib/common.sh`

Módulo central sourced por todos os scripts. Provê funções reutilizáveis organizadas em categorias:

### Funções de Output

| Função | Cor | Uso |
|--------|-----|-----|
| `msg_action(msg)` | Verde | Ação sendo executada no momento |
| `msg_skip(msg)` | Amarelo | Etapa pulada (já concluída anteriormente) |
| `msg_error(msg)` | Vermelho | Erro que pode resultar em encerramento |

As cores são geradas via `tput` (compatível com qualquer terminal que suporte ANSI):

```bash
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
NO_COLOR=$(tput sgr0)
```

### Funções de Gerenciamento do .env

| Função | Descrição |
|--------|-----------|
| `require_env_file(path)` | Verifica existência; exit 1 se ausente |
| `load_env_file(path)` | Carrega variáveis com expansão de referências |
| `create_default_env(path)` | Cria .env com valores padrão (legado) |
| `interactive_env_wizard(path)` | Wizard interativo para criação do .env |
| `ensure_env_for_option(path, option)` | Coleta apenas variáveis necessárias para a opção |
| `resolve_git_url(path)` | Garante GIT_URL disponível (lê do .env ou solicita) |

**Fluxo do `ensure_env_for_option`:**

1. Carrega .env existente (se houver)
2. Verifica quais variáveis estão faltando para a opção escolhida
3. Solicita apenas as variáveis ausentes via prompt interativo
4. Grava o .env atualizado com comentários descritivos
5. Exibe confirmação com os valores configurados

### Funções de Detecção de Sistema

| Função | Descrição |
|--------|-----------|
| `detect_distro()` | Define `DISTRO_TYPE` e `DISTRO_NAME` |
| `get_supervisor_conf_dir()` | Retorna caminho do Supervisor por distro |
| `get_nginx_conf_path()` | Retorna caminho de destino do Nginx |
| `is_pkg_installed(pkg)` | Verifica se pacote está instalado |
| `check_all_packages_installed(...)` | Verifica lista de pacotes |
| `check_docker_available()` | Verifica Docker + oferece instalação |

**Algoritmo de detecção (`detect_distro`):**

```
1. uname -s == "Darwin" → DISTRO_TYPE="macos"
2. Caso contrário, ler /etc/os-release:
   - ID ou ID_LIKE contém "debian" ou "ubuntu" → "deb"
   - ID ou ID_LIKE contém "rhel", "fedora" ou "centos" → "rpm"
   - ID ou ID_LIKE contém "arch" → "arch"
   - Nenhum match → exit 3 (não suportada)
3. Se /etc/os-release não existe e não é macOS → exit 3
```

---

## Wrapper Principal

**Arquivo:** `setup.sh`

Ponto de entrada único do projeto. Automatiza toda a cadeia de configuração.

### Fluxo de Execução Detalhado

```
1. Determina SCRIPT_DIR (diretório raiz do repositório)
2. Source lib/common.sh (carrega todas as funções utilitárias)
3. Detecta distribuição/OS via detect_distro()
4. Exibe menu adaptativo conforme plataforma:
   - Linux: 7 opções (dev, prod, redis, nginx, docker dev, docker prod, dockhand)
   - macOS: 4 opções (dev, docker dev, docker prod, dockhand)
5. Valida entrada do usuário
6. Remapeia opções do macOS para índices internos
7. Coleta variáveis via ensure_env_for_option (wizard se necessário)
8. Carrega .env completo com load_env_file
9. Determina path do script alvo baseado em DISTRO_TYPE + opção
10. Verifica existência do script (exit 2 se não encontrado)
11. Executa o script via bash
```

### Mapeamento de Opções

**Linux (mapeamento direto):**

| Opção | Script | Variáveis necessárias |
|-------|--------|----------------------|
| 1 | `{distro}/suap-dev.sh` | PYTHON_VERSION, BASE_DIR, SUAP_DIR, VENV_DIR, GIT_URL |
| 2 | `{distro}/suap-prod.sh` | Todas as de dev + GUNICORN_*, CELERY_* |
| 3 | `{distro}/install-redis.sh` | Nenhuma |
| 4 | `{distro}/install-nginx.sh` | Nenhuma |
| 5 | `docker/dev/docker-setup.sh` | PYTHON_VERSION, GIT_URL |
| 6 | `docker/prod/docker-setup.sh` | PYTHON_VERSION, GIT_URL |
| 7 | `docker/dockhand-setup.sh` | Nenhuma |

**macOS (com remapeamento):**

| Opção exibida | Opção interna | Script |
|:---:|:---:|--------|
| 1 | 1 | `macos/suap-dev.sh` |
| 2 | 5 | `docker/dev/docker-setup.sh` |
| 3 | 6 | `docker/prod/docker-setup.sh` |
| 4 | 7 | `docker/dockhand-setup.sh` |

---

## Ambiente de Desenvolvimento Nativo

**Arquivos:** `deb/suap-dev.sh`, `rpm/suap-dev.sh`, `arch/suap-dev.sh`, `macos/suap-dev.sh`

Configura um ambiente completo de desenvolvimento local com todas as dependências
necessárias para compilar e executar o SUAP.

### Pré-requisitos

- Acesso à internet
- Permissões de sudo (para instalar pacotes do sistema)
- URL do repositório Git do SUAP
- `.env` configurado (gerado pelo wrapper na primeira execução)

### Etapas Passo a Passo

#### Etapa 1 — Carregamento de Configuração

```
1. Source lib/common.sh
2. require_env_file() → verifica se .env existe (exit 1 se não)
3. load_env_file() → carrega variáveis centralizadas
4. Define valores padrão de desenvolvimento:
   - BASE_DIR = $HOME/Projetos
   - SUAP_DIR = $BASE_DIR/suap
   - VENV_DIR = $SUAP_DIR/.venv
   - PYTHON_VERSION = 3.12
5. resolve_git_url() → garante GIT_URL disponível
```

#### Etapa 2 — Instalação de Dependências do Sistema

O script verifica se TODOS os pacotes estão instalados antes de executar o
gerenciador de pacotes. Se ao menos um pacote estiver faltando, instala todos.

**Pacotes instalados (Debian/Ubuntu via apt):**

| Categoria | Pacotes |
|-----------|---------|
| Compilação e utilitários | `locales`, `vim`, `git`, `build-essential`, `language-pack-pt`, `openssl`, `curl`, `wget`, `libpq-dev`, `tmpreaper`, `swig` |
| LDAP | `libldap2-dev`, `libsasl2-dev` |
| Pillow (imagens) | `libjpeg-dev`, `libpng-dev`, `zlib1g-dev`, `libfreetype6-dev` |
| PyMSSQL | `freetds-dev` |
| lxml (XML/HTML) | `libxml2-dev`, `libxslt1-dev`, `libxmlsec1-dev` |
| WeasyPrint (PDF) | `libcairo2-dev`, `libpango1.0-dev`, `libgdk-pixbuf2.0-dev`, `libffi-dev` |
| PDF tools | `poppler-utils` |
| Python headers | `python3-dev` |

**Pacotes equivalentes (Fedora/RHEL via dnf):**

| Categoria | Pacotes |
|-----------|---------|
| Compilação e utilitários | `vim`, `git`, `gcc`, `gcc-c++`, `make`, `openssl-devel`, `curl`, `wget`, `libpq-devel`, `swig` |
| LDAP | `openldap-devel` |
| Pillow | `libjpeg-turbo-devel`, `libpng-devel`, `zlib-devel`, `freetype-devel` |
| PyMSSQL | `freetds-devel` |
| lxml | `libxml2-devel`, `libxslt-devel`, `xmlsec1-devel` |
| WeasyPrint | `cairo-devel`, `pango-devel`, `gdk-pixbuf2-devel`, `libffi-devel` |
| PDF tools | `poppler-utils` |
| Python headers | `python3-devel` |

**Pacotes equivalentes (Arch Linux via pacman):**

| Categoria | Pacotes |
|-----------|---------|
| Compilação | `base-devel`, `git`, `openssl`, `curl`, `wget`, `postgresql-libs`, `swig` |
| LDAP | `libldap` |
| Pillow | `libjpeg-turbo`, `libpng`, `zlib`, `freetype2` |
| PyMSSQL | `freetds` |
| lxml | `libxml2`, `libxslt`, `xmlsec` |
| WeasyPrint | `cairo`, `pango`, `gdk-pixbuf2`, `libffi` |
| PDF tools | `poppler` |
| Python | `python` |

**Pacotes equivalentes (macOS via Homebrew):**

| Categoria | Pacotes |
|-----------|---------|
| Compilação | `openssl`, `curl`, `wget`, `libpq`, `swig` |
| LDAP | `openldap` |
| Pillow | `jpeg`, `libpng`, `zlib`, `freetype` |
| PyMSSQL | `freetds` |
| lxml | `libxml2`, `libxslt`, `xmlsec1` |
| WeasyPrint | `cairo`, `pango`, `gdk-pixbuf`, `libffi` |
| PDF tools | `poppler` |

> **Comportamento em caso de falha:** Se o gerenciador de pacotes retorna erro
> (exit code ≠ 0), o script exibe `msg_error` e encerra com exit 1 imediatamente.

#### Etapa 3 — Configuração de Locale

Configura o locale do sistema para `pt_BR.UTF-8` (necessário para formatação
de datas, moedas e ordenação de texto em português).

| Plataforma | Comando |
|------------|---------|
| Debian/Ubuntu | `sudo locale-gen pt_BR.UTF-8 && sudo update-locale LANG=pt_BR.UTF-8` |
| Fedora/RHEL | `sudo localectl set-locale LANG=pt_BR.UTF-8` |
| Arch Linux | `sudo localectl set-locale LANG=pt_BR.UTF-8` |
| macOS | Pulado com `msg_skip` (locale não necessário) |

**Idempotência:** verifica `locale | grep LANG=` antes de executar.

#### Etapa 4 — Configuração de Timezone

Define o timezone do sistema para `America/Fortaleza` (UTC-3).

| Plataforma | Comando |
|------------|---------|
| Linux (todas) | `sudo timedatectl set-timezone America/Fortaleza` |
| macOS | `sudo systemsetup -settimezone America/Fortaleza` |

**Idempotência:** verifica `timedatectl show -p Timezone --value` antes de executar.

#### Etapa 5 — Instalação do UV

[UV](https://docs.astral.sh/uv/) é um gerenciador de pacotes Python ultrarrápido
(substituto do pip/pip-tools/virtualenv).

**Algoritmo de detecção:**

```
1. Verificar se `uv` está no PATH → pular
2. Verificar ~/.cargo/bin/uv → adicionar ao PATH
3. Verificar ~/.local/bin/uv → adicionar ao PATH
4. Nenhum encontrado → baixar de https://astral.sh/uv/install.sh
5. Adicionar auto-completar ao .bashrc (se não existir)
```

#### Etapa 6 — Clone/Pull do Repositório SUAP

| Cenário | Ação |
|---------|------|
| Diretório não existe | `mkdir -p $BASE_DIR && git clone $GIT_URL suap` |
| Diretório já tem .git | `git checkout master && git pull` |

#### Etapa 7 — Geração de Arquivos de Configuração

O SUAP possui arquivos sample que servem de template:

| Arquivo destino | Arquivo fonte | Condição |
|-----------------|---------------|----------|
| `suap/settings.py` | `suap/settings_sample.py` | Só copia se não existir |
| `.env` (do SUAP) | `.env.dev.sample` | Só copia se não existir |

> **Importante:** Arquivos existentes NUNCA são sobrescritos. Isso preserva
> configurações customizadas pelo desenvolvedor.

#### Etapa 8 — Instalação do Python via UV

```bash
# Verifica se a versão está instalada
uv python list --only-installed | grep "3.12"

# Se não estiver, instala
uv python install 3.12
```

#### Etapa 9 — Criação do Virtualenv

```bash
# Só cria se o diretório .venv não existir
cd $SUAP_DIR
uv venv --python 3.12
```

#### Etapa 10 — Instalação de Dependências Python

O script detecta automaticamente o formato de gerenciamento de dependências:

| Cenário | Comando |
|---------|---------|
| `pyproject.toml` existe | `uv sync --group dev` |
| `requirements/` existe | `uv pip install -r requirements/development.txt` |
| Nenhum encontrado | exit 1 com erro |

> **Comportamento em caso de falha:** Se `uv sync` ou `uv pip install` retorna
> erro, o script encerra imediatamente com exit 1.

#### Etapa 11 — Mensagem Final

Exibe próximos passos para o desenvolvedor:

```
1. Recarregar bashrc:           source ~/.bashrc
2. Editar variáveis de ambiente: nano $SUAP_DIR/.env
3. Acessar o diretório:         cd $SUAP_DIR
4. Rodar servidor dev:          uv run python manage.py runserver 0.0.0.0:8000
```

---

## Ambiente de Produção Nativo

**Arquivos:** `deb/suap-prod.sh`, `rpm/suap-prod.sh`, `arch/suap-prod.sh`

Configura um servidor de produção completo com Gunicorn, Celery e Supervisor.

> **macOS não suporta ambiente de produção.** Opções de produção nativa são
> automaticamente ocultas no menu quando executado no macOS.

### Pré-requisitos

- Acesso root (o script usa `exec sudo` se necessário)
- Acesso à internet
- `.env` configurado com variáveis de produção

### Etapas Passo a Passo

#### Etapa 1 — Validação de Root

```bash
if [ "$EUID" -ne 0 ]; then
  exec sudo bash "$0" "$@"  # Re-executa como root
fi
```

Se o script não está rodando como root, ele se re-executa com `sudo` automaticamente.

#### Etapa 2 — Instalação de Dependências do Sistema

**Pacotes de produção adicionais (além dos de desenvolvimento):**

| Categoria | Pacotes (Debian) | Pacotes (RPM) | Pacotes (Arch) |
|-----------|-----------------|---------------|----------------|
| Servidor WSGI | — (instalado via pip) | — | — |
| Processos | `supervisor` | `supervisor` | `supervisor` |
| Agendamento | `cron` | `cronie` | `cronie` |
| Sincronização de tempo | `ntpdate` | `chrony` | `chrony` |
| Python runtime | `python3-dev`, `python3-venv`, `python3-pip` | `python3-devel`, `python3` | `python` |
| PDF (produção) | `qpdf`, `ghostscript`, `mupdf-tools`, `wkhtmltopdf` | equivalentes | equivalentes |
| Magic (tipo de arquivo) | `libmagic1` | `file-libs` | `file` |

#### Etapa 3 — Configuração de Locale e Timezone

Idêntico ao ambiente de desenvolvimento (Etapas 3 e 4 da seção anterior).

#### Etapa 4 — Clone do Código SUAP

| Cenário | Ação |
|---------|------|
| Primeiro deploy | `git clone --depth 1 $GIT_URL` (clone raso = mais rápido) |
| Atualização | `git checkout master && git pull` |

> O flag `--depth 1` economiza banda e espaço em disco — em produção o histórico
> completo não é necessário.

#### Etapa 5 — Geração de Configurações

Mesmo comportamento do ambiente de desenvolvimento: copia samples apenas se
os arquivos destino não existem. Adicionalmente:

```bash
# Copia .env centralizado para BASE_DIR (usado pelos runners do Supervisor)
cp "${SCRIPT_DIR}/.env" "${BASE_DIR}/.env"
```

#### Etapa 6 — Criação de Virtualenv e Instalação de Dependências

Em produção, o virtualenv é criado com UV (assim como em dev) mas em um diretório
separado (`/opt/venv` por padrão):

```bash
# Criar virtualenv
uv venv --python 3.12 /opt/venv

# Instalar dependências (com UV_PROJECT_ENVIRONMENT apontando para o venv externo)
export UV_PROJECT_ENVIRONMENT="/opt/venv"
uv sync --group prod
# ou
uv pip install --python /opt/venv/bin/python -r requirements/production.txt
```

Após a instalação de dependências:

```bash
# Coletar arquivos estáticos para o diretório de deploy
/opt/venv/bin/python manage.py collectstatic --noinput
```

#### Etapa 7 — Configuração do Supervisor

O script apresenta um menu interativo:

```
Qual serviço você deseja configurar no Supervisor?
1) SUAP (servidor web)
2) Celery (processamento de tarefas assíncronas)
3) Ambos (SUAP + Celery)
```

**Arquivos copiados por opção:**

| Opção | Arquivos .conf | Runners (.sh) |
|-------|---------------|---------------|
| 1 — SUAP | `suap.conf` | `run_suap.sh` |
| 2 — Celery | `celery_worker.conf`, `celery_beat.conf`, `celery_flower.conf` | `run_celery_worker.sh`, `run_celery_beat.sh`, `run_celery_flower.sh` |
| 3 — Ambos | Todos acima | Todos acima |

**Destino dos arquivos por distribuição:**

| Distribuição | Diretório de configuração | Serviço |
|-------------|--------------------------|---------|
| Debian/Ubuntu | `/etc/supervisor/conf.d/` | `supervisor` |
| Fedora/RHEL | `/etc/supervisord.d/` | `supervisord` |
| Arch Linux | `/etc/supervisor.d/` | `supervisord` |

**Pós-cópia:**

1. `chmod +x` em todos os runners
2. Ajuste de paths nos `.conf` para refletir `BASE_DIR` real
3. `supervisorctl reread && supervisorctl update` (SOMENTE se arquivos foram copiados)

> **Idempotência do Supervisor:** Se nenhum arquivo foi copiado (tudo já estava
> no lugar), o `supervisorctl reread/update` é pulado com `msg_skip`.

#### Etapa 8 — Ajuste de Permissões

```bash
chown -R www-data:www-data $SUAP_DIR
chown -R www-data:www-data $BASE_DIR/logs
chown -R www-data:www-data $VENV_DIR
```

Garante que o Supervisor (que executa como `www-data`) tenha acesso a todos os
diretórios necessários.

#### Etapa 9 — Mensagem Final

Exibe comandos de gerenciamento conforme a opção escolhida:

```bash
# SUAP
supervisorctl start suap

# Celery
supervisorctl start celery-worker celery-beat celery-flower

# Todos
supervisorctl start all
```

---

## Instalação de Redis

**Arquivos:** `deb/install-redis.sh`, `rpm/install-redis.sh`, `arch/install-redis.sh`

### O que é instalado

O [Redis](https://redis.io/) é um banco de dados em memória usado pelo SUAP como:
- Cache de sessões e dados
- Broker de mensagens para o Celery
- Backend de resultados do Celery

### Etapas

```
1. Source lib/common.sh
2. Verificar se pacote Redis já está instalado
   - Debian: pacote "redis-server"
   - RPM: pacote "redis"
   - Arch: pacote "redis"
3. Se não instalado → instalar via gerenciador de pacotes
4. systemctl start redis[-server]
5. systemctl enable redis[-server] (auto-start no boot)
6. Exibir status do serviço
```

**Porta padrão:** 6379

---

## Instalação de Nginx

**Arquivos:** `deb/install-nginx.sh`, `rpm/install-nginx.sh`, `arch/install-nginx.sh`

### O que é instalado

O [Nginx](https://nginx.org/) atua como proxy reverso para a aplicação SUAP,
servindo arquivos estáticos e de mídia diretamente e encaminhando requisições
dinâmicas para o Gunicorn.

### Etapas

```
1. Source lib/common.sh
2. Verificar se Nginx já está instalado
3. Se não → instalar via gerenciador de pacotes
4. systemctl start nginx
5. systemctl enable nginx
6. Copiar configuração do SUAP para o local correto:
   - Debian: /etc/nginx/sites-available/suap + link em sites-enabled
   - RPM/Arch: /etc/nginx/conf.d/suap.conf
7. [Debian only] Remover /etc/nginx/sites-enabled/default
   (SOMENTE após configuração do SUAP ser copiada com sucesso)
8. nginx -t (testar configuração)
9. systemctl reload nginx
```

> **Remoção condicional do default:** No Debian, o link `sites-enabled/default`
> só é removido APÓS a configuração do SUAP ter sido instalada E o link em
> `sites-enabled/suap` criado com sucesso. Se a cópia foi pulada por idempotência,
> o default NÃO é removido.

---

## Ambiente Docker — Desenvolvimento

**Arquivos:**
- `docker/dev/docker-setup.sh` — Script de orquestração
- `docker/dev/Dockerfile` — Imagem de desenvolvimento
- `docker/dev/docker-compose.yml` — Definição dos serviços

### Visão Geral

O ambiente Docker de desenvolvimento oferece uma alternativa isolada à instalação
nativa. Funciona em qualquer sistema com Docker, sem instalar dependências no host.

### Dockerfile de Desenvolvimento

**Imagem base:** `ghcr.io/astral-sh/uv:python{VERSION}-trixie-slim`

A imagem já vem com UV e Python pré-instalados. O Dockerfile:

1. Instala dependências de compilação do sistema (mesmo conjunto do script nativo)
2. Configura locale `pt_BR.UTF-8`
3. Instala dependências Python via `uv sync --locked --group dev`
4. Usa cache mount para acelerar builds subsequentes
5. Expõe porta 8000

**Build arg:** `PYTHON_VERSION` (padrão: 3.12) — permite trocar a versão do
Python sem editar o Dockerfile.

### Docker Compose — Serviços

| Serviço | Imagem | Porta | Volume | Descrição |
|---------|--------|-------|--------|-----------|
| `suap` | Build local | 8000 | `../../:/app` (bind mount) | Aplicação Django com hot-reload |
| `db` | `postgres:16` | 5432 | `pgdata` (named volume) | Banco de dados PostgreSQL |
| `redis` | `redis:7-alpine` | 6379 | — | Cache e broker Celery |

**Hot-reload:** O código-fonte é montado como volume bind (`../../:/app`),
permitindo editar arquivos no host e ver as mudanças refletidas imediatamente
no container (sem rebuild).

### Etapas do Script

```
1. Source lib/common.sh
2. require_env_file() → verifica .env
3. load_env_file() → carrega variáveis
4. check_docker_available() → verifica Docker (oferece instalar se ausente)
5. resolve_git_url() → garante GIT_URL
6. docker compose build --build-arg PYTHON_VERSION=3.12
7. docker compose up (foreground — logs visíveis no terminal)
8. Exibe URLs de acesso e comandos úteis
```

### Comandos Úteis

```bash
# Parar containers
docker compose -f docker/dev/docker-compose.yml down

# Ver logs
docker compose -f docker/dev/docker-compose.yml logs -f

# Acessar shell do container
docker compose -f docker/dev/docker-compose.yml exec suap bash

# Executar migrations
docker compose -f docker/dev/docker-compose.yml exec suap uv run python manage.py migrate
```

---

## Ambiente Docker — Produção

**Arquivos:**
- `docker/prod/docker-setup.sh` — Script de orquestração
- `docker/prod/Dockerfile` — Imagem de produção (multi-stage)
- `docker/prod/docker-compose.prod.yml` — Definição dos serviços

### Visão Geral

O ambiente Docker de produção fornece todos os serviços necessários em containers
isolados, com restart automático, volumes persistentes e Nginx como proxy reverso.

### Dockerfile de Produção (Multi-Stage Build)

**Stage 1 — Builder:**
- Imagem: `ghcr.io/astral-sh/uv:python{VERSION}-trixie-slim`
- Instala dependências de compilação
- Executa `uv sync --locked --no-install-project` (cache de dependências)
- Copia código e faz sync final
- Instala Gunicorn no venv

**Stage 2 — Runtime:**
- Imagem: `python:{VERSION}-slim-trixie` (sem UV, sem compiladores)
- Instala apenas bibliotecas de runtime (`.so` compartilhadas)
- Configura locale `pt_BR.UTF-8`
- Cria usuário não-root (`suap:999`)
- Copia `/app` do builder (inclui `.venv`)
- Expõe porta 8000
- CMD: Gunicorn com 4 workers, timeout 300s, logging em `/opt/logs/`

**Resultado:** Imagem final ~50% menor que uma imagem com ferramentas de build.

### Docker Compose — Serviços de Produção

| Serviço | Imagem | Portas | Restart | Descrição |
|---------|--------|--------|---------|-----------|
| `suap` | Build local | — (via nginx) | `unless-stopped` | Gunicorn servindo SUAP |
| `celery-worker` | Build local | — | `unless-stopped` | Processamento assíncrono |
| `celery-beat` | Build local | — | `unless-stopped` | Agendamento de tarefas |
| `celery-flower` | Build local | 5555 | `unless-stopped` | Monitor web do Celery |
| `redis` | `redis:7-alpine` | — | `unless-stopped` | Broker de mensagens |
| `nginx` | `nginx:alpine` | 80, 8001 | `unless-stopped` | Proxy reverso + static |

### Volumes Persistentes

| Volume | Montagem | Propósito |
|--------|----------|-----------|
| `static` | `/opt/suap/deploy/static` | Arquivos estáticos (CSS, JS, imagens) |
| `media` | `/opt/suap/deploy/media` | Uploads de usuários |
| `logs` | `/opt/logs` | Logs de Gunicorn e Celery |
| `pgdata` | (reservado) | Dados do PostgreSQL (se adicionado) |

### Nginx no Docker

O container Nginx usa `nginx/suap.docker` como configuração, que difere do
`nginx/suap` nativo no upstream:

```nginx
# nginx/suap.docker (Docker)
upstream suap_server {
    least_conn;
    server suap:8000;  # Nome do serviço Docker (DNS interno)
}

# nginx/suap (nativo)
upstream suap_server {
    least_conn;
    server 127.0.0.1:8000;  # Localhost
}
```

### Etapas do Script

```
1. Source lib/common.sh
2. require_env_file() → verifica .env
3. load_env_file() → carrega variáveis
4. check_docker_available() → verifica Docker
5. resolve_git_url() → garante GIT_URL
6. docker compose -f docker-compose.prod.yml build --build-arg PYTHON_VERSION=3.12
7. docker compose -f docker-compose.prod.yml up -d (detached)
8. docker compose -f docker-compose.prod.yml ps (exibe status)
9. Exibe URLs de acesso e comandos de gerenciamento
```

### Comandos de Gerenciamento

```bash
# Ver status
docker compose -f docker/prod/docker-compose.prod.yml ps

# Ver logs de todos os serviços
docker compose -f docker/prod/docker-compose.prod.yml logs -f

# Escalar workers do Celery
docker compose -f docker/prod/docker-compose.prod.yml up -d --scale celery-worker=3

# Reiniciar apenas o SUAP
docker compose -f docker/prod/docker-compose.prod.yml restart suap

# Parar tudo
docker compose -f docker/prod/docker-compose.prod.yml down

# Acessar shell da aplicação
docker compose -f docker/prod/docker-compose.prod.yml exec suap bash
```

---

## Instalação do Docker

**Arquivo:** `docker/install-docker.sh`

Script dedicado para instalação automatizada do Docker Engine e Docker Compose.
É invocado automaticamente quando `check_docker_available()` detecta que Docker
não está instalado e o usuário confirma a instalação.

### Etapas por Distribuição

**Debian/Ubuntu:**

```
1. Instalar dependências: ca-certificates, curl, gnupg
2. Adicionar chave GPG oficial do Docker
3. Adicionar repositório Docker ao apt sources
4. apt-get update
5. apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

**Fedora/RHEL:**

```
1. Instalar dnf-plugins-core
2. Adicionar repositório oficial Docker (docker-ce.repo)
3. dnf install docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

**Arch Linux:**

```
1. pacman -S --needed --noconfirm docker docker-compose
```

**macOS:**

```
1. Exibir mensagem informando que Docker Desktop é necessário
2. Exibir URL: https://docs.docker.com/desktop/install/mac-install/
3. exit 0 (sem instalação automática)
```

### Pós-Instalação (Linux)

```bash
# Iniciar e habilitar serviço
systemctl start docker
systemctl enable docker

# Adicionar usuário ao grupo docker (evita necessidade de sudo)
usermod -aG docker $USER

# Verificar instalação
docker --version
docker compose version
```

> **Nota:** É necessário fazer logout e login novamente para que a adição ao
> grupo `docker` tenha efeito.

---

## Dockhand

**Arquivo:** `docker/dockhand-setup.sh`

### O que é

O [Dockhand](https://dockhand.pro/) é uma interface web para gerenciamento
visual de containers Docker. Permite visualizar, iniciar, parar e inspecionar
containers através do navegador.

### Especificações Técnicas

| Propriedade | Valor |
|-------------|-------|
| Imagem | `lscr.io/linuxserver/dockhand:latest` |
| Porta host | 9093 |
| Porta container | 3000 |
| Docker Socket | `/var/run/docker.sock` montado como volume |
| Restart policy | `unless-stopped` |
| Nome do container | `dockhand` |

### Etapas

```
1. Source lib/common.sh
2. check_docker_available() → verifica Docker
3. Verificar se container "dockhand" já está ativo:
   - Se sim: msg_skip + exibir URL → exit 0
4. docker pull lscr.io/linuxserver/dockhand:latest
5. docker run -d --name dockhand -p 9093:3000 \
     -v /var/run/docker.sock:/var/run/docker.sock \
     --restart unless-stopped lscr.io/linuxserver/dockhand:latest
6. Verificar se container iniciou com sucesso
7. Exibir URL de acesso: http://localhost:9093
```

> **Idempotência:** Se o container `dockhand` já estiver rodando, o script
> apenas exibe a URL de acesso e encerra sem criar outro container.

---

## Configuração Nginx Detalhada

**Arquivo:** `nginx/suap`

### Blocos de Configuração

#### Log Format Customizado

```nginx
log_format suap_log '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent" '
                    'rt=$request_time uct=$upstream_connect_time '
                    'uht=$upstream_header_time urt=$upstream_response_time';
```

Inclui métricas de performance:
- `rt` — tempo total da requisição
- `uct` — tempo de conexão com o upstream
- `uht` — tempo até receber headers do upstream
- `urt` — tempo total de resposta do upstream

#### Upstream (Balanceamento)

```nginx
upstream suap_server {
    least_conn;           # Balanceia para o server com menos conexões
    server 127.0.0.1:8000;  # Gunicorn local
}
```

#### Servidor Principal (porta 80)

| Diretiva | Valor | Propósito |
|----------|-------|-----------|
| `client_max_body_size` | 100m | Permite uploads grandes (PDFs, planilhas) |
| `proxy_buffer_size` | 128k | Suporta headers HTTP grandes |
| `proxy_buffers` | 4 × 256k | Buffer para respostas do upstream |
| `proxy_read_timeout` | 300s | Timeout para relatórios longos |

#### Arquivos Estáticos e Mídia

```nginx
location /static/ {
    alias /opt/suap/deploy/static/;
    expires 30d;
    access_log off;
}

location /media/ {
    alias /opt/suap/deploy/media/;
    expires 30d;
    access_log off;
}
```

Servidos diretamente pelo Nginx (sem passar pelo Gunicorn), com cache de 30 dias.

#### Páginas de Erro Customizadas

```nginx
error_page 500 502 503 504 /500.html;
error_page 413 /413.html;
```

- 500/502/503/504 — Erro interno ou upstream indisponível
- 413 — Payload muito grande (acima de 100m)

#### Servidor Secundário (porta 8001)

Bloco idêntico ao principal mas na porta 8001. Usado para acesso administrativo
ou monitoramento separado.

---

## Configuração Supervisor Detalhada

### Arquivos de Configuração

#### `supervisor/suap.conf`

```ini
[program:suap]
directory = /opt/suap/
user = www-data
command = /opt/scripts/run_suap.sh
stdout_logfile = /opt/logs/suap_out.log
stderr_logfile = /opt/logs/suap_err.log
redirect_stderr = true
```

#### `supervisor/celery_worker.conf`

```ini
[program:celery_worker]
directory = /opt/suap/
user = www-data
command = /opt/scripts/run_celery_worker.sh
numprocs = 1
autostart = true
autorestart = unexpected
startsecs = 10
stopwaitsecs = 600      # Espera tarefas longas finalizarem
killasgroup = true      # Mata subprocessos também
stopasgroup = true
priority = 997
```

### Scripts Runner

Os runners são scripts intermediários que:
1. Determinam `BASE_DIR` automaticamente
2. Carregam variáveis do `.env` centralizado
3. Aplicam configurações dinâmicas (workers, threads, filas)
4. Executam o processo via `exec` (substituição de processo)

#### `run_suap.sh` — Gunicorn

```bash
exec $VENV_DIR/bin/gunicorn suap.wsgi:application \
  -w $GUNICORN_WORKERS \
  --threads $GUNICORN_THREADS \
  -b :8000 \
  --user=www-data --group=www-data \
  --log-level=info \
  --max-requests=2000 \          # Recicla workers após 2000 requisições
  --max-requests-jitter=100 \    # Jitter para evitar reinício simultâneo
  --timeout=600
```

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `GUNICORN_WORKERS` | 5 | Número de processos worker (recomendado: 2×CPUs + 1) |
| `GUNICORN_THREADS` | 1 | Threads por worker |

#### `run_celery_worker.sh` — Celery Worker

```bash
exec $VENV_DIR/bin/celery -A suap worker \
  --autoscale=$CELERY_MAX_WORKERS,$CELERY_MIN_WORKERS \
  -l INFO \
  -Q $CELERY_QUEUE
```

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `CELERY_MAX_WORKERS` | 5 | Máximo de workers (autoscale) |
| `CELERY_MIN_WORKERS` | 2 | Mínimo de workers (autoscale) |
| `CELERY_QUEUE` | `geral,celery_beat` | Filas monitoradas |

#### `run_celery_beat.sh` — Celery Beat (Scheduler)

Executa o scheduler do Celery que dispara tarefas periódicas conforme configurado
no código do SUAP.

#### `run_celery_flower.sh` — Celery Flower (Monitor)

Interface web para monitoramento de tarefas do Celery.

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `CELERY_BROKER_URL` | `redis://127.0.0.1:6379/3` | URL do Redis broker |
| `CELERY_FLOWER_AUTH` | `admin:admin` | Credenciais de acesso |

Acesso: `http://servidor:5555`

---

## Variáveis de Ambiente

### Arquivo `.env` Centralizado

Localizado na raiz do repositório suap-setup. Gerado pelo wizard interativo
na primeira execução do `setup.sh`.

### Variáveis de Desenvolvimento

| Variável | Tipo | Padrão | Descrição |
|----------|------|--------|-----------|
| `PYTHON_VERSION` | String | `3.12` | Versão do Python a instalar/usar |
| `BASE_DIR` | Path | `$HOME/Projetos` | Diretório raiz para projetos |
| `SUAP_DIR` | Path | `${BASE_DIR}/suap` | Diretório do código SUAP |
| `VENV_DIR` | Path | `${SUAP_DIR}/.venv` | Diretório do virtualenv |
| `GIT_URL` | URL | *(obrigatório)* | URL do repositório Git |

### Variáveis de Produção (adicionais)

| Variável | Tipo | Padrão | Descrição |
|----------|------|--------|-----------|
| `GUNICORN_WORKERS` | Int | `5` | Workers do Gunicorn (recomendado: 2n+1) |
| `GUNICORN_THREADS` | Int | `1` | Threads por worker |
| `CELERY_BROKER_URL` | URL | `redis://127.0.0.1:6379/3` | URL do broker Redis |
| `CELERY_FLOWER_AUTH` | String | `admin:admin` | Credenciais do Flower (user:pass) |
| `CELERY_MAX_WORKERS` | Int | `5` | Máximo de workers Celery (autoscale) |
| `CELERY_MIN_WORKERS` | Int | `2` | Mínimo de workers Celery (autoscale) |
| `CELERY_QUEUE` | String | `geral,celery_beat` | Filas do Celery (separadas por vírgula) |

### Exemplo Completo de .env

```ini
# =============================================================
# Configuração centralizada do suap-setup
# =============================================================

# Versão do Python a ser utilizada
PYTHON_VERSION=3.12

# Diretório base para instalação
BASE_DIR=/opt

# Diretório onde o código SUAP será clonado
SUAP_DIR=${BASE_DIR}/suap

# Diretório do virtualenv
VENV_DIR=${BASE_DIR}/venv

# URL do repositório Git do SUAP
GIT_URL=https://gitlab.exemplo.com/suap/suap.git

# --- Gunicorn (produção) ---
GUNICORN_WORKERS=5
GUNICORN_THREADS=1

# --- Celery (produção) ---
CELERY_BROKER_URL=redis://127.0.0.1:6379/3
CELERY_FLOWER_AUTH=admin:senhasegura
CELERY_MAX_WORKERS=5
CELERY_MIN_WORKERS=2
CELERY_QUEUE=geral,celery_beat
```

### Carregamento de Variáveis

O `load_env_file()` realiza expansão de variáveis durante o carregamento:

```
BASE_DIR=/opt           → BASE_DIR="/opt"
SUAP_DIR=${BASE_DIR}/suap  → SUAP_DIR="/opt/suap" (expandido)
VENV_DIR=${BASE_DIR}/venv  → VENV_DIR="/opt/venv" (expandido)
```

Isso permite que os valores referenciem variáveis definidas anteriormente no arquivo.

---

## Testes Automatizados

### Framework

O projeto usa [bats-core](https://github.com/bats-core/bats-core) (Bash Automated
Testing System) com as bibliotecas auxiliares:

- **bats-assert** — assertions (`assert_success`, `assert_output`, `assert_line`)
- **bats-support** — funções de suporte (`fail`, formatação de output)

Instalados como git submodules em `tests/test_helper/`.

### Execução

```bash
# Pré-requisito: instalar submodules
git submodule update --init --recursive

# Executar todos os testes (exceto integração)
./tests/run_tests.sh

# Por categoria
./tests/run_tests.sh unit
./tests/run_tests.sh property
./tests/run_tests.sh smoke
./tests/run_tests.sh integration  # requer Docker
./tests/run_tests.sh all
```

### Categorias de Teste

#### Testes Unitários (`tests/unit/`)

Testam funções individuais de `lib/common.sh` em isolamento:

| Arquivo | O que testa |
|---------|-------------|
| `test_common_functions.bats` | `msg_action`, `msg_skip`, `msg_error`, `is_pkg_installed`, `check_docker_available`, `load_env_file`, `resolve_git_url` |
| `test_dev_flow.bats` | Idempotência, geração de configs, detecção de deps |
| `test_prod_flow.bats` | Validação de root, menu Supervisor, permissões, clone |
| `test_interactive_wizard.bats` | Wizard interativo de .env |

#### Testes de Propriedade (`tests/property/`)

Validam propriedades universais com inputs gerados aleatoriamente (mínimo 100
iterações por propriedade):

| Propriedade | Arquivo | O que valida |
|:-:|---------|-------------|
| 1 | `test_env_roundtrip.bats` | Escrever e ler .env preserva valores |
| 2 | `test_distro_paths.bats` | Classificação de distro produz caminhos corretos |
| 3 | `test_routing.bats` | Roteamento do menu mapeia corretamente |
| 4 | `test_idempotency.bats` | Segunda execução pula etapas |
| 5 | (em `test_dockhand.bats`) | Re-execução do Dockhand é idempotente |
| 6 | `test_env_roundtrip.bats` | Round-trip do wizard preserva valores |
| 7 | `test_env_roundtrip.bats` | Fallback de .env encerra com exit 1 |
| 8 | `test_msg_action.bats` | Todos os scripts usam msg_action |

#### Testes de Fumaça (`tests/smoke/`)

Validação estática de arquivos de configuração (não executam os scripts):

| Arquivo | O que valida |
|---------|-------------|
| `test_nginx_config.bats` | Diretivas do `nginx/suap` (upstream, ports, buffers) |
| `test_supervisor_confs.bats` | Formato dos `.conf` do Supervisor |
| `test_docker.bats` | YAML dos docker-compose, Dockerfiles |
| `test_dockhand.bats` | Script do Dockhand (source, idempotência, porta) |
| `test_install_docker.bats` | Script install-docker.sh (cases por distro) |

#### Testes de Integração (`tests/integration/`)

Executam fluxos completos em containers Docker isolados:

| Arquivo | Cenário |
|---------|---------|
| `test_dev_debian.bats` | Dev flow em container Debian |
| `test_dev_rpm.bats` | Dev flow em container Fedora |
| `test_prod_debian.bats` | Prod flow em container Debian |
| `test_prod_rpm.bats` | Prod flow em container Fedora |

Requerem Docker instalado. Usam Dockerfiles em `tests/integration/` que simulam
um sistema limpo.

---

## Apêndice: Códigos de Saída

| Código | Significado |
|--------|-------------|
| 0 | Sucesso |
| 1 | Erro genérico (opção inválida, pacote falhou, .env ausente, GIT_URL vazia) |
| 2 | Script alvo não encontrado (wrapper) |
| 3 | Distribuição não suportada ou `/etc/os-release` ausente |
