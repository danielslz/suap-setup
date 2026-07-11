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

  - [x] 1.3 Escrever teste de propriedade para round-trip do .env
    - **Property 1: Round-trip do arquivo .env**
    - Criar `tests/property/test_env_roundtrip.bats` com mínimo 100 iterações
    - Gerar pares chave=valor aleatórios, escrever no .env e verificar carregamento correto
    - **Valida: Requisitos 1.2, 1.3, 1.4, 1.5, 4.1, 4.3, 4.5**

  - [x] 1.4 Escrever teste de propriedade para classificação de distribuição
    - **Property 2: Classificação de distribuição determina caminhos corretos**
    - Criar `tests/property/test_distro_paths.bats` com mínimo 100 iterações
    - Gerar conteúdos aleatórios de `/etc/os-release` e verificar classificação correta
    - **Valida: Requisitos 2.1, 17.1, 17.2, 20.1, 20.3**

  - [x] 1.5 Escrever testes unitários para funções de output e utilitários
    - Criar `tests/unit/test_common_functions.bats`
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

  - [x] 2.2 Escrever teste de propriedade para roteamento do menu
    - **Property 3: Roteamento do menu produz caminho de script correto**
    - Criar `tests/property/test_routing.bats` com mínimo 100 iterações
    - Gerar combinações aleatórias de opção (1-6) + distro (deb/rpm) e verificar caminho
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

  - [x] 4.3 Escrever testes unitários para fluxo de desenvolvimento
    - Criar `tests/unit/test_dev_flow.bats`
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

  - [x] 5.3 Escrever testes unitários para fluxo de produção
    - Criar `tests/unit/test_prod_flow.bats`
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

  - [x] 7.4 Escrever testes de fumaça para configurações estáticas
    - Criar `tests/smoke/test_nginx_config.bats`
    - Criar `tests/smoke/test_supervisor_confs.bats`
    - Validar presença de diretivas obrigatórias no arquivo `nginx/suap`
    - Validar arquivos `.conf` do Supervisor (formato e diretivas)
    - _Requisitos: 21.1, 21.2, 21.3, 21.4, 21.5, 21.6, 21.7, 21.8_

- [x] 8. Implementar ambiente Docker
  - [x] 8.1 Criar `docker/dev/Dockerfile` e `docker/dev/docker-compose.yml`
    - Criar Dockerfile de desenvolvimento com todas as dependências
    - Criar docker-compose.yml com serviços: suap, db (PostgreSQL 16), redis
    - Montar código-fonte como volume para edição em tempo real
    - Expor porta 8000 para acesso local
    - Configurar env_file apontando para `.env` centralizado
    - Configurar volumes persistentes para PostgreSQL
    - _Requisitos: 22.1, 22.2, 22.6, 22.7, 22.8_

  - [x] 8.2 Criar `docker/dev/docker-setup.sh`
    - Fazer source de `lib/common.sh`
    - Chamar `load_env_file()` e `check_docker_available()`
    - Chamar `resolve_git_url()`
    - Executar `docker compose up --build`
    - Exibir mensagem com URL de acesso e comandos úteis
    - _Requisitos: 1.4, 22.3, 22.4, 22.5, 22.9_

  - [x] 8.3 Criar `docker/prod/Dockerfile` e `docker/prod/docker-compose.prod.yml`
    - Criar Dockerfile otimizado com multi-stage build
    - Criar docker-compose.prod.yml com serviços: suap, celery-worker, celery-beat, celery-flower, redis, nginx
    - Configurar volumes persistentes para static, media e logs
    - Configurar `restart: unless-stopped` para todos os serviços
    - Configurar Nginx como proxy reverso para container SUAP
    - Expor portas 80, 8001 e 5555
    - _Requisitos: 23.1, 23.2, 23.6, 23.7, 23.8, 23.9_

  - [x] 8.4 Criar `docker/prod/docker-setup.sh`
    - Fazer source de `lib/common.sh`
    - Chamar `load_env_file()` e `check_docker_available()`
    - Chamar `resolve_git_url()`
    - Executar `docker compose -f docker-compose.prod.yml up -d --build`
    - Exibir status dos serviços com `docker compose ps`
    - Exibir instruções de gerenciamento dos containers
    - _Requisitos: 1.5, 23.3, 23.4, 23.5, 23.10_

  - [x] 8.5 Escrever testes de fumaça para Docker
    - Validar sintaxe dos docker-compose files (yaml válido)
    - Validar presença de serviços obrigatórios em cada compose
    - Validar Dockerfiles (FROM, COPY, CMD presentes)
    - _Requisitos: 22.1, 22.2, 23.1, 23.2_

- [x] 9. Checkpoint - Verificar Docker e serviços
  - Garantir que todos os testes passem, perguntar ao usuário se houver dúvidas.

- [x] 10. Configurar framework de testes e testes de integração
  - [x] 10.1 Configurar estrutura de testes com bats-core
    - Criar diretório `tests/` com subdiretórios: `unit/`, `property/`, `integration/`, `smoke/`
    - Configurar bats-core, bats-assert e bats-support como dependências de teste
    - Criar helper de setup compartilhado para os testes (`tests/test_helper/common-setup.bash`)
    - Criar script de execução `tests/run_tests.sh`
    - _Requisitos: Infraestrutura de testes_

  - [x] 10.2 Escrever teste de propriedade para idempotência
    - **Property 4: Idempotência de execução**
    - Arquivo criado: `tests/property/test_idempotency.bats`
    - **Valida: Requisitos 24.3, 24.4, 25.1, 25.2, 25.3, 25.4**

  - [x] 10.3 Criar infraestrutura de testes de integração
    - Criar `tests/integration/Dockerfile.debian` para testes em ambiente Debian
    - Criar `tests/integration/Dockerfile.fedora` para testes em ambiente RPM
    - Criar `tests/integration/run_integration_tests.sh` para execução automatizada
    - Criar arquivos `.bats` para cenários: dev Debian, dev RPM, prod Debian, prod RPM
    - _Requisitos: Infraestrutura de testes_

- [x] 11. Integração final e documentação
  - [x] 11.1 Atualizar `README.md` com instruções de uso
    - Documentar pré-requisitos do sistema
    - Documentar uso do `setup.sh` e menu de opções (incluindo opções Docker 5 e 6)
    - Documentar variáveis do `.env` centralizado
    - Documentar opções Docker (desenvolvimento e produção)
    - Documentar execução de testes com `tests/run_tests.sh`
    - Documentar arquivo `nginx/suap.docker` para uso em containers
    - _Requisitos: Documentação geral_

  - [x] 11.2 Garantir integração entre todos os componentes
    - Verificar que todos os scripts fazem source de `lib/common.sh` corretamente
    - Verificar que `setup.sh` roteia para todos os scripts (incluindo Docker opções 5 e 6)
    - Verificar que `.env` é utilizado consistentemente por todos os scripts
    - Remover ou deprecar `config-env.sh` (substituído por `setup.sh`)
    - _Requisitos: 1.2, 1.3, 1.4, 1.5, 1.8, 1.9, 3.2_

- [x] 12. Checkpoint final - Verificar integração completa
  - Garantir que todos os testes passem, perguntar ao usuário se houver dúvidas.

- [x] 13. Implementar integração com Dockhand
  - [x] 13.1 Criar `docker/dockhand-setup.sh`
    - Criar arquivo `docker/dockhand-setup.sh` com `set -u`
    - Fazer source de `lib/common.sh`
    - Chamar `check_docker_available()` para verificar pré-requisitos Docker (exit 1 com `msg_error` se não disponível)
    - Verificar se já existe container "dockhand" em execução (`docker ps --filter name=dockhand`)
      - Se sim: exibir `msg_skip` informando que já está ativo + URL de acesso (http://localhost:9093) e encerrar com sucesso
    - Executar `docker pull lscr.io/linuxserver/dockhand:latest` para obter imagem mais recente
    - Executar `docker run -d --name dockhand -p 9093:3000 -v /var/run/docker.sock:/var/run/docker.sock --restart unless-stopped lscr.io/linuxserver/dockhand:latest`
    - Verificar se o container iniciou com sucesso (exit 1 com `msg_error` indicando motivo da falha se não iniciou)
    - Exibir URL de acesso (http://localhost:9093) com `msg_action` em caso de sucesso
    - _Requisitos: 27.1, 27.2, 27.3, 27.4, 27.5, 27.6, 27.7, 27.8_

  - [x] 13.2 Atualizar `setup.sh` para incluir opção 7 (Dockhand)
    - Adicionar opção "7) Iniciar Dockhand" no menu exibido ao usuário
    - Adicionar case `7)` no roteamento que executa `docker/dockhand-setup.sh`
    - A opção 7 não depende de detecção de distro (análogo às opções 5 e 6)
    - Verificar existência do script antes de executar (exit 2 se não encontrado, conforme padrão do wrapper)
    - _Requisitos: 3.1, 3.2, 3.4, 27.1_

  - [x] 13.3 Atualizar teste de propriedade de roteamento para incluir opção 7
    - Atualizar `tests/property/test_routing.bats`
    - Adicionar opção `7` → `docker/dockhand-setup.sh` na função `_resolve_target_script()`
    - Atualizar teste Property 3.2 para incluir opção 7 como path fixo (independente de distro)
    - Atualizar teste Property 3.3 para ajustar o gerador de opções inválidas (opções > 7 são inválidas)
    - Atualizar teste Property 3.4 para incluir opção 7 na lista de opções válidas
    - **Property 3: Roteamento do menu produz caminho de script correto**
    - **Valida: Requisitos 3.2, 3.3, 27.1**

  - [x] 13.4 Escrever testes de fumaça para `docker/dockhand-setup.sh`
    - Criar `tests/smoke/test_dockhand.bats` (ou estender `tests/smoke/test_docker.bats`)
    - Testar que o script faz source de `lib/common.sh`
    - Testar idempotência: quando container já existe, não tenta criar outro
    - Testar mensagem de erro quando Docker não está disponível
    - Testar que a porta mapeada é 9093:3000
    - Testar que o volume `/var/run/docker.sock` é montado
    - Testar que `--restart unless-stopped` é utilizado
    - **Property 5: Idempotência do Dockhand**
    - **Valida: Requisitos 27.1, 27.2, 27.7, 27.8**

- [x] 14. Checkpoint final - Verificar integração Dockhand
  - Garantir que todos os testes passem, perguntar ao usuário se houver dúvidas.

- [x] 15. Implementar wizard interativo de .env, fallback de require_env_file, e melhorias de robustez
  - [x] 15.1 Implementar `interactive_env_wizard()` em `lib/common.sh`
    - Implementar função `interactive_env_wizard(env_path)` que solicita ao usuário valores para: PYTHON_VERSION, BASE_DIR, SUAP_DIR, VENV_DIR, GIT_URL
    - Para cada variável: exibir nome, descrição do propósito, exemplos e valor padrão (dev)
    - Se o usuário pressiona Enter sem digitar → usar valor padrão (exceto GIT_URL)
    - GIT_URL não possui valor padrão → exit 1 com `msg_error` se vazia
    - Após coleta, gravar o .env com comentários descritivos por variável
    - Exibir confirmação ao usuário com os valores gravados
    - _Requisitos: 28.1, 28.2, 28.3, 28.4, 28.5, 28.6, 28.7, 28.8, 28.9, 28.10_

  - [x] 15.2 Implementar `require_env_file()` em `lib/common.sh`
    - Implementar função `require_env_file(env_path)` que verifica se .env existe
    - Se .env não existe: exibir `msg_error` orientando executar `setup.sh` primeiro e `exit 1`
    - Atualizar `deb/suap-dev.sh`, `rpm/suap-dev.sh` para chamar `require_env_file()` no início
    - Atualizar `deb/suap-prod.sh`, `rpm/suap-prod.sh` para chamar `require_env_file()` no início
    - Atualizar `docker/dev/docker-setup.sh`, `docker/prod/docker-setup.sh` para chamar `require_env_file()` no início
    - _Requisitos: 1.7_

  - [x] 15.3 Atualizar `setup.sh` para usar `interactive_env_wizard()`
    - Substituir chamada de `create_default_env()` por `interactive_env_wizard()` quando .env não existe
    - Manter fluxo: se .env já existe, carregar com `load_env_file()` normalmente
    - _Requisitos: 1.6, 28.1_

  - [x] 15.4 Adicionar halt em falha de instalação de pacotes nos scripts dev
    - Atualizar `deb/suap-dev.sh`: verificar código de retorno de `apt install` e `exit 1` em caso de falha
    - Atualizar `rpm/suap-dev.sh`: verificar código de retorno de `dnf install` e `exit 1` em caso de falha
    - Exibir `msg_error` com descrição do erro antes do exit
    - _Requisitos: 5.3_

  - [x] 15.5 Adicionar halt em falha de instalação de pacotes nos scripts prod
    - Atualizar `deb/suap-prod.sh`: verificar código de retorno de `apt install` e `exit 1` em caso de falha
    - Atualizar `rpm/suap-prod.sh`: verificar código de retorno de `dnf install` e `exit 1` em caso de falha
    - Exibir `msg_error` com descrição do erro antes do exit
    - _Requisitos: 11.3_

  - [x] 15.6 Implementar detecção de UV em locais conhecidos antes de download
    - Atualizar `deb/suap-dev.sh`: verificar `~/.cargo/bin/uv` e `~/.local/bin/uv` antes de baixar
    - Atualizar `rpm/suap-dev.sh`: verificar `~/.cargo/bin/uv` e `~/.local/bin/uv` antes de baixar
    - Se encontrado em local conhecido: adicionar ao PATH e pular download
    - Se não encontrado em nenhum local: prosseguir com download da URL oficial
    - _Requisitos: 7.1, 7.2_

  - [x] 15.7 Adicionar halt em falha de instalação de dependências Python
    - Atualizar `deb/suap-dev.sh` e `rpm/suap-dev.sh`: verificar retorno de `uv sync` / `uv pip install` e `exit 1` em falha
    - Atualizar `deb/suap-prod.sh` e `rpm/suap-prod.sh`: verificar retorno de `pip install` e `exit 1` em falha
    - Exibir `msg_error` com descrição antes do exit
    - _Requisitos: 10.7, 14.6_

  - [x] 15.8 Implementar supervisorctl condicional nos scripts prod
    - Atualizar `deb/suap-prod.sh`: rastrear flag `FILES_COPIED=true` quando arquivos são efetivamente copiados
    - Atualizar `rpm/suap-prod.sh`: mesma lógica de flag
    - Somente executar `supervisorctl reread` e `supervisorctl update` quando `FILES_COPIED=true`
    - Se nenhum arquivo foi copiado (idempotência): pular supervisorctl com `msg_skip`
    - _Requisitos: 15.8, 15.9_

  - [x] 15.9 Implementar remoção condicional do nginx default
    - Atualizar `deb/install-nginx.sh`: só remover link `/etc/nginx/sites-enabled/default` após configuração do SUAP ser copiada com sucesso E link simbólico em `sites-enabled/suap` ser criado com sucesso
    - Se a cópia foi pulada por idempotência: NÃO remover o default
    - _Requisitos: 20.2_

  - [x] 15.10 Garantir mensagens verdes (msg_action) em todos os scripts
    - Verificar e adicionar `msg_action()` em `deb/install-redis.sh` e `rpm/install-redis.sh`
    - Verificar e adicionar `msg_action()` em `deb/install-nginx.sh` e `rpm/install-nginx.sh`
    - Verificar e adicionar `msg_action()` em `docker/dev/docker-setup.sh` e `docker/prod/docker-setup.sh`
    - Verificar e adicionar `msg_action()` em `setup.sh` (Wrapper)
    - _Requisitos: 25.5, 25.6, 25.7, 25.8, 25.9_

  - [x] 15.11 Escrever teste de propriedade para round-trip do Wizard_Env
    - **Property 6: Round-trip do Wizard_Env**
    - Atualizar ou criar teste em `tests/property/test_env_roundtrip.bats`
    - Simular inputs do wizard via stdin e verificar que .env gerado contém os mesmos valores
    - Mínimo 100 iterações com valores aleatórios
    - **Valida: Requisitos 28.3, 28.4, 28.5, 28.6, 28.8, 28.9**

  - [x] 15.12 Escrever teste de propriedade para fallback de .env
    - **Property 7: Fallback de .env em scripts individuais**
    - Atualizar ou criar teste em `tests/property/test_env_roundtrip.bats`
    - Verificar que todos os scripts individuais retornam exit 1 quando .env não existe
    - Verificar que nenhuma operação de instalação é executada
    - **Valida: Requisitos 1.7**

  - [x] 15.13 Escrever teste de propriedade para mensagens verdes
    - **Property 8: Mensagens de progresso em verde para todos os scripts**
    - Criar ou atualizar teste que verifique uso de `msg_action()` em todos os scripts
    - Verificar presença de chamadas `msg_action` em cada script
    - **Valida: Requisitos 25.5, 25.6, 25.7, 25.8, 25.9**

- [x] 16. Checkpoint final - Verificar melhorias de robustez
  - Garantir que todos os testes passem, perguntar ao usuário se houver dúvidas.

- [x] 17. Atualizar detecção de distribuição e funções utilitárias para Arch Linux e macOS
  - [x] 17.1 Atualizar `detect_distro()` em `lib/common.sh` para suporte a Arch e macOS
    - Adicionar verificação `uname -s` para Darwin → definir `DISTRO_TYPE="macos"` antes de ler `/etc/os-release`
    - Adicionar verificação de ID/ID_LIKE contendo "arch" → definir `DISTRO_TYPE="arch"`
    - Manter compatibilidade com "deb" e "rpm" existentes
    - Atualizar exit 3 para listar as 4 famílias suportadas na mensagem de erro
    - _Requisitos: 2.1, 2.2, 2.3, 2.4, 2.5, 30.1, 31.1_

  - [x] 17.2 Atualizar `is_pkg_installed()` em `lib/common.sh` para Arch e macOS
    - Adicionar case "arch" → usar `pacman -Q "$pkg_name" &>/dev/null`
    - Adicionar case "macos" → usar `brew list --formula 2>/dev/null | grep -q "^${pkg_name}$"`
    - Manter cases existentes para "deb" (dpkg) e "rpm" (rpm -q)
    - _Requisitos: 30.7, 30.8, 31.9_

  - [x] 17.3 Atualizar `get_supervisor_conf_dir()` em `lib/common.sh`
    - Adicionar case "arch" → retornar `/etc/supervisor.d/`
    - Manter cases existentes para "deb" e "rpm"
    - _Requisitos: 17.3, 30.9_

  - [x] 17.4 Atualizar `get_nginx_conf_path()` em `lib/common.sh`
    - Adicionar case "arch" → retornar `/etc/nginx/conf.d/suap.conf` (mesmo padrão RPM)
    - _Requisitos: 20.4, 30.10_

  - [x] 17.5 Atualizar `check_docker_available()` em `lib/common.sh`
    - Adicionar suporte a Arch: oferecer instalar via `pacman -S --needed --noconfirm docker docker-compose`
    - Adicionar suporte a macOS: verificar Docker Desktop, exibir URL advisory se ausente
    - _Requisitos: 29.6, 29.7, 31.11, 31.12_

  - [x] 17.6 Atualizar teste de propriedade `tests/property/test_distro_paths.bats`
    - Adicionar cenários de teste para `ID=arch` e `ID_LIKE=arch` → DISTRO_TYPE="arch"
    - Adicionar cenário de teste para `uname -s` == "Darwin" → DISTRO_TYPE="macos"
    - Verificar que `get_supervisor_conf_dir()` retorna `/etc/supervisor.d/` para Arch
    - Verificar que `get_nginx_conf_path()` retorna `/etc/nginx/conf.d/suap.conf` para Arch
    - **Property 2: Classificação de distribuição/OS determina caminhos corretos**
    - **Valida: Requisitos 2.2, 2.3, 17.3, 20.4, 30.1, 31.1**

- [x] 18. Implementar scripts Arch Linux
  - [x] 18.1 Criar `arch/suap-dev.sh`
    - Criar diretório `arch/` e arquivo `suap-dev.sh`
    - Fazer source de `lib/common.sh` e chamar `require_env_file()` + `load_env_file()`
    - Chamar `resolve_git_url()`
    - Instalar dependências via `pacman -S --needed --noconfirm` (base-devel, python, openldap, etc.)
    - Halt com exit 1 se `pacman` falha
    - Configurar locale via `localectl set-locale LANG=pt_BR.UTF-8` (se necessário)
    - Configurar timezone via `timedatectl set-timezone America/Fortaleza` (se necessário)
    - Verificar pacotes com `pacman -Q`
    - Instalar UV, clone/pull SUAP, gerar configs, criar venv, instalar deps (mesma lógica dev)
    - Garantir idempotência e mensagens `msg_action()`/`msg_skip()`
    - _Requisitos: 1.2, 1.7, 1.8, 5.1, 5.2, 5.3, 6.1, 6.2, 6.3, 6.4, 7.1, 7.2, 7.3, 8.1, 8.2, 9.1, 9.2, 9.3, 9.4, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 24.1, 24.3, 25.1, 25.2, 26.1, 30.2, 30.4, 30.6, 30.7_

  - [x] 18.2 Criar `arch/suap-prod.sh`
    - Criar arquivo `arch/suap-prod.sh`
    - Fazer source de `lib/common.sh` e chamar `require_env_file()` + `load_env_file()`
    - Validar execução como root (exit 1 se EUID != 0)
    - Instalar dependências de produção via `pacman -S --needed --noconfirm` (python, supervisor, cronie, chrony, etc.)
    - Halt com exit 1 se `pacman` falha
    - Configurar locale via `localectl` e timezone via `timedatectl`
    - Clone com `git clone --depth 1` ou pull
    - Criar virtualenv com `python3 -m venv`, instalar deps via pip
    - Halt com exit 1 se `pip install` falha
    - Menu do Supervisor (SUAP / Celery / Ambos)
    - Copiar configs para `/etc/supervisor.d/`
    - Executar supervisorctl reread/update condicionalmente (flag FILES_COPIED)
    - Ajustar permissões
    - _Requisitos: 1.3, 1.7, 1.9, 11.1, 11.2, 11.3, 12.1, 12.2, 13.1, 13.2, 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 15.1, 15.2, 15.3, 15.4, 15.5, 15.6, 15.7, 15.8, 15.9, 16.1, 17.3, 24.2, 24.4, 25.3, 25.4, 26.2, 30.3, 30.5, 30.8, 30.9_

  - [x] 18.3 Criar `arch/install-redis.sh`
    - Criar arquivo `arch/install-redis.sh`
    - Fazer source de `lib/common.sh`
    - Instalar pacote Redis via `pacman -S --needed --noconfirm redis`
    - Iniciar e habilitar serviço via `systemctl start redis` + `systemctl enable redis`
    - Exibir status com `msg_action()`
    - _Requisitos: 18.1, 18.2, 18.3, 25.5, 30.4_

  - [x] 18.4 Criar `arch/install-nginx.sh`
    - Criar arquivo `arch/install-nginx.sh`
    - Fazer source de `lib/common.sh`
    - Instalar pacote Nginx via `pacman -S --needed --noconfirm nginx`
    - Iniciar e habilitar serviço via systemctl
    - Copiar configuração para `/etc/nginx/conf.d/suap.conf`
    - Testar com `nginx -t` e recarregar com `systemctl reload nginx`
    - Exibir mensagens com `msg_action()`
    - _Requisitos: 19.1, 19.2, 19.3, 19.4, 19.5, 19.6, 20.4, 25.6, 30.10_

- [x] 19. Implementar script macOS
  - [x] 19.1 Criar `macos/suap-dev.sh`
    - Criar diretório `macos/` e arquivo `suap-dev.sh`
    - Fazer source de `lib/common.sh` e chamar `require_env_file()` + `load_env_file()`
    - Verificar Homebrew instalado (exit 1 com `msg_error` + URL https://brew.sh se ausente)
    - Chamar `resolve_git_url()`
    - Instalar dependências via `brew install` (openldap, libpq, freetype, libxml2, etc.)
    - Halt com exit 1 se `brew install` falha
    - Pular configuração de locale com `msg_skip` ("Locale não necessário no macOS")
    - Configurar timezone via `sudo systemsetup -settimezone America/Fortaleza` (se necessário)
    - Verificar pacotes com `brew list --formula | grep -q`
    - Instalar UV, clone/pull SUAP, gerar configs, criar venv, instalar deps (mesma lógica dev)
    - Garantir idempotência e mensagens `msg_action()`/`msg_skip()`
    - _Requisitos: 1.2, 1.7, 1.8, 5.1, 5.4, 6.1, 6.2, 6.3, 6.4, 7.1, 7.2, 7.3, 8.1, 8.2, 9.1, 9.2, 9.3, 9.4, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 24.1, 24.3, 25.1, 25.2, 26.1, 31.1, 31.3, 31.4, 31.5, 31.6, 31.7, 31.8, 31.9_

- [x] 20. Criar script de instalação do Docker (`docker/install-docker.sh`)
  - [x] 20.1 Implementar `docker/install-docker.sh`
    - Criar arquivo `docker/install-docker.sh`
    - Fazer source de `lib/common.sh`
    - Detectar distribuição/OS via `detect_distro()`
    - Implementar case Debian: adicionar repositório oficial Docker (gpg key + sources.list) + `apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin`
    - Implementar case RPM: adicionar repositório oficial Docker (dnf config-manager) + `dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin`
    - Implementar case Arch: `pacman -S --needed --noconfirm docker docker-compose`
    - Implementar case macOS: exibir URL advisory (https://docs.docker.com/desktop/install/mac-install/) + exit 0 sem instalação automatizada
    - Caso distro não suportada: `msg_error` + exit 1
    - Após instalação: `systemctl start docker` + `systemctl enable docker`
    - Adicionar usuário atual ao grupo docker: `usermod -aG docker $USER`
    - Verificação pós-instalação: `docker --version` + `docker compose version`
    - Se verificação falha: `msg_error` + exit 1
    - Exibir mensagem de sucesso com versões e aviso sobre logout/login
    - _Requisitos: 29.1, 29.2, 29.3, 29.4, 29.5, 29.6, 29.7, 29.8, 29.9, 29.10, 29.11, 29.12, 29.13, 29.14, 29.15_

  - [x] 20.2 Escrever testes de fumaça para `docker/install-docker.sh`
    - Validar que o script faz source de `lib/common.sh`
    - Validar presença de cases para deb, rpm, arch, macos
    - Validar que instala pacotes docker-ce, docker-ce-cli, containerd.io, docker-compose-plugin (deb/rpm)
    - Validar que Arch usa `pacman -S --needed --noconfirm docker docker-compose`
    - Validar presença de `systemctl start docker` e `systemctl enable docker`
    - Validar presença de `usermod -aG docker`
    - Validar verificação pós-instalação (`docker --version`, `docker compose version`)
    - _Requisitos: 29.4, 29.5, 29.6, 29.8, 29.9, 29.10, 29.11_

- [x] 21. Atualizar `setup.sh` para roteamento Arch e macOS
  - [x] 21.1 Atualizar menu e roteamento em `setup.sh`
    - Adicionar roteamento de opções 1-4 para diretório `arch/` quando `DISTRO_TYPE="arch"`
    - Adicionar roteamento de opção 1 para `macos/suap-dev.sh` quando `DISTRO_TYPE="macos"`
    - Implementar menu restrito para macOS: exibir opções 1, 5, 6, 7; ocultar 2, 3, 4 com mensagem "não suportado no macOS"
    - Manter roteamento existente para deb/rpm intacto
    - Manter opções Docker (5, 6, 7) independentes de distro
    - _Requisitos: 3.1, 3.2, 3.3, 3.4, 30.11, 31.10_

  - [x] 21.2 Atualizar teste de propriedade `tests/property/test_routing.bats`
    - Adicionar distro "arch" ao gerador de distros no test de roteamento
    - Adicionar combinações: opção 1-4 + arch → `arch/suap-dev.sh`, `arch/suap-prod.sh`, `arch/install-redis.sh`, `arch/install-nginx.sh`
    - Adicionar distro "macos" ao gerador de distros
    - Adicionar combinação: opção 1 + macos → `macos/suap-dev.sh`
    - Adicionar testes para opções 2, 3, 4 rejeitadas em macOS (exit 1 ou mensagem de não suportado)
    - Atualizar `_resolve_target_script()` para incluir "arch" e "macos"
    - **Property 3: Roteamento do menu produz caminho de script correto**
    - **Valida: Requisitos 3.2, 3.3, 30.11, 31.10**

- [x] 22. Checkpoint - Verificar suporte Arch/macOS/Docker install
  - Garantir que todos os testes passem, perguntar ao usuário se houver dúvidas.

## Notes

- Tasks marcadas com `*` são opcionais e podem ser puladas para um MVP mais rápido
- Cada task referencia requisitos específicos para rastreabilidade
- Checkpoints garantem validação incremental
- Testes de propriedade validam propriedades universais de corretude
- Testes unitários validam exemplos específicos e casos extremos
- A linguagem de implementação é Bash/Shell Script conforme o design
- O arquivo `config-env.sh` é legado e foi substituído funcionalmente por `setup.sh`

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
    { "id": 11, "tasks": ["11.1", "11.2"] },
    { "id": 12, "tasks": ["13.1", "13.2"] },
    { "id": 13, "tasks": ["13.3", "13.4"] },
    { "id": 14, "tasks": ["15.1", "15.2"] },
    { "id": 15, "tasks": ["15.3", "15.4", "15.5", "15.6", "15.7"] },
    { "id": 16, "tasks": ["15.8", "15.9", "15.10"] },
    { "id": 17, "tasks": ["15.11", "15.12", "15.13"] },
    { "id": 18, "tasks": ["17.1", "17.2", "17.3", "17.4", "17.5"] },
    { "id": 19, "tasks": ["17.6", "18.1", "18.3", "18.4", "19.1", "20.1"] },
    { "id": 20, "tasks": ["18.2", "20.2", "21.1"] },
    { "id": 21, "tasks": ["21.2"] }
  ]
}
```
