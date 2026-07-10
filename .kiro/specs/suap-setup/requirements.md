# Requirements Document

## Introduction

Este documento define os requisitos para o projeto **suap-setup**, uma coleção de scripts shell que automatizam a configuração do ambiente da aplicação SUAP em sistemas Linux e macOS. Os scripts suportam distribuições Debian-like (Debian/Ubuntu), RPM-like (Fedora/RHEL/CentOS), Arch Linux (Arch/Manjaro/EndeavourOS) e macOS (via Homebrew), cobrindo ambientes de desenvolvimento, produção, instalação de serviços de infraestrutura (Redis e Nginx) e ambientes containerizados com Docker.

## Glossary

- **Wrapper**: Script principal (`setup.sh`) que detecta a distribuição Linux e roteia para o script apropriado.
- **Script_Dev**: Scripts de configuração de ambiente de desenvolvimento (`deb/suap-dev.sh`, `rpm/suap-dev.sh`).
- **Script_Prod**: Scripts de configuração de ambiente de produção (`deb/suap-prod.sh`, `rpm/suap-prod.sh`).
- **Script_Redis**: Scripts de instalação do Redis (`deb/install-redis.sh`, `rpm/install-redis.sh`).
- **Script_Nginx**: Scripts de instalação do Nginx (`deb/install-nginx.sh`, `rpm/install-nginx.sh`).
- **Script_Docker_Dev**: Script para construção e execução do ambiente SUAP em container Docker para desenvolvimento.
- **Script_Docker_Prod**: Script para construção e execução do ambiente SUAP em container Docker para produção.
- **Distribuição_Debian**: Família de distribuições baseadas em Debian (Debian, Ubuntu e derivados).
- **Distribuição_RPM**: Família de distribuições baseadas em RPM (Fedora, RHEL, CentOS e derivados).
- **Distribuição_Arch**: Família de distribuições baseadas em Arch Linux (Arch, Manjaro, EndeavourOS e derivados).
- **Distribuição_macOS**: Sistema operacional macOS da Apple, utilizando Homebrew como gerenciador de pacotes.
- **Script_Dev_Arch**: Script de configuração de ambiente de desenvolvimento para Arch Linux (`arch/suap-dev.sh`).
- **Script_Prod_Arch**: Script de configuração de ambiente de produção para Arch Linux (`arch/suap-prod.sh`).
- **Script_Dev_macOS**: Script de configuração de ambiente de desenvolvimento para macOS (`macos/suap-dev.sh`).
- **UV**: Gerenciador de pacotes Python moderno (astral.sh/uv) utilizado no ambiente de desenvolvimento.
- **Supervisor**: Sistema de controle de processos utilizado para gerenciar serviços SUAP em produção.
- **Virtualenv**: Ambiente virtual Python isolado para dependências do projeto.
- **Arquivo_Env**: Arquivo `.env` na raiz do projeto suap-setup que armazena variáveis de configuração compartilhadas entre todos os scripts (GIT_URL, PYTHON_VERSION, BASE_DIR, SUAP_DIR, VENV_DIR, etc.).
- **Arquivo_Env_Central**: Arquivo centralizado de configuração (`.env`) na raiz do repositório suap-setup que contém todas as variáveis reutilizáveis entre os scripts.
- **Docker_Compose**: Ferramenta para definir e executar aplicações multi-container Docker usando arquivo `docker-compose.yml`.
- **Dockhand**: Interface web para gerenciamento de containers Docker (https://dockhand.pro/), executada como container Docker.
- **Wizard_Env**: Assistente interativo executado pelo Wrapper para criação do Arquivo_Env_Central quando este não existe, solicitando ao usuário os valores de cada variável via prompts no terminal.
- **Script_Install_Docker**: Script de instalação automatizada do Docker (`docker/install-docker.sh`) que suporta Distribuição_Debian e Distribuição_RPM, adicionando o repositório oficial Docker e instalando o Docker Engine e Docker Compose plugin.

## Requirements

### Requirement 1: Centralização de variáveis em arquivo de ambiente compartilhado

**User Story:** Como desenvolvedor, eu quero que todas as variáveis de configuração dos scripts estejam centralizadas em um único arquivo de ambiente, para que eu possa reutilizá-las de forma consistente entre os diversos scripts sem duplicação.

#### Acceptance Criteria

1. THE Arquivo_Env_Central SHALL conter todas as variáveis compartilhadas entre os scripts: PYTHON_VERSION, BASE_DIR, SUAP_DIR, VENV_DIR e GIT_URL.
2. WHEN o Script_Dev é executado, THE Script_Dev SHALL carregar as variáveis a partir do Arquivo_Env_Central antes de iniciar qualquer operação.
3. WHEN o Script_Prod é executado, THE Script_Prod SHALL carregar as variáveis a partir do Arquivo_Env_Central antes de iniciar qualquer operação.
4. WHEN o Script_Docker_Dev é executado, THE Script_Docker_Dev SHALL carregar as variáveis a partir do Arquivo_Env_Central antes de iniciar qualquer operação.
5. WHEN o Script_Docker_Prod é executado, THE Script_Docker_Prod SHALL carregar as variáveis a partir do Arquivo_Env_Central antes de iniciar qualquer operação.
6. IF o Arquivo_Env_Central não existe na raiz do repositório, THEN THE Wrapper SHALL iniciar o Wizard_Env para criação interativa do arquivo conforme definido no Requirement 28.
7. IF o Arquivo_Env_Central não existe quando um script individual (Script_Dev, Script_Prod, Script_Docker_Dev ou Script_Docker_Prod) é executado diretamente sem passar pelo Wrapper, THEN o script SHALL exibir uma mensagem de erro informando que o Arquivo_Env_Central é obrigatório e encerrar com código de saída 1.
8. THE Arquivo_Env_Central SHALL conter comentários descrevendo cada variável e seus valores esperados.
9. WHEN uma variável é definida no Arquivo_Env_Central, THE Script_Dev SHALL utilizar o valor centralizado em vez de definir a variável localmente no corpo do script.
10. WHEN uma variável é definida no Arquivo_Env_Central, THE Script_Prod SHALL utilizar o valor centralizado em vez de definir a variável localmente no corpo do script.

### Requirement 2: Detecção automática da distribuição ou sistema operacional

**User Story:** Como administrador de sistemas, eu quero que o wrapper detecte automaticamente a família da distribuição Linux ou o sistema operacional macOS, para que o script correto seja executado sem intervenção manual.

#### Acceptance Criteria

1. WHEN o arquivo `/etc/os-release` está presente, THE Wrapper SHALL identificar a família da distribuição como Distribuição_Debian, Distribuição_RPM ou Distribuição_Arch com base nos campos `ID` e `ID_LIKE`.
2. WHEN o campo `ID` é "arch" ou o campo `ID_LIKE` contém "arch" no `/etc/os-release`, THE Wrapper SHALL classificar a distribuição como Distribuição_Arch.
3. WHEN o comando `uname -s` retorna "Darwin", THE Wrapper SHALL classificar o sistema operacional como Distribuição_macOS independentemente da presença do `/etc/os-release`.
4. IF o arquivo `/etc/os-release` não está presente e o sistema não é Distribuição_macOS, THEN THE Wrapper SHALL exibir uma mensagem de erro e encerrar a execução com código de saída 3.
5. IF a distribuição identificada não pertence à família Distribuição_Debian, Distribuição_RPM, Distribuição_Arch nem é Distribuição_macOS, THEN THE Wrapper SHALL exibir uma mensagem informando a distribuição não suportada e encerrar com código de saída 3.

### Requirement 3: Menu interativo do wrapper

**User Story:** Como administrador de sistemas, eu quero um menu interativo com opções de configuração, para que eu possa escolher qual ação executar de forma simples.

#### Acceptance Criteria

1. WHEN a detecção da distribuição é concluída com sucesso, THE Wrapper SHALL exibir um menu com as opções: (1) Configurar ambiente dev, (2) Configurar ambiente prod, (3) Instalar Redis, (4) Instalar Nginx, (5) Configurar ambiente dev via Docker, (6) Configurar ambiente prod via Docker, (7) Iniciar Dockhand.
2. WHILE executando em Distribuição_macOS, THE Wrapper SHALL exibir apenas as opções (1) Configurar ambiente dev, (5) Configurar ambiente dev via Docker, (6) Configurar ambiente prod via Docker e (7) Iniciar Dockhand, ocultando as opções 2, 3 e 4 com uma mensagem "não suportado no macOS".
3. WHEN o usuário seleciona uma opção válida (1 a 7), THE Wrapper SHALL executar o script correspondente à distribuição detectada, ao ambiente Docker ou ao Dockhand.
4. IF o usuário informa uma opção inválida, THEN THE Wrapper SHALL exibir uma mensagem de erro e encerrar com código de saída 1.
5. IF o arquivo do script correspondente não é encontrado no diretório, THEN THE Wrapper SHALL exibir uma mensagem de erro e encerrar com código de saída 2.

### Requirement 4: Gerenciamento da URL do repositório Git

**User Story:** Como desenvolvedor, eu quero que a URL do repositório Git seja persistida no Arquivo_Env_Central, para que eu não precise informá-la novamente em execuções futuras.

#### Acceptance Criteria

1. WHEN o Arquivo_Env_Central existe e contém a variável `GIT_URL`, THE Script_Dev SHALL utilizar o valor armazenado sem solicitar entrada do usuário.
2. WHEN o Arquivo_Env_Central não existe ou não contém a variável `GIT_URL`, THE Script_Dev SHALL solicitar a URL do repositório Git ao usuário via prompt interativo.
3. WHEN o usuário informa a URL do repositório, THE Script_Dev SHALL persistir o valor no Arquivo_Env_Central para uso futuro.
4. IF o usuário informa uma URL vazia, THEN THE Script_Dev SHALL exibir uma mensagem de erro e encerrar com código de saída 1.
5. WHEN o Arquivo_Env_Central existe e contém a variável `GIT_URL`, THE Script_Prod SHALL utilizar o valor armazenado sem solicitar entrada do usuário.
6. WHEN o Arquivo_Env_Central não existe ou não contém a variável `GIT_URL`, THE Script_Prod SHALL solicitar a URL do repositório Git ao usuário via prompt interativo.

### Requirement 5: Instalação de dependências do sistema (Desenvolvimento)

**User Story:** Como desenvolvedor, eu quero que todas as dependências do sistema sejam instaladas automaticamente, para que eu possa começar a trabalhar no SUAP sem configuração manual.

#### Acceptance Criteria

1. THE Script_Dev SHALL verificar se as dependências do sistema já estão instaladas antes de tentar instalá-las.
2. WHEN uma ou mais dependências do sistema não estão instaladas, THE Script_Dev SHALL instalar todas as dependências necessárias usando o gerenciador de pacotes da distribuição (apt para Distribuição_Debian, dnf para Distribuição_RPM).
3. IF a instalação de pacotes pelo gerenciador de pacotes falha, THEN THE Script_Dev SHALL exibir uma mensagem de erro e encerrar com código de saída 1.
4. WHEN todas as dependências já estão instaladas, THE Script_Dev SHALL prosseguir para a próxima etapa sem executar o gerenciador de pacotes.
5. THE Script_Dev SHALL instalar dependências para: ferramentas de compilação, LDAP, Pillow, PyMSSQL, lxml, WeasyPrint, manipulação de PDF e utilitários gerais.

### Requirement 6: Configuração de locale e timezone (Desenvolvimento)

**User Story:** Como desenvolvedor, eu quero que o locale e o timezone sejam configurados corretamente, para que a aplicação SUAP funcione com a localização brasileira.

#### Acceptance Criteria

1. WHEN o locale atual não é `pt_BR.UTF-8`, THE Script_Dev SHALL configurar o locale do sistema para `pt_BR.UTF-8`.
2. WHEN o locale atual já é `pt_BR.UTF-8`, THE Script_Dev SHALL prosseguir sem alterar a configuração.
3. WHEN o timezone atual não é `America/Fortaleza`, THE Script_Dev SHALL configurar o timezone para `America/Fortaleza`.
4. WHEN o timezone atual já é `America/Fortaleza`, THE Script_Dev SHALL prosseguir sem alterar a configuração.

### Requirement 7: Instalação do gerenciador UV (Desenvolvimento)

**User Story:** Como desenvolvedor, eu quero que o UV seja instalado automaticamente, para que eu possa gerenciar dependências Python de forma moderna.

#### Acceptance Criteria

1. WHEN o comando `uv` não está disponível no PATH, THE Script_Dev SHALL verificar se o UV está instalado em outro local do sistema (ex: `~/.cargo/bin/uv`, `~/.local/bin/uv`) e adicioná-lo ao PATH caso encontrado.
2. IF o UV não está disponível no PATH e não é encontrado em nenhum local conhecido do sistema, THEN THE Script_Dev SHALL baixar e instalar o UV a partir da URL oficial.
3. WHEN o UV é instalado ou encontrado, THE Script_Dev SHALL adicionar a configuração de auto-completar ao arquivo `.bashrc` do usuário.
4. WHEN o comando `uv` já está disponível no PATH, THE Script_Dev SHALL prosseguir sem reinstalar.

### Requirement 8: Clone e atualização do código SUAP (Desenvolvimento)

**User Story:** Como desenvolvedor, eu quero que o código do SUAP seja clonado ou atualizado automaticamente, para que eu tenha sempre a versão mais recente.

#### Acceptance Criteria

1. WHEN o diretório do SUAP não contém um repositório Git, THE Script_Dev SHALL executar `git clone` da URL configurada para o diretório base de projetos.
2. WHEN o diretório do SUAP já contém um repositório Git, THE Script_Dev SHALL executar `git checkout master` seguido de `git pull` para atualizar o código.

### Requirement 9: Geração de arquivos de configuração (Desenvolvimento)

**User Story:** Como desenvolvedor, eu quero que os arquivos de configuração sejam gerados automaticamente a partir dos exemplos, para que eu tenha uma base funcional.

#### Acceptance Criteria

1. WHEN o arquivo `settings.py` não existe no diretório do SUAP, THE Script_Dev SHALL copiar `settings_sample.py` para `settings.py`.
2. WHEN o arquivo `settings.py` já existe, THE Script_Dev SHALL preservar o arquivo existente sem sobrescrevê-lo.
3. WHEN o arquivo `.env` não existe no diretório do SUAP, THE Script_Dev SHALL copiar `.env.dev.sample` para `.env`.
4. WHEN o arquivo `.env` já existe, THE Script_Dev SHALL preservar o arquivo existente sem sobrescrevê-lo.

### Requirement 10: Criação de virtualenv e instalação de dependências (Desenvolvimento)

**User Story:** Como desenvolvedor, eu quero que o virtualenv seja criado e as dependências instaladas automaticamente, para que o ambiente esteja pronto para uso.

#### Acceptance Criteria

1. WHEN o Python 3.12 não está disponível via UV, THE Script_Dev SHALL instalar Python 3.12 usando `uv python install`.
2. WHEN o diretório `.venv` não existe no projeto, THE Script_Dev SHALL criar um virtualenv com Python 3.12 usando `uv venv`.
3. WHEN o diretório `.venv` já existe, THE Script_Dev SHALL prosseguir sem recriar o virtualenv.
4. WHEN o arquivo `pyproject.toml` existe no projeto, THE Script_Dev SHALL instalar dependências usando `uv sync --group dev`.
5. WHEN o arquivo `pyproject.toml` não existe e o diretório `requirements/` existe, THE Script_Dev SHALL instalar dependências usando `uv pip install -r requirements/development.txt`.
6. IF nem o arquivo `pyproject.toml` nem o diretório `requirements/` existem, THEN THE Script_Dev SHALL exibir uma mensagem de erro e encerrar com código de saída 1.
7. IF a instalação de dependências (uv sync ou uv pip install) falha, THEN THE Script_Dev SHALL exibir uma mensagem de erro e encerrar com código de saída 1.

### Requirement 11: Instalação de dependências do sistema (Produção)

**User Story:** Como administrador de sistemas, eu quero que as dependências de produção sejam instaladas automaticamente, para que o servidor esteja pronto para executar o SUAP.

#### Acceptance Criteria

1. THE Script_Prod SHALL verificar se as dependências do sistema já estão instaladas antes de tentar instalá-las.
2. WHEN uma ou mais dependências não estão instaladas, THE Script_Prod SHALL instalar todas as dependências necessárias usando o gerenciador de pacotes da distribuição.
3. IF a instalação de pacotes pelo gerenciador de pacotes falha, THEN THE Script_Prod SHALL exibir uma mensagem de erro e encerrar com código de saída 1.
4. THE Script_Prod SHALL instalar pacotes adicionais de produção incluindo: python3, supervisor, cron/cronie, ntp/chrony e ferramentas de gerenciamento de processos.

### Requirement 12: Validação de execução como root (Produção)

**User Story:** Como administrador de sistemas, eu quero que o script de produção exija execução como root, para que as operações privilegiadas sejam realizadas corretamente.

#### Acceptance Criteria

1. WHEN o script de produção é executado sem privilégios de root, THE Script_Prod SHALL exibir uma mensagem informando que o script deve ser executado como root e encerrar com código de saída 1.
2. WHEN o script é executado com privilégios de root, THE Script_Prod SHALL prosseguir com a execução normalmente.

### Requirement 13: Clone e atualização do código SUAP (Produção)

**User Story:** Como administrador de sistemas, eu quero que o código seja clonado com profundidade mínima em produção, para que o download seja mais rápido e ocupe menos espaço.

#### Acceptance Criteria

1. WHEN o diretório do SUAP não contém um repositório Git, THE Script_Prod SHALL executar `git clone --depth 1` da URL configurada.
2. WHEN o diretório do SUAP já contém um repositório Git, THE Script_Prod SHALL executar `git checkout master` seguido de `git pull` para atualizar.
3. IF o diretório do SUAP não contém um repositório Git, THEN THE Script_Prod SHALL executar apenas `git clone` e não executar `git checkout` ou `git pull`.

### Requirement 14: Criação de virtualenv e instalação de dependências (Produção)

**User Story:** Como administrador de sistemas, eu quero que o virtualenv de produção seja criado com o venv padrão, para manter compatibilidade com o ambiente de produção.

#### Acceptance Criteria

1. WHEN o diretório do virtualenv não existe, THE Script_Prod SHALL criar um virtualenv usando `python3 -m venv`.
2. WHEN o diretório do virtualenv já existe, THE Script_Prod SHALL prosseguir sem recriar.
3. WHEN o arquivo `pyproject.toml` existe no projeto, THE Script_Prod SHALL instalar dependências usando `pip install . --group prod --no-cache-dir`.
4. WHEN o arquivo `pyproject.toml` não existe e o diretório `requirements/` existe, THE Script_Prod SHALL instalar dependências usando `pip install -r requirements/production.txt --no-cache-dir`.
5. IF nem o arquivo `pyproject.toml` nem o diretório `requirements/` existem, THEN THE Script_Prod SHALL exibir uma mensagem de erro e encerrar com código de saída 1.
6. IF a instalação de dependências via pip install falha, THEN THE Script_Prod SHALL exibir uma mensagem de erro e encerrar com código de saída diferente de zero.

### Requirement 15: Configuração do Supervisor (Produção)

**User Story:** Como administrador de sistemas, eu quero escolher quais serviços configurar no Supervisor, para que o deploy seja flexível conforme a necessidade do servidor.

#### Acceptance Criteria

1. WHEN a instalação de dependências é concluída, THE Script_Prod SHALL exibir um menu com as opções: (1) SUAP, (2) Celery, (3) Ambos.
2. WHEN o usuário seleciona a opção SUAP, THE Script_Prod SHALL copiar os arquivos de configuração e runner do SUAP para os diretórios do Supervisor.
3. WHEN o usuário seleciona a opção Celery, THE Script_Prod SHALL copiar os arquivos de configuração e runners do Celery Worker, Celery Beat e Celery Flower para os diretórios do Supervisor.
4. WHEN o usuário seleciona a opção Ambos, THE Script_Prod SHALL copiar os arquivos de configuração e runners tanto do SUAP quanto do Celery.
5. IF o usuário informa uma opção inválida, THEN THE Script_Prod SHALL exibir uma mensagem de erro e encerrar com código de saída 1.
6. IF um arquivo de configuração do Supervisor não é encontrado no diretório de instalação, THEN THE Script_Prod SHALL exibir mensagem de erro e encerrar com código de saída 1.
7. WHEN os arquivos são copiados, THE Script_Prod SHALL definir permissão de execução nos scripts runner.
8. WHEN os arquivos de configuração do Supervisor são efetivamente copiados para o diretório de destino, THE Script_Prod SHALL executar `supervisorctl reread` e `supervisorctl update` para aplicar as alterações.
9. WHEN nenhum arquivo de configuração do Supervisor é copiado (etapa pulada por idempotência), THE Script_Prod SHALL não executar `supervisorctl reread` nem `supervisorctl update`.

### Requirement 16: Configuração de permissões de arquivos (Produção)

**User Story:** Como administrador de sistemas, eu quero que as permissões dos arquivos sejam ajustadas corretamente, para que o Supervisor e o SUAP funcionem com o usuário adequado.

#### Acceptance Criteria

1. WHEN toda a configuração de produção é concluída, THE Script_Prod SHALL definir o proprietário do diretório do SUAP, diretório de logs e virtualenv para o usuário `www-data`.

### Requirement 17: Destino de configuração do Supervisor por distribuição

**User Story:** Como administrador de sistemas, eu quero que os arquivos do Supervisor sejam copiados para o diretório correto da distribuição, para que o serviço funcione adequadamente.

#### Acceptance Criteria

1. WHILE executando em uma Distribuição_Debian, THE Script_Prod SHALL copiar arquivos de configuração do Supervisor para `/etc/supervisor/conf.d/`.
2. WHILE executando em uma Distribuição_RPM, THE Script_Prod SHALL copiar arquivos de configuração do Supervisor para `/etc/supervisord.d/`.
3. WHILE executando em uma Distribuição_Arch, THE Script_Prod SHALL copiar arquivos de configuração do Supervisor para `/etc/supervisor.d/` ou configurar serviços via systemd user services.

### Requirement 18: Instalação do Redis

**User Story:** Como administrador de sistemas, eu quero instalar o Redis de forma automatizada, para que o cache da aplicação esteja disponível rapidamente.

#### Acceptance Criteria

1. WHEN o Script_Redis é executado, THE Script_Redis SHALL instalar o pacote Redis usando o gerenciador de pacotes da distribuição.
2. WHEN a instalação é concluída, THE Script_Redis SHALL iniciar o serviço Redis via systemctl.
3. WHEN o serviço Redis é iniciado, THE Script_Redis SHALL habilitar o serviço para iniciar automaticamente no boot do sistema.

### Requirement 19: Instalação do Nginx

**User Story:** Como administrador de sistemas, eu quero instalar o Nginx e configurar o proxy reverso do SUAP automaticamente, para que a aplicação fique acessível via web.

#### Acceptance Criteria

1. WHEN o Script_Nginx é executado, THE Script_Nginx SHALL instalar o pacote Nginx usando o gerenciador de pacotes da distribuição.
2. WHEN a instalação é concluída, THE Script_Nginx SHALL iniciar o serviço Nginx via systemctl.
3. WHEN o serviço é iniciado, THE Script_Nginx SHALL habilitar o serviço para iniciar automaticamente no boot.
4. WHEN a instalação é concluída, THE Script_Nginx SHALL copiar o arquivo de configuração do SUAP para o local adequado da distribuição.
5. WHEN a configuração é copiada, THE Script_Nginx SHALL testar a configuração do Nginx usando `nginx -t`.
6. WHEN o teste é bem-sucedido, THE Script_Nginx SHALL recarregar o Nginx para aplicar a configuração.

### Requirement 20: Configuração de Nginx por distribuição

**User Story:** Como administrador de sistemas, eu quero que a configuração do Nginx respeite o padrão de cada distribuição, para que o serviço funcione de acordo com as convenções do sistema.

#### Acceptance Criteria

1. WHILE executando em uma Distribuição_Debian, THE Script_Nginx SHALL copiar a configuração para `/etc/nginx/sites-available/suap` e criar um link simbólico em `/etc/nginx/sites-enabled/suap`.
2. WHILE executando em uma Distribuição_Debian, THE Script_Nginx SHALL remover o link simbólico da configuração padrão em `/etc/nginx/sites-enabled/default` somente após a configuração do SUAP ser copiada e o link simbólico em `sites-enabled/suap` ser criado com sucesso.
3. WHILE executando em uma Distribuição_RPM, THE Script_Nginx SHALL copiar a configuração para `/etc/nginx/conf.d/suap.conf`.
4. WHILE executando em uma Distribuição_Arch, THE Script_Nginx SHALL copiar a configuração para `/etc/nginx/conf.d/suap.conf`.

### Requirement 21: Configuração do Nginx como proxy reverso

**User Story:** Como administrador de sistemas, eu quero que o Nginx esteja configurado como proxy reverso para o SUAP, para que a aplicação Django seja servida corretamente.

#### Acceptance Criteria

1. THE Script_Nginx SHALL configurar um upstream com balanceamento de carga usando a estratégia `least_conn` apontando para a porta 8000.
2. THE Script_Nginx SHALL configurar o tamanho máximo do corpo da requisição para 100 MB.
3. THE Script_Nginx SHALL configurar o Nginx para servir arquivos estáticos diretamente a partir do diretório `/opt/suap/deploy/static`.
4. THE Script_Nginx SHALL configurar o Nginx para servir arquivos de mídia diretamente a partir do diretório `/opt/suap/deploy/media`.
5. THE Script_Nginx SHALL configurar páginas de erro customizadas para os códigos 500, 502, 503, 504 e 413.
6. THE Script_Nginx SHALL configurar um bloco de servidor secundário na porta 8001 com proxy reverso para o mesmo upstream.
7. THE Script_Nginx SHALL configurar um formato de log customizado que inclua tempo de requisição e tempo de resposta do upstream.
8. THE Script_Nginx SHALL configurar buffers de proxy aumentados para suportar cabeçalhos HTTP grandes.

### Requirement 22: Ambiente Docker para desenvolvimento

**User Story:** Como desenvolvedor, eu quero subir o ambiente SUAP em containers Docker para desenvolvimento, para que eu possa trabalhar em um ambiente isolado e reproduzível sem instalar dependências diretamente no sistema operacional.

#### Acceptance Criteria

1. THE Script_Docker_Dev SHALL fornecer um arquivo `Dockerfile` para construção da imagem de desenvolvimento do SUAP com todas as dependências necessárias.
2. THE Script_Docker_Dev SHALL fornecer um arquivo `docker-compose.yml` que defina os serviços necessários para o ambiente de desenvolvimento (aplicação SUAP, banco de dados PostgreSQL e Redis).
3. WHEN o Script_Docker_Dev é executado, THE Script_Docker_Dev SHALL verificar se o Docker e o Docker_Compose estão instalados no sistema.
4. IF o Docker ou o Docker_Compose não estão instalados, THEN THE Script_Docker_Dev SHALL oferecer ao usuário a opção de instalar o Docker automaticamente usando o Script_Install_Docker conforme definido no Requirement 29, e caso o usuário recuse, exibir uma mensagem de erro informando os pré-requisitos e encerrar com código de saída 1.
5. WHEN o Docker e o Docker_Compose estão disponíveis, THE Script_Docker_Dev SHALL construir as imagens e iniciar os containers usando `docker compose up`.
6. THE Script_Docker_Dev SHALL montar o código-fonte do SUAP como volume no container para permitir edição em tempo real no host.
7. THE Script_Docker_Dev SHALL expor a porta 8000 do container de desenvolvimento para acesso local à aplicação.
8. THE Script_Docker_Dev SHALL configurar variáveis de ambiente no container a partir do Arquivo_Env_Central.
9. WHEN os containers são iniciados, THE Script_Docker_Dev SHALL exibir uma mensagem informando como acessar a aplicação e os logs.

### Requirement 23: Ambiente Docker para produção

**User Story:** Como administrador de sistemas, eu quero subir o ambiente SUAP em containers Docker para produção, para que o deploy seja padronizado, escalável e independente da distribuição Linux do host.

#### Acceptance Criteria

1. THE Script_Docker_Prod SHALL fornecer um arquivo `Dockerfile` otimizado para produção com imagem base mínima e multi-stage build.
2. THE Script_Docker_Prod SHALL fornecer um arquivo `docker-compose.prod.yml` que defina os serviços necessários para o ambiente de produção (aplicação SUAP, Celery Worker, Celery Beat, Celery Flower, Redis e Nginx como proxy reverso).
3. WHEN o Script_Docker_Prod é executado, THE Script_Docker_Prod SHALL verificar se o Docker e o Docker_Compose estão instalados no sistema.
4. IF o Docker ou o Docker_Compose não estão instalados, THEN THE Script_Docker_Prod SHALL oferecer ao usuário a opção de instalar o Docker automaticamente usando o Script_Install_Docker conforme definido no Requirement 29, e caso o usuário recuse, exibir uma mensagem de erro informando os pré-requisitos e encerrar com código de saída 1.
5. WHEN o Docker e o Docker_Compose estão disponíveis, THE Script_Docker_Prod SHALL construir as imagens e iniciar os containers usando `docker compose -f docker-compose.prod.yml up -d`.
6. THE Script_Docker_Prod SHALL configurar o container Nginx como proxy reverso para o container da aplicação SUAP.
7. THE Script_Docker_Prod SHALL configurar volumes persistentes para dados do banco de dados, arquivos de mídia e logs.
8. THE Script_Docker_Prod SHALL configurar variáveis de ambiente no container a partir do Arquivo_Env_Central.
9. THE Script_Docker_Prod SHALL configurar política de restart automático (`restart: unless-stopped`) para todos os serviços de produção.
10. WHEN os containers são iniciados, THE Script_Docker_Prod SHALL exibir o status dos serviços e instruções para gerenciamento dos containers.

### Requirement 24: Idempotência dos scripts

**User Story:** Como administrador de sistemas, eu quero que os scripts sejam idempotentes, para que eu possa executá-los várias vezes sem efeitos colaterais indesejados.

#### Acceptance Criteria

1. THE Script_Dev SHALL verificar o estado atual de cada componente antes de realizar uma ação de instalação ou configuração.
2. THE Script_Prod SHALL verificar o estado atual de cada componente antes de realizar uma ação de instalação ou configuração.
3. WHEN um componente já está instalado ou configurado corretamente, THE Script_Dev SHALL pular a etapa correspondente e exibir uma mensagem informando que o componente já está configurado.
4. WHEN um componente já está instalado ou configurado corretamente, THE Script_Prod SHALL pular a etapa correspondente e exibir uma mensagem informando que o componente já está configurado.

### Requirement 25: Saída com feedback visual colorido

**User Story:** Como operador, eu quero que os scripts exibam mensagens coloridas, para que eu possa acompanhar o progresso e identificar rapidamente o status de cada etapa.

#### Acceptance Criteria

1. THE Script_Dev SHALL exibir mensagens de progresso em cor verde para ações sendo executadas.
2. THE Script_Dev SHALL exibir mensagens em cor amarela para etapas já concluídas anteriormente (pulos por idempotência).
3. THE Script_Prod SHALL exibir mensagens de progresso em cor verde para ações sendo executadas.
4. THE Script_Prod SHALL exibir mensagens em cor amarela para etapas já concluídas anteriormente (pulos por idempotência).
5. THE Script_Redis SHALL exibir mensagens de progresso em cor verde para ações sendo executadas.
6. THE Script_Nginx SHALL exibir mensagens de progresso em cor verde para ações sendo executadas.
7. THE Script_Docker_Dev SHALL exibir mensagens de progresso em cor verde para ações sendo executadas.
8. THE Script_Docker_Prod SHALL exibir mensagens de progresso em cor verde para ações sendo executadas.
9. THE Wrapper SHALL exibir mensagens de progresso em cor verde para ações sendo executadas.

### Requirement 26: Mensagem final com próximos passos

**User Story:** Como operador, eu quero receber instruções claras ao final da execução, para que eu saiba quais ações realizar em seguida.

#### Acceptance Criteria

1. WHEN a execução do Script_Dev é concluída com sucesso, THE Script_Dev SHALL exibir uma mensagem de sucesso e instruções para: recarregar o bashrc, editar variáveis de ambiente, acessar a pasta do SUAP e rodar o servidor de desenvolvimento.
2. WHEN a execução do Script_Prod é concluída com sucesso, THE Script_Prod SHALL exibir uma mensagem de sucesso e instruções para: recarregar o bashrc, editar variáveis de ambiente, acessar a pasta do SUAP e iniciar os serviços configurados via Supervisor.

### Requirement 27: Integração com Dockhand para gerenciamento de containers

**User Story:** Como administrador de sistemas, eu quero iniciar o Dockhand a partir do menu do setup, para que eu possa gerenciar containers Docker por meio de uma interface web sem instalar ferramentas adicionais.

#### Acceptance Criteria

1. WHEN o usuário seleciona a opção 7 no menu, THE Wrapper SHALL verificar se o Docker está disponível no sistema antes de prosseguir.
2. IF o Docker não está instalado ou o daemon não está em execução, THEN THE Wrapper SHALL oferecer ao usuário a opção de instalar o Docker automaticamente usando o Script_Install_Docker conforme definido no Requirement 29, e caso o usuário recuse ou a instalação falhe, exibir uma mensagem de erro informando que o Docker é pré-requisito para o Dockhand e encerrar com código de saída 1.
3. WHEN o Docker está disponível, THE Wrapper SHALL executar `docker pull lscr.io/linuxserver/dockhand:latest` para obter a imagem mais recente do Dockhand.
4. WHEN a imagem é obtida, THE Wrapper SHALL iniciar o container Dockhand expondo a interface web na porta 9093 do host.
5. WHEN o container Dockhand é iniciado, THE Wrapper SHALL montar o socket do Docker (`/var/run/docker.sock`) como volume para permitir o gerenciamento dos containers do host.
6. WHEN o container Dockhand é iniciado com sucesso, THE Wrapper SHALL exibir uma mensagem informando a URL de acesso à interface web usando a porta efetivamente configurada para o container (ex: http://localhost:<porta_configurada>).
7. IF o container Dockhand falha ao iniciar, THEN THE Wrapper SHALL exibir uma mensagem de erro com o motivo da falha e encerrar com código de saída 1.
8. WHEN já existe um container Dockhand em execução, THE Wrapper SHALL exibir uma mensagem informando que o Dockhand já está ativo e mostrar a URL de acesso.

### Requirement 28: Criação interativa do arquivo de ambiente

**User Story:** Como desenvolvedor, eu quero que o script me pergunte interativamente os valores de cada variável ao criar o `.env` pela primeira vez, para que eu possa personalizar o ambiente sem editar o arquivo manualmente depois.

#### Acceptance Criteria

1. WHEN o Arquivo_Env_Central não existe e o Wrapper é executado, THE Wizard_Env SHALL exibir um prompt interativo para cada variável na seguinte ordem: PYTHON_VERSION, BASE_DIR, SUAP_DIR, VENV_DIR, GIT_URL.
2. WHEN o Wizard_Env exibe o prompt de uma variável, THE Wizard_Env SHALL mostrar o nome da variável, uma descrição do propósito, exemplos de valores válidos e o valor padrão para ambiente de desenvolvimento.
3. WHEN o usuário pressiona Enter sem digitar um valor para PYTHON_VERSION, THE Wizard_Env SHALL utilizar o valor padrão `3.12`.
4. WHEN o usuário pressiona Enter sem digitar um valor para BASE_DIR, THE Wizard_Env SHALL utilizar o valor padrão `$HOME/Projetos`.
5. WHEN o usuário pressiona Enter sem digitar um valor para SUAP_DIR, THE Wizard_Env SHALL utilizar o valor padrão `${BASE_DIR}/suap`.
6. WHEN o usuário pressiona Enter sem digitar um valor para VENV_DIR, THE Wizard_Env SHALL utilizar o valor padrão `${SUAP_DIR}/.venv`.
7. IF o usuário pressiona Enter sem digitar um valor para GIT_URL (valor vazio), THEN THE Wizard_Env SHALL exibir uma mensagem de erro informando que GIT_URL é obrigatória e encerrar com código de saída 1.
8. WHEN o usuário informa qualquer valor não vazio para GIT_URL, THE Wizard_Env SHALL aceitar a string fornecida e utilizá-la sem validação adicional de formato.
9. WHEN todos os valores são coletados, THE Wizard_Env SHALL gravar o Arquivo_Env_Central com comentários descritivos acima de cada variável.
10. WHEN o Arquivo_Env_Central é gravado com sucesso, THE Wizard_Env SHALL exibir uma mensagem de confirmação mostrando o caminho do arquivo criado e um resumo dos valores configurados.

### Requirement 29: Instalação interativa do Docker

**User Story:** Como administrador de sistemas, eu quero que o script ofereça instalar o Docker automaticamente quando ele não está presente, para que eu possa configurar o ambiente Docker sem precisar instalar manualmente os pré-requisitos.

#### Acceptance Criteria

1. WHEN a função `check_docker_available()` detecta que o Docker não está instalado, THE Script_Install_Docker SHALL exibir um prompt perguntando ao usuário se deseja instalar o Docker automaticamente.
2. WHEN o usuário responde afirmativamente ao prompt de instalação, THE Script_Install_Docker SHALL executar o script de instalação localizado em `docker/install-docker.sh`.
3. IF o usuário responde negativamente ao prompt de instalação, THEN THE Script_Install_Docker SHALL exibir uma mensagem de erro informando os pré-requisitos e encerrar com código de saída 1.
4. WHILE executando em uma Distribuição_Debian, THE Script_Install_Docker SHALL adicionar o repositório oficial Docker para apt conforme documentação oficial (https://docs.docker.com/engine/install/debian/) e instalar os pacotes `docker-ce`, `docker-ce-cli`, `containerd.io` e `docker-compose-plugin`.
5. WHILE executando em uma Distribuição_RPM, THE Script_Install_Docker SHALL adicionar o repositório oficial Docker para dnf conforme documentação oficial (https://docs.docker.com/engine/install/fedora/) e instalar os pacotes `docker-ce`, `docker-ce-cli`, `containerd.io` e `docker-compose-plugin`.
6. WHILE executando em uma Distribuição_Arch, THE Script_Install_Docker SHALL instalar os pacotes `docker` e `docker-compose` usando `pacman -S --needed --noconfirm`.
7. WHILE executando em uma Distribuição_macOS, THE Script_Install_Docker SHALL informar que o Docker Desktop é obrigatório, exibir a URL de download (https://docs.docker.com/desktop/install/mac-install/) e encerrar sem realizar instalação automatizada.
8. WHEN a instalação dos pacotes Docker é concluída, THE Script_Install_Docker SHALL iniciar o serviço Docker via `systemctl start docker`.
9. WHEN o serviço Docker é iniciado, THE Script_Install_Docker SHALL habilitar o serviço Docker para iniciar automaticamente no boot via `systemctl enable docker`.
10. WHEN a instalação dos pacotes Docker é concluída, THE Script_Install_Docker SHALL adicionar o usuário atual ao grupo `docker` para permitir execução sem privilégios de root.
11. WHEN a instalação e configuração são concluídas, THE Script_Install_Docker SHALL verificar que o Docker funciona corretamente executando `docker --version` e `docker compose version`.
12. IF a verificação pós-instalação falha (o comando `docker --version` ou `docker compose version` retorna erro), THEN THE Script_Install_Docker SHALL exibir uma mensagem de erro informando que a instalação não foi concluída com sucesso e encerrar com código de saída 1.
13. WHEN a verificação pós-instalação é bem-sucedida, THE Script_Install_Docker SHALL exibir uma mensagem de sucesso com as versões instaladas e informar ao usuário que pode ser necessário fazer logout e login novamente para que a adição ao grupo `docker` tenha efeito.
14. IF a instalação dos pacotes Docker falha (erro no gerenciador de pacotes), THEN THE Script_Install_Docker SHALL exibir uma mensagem de erro com detalhes da falha e encerrar com código de saída 1.
15. IF o sistema operacional não é uma Distribuição_Debian, Distribuição_RPM, Distribuição_Arch nem Distribuição_macOS, THEN THE Script_Install_Docker SHALL exibir uma mensagem informando que a instalação automática não é suportada para a distribuição detectada e encerrar com código de saída 1.

### Requirement 30: Suporte a Arch Linux

**User Story:** Como desenvolvedor usando Arch Linux, eu quero que os scripts suportem minha distribuição, para que eu possa configurar o ambiente SUAP sem adaptações manuais.

#### Acceptance Criteria

1. WHEN o campo `ID` no `/etc/os-release` é "arch" ou o campo `ID_LIKE` contém "arch", THE Wrapper SHALL classificar a distribuição como Distribuição_Arch e rotear para os scripts no diretório `arch/`.
2. WHEN a distribuição detectada é Distribuição_Arch, THE Script_Dev_Arch SHALL instalar dependências do sistema usando `pacman -S --needed --noconfirm`.
3. WHEN a distribuição detectada é Distribuição_Arch, THE Script_Prod_Arch SHALL instalar dependências de produção usando `pacman -S --needed --noconfirm`.
4. THE Script_Dev_Arch SHALL utilizar nomes de pacotes adaptados ao ecossistema Arch (ex: `base-devel`, `python`, `redis`, `nginx`).
5. THE Script_Prod_Arch SHALL utilizar nomes de pacotes adaptados ao ecossistema Arch incluindo pacotes do AUR ou repositório community quando necessário (ex: `supervisor`).
6. WHEN o locale precisa ser configurado em Distribuição_Arch, THE Script_Dev_Arch SHALL utilizar `localectl set-locale LANG=pt_BR.UTF-8` para configuração do locale.
7. WHEN a função `is_pkg_installed()` é chamada em Distribuição_Arch, THE Script_Dev_Arch SHALL verificar a instalação do pacote usando `pacman -Q`.
8. WHEN a função `is_pkg_installed()` é chamada em Distribuição_Arch, THE Script_Prod_Arch SHALL verificar a instalação do pacote usando `pacman -Q`.
9. WHILE executando em uma Distribuição_Arch, THE Script_Prod_Arch SHALL copiar arquivos de configuração do Supervisor para `/etc/supervisor.d/` ou configurar serviços via systemd user services.
10. WHILE executando em uma Distribuição_Arch, THE Script_Nginx SHALL copiar a configuração do Nginx para `/etc/nginx/conf.d/suap.conf` seguindo o mesmo padrão da Distribuição_RPM.
11. WHEN o usuário seleciona as opções 1 a 4 no menu e a distribuição detectada é Distribuição_Arch, THE Wrapper SHALL rotear a execução para os scripts correspondentes no diretório `arch/`.
12. WHILE executando em uma Distribuição_Arch, THE Script_Install_Docker SHALL instalar os pacotes `docker` e `docker-compose` usando `pacman -S --needed --noconfirm`.

### Requirement 31: Suporte a macOS

**User Story:** Como desenvolvedor usando macOS, eu quero configurar o ambiente de desenvolvimento SUAP no meu Mac, para que eu possa desenvolver sem precisar de uma VM Linux.

#### Acceptance Criteria

1. WHEN o comando `uname -s` retorna "Darwin", THE Wrapper SHALL classificar o sistema operacional como Distribuição_macOS e rotear para os scripts no diretório `macos/`.
2. THE Distribuição_macOS SHALL suportar apenas o ambiente de desenvolvimento (Script_Dev_macOS); scripts de produção não são fornecidos para macOS.
3. WHEN a distribuição detectada é Distribuição_macOS, THE Script_Dev_macOS SHALL verificar se o Homebrew está instalado no sistema.
4. IF o Homebrew não está instalado, THEN THE Script_Dev_macOS SHALL exibir uma mensagem de erro com instruções de instalação (https://brew.sh) e encerrar com código de saída 1.
5. WHEN o Homebrew está disponível, THE Script_Dev_macOS SHALL instalar dependências do sistema usando `brew install`.
6. THE Script_Dev_macOS SHALL utilizar nomes de pacotes adaptados ao Homebrew (ex: `openldap`, `libpq`, `freetype`, `libxml2`).
7. WHEN a configuração de locale é solicitada em Distribuição_macOS, THE Script_Dev_macOS SHALL pular a etapa com uma mensagem informativa (msg_skip) indicando que a configuração de locale não é necessária no macOS.
8. WHEN a configuração de timezone é solicitada em Distribuição_macOS, THE Script_Dev_macOS SHALL configurar o timezone usando `sudo systemsetup -settimezone America/Fortaleza`.
9. WHEN a função `is_pkg_installed()` é chamada em Distribuição_macOS, THE Script_Dev_macOS SHALL verificar a instalação do pacote usando `brew list --formula | grep -q`.
10. WHILE executando em Distribuição_macOS, THE Wrapper SHALL exibir no menu apenas as opções (1) Configurar ambiente dev, (5) Configurar ambiente dev via Docker, (6) Configurar ambiente prod via Docker e (7) Iniciar Dockhand; as opções 2, 3 e 4 SHALL ser ocultadas com mensagem "não suportado no macOS".
11. WHEN a função `check_docker_available()` é executada em Distribuição_macOS, THE Script_Install_Docker SHALL verificar se o Docker Desktop está instalado no sistema.
12. IF o Docker Desktop não está instalado em Distribuição_macOS, THEN THE Script_Install_Docker SHALL exibir a URL de download (https://docs.docker.com/desktop/install/mac-install/) e informar que o Docker Desktop é obrigatório, sem realizar instalação automatizada via brew.
