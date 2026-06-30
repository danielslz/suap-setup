# Requirements Document

## Introduction

Este documento define os requisitos para o projeto **suap-setup**, uma coleção de scripts shell que automatizam a configuração do ambiente da aplicação SUAP em sistemas Linux. Os scripts suportam distribuições Debian-like (Debian/Ubuntu) e RPM-like (Fedora/RHEL/CentOS), cobrindo ambientes de desenvolvimento, produção, instalação de serviços de infraestrutura (Redis e Nginx) e ambientes containerizados com Docker.

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
- **UV**: Gerenciador de pacotes Python moderno (astral.sh/uv) utilizado no ambiente de desenvolvimento.
- **Supervisor**: Sistema de controle de processos utilizado para gerenciar serviços SUAP em produção.
- **Virtualenv**: Ambiente virtual Python isolado para dependências do projeto.
- **Arquivo_Env**: Arquivo `.env` na raiz do projeto suap-setup que armazena variáveis de configuração compartilhadas entre todos os scripts (GIT_URL, PYTHON_VERSION, BASE_DIR, SUAP_DIR, VENV_DIR, etc.).
- **Arquivo_Env_Central**: Arquivo centralizado de configuração (`.env`) na raiz do repositório suap-setup que contém todas as variáveis reutilizáveis entre os scripts.
- **Docker_Compose**: Ferramenta para definir e executar aplicações multi-container Docker usando arquivo `docker-compose.yml`.
- **Dockhand**: Interface web para gerenciamento de containers Docker (https://dockhand.pro/), executada como container Docker.

## Requirements

### Requirement 1: Centralização de variáveis em arquivo de ambiente compartilhado

**User Story:** Como desenvolvedor, eu quero que todas as variáveis de configuração dos scripts estejam centralizadas em um único arquivo de ambiente, para que eu possa reutilizá-las de forma consistente entre os diversos scripts sem duplicação.

#### Acceptance Criteria

1. THE Arquivo_Env_Central SHALL conter todas as variáveis compartilhadas entre os scripts: PYTHON_VERSION, BASE_DIR, SUAP_DIR, VENV_DIR e GIT_URL.
2. WHEN o Script_Dev é executado, THE Script_Dev SHALL carregar as variáveis a partir do Arquivo_Env_Central antes de iniciar qualquer operação.
3. WHEN o Script_Prod é executado, THE Script_Prod SHALL carregar as variáveis a partir do Arquivo_Env_Central antes de iniciar qualquer operação.
4. WHEN o Script_Docker_Dev é executado, THE Script_Docker_Dev SHALL carregar as variáveis a partir do Arquivo_Env_Central antes de iniciar qualquer operação.
5. WHEN o Script_Docker_Prod é executado, THE Script_Docker_Prod SHALL carregar as variáveis a partir do Arquivo_Env_Central antes de iniciar qualquer operação.
6. IF o Arquivo_Env_Central não existe na raiz do repositório, THEN THE Wrapper SHALL criar o arquivo com valores padrão e informar o usuário.
7. THE Arquivo_Env_Central SHALL conter comentários descrevendo cada variável e seus valores esperados.
8. WHEN uma variável é definida no Arquivo_Env_Central, THE Script_Dev SHALL utilizar o valor centralizado em vez de definir a variável localmente no corpo do script.
9. WHEN uma variável é definida no Arquivo_Env_Central, THE Script_Prod SHALL utilizar o valor centralizado em vez de definir a variável localmente no corpo do script.

### Requirement 2: Detecção automática da distribuição Linux

**User Story:** Como administrador de sistemas, eu quero que o wrapper detecte automaticamente a família da distribuição Linux, para que o script correto seja executado sem intervenção manual.

#### Acceptance Criteria

1. WHEN o arquivo `/etc/os-release` está presente, THE Wrapper SHALL identificar a família da distribuição como Distribuição_Debian ou Distribuição_RPM com base nos campos `ID` e `ID_LIKE`.
2. IF o arquivo `/etc/os-release` não está presente, THEN THE Wrapper SHALL exibir uma mensagem de erro e encerrar a execução com código de saída 3.
3. IF a distribuição identificada não pertence à família Distribuição_Debian nem à família Distribuição_RPM, THEN THE Wrapper SHALL exibir uma mensagem informando a distribuição não suportada e encerrar com código de saída 3.

### Requirement 3: Menu interativo do wrapper

**User Story:** Como administrador de sistemas, eu quero um menu interativo com opções de configuração, para que eu possa escolher qual ação executar de forma simples.

#### Acceptance Criteria

1. WHEN a detecção da distribuição é concluída com sucesso, THE Wrapper SHALL exibir um menu com as opções: (1) Configurar ambiente dev, (2) Configurar ambiente prod, (3) Instalar Redis, (4) Instalar Nginx, (5) Configurar ambiente dev via Docker, (6) Configurar ambiente prod via Docker, (7) Iniciar Dockhand.
2. WHEN o usuário seleciona uma opção válida (1 a 7), THE Wrapper SHALL executar o script correspondente à distribuição detectada, ao ambiente Docker ou ao Dockhand.
3. IF o usuário informa uma opção inválida, THEN THE Wrapper SHALL exibir uma mensagem de erro e encerrar com código de saída 1.
4. IF o arquivo do script correspondente não é encontrado no diretório, THEN THE Wrapper SHALL exibir uma mensagem de erro e encerrar com código de saída 2.

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
3. WHEN todas as dependências já estão instaladas, THE Script_Dev SHALL prosseguir para a próxima etapa sem executar o gerenciador de pacotes.
4. THE Script_Dev SHALL instalar dependências para: ferramentas de compilação, LDAP, Pillow, PyMSSQL, lxml, WeasyPrint, manipulação de PDF e utilitários gerais.

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

1. WHEN o comando `uv` não está disponível no PATH, THE Script_Dev SHALL baixar e instalar o UV a partir da URL oficial.
2. WHEN o UV é instalado, THE Script_Dev SHALL adicionar a configuração de auto-completar ao arquivo `.bashrc` do usuário.
3. WHEN o comando `uv` já está disponível no PATH, THE Script_Dev SHALL prosseguir sem reinstalar.

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

### Requirement 11: Instalação de dependências do sistema (Produção)

**User Story:** Como administrador de sistemas, eu quero que as dependências de produção sejam instaladas automaticamente, para que o servidor esteja pronto para executar o SUAP.

#### Acceptance Criteria

1. THE Script_Prod SHALL verificar se as dependências do sistema já estão instaladas antes de tentar instalá-las.
2. WHEN uma ou mais dependências não estão instaladas, THE Script_Prod SHALL instalar todas as dependências necessárias usando o gerenciador de pacotes da distribuição.
3. THE Script_Prod SHALL instalar pacotes adicionais de produção incluindo: python3, supervisor, cron/cronie, ntp/chrony e ferramentas de gerenciamento de processos.

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

### Requirement 14: Criação de virtualenv e instalação de dependências (Produção)

**User Story:** Como administrador de sistemas, eu quero que o virtualenv de produção seja criado com o venv padrão, para manter compatibilidade com o ambiente de produção.

#### Acceptance Criteria

1. WHEN o diretório do virtualenv não existe, THE Script_Prod SHALL criar um virtualenv usando `python3 -m venv`.
2. WHEN o diretório do virtualenv já existe, THE Script_Prod SHALL prosseguir sem recriar.
3. WHEN o arquivo `pyproject.toml` existe no projeto, THE Script_Prod SHALL instalar dependências usando `pip install . --group prod --no-cache-dir`.
4. WHEN o arquivo `pyproject.toml` não existe e o diretório `requirements/` existe, THE Script_Prod SHALL instalar dependências usando `pip install -r requirements/production.txt --no-cache-dir`.
5. IF nem o arquivo `pyproject.toml` nem o diretório `requirements/` existem, THEN THE Script_Prod SHALL exibir uma mensagem de erro e encerrar com código de saída 1.

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
8. WHEN a configuração do Supervisor é concluída, THE Script_Prod SHALL executar `supervisorctl reread` e `supervisorctl update` para aplicar as alterações.

### Requirement 16: Configuração de permissões de arquivos (Produção)

**User Story:** Como administrador de sistemas, eu quero que as permissões dos arquivos sejam ajustadas corretamente, para que o Supervisor e o SUAP funcionem com o usuário adequado.

#### Acceptance Criteria

1. WHEN toda a configuração de produção é concluída, THE Script_Prod SHALL definir o proprietário do diretório do SUAP, diretório de logs e virtualenv para o usuário `www-data`.

### Requirement 17: Destino de configuração do Supervisor por distribuição

**User Story:** Como administrador de sistemas, eu quero que os arquivos do Supervisor sejam copiados para o diretório correto da distribuição, para que o serviço funcione adequadamente.

#### Acceptance Criteria

1. WHILE executando em uma Distribuição_Debian, THE Script_Prod SHALL copiar arquivos de configuração do Supervisor para `/etc/supervisor/conf.d/`.
2. WHILE executando em uma Distribuição_RPM, THE Script_Prod SHALL copiar arquivos de configuração do Supervisor para `/etc/supervisord.d/`.

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
2. WHILE executando em uma Distribuição_Debian, THE Script_Nginx SHALL remover o link simbólico da configuração padrão em `/etc/nginx/sites-enabled/default`.
3. WHILE executando em uma Distribuição_RPM, THE Script_Nginx SHALL copiar a configuração para `/etc/nginx/conf.d/suap.conf`.

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
4. IF o Docker ou o Docker_Compose não estão instalados, THEN THE Script_Docker_Dev SHALL exibir uma mensagem de erro informando os pré-requisitos e encerrar com código de saída 1.
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
4. IF o Docker ou o Docker_Compose não estão instalados, THEN THE Script_Docker_Prod SHALL exibir uma mensagem de erro informando os pré-requisitos e encerrar com código de saída 1.
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

### Requirement 26: Mensagem final com próximos passos

**User Story:** Como operador, eu quero receber instruções claras ao final da execução, para que eu saiba quais ações realizar em seguida.

#### Acceptance Criteria

1. WHEN a execução do Script_Dev é concluída com sucesso, THE Script_Dev SHALL exibir uma mensagem de sucesso e instruções para: recarregar o bashrc, editar variáveis de ambiente, acessar a pasta do SUAP e rodar o servidor de desenvolvimento.
2. WHEN a execução do Script_Prod é concluída com sucesso, THE Script_Prod SHALL exibir uma mensagem de sucesso e instruções para: recarregar o bashrc, editar variáveis de ambiente, acessar a pasta do SUAP e iniciar os serviços configurados via Supervisor.

### Requirement 27: Integração com Dockhand para gerenciamento de containers

**User Story:** Como administrador de sistemas, eu quero iniciar o Dockhand a partir do menu do setup, para que eu possa gerenciar containers Docker por meio de uma interface web sem instalar ferramentas adicionais.

#### Acceptance Criteria

1. WHEN o usuário seleciona a opção 7 no menu, THE Wrapper SHALL verificar se o Docker está disponível no sistema antes de prosseguir.
2. IF o Docker não está instalado ou o daemon não está em execução, THEN THE Wrapper SHALL exibir uma mensagem de erro informando que o Docker é pré-requisito para o Dockhand e encerrar com código de saída 1.
3. WHEN o Docker está disponível, THE Wrapper SHALL executar `docker pull lscr.io/linuxserver/dockhand:latest` para obter a imagem mais recente do Dockhand.
4. WHEN a imagem é obtida, THE Wrapper SHALL iniciar o container Dockhand expondo a interface web na porta 9093 do host.
5. WHEN o container Dockhand é iniciado, THE Wrapper SHALL montar o socket do Docker (`/var/run/docker.sock`) como volume para permitir o gerenciamento dos containers do host.
6. WHEN o container Dockhand é iniciado com sucesso, THE Wrapper SHALL exibir uma mensagem informando a URL de acesso à interface web (http://localhost:9093).
7. IF o container Dockhand falha ao iniciar, THEN THE Wrapper SHALL exibir uma mensagem de erro com o motivo da falha e encerrar com código de saída 1.
8. WHEN já existe um container Dockhand em execução, THE Wrapper SHALL exibir uma mensagem informando que o Dockhand já está ativo e mostrar a URL de acesso.
