# SUAP Scripts

## Introdução

Este repositório contém um conjunto de scripts de automação para configuração de ambientes para execução do **SUAP** (Sistema Unificado de Administração Pública). Os scripts automatizam o processo de instalação de dependências do sistema operacional e configuração do ambiente, tanto para desenvolvimento quanto para produção.

## Finalidade

O objetivo deste projeto é facilitar e acelerar o processo de configuração de ambientes SUAP, eliminando a necessidade de executar manualmente cada etapa de instalação. Os scripts cobrem diferentes combinações de sistemas operacionais e tipos de ambiente, permitindo que desenvolvedores e administradores preparem rapidamente um novo servidor.

## Scripts Disponíveis

| Script | Ambiente | Sistema Operacional | Descrição |
|--------|----------|-------------------|-----------|
| `install-suap-dev-ubuntu.sh` | Desenvolvimento | Ubuntu/Debian | Instala dependências e configura o ambiente de desenvolvimento no Ubuntu |
| `install-suap-dev-fedora.sh` | Desenvolvimento | Fedora/RHEL | Instala dependências e configura o ambiente de desenvolvimento no Fedora |
| `install-suap-prod-ubuntu.sh` | Produção | Ubuntu/Debian | Instala dependências, configura Supervisor com menu interativo para SUAP/Celery no Ubuntu |
| `install-suap-prod-fedora.sh` | Produção | Fedora/RHEL | Instala dependências, configura Supervisor com menu interativo para SUAP/Celery no Fedora |

## O que cada script faz

### Scripts de Desenvolvimento

Cada script de desenvolvimento realiza as seguintes operações:

1. **Instalação de dependências do sistema operacional**: Instala bibliotecas, ferramentas de compilação e pacotes necessários para executar o SUAP
2. **Configuração de localização e fuso horário**: Define português brasileiro (pt_BR.UTF-8) e fuso horário (America/Fortaleza)
3. **Instalação do UV**: Gerenciador de pacotes Python moderno para gerenciar dependências do projeto
4. **Download do código SUAP**: Clona ou atualiza o repositório do SUAP via Git
5. **Configuração do ambiente Python**: Prepara o ambiente Python 3.12 para execução
6. **Instalação de dependências**: Instala bibliotecas Python do grupo `dev`

### Scripts de Produção

Os scripts de produção realizam todas as operações acima, mais:

1. **Menu interativo do Supervisor**: Permite escolher qual(is) serviço(s) configurar:
   - **Opção 1**: Apenas SUAP (servidor web Django)
   - **Opção 2**: Apenas Celery (processamento de tarefas assíncronas)
     - Celery Worker (executa tarefas)
     - Celery Beat (agendador de tarefas)
     - Celery Flower (monitoramento)
   - **Opção 3**: SUAP + Celery (todos os serviços)
2. **Configuração automática do Supervisor**: Copia arquivos de configuração específicos baseado na escolha do usuário
3. **Validação de arquivos**: Verifica se os arquivos de configuração existem antes de copiar
4. **Mensagens finais personalizadas**: Exibe comandos específicos para iniciar cada serviço configurado
5. **Instalação de dependências**: Instala bibliotecas Python do grupo `prod`

## Como executar

### Pré-requisitos

- Ter acesso via SSH ao repositório GitLab do SUAP
- Sistema operacional suportado (Ubuntu/Debian ou Fedora/RHEL)
- Conexão com a internet
- Permissões de `sudo` (os scripts necessitam de privilégios administrativos)

### Execução básica

Para executar um script, siga os passos abaixo:

1. Clone este repositório:
```bash
git clone https://gitlab.ifma.edu.br/ndsis/suap-scripts.git
cd suap-scripts
```

2. Escolha o script apropriado para seu ambiente e execute com permissões de superusuário:

**Para desenvolvimento no Ubuntu:**
```bash
bash install-suap-dev-ubuntu.sh
```

**Para desenvolvimento no Fedora:**
```bash
bash install-suap-dev-fedora.sh
```

**Para produção no Ubuntu:**
```bash
bash install-suap-prod-ubuntu.sh
```

**Para produção no Fedora:**
```bash
bash install-suap-prod-fedora.sh
```

### O que esperar

#### Scripts de Desenvolvimento

Durante a execução, o script:
- Pedirá sua senha para operações que requerem privilégios administrativos
- Exibirá mensagens coloridas indicando o progresso
- Pode levar alguns minutos para completar, dependendo da velocidade da internet e do sistema
- Criará diretório e clonará o código SUAP nele
- Exibirá instruções finais para começar o desenvolvimento

#### Scripts de Produção

Durante a execução, o script:
- Pedirá sua senha para operações que requerem privilégios administrativos
- Exibirá mensagens coloridas indicando o progresso
- **Apresentará um menu interativo** pedindo que você escolha qual(is) serviço(s) deseja configurar:

```
Qual serviço você deseja configurar no Supervisor?
1) SUAP (servidor web)
2) Celery (processamento de tarefas assíncronas)
3) Ambos (SUAP + Celery)

Escolha uma opção (1/2/3):
```

- Copiará automaticamente os arquivos de configuração do Supervisor apropriados
- Exibirá mensagens finais com os comandos específicos para iniciar cada serviço

**Exemplo de saída final (opção 3):**
```
SUAP instalado com sucesso em /opt/suap!

Próximos passos:
1. Para recarregar as configurações neste terminal: source $HOME/.bashrc
2. Para configurar as variáveis de ambiente, edite: /opt/suap/suap/.env
3. Para ir para a pasta do SUAP: cd /opt/suap

4. Para rodar SUAP e todos os serviços Celery:
   - SUAP: sudo supervisorctl start suap
   - Celery Worker: sudo supervisorctl start celery-worker
   - Celery Beat: sudo supervisorctl start celery-beat
   - Celery Flower: sudo supervisorctl start celery-flower
   - Todos: sudo supervisorctl start all
```

## Configurações padrão

### Ambientes de Desenvolvimento
- **Versão Python**: 3.12
- **Diretório de projetos**: `$HOME/Projetos`
- **Diretório SUAP**: `$HOME/Projetos/suap`

### Ambientes de Produção
- **Versão Python**: 3.12
- **Diretório de instalação**: `/opt`
- **Diretório SUAP**: `/opt/suap`
- **Diretório de logs**: `/opt/logs`
- **Diretório de scripts**: `/opt/scripts`

### Ambas as Versões
- **Repositório SUAP**: `git@gitlab.ifma.edu.br:ndsis/suap.git`
- **Localização**: Português Brasileiro (pt_BR.UTF-8)
- **Fuso Horário**: America/Fortaleza

## Personalização

Caso necessite modificar as configurações padrão (como diretório de instalação ou versão do Python), edite as variáveis no início do script antes de executá-lo.

### Variáveis principais

```bash
PYTHON_VERSION=3.12          # Versão do Python a instalar
BASE_DIR=$HOME/Projetos      # Diretório base (desenvolvimento)
BASE_DIR=/opt                # Diretório base (produção)
SUAP_DIR=$BASE_DIR/suap      # Diretório do SUAP
GIT_URL=...                  # URL do repositório Git
```

## Estrutura de arquivos de Supervisor (Produção)

Os scripts de produção esperam que os seguintes arquivos existam no diretório `supervisor/`:

```
supervisor/
├── suap.conf
├── run_suap.sh
├── celery_worker.conf
├── run_celery_worker.sh
├── celery_beat.conf
├── run_celery_beat.sh
├── celery_flower.conf
└── run_celery_flower.sh
```

## Comandos úteis após instalação

### Para ambientes de desenvolvimento

```bash
# Entrar no diretório do SUAP
cd $HOME/Projetos/suap

# Ativar ambiente virtual
source .venv/bin/activate

# Executar servidor de desenvolvimento
python manage.py runserver 0.0.0.0:8000

# Ou usando uv (recomendado)
uv run python manage.py runserver 0.0.0.0:8000
```

### Para ambientes de produção

```bash
# Ver status de todos os serviços
sudo supervisorctl status

# Iniciar SUAP
sudo supervisorctl start suap

# Iniciar Celery Worker
sudo supervisorctl start celery-worker

# Iniciar Celery Beat
sudo supervisorctl start celery-beat

# Iniciar Celery Flower
sudo supervisorctl start celery-flower

# Iniciar todos os serviços configurados
sudo supervisorctl start all

# Parar todos os serviços
sudo supervisorctl stop all

# Reiniciar todos os serviços
sudo supervisorctl restart all

# Ver logs de um serviço
sudo supervisorctl tail suap
sudo supervisorctl tail celery-worker
```

## Suporte

Para questões, problemas ou sugestões, entre em contato com a equipe NDSIS pelo repositório do SUAP em GitLab.

## Licença

Este projeto segue a mesma licença do SUAP.
