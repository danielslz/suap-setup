# Design Document

## Visão Geral

Esta funcionalidade adiciona ao suap-setup a capacidade de **reverter** (desfazer) o que cada rotina de instalação aplicou, com uma **abordagem baseada em estado (manifesto de precisão)**: cada rotina de instalação registra, em um manifesto por funcionalidade, exatamente os artefatos que ela criou/instalou; a rotina de reversão lê esse manifesto e desfaz apenas esses artefatos, de forma **conservadora** (nunca remove o que já existia, pede confirmação para operações destrutivas e preserva serviços compartilhados por padrão).

O design reutiliza a infraestrutura existente: `lib/common.sh` (mensagens, detecção de distro, verificação de pacotes), o `.env` centralizado e o roteamento por `DISTRO_TYPE` no `setup.sh`.

## Arquitetura

```
setup.sh (Wrapper)
  ├── menu de instalação (existente)
  └── menu de reversão (novo)  ──► roteia por DISTRO_TYPE para a Rotina_Reversao

lib/common.sh
  ├── funções de mensagem/distro/pacote (existentes)
  ├── funções de MANIFESTO (novas): manifest_path, manifest_record, manifest_has,
  │     manifest_entries, manifest_remove_entry, manifest_is_empty
  └── funções de REVERSÃO (novas, reutilizáveis): revert_dir, revert_file,
        revert_package, revert_binary, revert_service, revert_user,
        confirm_destructive, revert_apply (loop sobre o manifesto)

<distro>/<rotina>.sh (instalação, modificados)
  └── passam a chamar manifest_record ao criar cada Artefato_Criado

<distro>/<rotina>-revert.sh (reversão, novos)
  └── leem o manifesto e chamam as funções revert_* conforme o tipo de artefato
```

### Decisão de nomenclatura dos scripts de reversão

Cada rotina de instalação `X.sh` ganha um par `X-revert.sh` na mesma pasta de distro, por exemplo:
- `deb/suap-dev-revert.sh`, `rpm/suap-dev-revert.sh`, `arch/suap-dev-revert.sh`, `macos/suap-dev-revert.sh`
- `deb/suap-prod-revert.sh`, `rpm/suap-prod-revert.sh`, `arch/suap-prod-revert.sh`
- `deb/install-redis-revert.sh`, `deb/install-nginx-revert.sh`, `deb/install-postgres-revert.sh` (e equivalentes rpm/arch)
- `docker/dev/docker-setup-revert.sh`, `docker/prod/docker-setup-revert.sh`, `docker/dockhand-revert.sh`, `docker/minio-revert.sh`

A lógica pesada vive em `lib/common.sh` (funções `revert_*` e de manifesto); os scripts `-revert.sh` são finos: carregam o `.env`, definem a `DISTRO_TYPE`, apontam o manifesto correto e invocam `revert_apply` com as políticas específicas (quais tipos exigem confirmação).

## Formato do Manifesto de Estado

### Localização

- Um manifesto por **funcionalidade + ambiente**, em um diretório de estado local, ignorado pelo git:
  - `<repo>/.state/<chave>.manifest` — ex.: `.state/suap-dev.manifest`, `.state/postgres.manifest`, `.state/nginx.manifest`.
- Alternativa para rotinas de produção que rodam como root e podem ser executadas fora do repo: fallback para `/var/lib/suap-setup/<chave>.manifest`. A função `manifest_path <chave>` resolve o local apropriado (preferindo o do repo quando gravável; caso contrário, o de sistema).
- `.gitignore` passa a ignorar `.state/`.

### Estrutura das entradas

Formato de linha simples, fácil de ler/escrever em bash, resistente a espaços via delimitador TAB:

```
<tipo>\t<identificador>\t<metadado-opcional>
```

Tipos suportados e semântica de reversão:

| Tipo | Identificador | Metadado | Ação de reversão |
|------|---------------|----------|------------------|
| `dir` | caminho absoluto | — | remover diretório (destrutivo se contiver dados do usuário) |
| `file` | caminho absoluto | — | remover arquivo |
| `symlink` | caminho do link | alvo original (se substituiu algo) | remover link; restaurar alvo se registrado |
| `package` | nome do pacote | — | desinstalar via gerenciador (apenas com confirmação) |
| `binary` | caminho em /usr/local/bin | — | remover binário |
| `service` | nome do serviço | `enabled`/`started` | parar/desabilitar apenas o que a rotina ativou (serviço compartilhado preservado) |
| `user` | nome do usuário | `created` | remover usuário (nunca `www-data` por padrão) |
| `pg_db` | nome do banco | — | DROP DATABASE (destrutivo, confirmação) |
| `pg_user` | nome do role | — | DROP ROLE (confirmação) |
| `file_lines` | caminho do arquivo | marcador/âncora das linhas inseridas | remover as linhas que a rotina inseriu (ex.: pg_hba.conf) |
| `repo_added` | caminho da lista/keyring | — | remover a fonte de apt/repo adicionada |

Observações:
- `file_lines` cobre as edições por `sed` (ex.: `pg_hba.conf`, `postgresql.conf`). A rotina de instalação registra um marcador único (comentário sentinela) inserido junto, permitindo remover exatamente o bloco inserido na reversão.
- `symlink` com alvo original cobre o caso do Nginx, que remove `sites-enabled/default`: na reversão, recria-se o default se o manifesto registrar que ele foi removido.

## Componentes e Funções

### Funções de manifesto (lib/common.sh)

- `manifest_path(chave)` → ecoa o caminho do manifesto para a chave, criando o diretório `.state/` (ou `/var/lib/suap-setup/`) se necessário.
- `manifest_record(chave, tipo, id, [meta])` → adiciona a entrada se ainda não existir (idempotente; usa `manifest_has`).
- `manifest_has(chave, tipo, id)` → retorna 0 se a entrada já existe.
- `manifest_entries(chave)` → emite as entradas (para iteração na reversão), em ordem adequada.
- `manifest_remove_entry(chave, tipo, id)` → remove a linha correspondente após reverter com sucesso.
- `manifest_is_empty(chave)` → verdadeiro se não há manifesto ou está vazio.

### Padrão de registro na instalação (pacotes pré-existentes)

Para cumprir o Requirement 1.3 (registrar só o que a própria rotina instalou), o padrão é capturar o estado ANTES e registrar só o delta:

```bash
# antes de instalar
for pkg in "${PACKAGES[@]}"; do
  is_pkg_installed "$pkg" || _to_install+=("$pkg")
done
# ... instala "${PACKAGES[@]}" ...
# registra apenas os que não estavam instalados
for pkg in "${_to_install[@]}"; do
  manifest_record "suap-dev" package "$pkg"
done
```

O mesmo princípio vale para serviços (registrar `service` só se a rotina executou `enable`/`start` e o serviço não estava já ativo/habilitado), diretórios (registrar `dir` só quando a rotina efetivamente clonou/criou), etc.

### Funções de reversão (lib/common.sh)

Cada função trata um tipo, é idempotente e respeita a política conservadora:

- `revert_dir(caminho, [--destructive])` — remove diretório; se `--destructive` (contém dados do usuário), passa por `confirm_destructive`.
- `revert_file(caminho)` — remove arquivo se existir.
- `revert_symlink(link, [alvo_restaurar])` — remove link; recria alvo original se fornecido.
- `revert_package(pkg)` — desinstala via gerenciador da `DISTRO_TYPE`, somente após confirmação (pacotes são sempre tratados como "exige confirmação" por padrão).
- `revert_binary(caminho)` — remove binário de /usr/local/bin.
- `revert_service(nome, meta)` — para e/ou desabilita conforme `meta`; para Servico_Compartilhado não desinstala o pacote, só reverte o que a rotina mudou.
- `revert_user(nome)` — remove usuário; recusa `www-data` por padrão (exige confirmação explícita e flag).
- `revert_pg_db(nome)` / `revert_pg_user(nome)` — DROP com confirmação destrutiva.
- `revert_file_lines(arquivo, marcador)` — remove o bloco de linhas delimitado pelo marcador sentinela.
- `confirm_destructive(descricao)` — exibe o que será afetado e lê confirmação (respeita um modo não-interativo/dry-run).
- `revert_apply(chave, [--dry-run])` — itera `manifest_entries`, despacha para a função `revert_*` por tipo, remove a entrada do manifesto ao sucesso, acumula falhas e imprime resumo final.

### Ordem de reversão

`revert_apply` processa em ordem segura, independente da ordem de inserção:
1. `service` (parar/desabilitar) e containers/compose (down)
2. `pg_db`, `pg_user` (com confirmação)
3. `file_lines`, `file`, `symlink`
4. `binary`
5. `dir` (do mais profundo para o mais raso)
6. `package` (com confirmação; por último, pois outros artefatos podem depender)
7. `user` (por último; `www-data` preservado por padrão)
8. `repo_added`

## Fluxo do Wrapper (setup.sh)

O menu principal ganha **uma única entrada "Reverter"** que abre um **submenu de reversão**, para não poluir a lista de instalação. O submenu lista apenas as funcionalidades que suportam reversão e que são compatíveis com a `DISTRO_TYPE` detectada (ex.: não oferece reversão de produção no macOS).

```
=== SUAP Setup ===
  1) ... (opções de instalação atuais)
  ...
  R) Reverter uma funcionalidade  ──► abre o submenu abaixo
  0) Sair

=== SUAP Setup — Reverter ===
  1) Reverter ambiente de desenvolvimento
  2) Reverter ambiente de produção
  3) Reverter Redis
  4) Reverter Nginx
  ...
  0) Voltar
```

Ao escolher uma entrada do submenu, o Wrapper mapeia para um `INTERNAL_CHOICE` de reversão (análogo ao mapeamento de instalação) e roteia para `<distro>/<rotina>-revert.sh` via `bash`, exatamente como o roteamento atual de instalação. O submenu respeita o mesmo remapeamento por plataforma já existente para o macOS.

Antes de executar qualquer reversão, o script de reversão exibe o resumo do manifesto (o que será removido e o que será preservado) e solicita confirmação, conforme Requirement 4.4.

## Tratamento de Erros

- Reversão de artefato ausente → `msg_skip` e segue (idempotência, Requirement 7.1).
- Falha ao reverter um artefato → `msg_error`, não remove a entrada do manifesto, continua com os demais quando seguro, e reporta no resumo final (Requirement 2.6).
- Falta de privilégios → detecta (ex.: `[ "$EUID" -ne 0 ]` para operações de sistema) e informa claramente; rotinas de produção seguem o padrão de auto-elevação com `sudo` já usado nas instalações.
- Manifesto ausente/vazio → informa que não há nada a reverter e sai com sucesso (Requirement 2.4).

## Estratégia de Testes

Seguindo o padrão bats existente (unit/property/smoke), com mock de operações de sistema:

- **Unit (manifesto):** `manifest_record` idempotente; `manifest_has`; `manifest_remove_entry`; `manifest_is_empty`; resolução de `manifest_path`.
- **Unit (reversão):** cada `revert_*` com binários de sistema mockados (apt/dnf/pacman, systemctl, psql, userdel) para verificar que o comando correto seria chamado, sem executar de verdade.
- **Property/Conservadorismo:**
  - Preservação de Artefato_Preexistente: dado um pacote não registrado no manifesto, a reversão não o remove.
  - Operacao_Destrutiva sempre passa por confirmação (simular resposta negativa → não remove).
  - Idempotência: rodar a reversão duas vezes não falha.
  - `www-data` nunca removido por padrão.
- **Dry-run:** `revert_apply --dry-run` não altera o sistema nem o manifesto, apenas lista.

Nenhum teste executa remoção real: todos mockam os comandos de sistema, no mesmo estilo dos testes atuais (ex.: `test_prod_flow.bats`, `test_common_functions.bats`).

## Impacto na Documentação

- **README.md:** nova seção "Reversão", com as opções de menu e o aviso de política conservadora.
- **docs/TECHNICAL.md:** formato do manifesto, funções novas em `lib/common.sh`, algoritmo de `revert_apply`, ordem de reversão, e o padrão de registro de delta de pacotes.
- **docs/DEPLOYMENT.md:** implicações de reverter em produção (confirmações destrutivas, serviços compartilhados preservados, cuidado com `pg_db`).
- **.gitignore:** ignorar `.state/`.
