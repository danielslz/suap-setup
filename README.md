# SUAP Env Scripts

## Introdução

Este repositório reúne scripts de automação para preparar ambientes SUAP em sistemas Linux, com suporte para distribuições Debian-like e RPM-like.

Os scripts automatizam a instalação de dependências, configuração de ambiente Python, download/atualização do código SUAP e implantação de serviços de produção via Supervisor.

## Organização do repositório

- `config-env.sh`: wrapper interativo que detecta a família da distribuição e escolhe o script correto.
- `deb/`: scripts específicos para Debian/Ubuntu.
- `rpm/`: scripts específicos para Fedora/RHEL/CentOS.
- `nginx/`: configuração Nginx para SUAP.
- `supervisor/`: arquivos de configuração e scripts de execução para Supervisor.

## Scripts disponíveis

| Script | Ambiente | Descrição |
|--------|----------|-----------|
| `config-env.sh` | Wrapper | Detecta a distro e executa o script correto para dev/prod, Redis ou Nginx |
| `deb/suap-dev.sh` | Desenvolvimento | Configura ambiente de desenvolvimento SUAP em Debian/Ubuntu |
| `rpm/suap-dev.sh` | Desenvolvimento | Configura ambiente de desenvolvimento SUAP em Fedora/RHEL |
| `deb/suap-prod.sh` | Produção | Configura ambiente de produção SUAP em Debian/Ubuntu |
| `rpm/suap-prod.sh` | Produção | Configura ambiente de produção SUAP em Fedora/RHEL |
| `deb/install-redis.sh` | Infraestrutura | Instala e habilita Redis em Debian/Ubuntu |
| `rpm/install-redis.sh` | Infraestrutura | Instala e habilita Redis em Fedora/RHEL |
| `deb/install-nginx.sh` | Infraestrutura | Instala e habilita Nginx e deploya configuração SUAP em Debian/Ubuntu |
| `rpm/install-nginx.sh` | Infraestrutura | Instala e habilita Nginx e deploya configuração SUAP em Fedora/RHEL |

## Funcionalidades principais

### Wrapper cross-distro

`config-env.sh` oferece um menu com as opções:

1. Configurar ambiente de desenvolvimento
2. Configurar ambiente de produção
3. Instalar Redis
4. Instalar Nginx

O script detecta automaticamente se o sistema é Debian-like ou RPM-like usando `/etc/os-release` e chama o script equivalente em `deb/` ou `rpm/`.

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

### Infraestrutura

Os scripts de infraestrutura instalam e configuram:

- Redis (`deb/install-redis.sh` e `rpm/install-redis.sh`)
- Nginx e configuração SUAP (`deb/install-nginx.sh` e `rpm/install-nginx.sh`)

## Como usar

### 1. Clonar o repositório

```bash
git clone https://github.com/danielslz/suap-env-scripts.git
cd suap-env-scripts
```

### 2. Executar o wrapper interativo

```bash
bash config-env.sh
```

### 3. Executar um script diretamente

```bash
bash deb/suap-dev.sh
bash rpm/suap-dev.sh
bash deb/suap-prod.sh
bash rpm/suap-prod.sh
bash deb/install-redis.sh
bash rpm/install-redis.sh
bash deb/install-nginx.sh
bash rpm/install-nginx.sh
```

> Observação: os scripts de produção devem ser executados como root.

## Estrutura do repositório

```
config-env.sh

deb/
  install-redis.sh
  install-nginx.sh
  suap-dev.sh
  suap-prod.sh

rpm/
  install-redis.sh
  install-nginx.sh
  suap-dev.sh
  suap-prod.sh

nginx/
  suap

supervisor/
  celery_beat.conf
  celery_flower.conf
  celery_worker.conf
  run_celery_beat.sh
  run_celery_flower.sh
  run_celery_worker.sh
  run_suap.sh
  suap.conf
```

## Pré-requisitos

- Acesso ao repositório GitLab do SUAP
- Conexão com a internet
- Permissões de `sudo`
- Sistema suportado: Debian/Ubuntu ou Fedora/RHEL/CentOS

## Exemplos de uso

### Desenvolvimento

```bash
cd $HOME/Projetos/suap
source .venv/bin/activate
uv run python manage.py runserver 0.0.0.0:8000
```

### Produção

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

## Observações

- `config-env.sh` facilita a escolha do script certo para a família de distribuição.
- Os scripts são projetados para serem idempotentes, evitando repetição de etapas quando possível.
- A configuração de Supervisor e Nginx depende dos arquivos em `supervisor/` e `nginx/`.

## Suporte

Para dúvidas ou sugestões, abra uma issue neste repositório.
