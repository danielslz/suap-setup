# Docker - Arquitetura de Delegação

O suap-setup **não mantém Dockerfiles próprios**. Em vez disso, os scripts
delegam para os projetos oficiais:

## Desenvolvimento (`docker/dev/docker-setup.sh`)

Utiliza o `docker-compose.dev.yml` do repositório **suap** (código-fonte da
aplicação). Isso garante que:

- Os Dockerfiles usados são os mesmos que o CI/CD constrói
- Serviços auxiliares (minio, pdfprinter, ai) estão disponíveis
- Atualizações de dependências do upstream são automaticamente refletidas

**Fluxo:**
1. Verifica/clona o repositório SUAP em `SUAP_DIR`
2. Gera `.env` a partir do sample se necessário
3. Executa `docker compose -f docker/docker-compose.dev.yml up`

**Variáveis necessárias no `.env` do suap-setup:**
- `SUAP_DIR` - Caminho para o repositório suap
- `GIT_URL` - URL git do repositório (para clone automático)
- `SUAP_IMAGE` - URL da imagem no registry

## Produção (`docker/prod/docker-setup.sh`)

Utiliza o projeto **suap_deploy** que é o orquestrador oficial de produção.
O suap_deploy:

- Puxa imagens pré-construídas do registry GitLab
- Usa OWASP ModSecurity CRS como WAF no Nginx
- Suporta resource limits por container
- Integra com Vault para gerenciamento de segredos
- Inclui serviços auxiliares (pdfprinter, ai)
- Gerencia via Makefile com targets bem definidos

**Fluxo:**
1. Verifica/clona o repositório suap_deploy em `SUAP_DEPLOY_DIR`
2. Configura `.env` de produção
3. Apresenta menu interativo com opções de gerenciamento
4. Delega para os targets do Makefile

**Variáveis necessárias no `.env` do suap-setup:**
- `SUAP_DEPLOY_DIR` - Caminho para o repositório suap_deploy
- `SUAP_DEPLOY_GIT_URL` - URL git do suap_deploy

## Dockhand (`docker/dockhand-setup.sh`)

Instala e inicia o Dockhand (interface web para gerenciamento Docker).
Este é um utilitário independente e não depende dos projetos acima.

## Por que não manter Dockerfiles locais?

1. **Evita drift**: Quando o upstream muda dependências (ex: nova lib Python),
   os Dockerfiles locais ficariam desatualizados silenciosamente
2. **Single source of truth**: Os Dockerfiles do suap são os que o CI/CD
   constrói e publica — são os "oficiais"
3. **Completude**: O compose do suap inclui todos os serviços necessários
   (minio, ai, pdf) que um setup local precisaria duplicar
4. **Produção real**: O suap_deploy tem configurações battle-tested (WAF, limits,
   Vault, SSL) que não fazem sentido recriar
