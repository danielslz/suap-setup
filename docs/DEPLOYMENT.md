# Guia de Implantação do SUAP em Produção
## Ambientes de Homologação e Produção com Automação via `suap-setup`

**Projeto de automação:** [suap-setup](https://github.com/danielslz/suap-setup)
**Sistema:** [SUAP — Sistema Unificado de Administração Pública](https://portal.suap.ifrn.edu.br)

---

## Sumário

- [Guia de Implantação do SUAP em Produção](#guia-de-implantação-do-suap-em-produção)
  - [Ambientes de Homologação e Produção com Automação via `suap-setup`](#ambientes-de-homologação-e-produção-com-automação-via-suap-setup)
  - [Sumário](#sumário)
  - [1. Introdução](#1-introdução)
  - [2. Visão geral do SUAP](#2-visão-geral-do-suap)
  - [3. Filosofia de automação: por que usar o suap-setup](#3-filosofia-de-automação-por-que-usar-o-suap-setup)
  - [4. Planejamento de ambientes](#4-planejamento-de-ambientes)
  - [5. Dimensionamento de máquinas/VMs](#5-dimensionamento-de-máquinasvms)
    - [5.1. Homologação (configuração mínima)](#51-homologação-configuração-mínima)
    - [5.2. Produção (configuração recomendada — segmentada)](#52-produção-configuração-recomendada--segmentada)
    - [5.3. Por que segmentar em VMs separadas?](#53-por-que-segmentar-em-vms-separadas)
  - [6. Arquitetura de referência](#6-arquitetura-de-referência)
  - [7. Pré-requisitos gerais](#7-pré-requisitos-gerais)
  - [8. Implantação do ambiente de Homologação](#8-implantação-do-ambiente-de-homologação)
    - [8.1. Passo a passo](#81-passo-a-passo)
    - [8.2. Ajustes específicos de homologação](#82-ajustes-específicos-de-homologação)
  - [9. Implantação do ambiente de Produção](#9-implantação-do-ambiente-de-produção)
    - [9.1. VM(s) de Aplicação](#91-vms-de-aplicação)
    - [9.2. Instalação do Nginx (rota nativa)](#92-instalação-do-nginx-rota-nativa)
    - [9.3. VM de Banco de Dados + Redis](#93-vm-de-banco-de-dados--redis)
    - [9.4. VM de Tarefas Assíncronas (Celery)](#94-vm-de-tarefas-assíncronas-celery)
  - [10. Configuração de banco de dados](#10-configuração-de-banco-de-dados)
    - [10.1. Escolha da versão](#101-escolha-da-versão)
    - [10.2. Instalação](#102-instalação)
    - [10.3. Estrutura de diretórios e disco](#103-estrutura-de-diretórios-e-disco)
    - [10.4. Criação do banco e usuário de aplicação](#104-criação-do-banco-e-usuário-de-aplicação)
    - [10.5. Controle de acesso (`pg_hba.conf`)](#105-controle-de-acesso-pg_hbaconf)
    - [10.6. Tuning de performance (`postgresql.conf`)](#106-tuning-de-performance-postgresqlconf)
    - [10.7. Connection pooling (recomendado)](#107-connection-pooling-recomendado)
    - [10.8. Réplicas de leitura (opcional)](#108-réplicas-de-leitura-opcional)
    - [10.9. Backup do banco](#109-backup-do-banco)
    - [10.10. Preparação da aplicação e primeiro acesso](#1010-preparação-da-aplicação-e-primeiro-acesso)
  - [11. Balanceamento de carga e alta disponibilidade](#11-balanceamento-de-carga-e-alta-disponibilidade)
  - [12. Armazenamento de mídia (NFS / MinIO)](#12-armazenamento-de-mídia-nfs--minio)
    - [12.1. NFS](#121-nfs)
    - [12.2. MinIO (alternativa escalável)](#122-minio-alternativa-escalável)
  - [13. Rotina de atualização](#13-rotina-de-atualização)
    - [13.1. Rota nativa](#131-rota-nativa)
    - [13.2. Rota Docker](#132-rota-docker)
    - [13.3. Política de atualização recomendada](#133-política-de-atualização-recomendada)
  - [14. Backup e recuperação de desastres](#14-backup-e-recuperação-de-desastres)
  - [15. Monitoramento e logs](#15-monitoramento-e-logs)
  - [16. Checklist final de go-live](#16-checklist-final-de-go-live)
  - [17. Referências](#17-referências)

---

## 1. Introdução

Este documento descreve o planejamento e a execução da implantação do **SUAP** (Sistema Unificado de Administração Pública) em ambientes de **homologação** e **produção**.

Diferente de tutoriais baseados em instalação manual passo a passo, esta documentação adota como eixo central o **[suap-setup](https://github.com/danielslz/suap-setup)**, um conjunto de scripts de automação criado para eliminar a repetição manual, reduzir erros humanos e padronizar a preparação de ambientes SUAP — seja em instalação nativa (Debian, RHEL/Fedora/AlmaLinux, Arch) seja via **Docker**.

O objetivo é que qualquer desenvolvedor consiga, com o mínimo de intervenção manual, provisionar um ambiente completo, íntegro e reprodutível, tanto para testes/homologação quanto para produção crítica com múltiplos usuários simultâneos.

---

## 2. Visão geral do SUAP

O SUAP é uma plataforma de gestão acadêmica e administrativa mantida originalmente pelo IFRN e adotada por dezenas de Institutos Federais. Entre os módulos típicos estão: Ensino, RH, Almoxarifado, Protocolo, Documentos Eletrônicos, entre outros. Mais detalhes sobre o produto e seus módulos podem ser consultados no [portal oficial do SUAP](https://portal.suap.ifrn.edu.br).

Do ponto de vista de infraestrutura, o SUAP é uma aplicação **Django** que depende de:

| Componente | Função |
|---|---|
| **PostgreSQL** | Banco de dados relacional principal |
| **Redis** | Cache, armazenamento de sessão e broker do Celery |
| **Celery (worker + beat)** | Processamento assíncrono e tarefas agendadas |
| **Gunicorn** | Servidor WSGI da aplicação Django |
| **Nginx** | Proxy reverso, conexões SSL, servidor de arquivos estáticos e mídia |
| **wkhtmltopdf / LibreOffice** | Geração de PDFs e conversão de documentos |
| **Repositório de mídia (NFS, MinIO, AWS S3)** | Armazenamento compartilhado de arquivos |

O SUAP pode ser implantado de duas formas:

- **Instalação nativa** — pacotes do SO + `uv`/virtualenv + Supervisor + Nginx.
- **Instalação via Docker** — imagens pré-construídas orquestradas pelo projeto `suap_deploy`, com Makefile para gerenciamento dos serviços.

Ambas as formas são suportadas pelo `suap-setup`.

---

## 3. Filosofia de automação: por que usar o suap-setup

Tutoriais e/ou manuais com dezenas de comandos executados manualmente, em sequência estrita, contém alto risco de:

- Esquecimento de um pacote de dependência do sistema operacional;
- Configuração divergente entre servidores;
- Diferença de versão de Python/PostgreSQL entre ambientes;
- Erros de permissão em diretórios de mídia e logs;
- Divergência de configuração do Supervisor/Nginx entre nós de um cluster.

O `suap-setup` resolve esses problemas por meio de:

- **Wizard interativo** (`setup.sh`) que gera um `.env` centralizado, com prompts descritivos e valores padrão para cada variável.
- **Suporte multiplataforma**: Debian/Ubuntu (`apt`), Fedora/RHEL/CentOS/AlmaLinux/Rocky (`dnf`), Arch/Manjaro (`pacman`), macOS (Homebrew, apenas dev) e Docker.
- **Idempotência**: reexecutar um script pula etapas já concluídas sem corromper o que já está pronto.
- **Halt em falhas críticas**: se uma dependência falha ao instalar, o script interrompe imediatamente.
- **Separação de responsabilidades por script**: `suap-dev.sh`, `suap-prod.sh`, `suap-update.sh`, `install-redis.sh`, `install-nginx.sh`.
- **Delegação para os repositórios oficiais** nas rotas Docker: o suap-setup não mantém `Dockerfile`/`docker-compose` próprios — delega para o compose nativo do SUAP (dev) e para o Makefile do `suap_deploy` (produção).
- **Rollback automático** no script de atualização: se `git pull` ou a instalação de dependências falhar, os serviços são reiniciados automaticamente antes do script encerrar com erro.
- **Cobertura de testes** (via `bats-core`) validando idempotência, roteamento do menu, geração do `.env` e ausência de artefatos Docker locais indevidos.

---

## 4. Planejamento de ambientes

Recomenda-se manter **três ambientes logicamente isolados**, sem compartilhamento de banco de dados ou mídia entre si:

| Ambiente | Finalidade | Perfil de infraestrutura |
|---|---|---|
| **Desenvolvimento** | Uso local dos desenvolvedores (via Docker Compose) | Máquina local / notebook |
| **Homologação** | Testes de aceitação, validação de atualizações, treinamento | Servidor único, dimensionamento mínimo |
| **Produção** | Ambiente crítico, uso pela comunidade acadêmica | Múltiplos servidores segmentados |

**Por que não compartilhar banco entre homologação e produção?** Migrações testadas em homologação não devem vazar para produção antes da janela de manutenção planejada, e dados sigilosos de produção não devem circular em um ambiente com controles de acesso mais permissivos.

O `suap-setup` favorece essa separação porque cada ambiente tem seu próprio `.env`, próprio diretório base (`BASE_DIR`) e pode residir em servidores/VMs completamente distintos.

---

## 5. Dimensionamento de máquinas/VMs

### 5.1. Homologação (configuração mínima)

Ambiente de homologação pode operar em **servidor único**, concentrando aplicação, banco de dados e tarefas assíncronas:

| Recurso | Valor mínimo recomendado |
|---|---|
| vCPUs | 4 |
| RAM | 8 GB |
| Disco (partição de dados/`/opt`) | 60 GB (SSD) |
| Sistema Operacional | Debian 12 (Bookworm) ou AlmaLinux 9 |

### 5.2. Produção (configuração recomendada — segmentada)

Para produção, a recomendação é **segmentar os serviços em VMs distintas**, isolando cargas de trabalho com perfis de consumo diferentes e permitindo escalar cada camada de forma independente:

| Papel da VM | vCPUs | RAM | Disco | Observação |
|---|---|---|---|---|
| **Aplicação (Nginx + Gunicorn)** — 2+ nós | 8 | 16 GB | 100 GB em `/opt` | Escalar horizontalmente conforme carga |
| **Banco de dados + Redis** | 8 | 16 GB | 250 GB em `/var` (SSD NVMe) | Redis pode ficar junto do banco em porte médio |
| **Tarefas assíncronas (Celery)** | 8 | 16 GB | 100 GB em `/opt` | Isolado para não competir com requisições web |
| **Balanceador de carga** | 2 | 4 GB | 20 GB | Ponto único de entrada; redundância recomendada |
| **Servidor de mídia (NFS/MinIO)** | 4 | 8 GB | Conforme volume | Compartilhado entre nós de aplicação |

> **Nota:** os valores refletem o piso recomendado para uma instituição de porte médio. O número de nós de aplicação deve ser recalculado a partir de testes de carga reais (picos de matrícula, editais, etc.).

### 5.3. Por que segmentar em VMs separadas?

- **Isolamento de falhas**: pico de carga na aplicação não compromete o banco.
- **Escalabilidade independente**: novos nós de aplicação sem replicar banco.
- **Zero-downtime em atualizações**: rolling update retirando um nó por vez do pool.
- **Segurança**: banco nunca exposto diretamente à internet.
- **Perfis de hardware distintos**: banco se beneficia de NVMe e RAM; aplicação de mais vCPUs.

---

## 6. Arquitetura de referência

```
                                   ┌────────────┐
                                   │  Usuários  │
                                   └─────┬──────┘
                                         │ HTTPS
                                         ▼
                         ┌────────────────────────────────┐
                         │   Balanceador de Carga (HA)    │
                         │  HAProxy / Nginx — Injeção SSL │
                         └───────────────┬────────────────┘
                     ┌───────────────────┼───────────────────┐
                     ▼                   ▼                   ▼
             ┌───────────────┐  ┌───────────────┐   ┌───────────────┐
             │  App node 1   │  │  App node 2   │   │  App node N   │
             │   Gunicorn    │  │   Gunicorn    │   │   Gunicorn    │
             │   (Django)    │  │   (Django)    │   │   (Django)    │
             └───────┬───────┘  └───────┬───────┘   └───────┬───────┘
                     └──────────────────┼───────────────────┘
                                        ▼
           ┌─────────────────────────────────────────────────────────────┐
           │                    Rede interna / privada                   │
           └─────────────────────────────────────────────────────────────┘
               │                  │                 │                 │
               ▼                  ▼                 ▼                 ▼
       ┌───────────────┐ ┌────────────────┐ ┌───────────────┐ ┌───────────────┐
       │   PostgreSQL  │ │ Redis (cache/  │ │ Celery worker │ │     Mídia     │
       │    (dados)    │ │ sessão/broker) │ │ + celery beat │ │ compartilhada │
       │               │ │                │ │ (assíncrono)  │ │ (NFS / MinIO) │
       └───────────────┘ └────────────────┘ └───────────────┘ └───────────────┘
```

---

## 7. Pré-requisitos gerais

Antes de iniciar a implantação em qualquer ambiente, são necessários os seguintes pré-requisitos:

- Conta no GitLab da instituição de origem do código com acesso de leitura aos projetos `suap` e, se aplicável, `suap_deploy` e `suap-pdf`.
- Chave SSH cadastrada no GitLab.
- Se optar pela rota Docker: token de acesso pessoal ao registry (escopo `read_registry`).
- Acesso `sudo`/root nos servidores de homologação e produção.
- Sistema operacional suportado: **Debian 12+**, **AlmaLinux 9** (ou qualquer RHEL-like 9+: Rocky Linux, CentOS Stream, Fedora), **Arch Linux**.
- DNS configurado apontando para o balanceador (produção) ou para o servidor único (homologação).
- Certificado SSL válido (ou processo de emissão automatizada, ex. Let's Encrypt).
- Firewall liberando apenas portas necessárias (443/80 no balanceador; portas internas restritas à rede privada).

Instalar o `suap-setup` em cada servidor:

```bash
git clone https://github.com/danielslz/suap-setup.git
cd suap-setup
```

---

## 8. Implantação do ambiente de Homologação

Para homologação, a recomendação é usar a **rota Docker de produção** do `suap-setup` (mesmo perfil de execução da produção, porém em servidor único), garantindo que o que for validado reflita fielmente o comportamento em produção.

### 8.1. Passo a passo

```bash
cd suap-setup
bash setup.sh
```

No menu interativo, selecione:

```
=== SUAP Setup ===
6) Configurar ambiente prod via Docker
```

Na primeira execução, o wizard solicitará as variáveis principais:

| Variável | Descrição | Exemplo |
|---|---|---|
| `SUAP_DEPLOY_DIR` | Diretório do repositório `suap_deploy` | `/opt/suap_deploy` |
| `SUAP_DEPLOY_GIT_URL` | URL Git do `suap_deploy` | `git@gitlab.instituicao.edu.br:org/suap_deploy.git` |

> **Nota:** as variáveis de imagem Docker (`SUAP_IMAGE`, `SUAP_PDF_IMAGE`, `SUAP_AI_IMAGE`) são configuradas dentro do `.env` do próprio repositório `suap_deploy` (gerado pelo `make setup` a partir do `env.sample`), não no `.env` do suap-setup.

O script então:

1. Verifica se o Docker está disponível (oferece instalação automática caso não esteja);
2. Clona o repositório `suap_deploy` em `SUAP_DEPLOY_DIR`;
3. Executa `make setup` interativo (escolhe modo de imagem, gera `.env`, ativa template nginx, gera cert SSL);
4. Apresenta o menu de gerenciamento:

```
1) Fazer pull das imagens e iniciar serviços (modo registry)
2) Fazer build local das imagens e iniciar (modo local)
3) Apenas iniciar serviços (make up)
4) Parar todos os serviços (make down)
5) Reiniciar serviços (make restart)
6) Ver status dos containers
7) Ver logs
8) Acessar shell do container web
9) Executar backup do banco
10) Executar restore do banco
11) Executar setup interativo (make setup)
0) Sair
```

Para o primeiro provisionamento, selecione **1)** (modo registry) ou **2)** (modo local/build).

### 8.2. Ajustes específicos de homologação

- Utilize um domínio distinto de produção (ex.: `suap-hml.instituicao.edu.br`).
- Configure um banner visual indicando "AMBIENTE DE HOMOLOGAÇÃO".
- Restrinja o envio de e-mails (backend em modo console ou caixa de testes).
- Popule o banco com uma cópia anonimizada/subset dos dados, nunca dados sigilosos completos.

---

## 9. Implantação do ambiente de Produção

A produção deve seguir a arquitetura segmentada descrita na seção 6, com o `suap-setup` executado **em cada VM**, cada uma assumindo um papel específico.

### 9.1. VM(s) de Aplicação

Em cada nó de aplicação:

```bash
cd suap-setup
bash setup.sh
```

Selecione **6) Configurar ambiente prod via Docker** (recomendado) ou **2) Configurar ambiente de produção** (instalação nativa).

**Rota Docker (recomendada):** delega para o Makefile do `suap_deploy`, que já traz:

- Dois modos de imagem: **registry** (pull de imagens pré-construídas) e **local** (build a partir do código-fonte);
- **OWASP ModSecurity CRS** como WAF integrado ao Nginx;
- Resource limits por container;
- Controle de serviços via `COMPOSE_PROFILES` no `.env`.

Gerenciamento via Makefile:

```bash
cd /opt/suap_deploy
make up            # Iniciar serviços (respeita COMPOSE_PROFILES)
make status        # Ver status
make logs          # Ver logs
make down          # Parar serviços
make restart       # Reiniciar (down + up)
make bash          # Shell no container web
make backup        # Backup do banco
```

**Rota nativa (alternativa):** o script `suap-prod.sh` realiza:

- Instalação de dependências do sistema (halt em falha);
- Configuração de locale (`pt_BR.UTF-8`) e timezone;
- Clone raso do código (`git clone --depth 1`) ou atualização;
- Criação de virtualenv Python 3.12+ (versão configurável via `PYTHON_VERSION` no `.env`) e instalação de dependências;
- Menu interativo para configurar o Supervisor (SUAP / Celery / Ambos);
- Deploy das configurações do Supervisor com recarga condicional;
- Ajuste de permissões (`chown www-data`).

Caminhos do Supervisor por distribuição:

| Distribuição | Diretório de configuração |
|---|---|
| Debian/Ubuntu | `/etc/supervisor/conf.d/` |
| Fedora/RHEL/AlmaLinux/Rocky | `/etc/supervisord.d/` |
| Arch Linux | `/etc/supervisor.d/` |

### 9.2. Instalação do Nginx (rota nativa)

```bash
bash deb/install-nginx.sh   # ou rpm/ ou arch/ conforme a distribuição
```

A configuração provida automaticamente inclui:

- Upstream com política `least_conn` na porta 8000;
- `client_max_body_size 100m` (uploads de documentos);
- Entrega direta de estáticos (`/opt/suap/static/`) e mídia (`/opt/suap/deploy/media/`) sem passar pelo Gunicorn;
- Páginas de erro customizadas (500, 502, 503, 504, 413);
- Log customizado com tempos de requisição e upstream;
- Buffers de proxy aumentados para respostas grandes;
- Bloco de servidor secundário na porta 8001 (para uso interno/monitoramento).

### 9.3. VM de Banco de Dados + Redis

Instalar os serviços de banco e cache nesta VM:

```bash
cd suap-setup
bash setup.sh
```

Selecione **3) Instalar Redis** e depois **9) Instalar PostgreSQL**, ou execute-os diretamente:

```bash
sudo bash deb/install-redis.sh      # ou rpm/ ou arch/ conforme distribuição
sudo bash deb/install-postgres.sh   # ou rpm/ ou arch/ conforme distribuição
```

O script de instalação do PostgreSQL (`install-postgres.sh`) realiza automaticamente:

1. Adiciona o repositório oficial PGDG (versão configurável via `POSTGRES_VERSION`, padrão: 16);
2. Instala os pacotes do PostgreSQL;
3. Inicializa o cluster (initdb) e inicia o serviço;
4. Oferece criação interativa do banco e usuário de aplicação (nome do banco, usuário e senha via prompt);
5. Configura `pg_hba.conf` com `scram-sha-256` para o usuário criado;
6. Configura `password_encryption = scram-sha-256`;
7. Pergunta se o PostgreSQL deve escutar apenas em localhost ou em todos os endereços (para VMs separadas);
8. Exibe resumo com string de conexão.

Para tuning avançado, réplicas de leitura e connection pooling, ver seção 10.

### 9.4. VM de Tarefas Assíncronas (Celery)

Nesta VM, configure **apenas o Celery** no menu do Supervisor (worker + beat), sem subir o processo web. Isso garante que picos de processamento assíncrono não disputem CPU com requisições HTTP em tempo real.

Variáveis relevantes no `.env`:

| Variável | Descrição | Exemplo (produção) |
|---|---|---|
| `GUNICORN_WORKERS` | Workers do Gunicorn por nó de aplicação | `5` (ajustar: `2×vCPU+1`) |
| `GUNICORN_THREADS` | Threads por worker | `1` |
| `CELERY_BROKER_URL` | URL do broker Redis | `redis://<ip-interno-redis>:6379/3` |
| `CELERY_MIN_WORKERS` | Mínimo de workers Celery | `2` |
| `CELERY_MAX_WORKERS` | Máximo de workers Celery | `5` |
| `CELERY_FLOWER_AUTH` | Autenticação do painel Flower | Usuário/senha fortes |

> **Atenção de segurança:** o valor padrão de `CELERY_FLOWER_AUTH` é `admin:admin`. Este valor **deve obrigatoriamente ser trocado** em produção, e o painel Flower não deve ficar exposto publicamente — mantenha-o acessível apenas via rede interna/VPN.

---

## 10. Configuração de banco de dados

### 10.1. Escolha da versão

A versão compatível é **16+** (ou a que o IFRN recomendar à época). Recomenda-se adotar a **versão mais recente suportada oficialmente pela versão do SUAP em uso** — confirme com a equipe de desenvolvimento qual versão é homologada. O valor pode ser ajustado via a variável `POSTGRES_VERSION` no `.env` do suap-setup.

### 10.2. Instalação

A forma mais rápida de instalar é via `suap-setup` (opção 9 do menu ou executando diretamente o script `install-postgres.sh` da distribuição — ver seção 9.3). O script já adiciona o repositório oficial, instala os pacotes, inicializa o cluster e configura acesso.

Para instalação manual ou quando é necessário controle adicional:

**Debian/Ubuntu:**

```bash
sudo apt-get install -y curl ca-certificates gnupg lsb-release
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /usr/share/keyrings/postgresql.gpg
echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list

sudo apt-get update
sudo apt-get install -y postgresql-16 postgresql-contrib-16
```

**AlmaLinux/RHEL:**

```bash
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo dnf -qy module disable postgresql
sudo dnf install -y postgresql16-server postgresql16-contrib
sudo /usr/pgsql-16/bin/postgresql-16-setup initdb
sudo systemctl enable --now postgresql-16
```

### 10.3. Estrutura de diretórios e disco

O diretório de dados deve residir em partição própria, preferencialmente em NVMe:

**Debian/Ubuntu** (datadir padrão: `/var/lib/postgresql/16/main`):

```bash
sudo systemctl stop postgresql
sudo mv /var/lib/postgresql/16/main /mnt/pgdata
sudo ln -s /mnt/pgdata /var/lib/postgresql/16/main
sudo chown -R postgres:postgres /mnt/pgdata
sudo systemctl start postgresql
```

**RHEL/AlmaLinux** (datadir padrão: `/var/lib/pgsql/16/data`):

```bash
sudo systemctl stop postgresql-16
sudo mv /var/lib/pgsql/16/data /mnt/pgdata
sudo ln -s /mnt/pgdata /var/lib/pgsql/16/data
sudo chown -R postgres:postgres /mnt/pgdata
sudo systemctl start postgresql-16
```

### 10.4. Criação do banco e usuário de aplicação

> **Nota:** Se você utilizou o `install-postgres.sh` (seção 9.3) e respondeu "Sim" à criação do banco/usuário, estes passos já foram executados automaticamente. Os comandos abaixo são para referência ou criação manual.

```bash
sudo -u postgres psql
```

```sql
CREATE USER suap_app WITH PASSWORD 'senha-forte-aqui';
CREATE DATABASE suap OWNER suap_app ENCODING 'UTF8' LC_COLLATE 'pt_BR.UTF-8' LC_CTYPE 'pt_BR.UTF-8' TEMPLATE template0;
GRANT ALL PRIVILEGES ON DATABASE suap TO suap_app;
ALTER DATABASE suap SET bytea_output TO 'escape';
```

> **Importante:** o usuário de aplicação **não deve ter privilégio `SUPERUSER`**. Privilégios de superusuário ficam restritos a uma conta administrativa separada.

Se os locales `pt_BR.UTF-8` não estiverem disponíveis:

```bash
sudo locale-gen pt_BR.UTF-8
sudo update-locale
```

### 10.5. Controle de acesso (`pg_hba.conf`)

Restrinja o acesso apenas à rede interna dos nós de aplicação:

```
# TYPE  DATABASE     USER        ADDRESS              METHOD
host    suap         suap_app    10.0.1.0/24          scram-sha-256
host    replication  replicator  10.0.1.0/24          scram-sha-256
local   all          postgres                         peer
```

Em `postgresql.conf`:

```
password_encryption = scram-sha-256
listen_addresses = '10.0.1.5'   # apenas interface da rede interna
```

### 10.6. Tuning de performance (`postgresql.conf`)

Valores de referência para uma VM com 16 GB de RAM (ajustar proporcionalmente):

```
max_connections = 200
shared_buffers = 4GB
effective_cache_size = 12GB
maintenance_work_mem = 1GB
work_mem = 20MB
wal_buffers = 16MB
min_wal_size = 1GB
max_wal_size = 4GB
checkpoint_completion_target = 0.9
default_statistics_target = 100
random_page_cost = 1.1            # SSD/NVMe
effective_io_concurrency = 200    # SSD/NVMe
```

> ⚠️ Estes valores são um ponto de partida. **Valide com testes de carga em homologação** antes de aplicar em produção.

### 10.7. Connection pooling (recomendado)

Com múltiplos nós de aplicação, é comum esgotar `max_connections` rapidamente. Recomenda-se **PgBouncer** (modo `transaction pooling`) entre aplicação e banco:

```ini
[databases]
suap = host=10.0.1.5 port=5432 dbname=suap

[pgbouncer]
listen_addr = 10.0.1.6
listen_port = 6432
auth_type = scram-sha-256
pool_mode = transaction
max_client_conn = 500
default_pool_size = 40
```

A aplicação aponta para o endereço do PgBouncer em vez de diretamente para o PostgreSQL.

### 10.8. Réplicas de leitura (opcional)

Para alta disponibilidade e escala de leitura, configure um cluster PostgreSQL com nó WRITE e múltiplos nós READ, coordenados por **Pgpool-II**:

**Primário (WRITE) — `postgresql.conf`:**

```
wal_level = replica
max_wal_senders = 5
max_replication_slots = 5
```

```sql
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'senha-forte-replicacao';
```

**Cada réplica (READ):**

```bash
sudo -u postgres pg_basebackup -h 10.0.1.5 -D /mnt/pgdata -U replicator -P -R
```

> Essa topologia adiciona complexidade operacional. Recomenda-se implantá-la apenas após o ambiente básico estar estável, sempre testada primeiro em homologação.

### 10.9. Backup do banco

```bash
# Backup lógico diário (cron)
pg_dump -U suap_app -Fc suap > /backups/suap_$(date +\%Y\%m\%d).dump
```

Para *point-in-time recovery*, habilite arquivamento de WAL:

```
archive_mode = on
archive_command = 'test ! -f /mnt/wal_archive/%f && cp %p /mnt/wal_archive/%f'
```

Ou use **pgBackRest** para backup incremental e WAL archiving de forma integrada.

### 10.10. Preparação da aplicação e primeiro acesso

Independentemente da rota (nativa ou Docker):

1. **Banco e usuário criados** conforme 10.4, com `bytea_output = 'escape'`.
2. **Rodar as migrações** (`manage.py migrate` ou via Makefile).
3. **Criar o superusuário inicial**: `python manage.py createsuperuser`
4. Acessar `/comum/configuracao/` e revisar configurações institucionais.
5. Se aplicável, configurar autenticação LDAP/AD em `/admin/ldap_backend/ldapconf/`.

---

## 11. Balanceamento de carga e alta disponibilidade

- Utilize **HAProxy** ou **Nginx** como balanceador com política `least_conn`.
- Configure **health checks** ativos contra um endpoint leve do SUAP.
- **Sticky sessions** podem ser necessárias caso a sessão não esteja delegada ao Redis — validar com a equipe de desenvolvimento.
- Para eliminar ponto único de falha, considere **VRRP/keepalived** entre dois balanceadores.
- **Terminação SSL** no balanceador, tráfego interno em rede privada.

---

## 12. Armazenamento de mídia (NFS / MinIO)

Com múltiplos nós de aplicação, os arquivos enviados pelos usuários precisam estar acessíveis de forma consistente em todos os nós.

### 12.1. NFS

No servidor de NFS:

```bash
# /etc/exports
/var/opt/suap/media  <IP_REDE_INTERNA>/24(rw,no_root_squash,subtree_check)
```

```bash
exportfs -ra
```

Em cada nó de aplicação (`/etc/fstab`), ajuste o caminho de montagem conforme a rota utilizada:

- **Rota nativa:** monte em `/opt/suap/deploy/media` (caminho usado pelo Nginx local)
- **Rota Docker:** monte em `/opt/suap_deploy/deploy/media` (volume mapeado pelo compose)

Exemplo para rota nativa:

```
<IP_NFS>:/var/opt/suap/media  /opt/suap/deploy/media  nfs  nfsvers=4,rw,hard,intr  0  0
```

Exemplo para rota Docker:

```
<IP_NFS>:/var/opt/suap/media  /opt/suap_deploy/deploy/media  nfs  nfsvers=4,rw,hard,intr  0  0
```

```bash
mount -a
```

> **Nota:** prefira NFSv4 ao invés de NFSv3 em implantações novas — oferece melhor segurança (Kerberos), performance (compound operations) e firewall simplificado (porta única 2049).

### 12.2. MinIO (alternativa escalável)

MinIO oferece armazenamento de objetos compatível com S3, com escalabilidade horizontal e tolerância a falhas nativa via erasure coding.

**Topologia mínima para produção:** 4 nós (tolera perda de até 2 discos/nós).

**Integração com o SUAP (Django via `django-storages`):**

```python
DEFAULT_FILE_STORAGE = "djtools.storages.s3.MediaS3Storage"

AWS_ACCESS_KEY_ID = "suap-app"
AWS_SECRET_ACCESS_KEY = "<senha-do-usuario-app>"
AWS_S3_ENDPOINT_URL = "https://minio.instituicao.edu.br"
AWS_MEDIA_BUCKET_NAME='suap-media-bucket'
AWS_PRIVATE_MEDIA_BUCKET_NAME='suap-private-media-bucket'
AWS_STATIC_BUCKET_NAME='suap-static-bucket'
AWS_TEMP_BUCKET_NAME='suap-temp-bucket'
```

> Confirme se a versão do SUAP em uso já traz `django-storages` como dependência e se expõe essas variáveis nativamente.

**Recomendação:** se a instituição ainda não tem maturidade operacional em MinIO, comece com NFS e migre quando o volume justificar.

---

## 13. Rotina de atualização

O `suap-setup` fornece scripts dedicados de atualização para a rota nativa, e o Makefile do `suap_deploy` para a rota Docker.

### 13.1. Rota nativa

```bash
sudo bash deb/suap-update.sh   # ou rpm/ ou arch/ conforme distribuição
```

Fluxo executado automaticamente:

1. Para todos os serviços do Supervisor;
2. Atualiza o código-fonte (`git pull`);
3. Atualiza dependências Python via `uv`;
4. Pergunta ao operador se deseja rodar `migrate`;
5. Pergunta se deseja rodar `collectstatic`;
6. Pergunta se deseja rodar `sync_permissions`;
7. Corrige permissões dos diretórios (`chown www-data`);
8. Reinicia os serviços do Supervisor;
9. Exibe status e resumo das ações realizadas.

> **Rollback automático:** se o `git pull` ou a instalação de dependências falhar, os serviços são reiniciados automaticamente na versão anterior antes do script encerrar com erro.

### 13.2. Rota Docker

```bash
cd /opt/suap_deploy
docker compose pull    # Pull das imagens atualizadas do registry
make down              # Parar serviços atuais
make up                # Iniciar com as novas imagens
```

Ou, para modo local (build a partir do código-fonte):

```bash
cd /opt/suap_deploy
cd src/suap && git pull && cd ../..
make build             # Rebuild das imagens
make restart           # Reiniciar serviços
```

### 13.3. Política de atualização recomendada

- Atualizações **críticas** (com migrações de tabelas) devem ocorrer em janelas de menor impacto.
- Atualizações **corretivas** de baixo risco podem ser aplicadas no mesmo dia.
- Em ambientes com múltiplos nós, aplique **um nó por vez** (rolling update).
- **Sempre validar em homologação antes de promover para produção.**

---

## 14. Backup e recuperação de desastres

- **Banco de dados:** dump diário completo (`pg_dump`) + WAL archiving para *point-in-time recovery*.
- **Mídia:** backup incremental do volume NFS/MinIO, com retenção mínima de 30 dias.
- **Configurações:** versionar `.env`, configurações de Nginx e Supervisor customizadas em um repositório interno privado.
- **Teste de restauração:** validar periodicamente (ex.: trimestralmente) que os backups restauram um ambiente funcional, preferencialmente restaurando no ambiente de homologação.

---

## 15. Monitoramento e logs

- **Logs de aplicação e Nginx:** via `make logs` (Docker) ou diretamente em `/var/log/nginx/` e logs do Supervisor (rota nativa).
- **Monitor do Celery:** painel **Flower**, protegido por autenticação forte e acessível apenas via rede interna.
- **Métricas de infraestrutura:** recomenda-se Prometheus + Grafana (ou solução equivalente) para CPU, memória, conexões de banco e filas do Celery.
- **Auditoria:** manter logs de acesso administrativo auditáveis.

---

## 16. Checklist final de go-live

- [ ] Ambiente de homologação validado com o mesmo fluxo planejado para produção.
- [ ] Todas as VMs provisionadas conforme dimensionamento da seção 5.2.
- [ ] Balanceador de carga configurado com health check e política `least_conn`.
- [ ] Certificado SSL válido com renovação automática.
- [ ] Banco de dados com `bytea_output` ajustado, usuário com privilégios restritos.
- [ ] Redis, Celery worker e beat operacionais; Flower com autenticação não-padrão.
- [ ] Armazenamento de mídia compartilhado montado e testado em todos os nós.
- [ ] Rotina de backup configurada e testada (restauração validada).
- [ ] Scripts de atualização (`suap-update.sh` ou Makefile) testados em homologação.
- [ ] Firewall revisado — PostgreSQL e Redis não expostos à internet.
- [ ] Configurações institucionais (`/comum/configuracao/`) preenchidas.

---

## 17. Referências

- Repositório de automação: [danielslz/suap-setup](https://github.com/danielslz/suap-setup)
- Portal institucional do SUAP: [portal.suap.ifrn.edu.br](https://portal.suap.ifrn.edu.br)
- Wiki COSINF/IFRN — Instalação em produção (Debian)
- Wiki COSINF/IFRN — Múltiplas Instâncias do SUAP
- Wiki COSINF/IFRN — Instalação do SUAP em produção usando Docker
- Projeto `suap_deploy` (GitLab COSINF/IFRN)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [MinIO Documentation](https://min.io/docs/minio/linux/index.html)
- [UV — Python Package Manager](https://docs.astral.sh/uv/)

---

*Este documento serve como referência de implantação e manutenção dos ambientes de homologação e produção do SUAP para qualquer instituição que adote o sistema.*
