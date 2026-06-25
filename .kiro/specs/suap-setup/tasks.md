# Implementation Plan: suap-setup

## Overview

Implementação dos scripts de automação do ambiente SUAP, partindo da biblioteca compartilhada (`lib/common.sh`), seguida pelo wrapper principal (`setup.sh`), scripts por distribuição (dev/prod/redis/nginx), ambiente Docker e testes automatizados com bats-core. Cada etapa constrói sobre a anterior, garantindo integração incremental.

## Tasks

- [x] 1. Criar biblioteca compartilhada e arquivo .env centralizado
  - [x] 1.1 Criar `lib/common.sh` com funções utilitárias base
    - Criar diretório `lib/` e arquivo `common.sh`
    - Implementar constantes de cor (`GREEN`, `YELLOW`, `RED`, `NO_COLOR`) usando `tput`
    - Implementar funções de output: `msg_action()`, `msg_skip()`, `msg_error()`
    - Implementar `create_default_env()` que cria `.env` com valores padrão e comentários descritivos
    - Implementar `load_env_file()` que carrega variáveis do `.env` (cria se não existir)
    - Implementar `resolve_git_url()` que lê `GIT_URL` do `.env` ou solicita via prompt
    - _Requisitos: 1.1, 1.6, 1.7, 4.1, 4.2, 4.3, 4.4, 25.1, 25.2, 25.3, 25.4_

  - [x] 1.2 Implementar detecção de distribuição e funções de caminho
    - Implementar `detect_distro()` que lê `/etc/os-release` e classifica em "deb" ou "rpm"
    - Retornar exit 3 se `/etc/os-release` não existe ou distro não suportada
    - Implementar `get_supervisor_conf_dir()` que retorna caminho por distro
    - Implementar `get_nginx_conf_path()` que retorna caminho por distro
    - Implementar `is_pkg_installed()` usando dpkg (Debian) ou rpm -q (RPM)
    - Implementar `check_all_packages_installed()` para verificar lista de pacotes
    - Implementar `check_docker_available()` para verificar Docker e Docker Compose
    - _Requisitos: 2.1, 2.2, 2.3, 17.1, 17.2, 20.1, 20.3_

  - [x]* 1.3 Escrever teste de propriedade para round-trip do .env
    - **Property 1: Round-trip do arquivo .env**
    - **Valida: Requisitos 1.2, 1.3, 1.4, 1.5, 4.1, 4.3, 4.5**

  - [x]* 1.4 Escrever teste de propriedade para classificação de distribuição
    - **Property 2: Classificação de distribuição determina caminhos corretos**
    - **Valida: Requisitos 2.1, 17.1, 17.2, 20.1, 20.3**

  - [x]* 1.5 Escrever testes unitários para funções de output e utilitários
    - Testar `msg_action()`, `msg_skip()`, `msg_error()` quanto ao formato de saída
    - Testar `is_pkg_installed()` com mocks de dpkg/rpm
    - Testar `check_docker_available()` com cenários de sucesso e falha
    - _Requisitos: 25.1, 25.2, 25.3, 25.4_

- [x] 2. Implementar wrapper principal (`setup.sh`)
  - [x] 2.1 Criar `setup.sh` com menu interativo e roteamento
    - Renomear/recriar o ponto de entrada principal como `setup.sh`
    - Adicionar `set -u` e determinação de `SCRIPT_DIR`
    - Fazer source de `lib/common.sh`
    - Chamar `load_env_file()` e `detect_distro()`
    - Implementar exibição do menu com 6 opções
    - Implementar validação de entrada (exit 1 para opção inválida)
    - Implementar roteamento baseado em `DISTRO_TYPE` e opção selecionada
    - Verificar existência do script antes de executar (exit 2 se não encontrado)
    - Opções Docker (5, 6) não dependem de detecção de distro
    - _Requisitos: 3.1, 3.2, 3.3, 3.4_

  - [x]* 2.2 Escrever teste de propriedade para roteamento do menu
    - **Property 3: Roteamento do menu produz caminho de script correto**
    - **Valida: Requisitos 3.2, 3.3**

- [x] 3. Checkpoint - Verificar base do projeto
  - Garantir que todos os testes passem, perguntar ao usuário se houver dúvidas.

- [x] 4. Implementar scripts de desenvolvimento
  - [x] 4.1 Implementar `deb/suap-dev.sh`
    - Fazer source de `lib/common.sh` e carregar `.env`
    - Chamar `resolve_git_url()`
    - Verificar e instalar dependências do sistema via apt (ferramentas de compilação, LDAP, Pillow, etc.)
    - Configurar locale `pt_BR.UTF-8` com `update-locale` (se necessário)
    - Configurar timezone `America/Fortaleza` (se necessário)
    - Instalar UV se não disponível no PATH
    - Adicionar auto-completar do UV ao `.bashrc`
    - Clone/pull do repositório SUAP
    - Gerar `settings.py` e `.env` a partir dos samples (se não existem)
    - Instalar Python via `uv python install` (se necessário)
    - Criar virtualenv com `uv venv` (se não existe)
    - Instalar dependências via `uv sync --group dev` ou `uv pip install -r requirements/development.txt`
    - Exibir mensagem final com próximos passos
    - Garantir idempotência em todas as etapas (mensagens amarelas para pulos)
    - _Requisitos: 1.2, 1.8, 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3, 5.4, 6.1, 6.2, 6.3, 6.4, 7.1, 7.2, 7.3, 8.1, 8.2, 9.1, 9.2, 9.3, 9.4, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 24.1, 24.3, 25.1, 25.2, 26.1_

  - [x] 4.2 Implementar `rpm/suap-dev.sh`
    - Mesma lógica de `deb/suap-dev.sh` adaptada para distribuições RPM
    - Usar dnf como gerenciador de pacotes
    - Usar `localectl set-locale` para configuração de locale
    - Usar `rpm -q` para verificação de pacotes
    - Adaptar nomes de pacotes para o ecossistema RPM
    - _Requisitos: 1.2, 1.8, 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3, 5.4, 6.1, 6.2, 6.3, 6.4, 7.1, 7.2, 7.3, 8.1, 8.2, 9.1, 9.2, 9.3, 9.4, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 24.1, 24.3, 25.1, 25.2, 26.1_

  - [x]* 4.3 Escrever testes unitários para fluxo de desenvolvimento
    - Testar carregamento de variáveis e resolução de GIT_URL
    - Testar lógica de idempotência (pular etapas já concluídas)
    - Testar geração de arquivos de configuração (não sobrescrever existentes)
    - Testar detecção de pyproject.toml vs requirements/
    - _Requisitos: 9.1, 9.2, 9.3, 9.4, 10.4, 10.5, 10.6, 24.1, 24.3_

- [x] 5. Implementar scripts de produção
  - [x] 5.1 Implementar `deb/suap-prod.sh`
    - Fazer source de `lib/common.sh` e carregar `.env`
    - Validar execução como root (exit 1 se EUID != 0)
    - Chamar `resolve_git_url()`
    - Verificar e instalar dependências de produção via apt (python3, supervisor, cron, ntp, etc.)
    - Configurar locale e timezone
    - Clone com `git clone --depth 1` ou pull do repositório
    - Gerar `settings.py` e `.env` a partir dos samples
    - Criar virtualenv com `python3 -m venv` (se não existe)
    - Instalar dependências via pip (`pip install . --group prod` ou `pip install -r requirements/production.txt`)
    - Implementar menu do Supervisor (SUAP / Celery / Ambos)
    - Copiar configs e runners para `/etc/supervisor/conf.d/`
    - Definir permissão de execução nos runners
    - Executar `supervisorctl reread && supervisorctl update`
    - Ajustar permissões com `chown www-data`
    - Exibir mensagem final com próximos passos
    - _Requisitos: 1.3, 1.9, 4.5, 4.6, 11.1, 11.2, 11.3, 12.1, 12.2, 13.1, 13.2, 14.1, 14.2, 14.3, 14.4, 14.5, 15.1, 15.2, 15.3, 15.4, 15.5, 15.6, 15.7, 15.8, 16.1, 17.1, 24.2, 24.4, 25.3, 25.4, 26.2_

  - [x] 5.2 Implementar `rpm/suap-prod.sh`
    - Mesma lógica de `deb/suap-prod.sh` adaptada para distribuições RPM
    - Usar dnf como gerenciador de pacotes
    - Copiar configs para `/etc/supervisord.d/`
    - Usar nomes de pacotes RPM (cronie, chrony, etc.)
    - Usar serviço `supervisord` em vez de `supervisor`
    - _Requisitos: 1.3, 1.9, 4.5, 4.6, 11.1, 11.2, 11.3, 12.1, 12.2, 13.1, 13.2, 14.1, 14.2, 14.3, 14.4, 14.5, 15.1, 15.2, 15.3, 15.4, 15.5, 15.6, 15.7, 15.8, 16.1, 17.2, 24.2, 24.4, 25.3, 25.4, 26.2_

  - [x]* 5.3 Escrever testes unitários para fluxo de produção
    - Testar validação de root (EUID)
    - Testar menu do Supervisor e cópia de arquivos
    - Testar lógica de permissões
    - Testar clone com --depth 1
    - _Requisitos: 12.1, 12.2, 15.1, 15.5, 15.6, 16.1_

- [x] 6. Checkpoint - Verificar scripts de dev e prod
  - Garantir que todos os testes passem, perguntar ao usuário se houver dúvidas.

- [x] 7. Implementar scripts de Redis e Nginx
  - [x] 7.1 Implementar `deb/install-redis.sh` e `rpm/install-redis.sh`
    - Fazer source de `lib/common.sh`
    - Instalar pacote Redis (redis-server para Debian, redis para RPM)
    - Iniciar serviço via systemctl
    - Habilitar serviço para início automático no boot
    - Exibir status do serviço
    - _Requisitos: 18.1, 18.2, 18.3_

  - [x] 7.2 Implementar `deb/install-nginx.sh` e `rpm/install-nginx.sh`
    - Fazer source de `lib/common.sh`
    - Instalar pacote Nginx
    - Iniciar e habilitar serviço via systemctl
    - Copiar configuração para local correto por distro (`get_nginx_conf_path`)
    - Debian: copiar para sites-available, criar link em sites-enabled, remover default
    - RPM: copiar para conf.d/suap.conf
    - Testar configuração com `nginx -t`
    - Recarregar Nginx com `systemctl reload nginx`
    - _Requisitos: 19.1, 19.2, 19.3, 19.4, 19.5, 19.6, 20.1, 20.2, 20.3_

  - [x] 7.3 Atualizar configuração Nginx (`nginx/suap`)
    - Configurar upstream com `least_conn` apontando para porta 8000
    - Configurar `client_max_body_size 100m`
    - Configurar location para servir arquivos estáticos (`/opt/suap/deploy/static`)
    - Configurar location para servir mídia (`/opt/suap/deploy/media`)
    - Configurar páginas de erro customizadas (500, 502, 503, 504, 413)
    - Configurar bloco de servidor secundário na porta 8001
    - Configurar formato de log customizado com tempo de requisição e upstream
    - Configurar buffers de proxy aumentados
    - _Requisitos: 21.1, 21.2, 21.3, 21.4, 21.5, 21.6, 21.7, 21.8_

  - [x]* 7.4 Escrever testes de fumaça para configurações estáticas
    - Validar sintaxe do arquivo `nginx/suap`
    - Validar presença de diretivas obrigatórias no Nginx
    - Validar arquivos `.conf` do Supervisor
    - _Requisitos: 21.1, 21.2, 21.3, 21.4, 21.5, 21.6, 21.7, 21.8_

- [ ] 8. Implementar ambiente Docker
  - [x] 8.1 Criar `docker/dev/Dockerfile` e `docker/dev/docker-compose.yml`
    - Criar Dockerfile de desenvolvimento com todas as dependências
    - Criar docker-compose.yml com serviços: suap, db (PostgreSQL 16), redis
    - Montar código-fonte como volume para edição em tempo real
    - Expor porta 8000 para acesso local
    - Configurar env_file apontando para `.env` centralizado
    - Configurar volumes persistentes para PostgreSQL
    - _Requisitos: 22.1, 22.2, 22.6, 22.7, 22.8_

  - [ ] 8.2 Criar `docker/dev/docker-setup.sh`
    - Fazer source de `lib/common.sh`
    - Chamar `load_env_file()` e `check_docker_available()`
    - Chamar `resolve_git_url()`
    - Executar `docker compose up --build`
    - Exibir mensagem com URL de acesso e comandos úteis
    - _Requisitos: 1.4, 22.3, 22.4, 22.5, 22.9_

  - [ ] 8.3 Criar `docker/prod/Dockerfile` e `docker/prod/docker-compose.prod.yml`
    - Criar Dockerfile otimizado com multi-stage build
    - Criar docker-compose.prod.yml com serviços: suap, celery-worker, celery-beat, celery-flower, redis, nginx
    - Configurar volumes persistentes para static, media e logs
    - Configurar `restart: unless-stopped` para todos os serviços
    - Configurar Nginx como proxy reverso para container SUAP
    - Expor portas 80, 8001 e 5555
    - _Requisitos: 23.1, 23.2, 23.6, 23.7, 23.8, 23.9_

  - [ ] 8.4 Criar `docker/prod/docker-setup.sh`
    - Fazer source de `lib/common.sh`
    - Chamar `load_env_file()` e `check_docker_available()`
    - Chamar `resolve_git_url()`
    - Executar `docker compose -f docker-compose.prod.yml up -d --build`
    - Exibir status dos serviços com `docker compose ps`
    - Exibir instruções de gerenciamento dos containers
    - _Requisitos: 1.5, 23.3, 23.4, 23.5, 23.10_

  - [ ]* 8.5 Escrever testes de fumaça para Docker
    - Validar sintaxe dos docker-compose files (yaml válido)
    - Validar presença de serviços obrigatórios em cada compose
    - Validar Dockerfiles (FROM, COPY, CMD presentes)
    - _Requisitos: 22.1, 22.2, 23.1, 23.2_

- [ ] 9. Checkpoint - Verificar Docker e serviços
  - Garantir que todos os testes passem, perguntar ao usuário se houver dúvidas.

- [ ] 10. Configurar framework de testes e testes de integração
  - [ ] 10.1 Configurar estrutura de testes com bats-core
    - Criar diretório `tests/` com subdiretórios: `unit/`, `property/`, `integration/`, `smoke/`
    - Configurar bats-core, bats-assert e bats-support como dependências de teste
    - Criar helper de setup compartilhado para os testes
    - _Requisitos: Infraestrutura de testes_

  - [ ]* 10.2 Escrever teste de propriedade para idempotência
    - **Property 4: Idempotência de execução**
    - **Valida: Requisitos 24.3, 24.4, 25.1, 25.2, 25.3, 25.4**

  - [ ]* 10.3 Criar infraestrutura de testes de integração
    - Criar `tests/integration/Dockerfile.debian` para testes em ambiente Debian
    - Criar `tests/integration/Dockerfile.fedora` para testes em ambiente RPM
    - Criar scripts de execução de testes de integração
    - _Requisitos: Infraestrutura de testes_

- [ ] 11. Integração final e documentação
  - [ ] 11.1 Atualizar `README.md` com instruções de uso
    - Documentar pré-requisitos do sistema
    - Documentar uso do `setup.sh` e menu de opções
    - Documentar variáveis do `.env` centralizado
    - Documentar opções Docker
    - Documentar execução de testes
    - _Requisitos: Documentação geral_

  - [ ] 11.2 Garantir integração entre todos os componentes
    - Verificar que todos os scripts fazem source de `lib/common.sh` corretamente
    - Verificar que `setup.sh` roteia para todos os scripts
    - Verificar que `.env` é utilizado consistentemente por todos os scripts
    - Remover variáveis hardcoded remanescentes dos scripts existentes
    - _Requisitos: 1.2, 1.3, 1.4, 1.5, 1.8, 1.9, 3.2_

- [ ] 12. Checkpoint final - Verificar integração completa
  - Garantir que todos os testes passem, perguntar ao usuário se houver dúvidas.

## Notes

- Tasks marcadas com `*` são opcionais e podem ser puladas para um MVP mais rápido
- Cada task referencia requisitos específicos para rastreabilidade
- Checkpoints garantem validação incremental
- Testes de propriedade validam propriedades universais de corretude
- Testes unitários validam exemplos específicos e casos extremos
- A linguagem de implementação é Bash/Shell Script conforme o design

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["1.3", "1.4", "1.5", "2.1"] },
    { "id": 3, "tasks": ["2.2", "4.1", "4.2"] },
    { "id": 4, "tasks": ["4.3", "5.1", "5.2"] },
    { "id": 5, "tasks": ["5.3", "7.1", "7.2", "7.3"] },
    { "id": 6, "tasks": ["7.4", "8.1"] },
    { "id": 7, "tasks": ["8.2", "8.3"] },
    { "id": 8, "tasks": ["8.4", "8.5"] },
    { "id": 9, "tasks": ["10.1"] },
    { "id": 10, "tasks": ["10.2", "10.3"] },
    { "id": 11, "tasks": ["11.1", "11.2"] }
  ]
}
```
