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
| `install-suap-prod-ubuntu.sh` | Produção | Ubuntu/Debian | Instala dependências e configura o ambiente de produção no Ubuntu |
| `install-suap-prod-fedora.sh` | Produção | Fedora/RHEL | Instala dependências e configura o ambiente de produção no Fedora |

## O que cada script faz

Cada script realiza as seguintes operações:

1. **Instalação de dependências do sistema operacional**: Instala bibliotecas, ferramentas de compilação e pacotes necessários para executar o SUAP
2. **Configuração de localização e fuso horário**: Define português brasileiro (pt_BR.UTF-8) e fuso horário (America/Fortaleza)
3. **Instalação do UV**: Gerenciador de pacotes Python moderno para gerenciar dependências do projeto
4. **Download do código SUAP**: Clona ou atualiza o repositório do SUAP via Git
5. **Configuração do ambiente Python**: Prepara o ambiente Python 3.12 para execução

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

Durante a execução, o script:
- Pedirá sua senha para operações que requerem privilégios administrativos
- Exibirá mensagens coloridas indicando o progresso
- Pode levar alguns minutos para completar, dependendo da velocidade da internet e do sistema
- Criará diretório e clonará o código SUAP nele

## Configurações padrão

Os scripts utilizam as seguintes configurações padrão:

- **Versão Python**: 3.12
- **Diretório de projetos**: `$HOME/Projetos`
- **Diretório SUAP**: `$HOME/Projetos/suap`
- **Repositório SUAP**: `git@gitlab.ifma.edu.br:ndsis/suap.git`
- **Localização**: Português Brasileiro (pt_BR.UTF-8)
- **Fuso Horário**: America/Fortaleza

## Personalização

Caso necessite modificar as configurações padrão (como diretório de instalação ou versão do Python), edite as variáveis no início do script antes de executá-lo.

## Suporte

Para questões, problemas ou sugestões, entre em contato com a equipe NDSIS pelo repositório do SUAP em GitLab.

## Licença

Este projeto segue a mesma licença do SUAP.
