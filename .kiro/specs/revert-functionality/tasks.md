
## Overview

Implementação incremental da funcionalidade de reversão. Parte da infraestrutura compartilhada em `lib/common.sh` (manifesto + funções `revert_*`), instrumenta as rotinas de instalação para registrar o estado, cria os scripts `-revert.sh` por distribuição, integra ao menu do `setup.sh`, e cobre tudo com testes e documentação. Cada etapa constrói sobre a anterior.

## Tasks

- [ ] 1. Infraestrutura de manifesto em lib/common.sh
  - [ ] 1.1 Implementar funções de manifesto
    - Implementar `manifest_path(chave)` com resolução `.state/` (repo, se gravável) ou `/var/lib/suap-setup/` (fallback de sistema), criando o diretório
    - Implementar `manifest_record(chave, tipo, id, [meta])` idempotente (não duplica)
    - Implementar `manifest_has`, `manifest_entries`, `manifest_remove_entry`, `manifest_is_empty`
    - Usar TAB como delimitador; formato `<tipo>\t<id>\t<meta>`
    - _Requisitos: 1.1, 1.2, 1.5, 1.6, 2.4_
  - [ ] 1.2 Adicionar `.state/` ao .gitignore
    - _Requisitos: 1.6_
  - [ ] 1.3 Testes unitários das funções de manifesto
    - Criar `tests/unit/test_manifest.bats`: registro idempotente, has, remove_entry, is_empty, resolução de path
    - _Requisitos: 8.3_

- [ ] 2. Funções de reversão reutilizáveis em lib/common.sh
  - [ ] 2.1 Implementar funções `revert_*` por tipo de artefato
    - `revert_dir` (com flag destrutivo), `revert_file`, `revert_symlink` (restaura alvo), `revert_binary`
    - `revert_package` (desinstala por DISTRO_TYPE, sempre com confirmação), `revert_service` (para/desabilita só o que a rotina mudou)
    - `revert_user` (recusa `www-data` por padrão), `revert_pg_db`, `revert_pg_user`, `revert_file_lines` (remove bloco por marcador sentinela), `repo_added`
    - `confirm_destructive(descricao)` com suporte a modo não-interativo/dry-run
    - _Requisitos: 2.5, 3.1, 3.2, 3.3, 3.4, 3.5, 3.7, 6.1, 6.2, 6.3_
  - [ ] 2.2 Implementar `revert_apply(chave, [--dry-run])`
    - Iterar entradas, despachar por tipo na ordem segura definida no design, remover entrada ao sucesso, acumular falhas, imprimir resumo
    - Tratar manifesto vazio/ausente (sai sem erro); idempotência
    - _Requisitos: 2.2, 2.3, 2.6, 3.6, 7.1, 7.2, 7.3_
  - [ ] 2.3 Testes unitários/property das funções de reversão (com mocks)
    - Mock de apt/dnf/pacman, systemctl, psql, userdel; verificar comandos sem executar
    - Property: preserva Artefato_Preexistente; destrutivo exige confirmação; idempotência; `www-data` nunca removido por padrão; dry-run não altera nada
    - _Requisitos: 8.3, 8.4, 3.1, 3.2, 3.4, 7.1_

- [ ] 3. Instrumentar rotinas de instalação para registrar o manifesto
  - [ ] 3.1 Ambiente dev (deb/rpm/arch/macos) registra artefatos
    - Registrar delta de pacotes (só os que não estavam instalados), VENV_DIR, SUAP_DIR clonado, binário wkhtmltopdf, settings.py/.env gerados
    - _Requisitos: 1.3, 1.4, 1.7, 5.1, 5.2_
  - [ ] 3.2 Ambiente prod (deb/rpm/arch) registra artefatos
    - Delta de pacotes, confs do Supervisor copiadas, conf do Nginx, usuário www-data (se criado), SUAP_DIR, binário wkhtmltopdf
    - _Requisitos: 1.3, 1.4, 6.4_
  - [ ] 3.3 Serviços (redis/nginx/postgres) registram artefatos
    - Redis/Nginx: pacote (se instalado pela rotina), serviço habilitado, conf do SUAP; Nginx: symlink e remoção do default (para restaurar)
    - Postgres: repo PGDG adicionado, pacotes, serviço, pg_db, pg_user, linhas em pg_hba.conf/postgresql.conf (com marcador sentinela)
    - _Requisitos: 1.3, 1.4, 6.1, 6.2, 6.3_
  - [ ] 3.4 Docker dev/prod, Dockhand, MinIO registram artefatos
    - Repositórios clonados, containers/compose iniciados, diretórios de dados
    - _Requisitos: 1.4, 6.5_

- [ ] 4. Scripts de reversão por funcionalidade
  - [ ] 4.1 `suap-dev-revert.sh` (deb/rpm/arch/macos)
    - Carregar .env, definir DISTRO_TYPE, chamar `revert_apply "suap-dev"` com políticas (SUAP_DIR e pacotes exigem confirmação; UV/Python preservados)
    - _Requisitos: 2.1, 5.1, 5.2, 5.3, 5.4, 5.5, 7.4_
  - [ ] 4.2 `suap-prod-revert.sh` (deb/rpm/arch)
    - _Requisitos: 2.1, 6.4_
  - [ ] 4.3 Reversões de serviços: redis/nginx/postgres (deb/rpm/arch)
    - _Requisitos: 2.1, 6.1, 6.2, 6.3_
  - [ ] 4.4 Reversões de Docker dev/prod, Dockhand, MinIO
    - _Requisitos: 2.1, 6.5_

- [ ] 5. Integração no menu do Wrapper (setup.sh)
  - [ ] 5.1 Adicionar entrada "Reverter" no menu principal + submenu de reversão e roteamento por DISTRO_TYPE
    - Menu principal: uma única entrada "R) Reverter" que abre o submenu; submenu com opção "0) Voltar"
    - Submenu espelha as funcionalidades suportadas; não oferecer reversões incompatíveis com a plataforma (ex.: prod no macOS)
    - Exibir resumo do manifesto e confirmar antes de executar
    - _Requisitos: 4.1, 4.2, 4.3, 4.4, 4.5_
  - [ ] 5.2 Testes de roteamento do menu de reversão
    - Property/unit análogos ao `test_routing.bats` existente
    - _Requisitos: 8.3_

- [ ] 6. Documentação
  - [ ] 6.1 README.md — seção de reversão e política conservadora
    - _Requisitos: 8.1_
  - [ ] 6.2 docs/TECHNICAL.md — manifesto, funções novas, algoritmo de revert_apply, ordem de reversão
    - _Requisitos: 8.1_
  - [ ] 6.3 docs/DEPLOYMENT.md — implicações de reverter em produção e avisos destrutivos
    - _Requisitos: 8.2_

- [ ] 7. Validação final
  - [ ] 7.1 Rodar a suíte completa (`./tests/run_tests.sh`) e garantir verde
  - [ ] 7.2 Teste manual na VM Debian: aplicar dev, reverter dev, confirmar estado conservador (pacotes preservados, SUAP_DIR só com confirmação)
    - _Requisitos: 2.1, 3.1, 5.3_
