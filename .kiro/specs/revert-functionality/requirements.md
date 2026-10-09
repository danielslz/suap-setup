# Requirements Document

## Introduction

Este documento define os requisitos para a funcionalidade de **reversão** (desfazer/desinstalar) do projeto **suap-setup**. Hoje os scripts aplicam configurações de ambiente (desenvolvimento, produção, serviços de infraestrutura e ambientes Docker) de forma idempotente, mas não há um caminho suportado para desfazer o que foi aplicado. Esta funcionalidade adiciona, para cada rotina de instalação/configuração, uma rotina de reversão correspondente que remove com segurança os artefatos criados pela rotina.

A reversão é **conservadora por padrão**: remove apenas o que a rotina de instalação comprovadamente criou (registrado em um manifesto de estado), nunca removendo artefatos pré-existentes no sistema, e exigindo confirmação explícita para operações destrutivas ou que afetem serviços compartilhados.

A funcionalidade adota uma **abordagem baseada em estado (manifesto de precisão)**: cada rotina de instalação passa a registrar, em um arquivo de manifesto, exatamente o que criou (diretórios, arquivos, pacotes instalados por ela, binários, serviços, usuários), e a rotina de reversão desfaz apenas o que consta nesse manifesto.

## Glossary

- **Rotina_Instalacao**: Qualquer rotina existente que aplica configuração/instalação (Script_Dev, Script_Prod, Script_Redis, Script_Nginx, Script_Postgres, Script_Docker_Dev, Script_Docker_Prod, Script_Minio, Dockhand).
- **Rotina_Reversao**: Nova rotina correspondente a uma Rotina_Instalacao, responsável por desfazer o que aquela rotina aplicou.
- **Manifesto_Estado**: Arquivo versionável em disco (fora do controle do git) onde cada Rotina_Instalacao registra os artefatos que efetivamente criou/instalou. É a fonte de verdade para a reversão de precisão.
- **Artefato_Criado**: Qualquer recurso que uma Rotina_Instalacao criou e que, portanto, pode ser revertido com segurança: diretório clonado, arquivo de configuração copiado, pacote instalado pela própria rotina, binário instalado manualmente, serviço habilitado, usuário/grupo criado.
- **Artefato_Preexistente**: Recurso que já existia no sistema antes da execução da Rotina_Instalacao (ex.: um pacote já instalado, um diretório já presente). NUNCA deve ser removido pela Rotina_Reversao.
- **Operacao_Destrutiva**: Remoção que pode causar perda de dados ou afetar outros sistemas (apagar banco de dados, remover diretório com conteúdo do usuário, desinstalar serviço compartilhado, remover usuário de sistema).
- **Servico_Compartilhado**: Serviço de infraestrutura que pode ser usado por outros sistemas além do SUAP (PostgreSQL, Redis, Nginx, Docker).
- **Reversao_Conservadora**: Política padrão em que a Rotina_Reversao remove apenas Artefato_Criado registrado no Manifesto_Estado, preserva Artefato_Preexistente, e exige confirmação explícita para Operacao_Destrutiva.
- **Wrapper**: Script principal (`setup.sh`) que exibe o menu e roteia para a rotina apropriada.
- **lib/common.sh**: Biblioteca compartilhada que conterá as funções utilitárias de manifesto e de reversão reutilizáveis.
- **DISTRO_TYPE**: Variável que identifica a família da distribuição (`deb`, `rpm`, `arch`, `macos`).

## Requirements

### Requirement 1: Registro de estado durante a instalação (Manifesto)

**User Story:** Como operador do suap-setup, eu quero que cada rotina de instalação registre o que ela realmente criou, para que a reversão posterior possa desfazer apenas isso com precisão, sem afetar o que já existia no sistema.

#### Acceptance Criteria

1. THE lib/common.sh SHALL fornecer uma função utilitária para registrar um Artefato_Criado no Manifesto_Estado, identificando o tipo do artefato (ex.: `dir`, `file`, `package`, `binary`, `service`, `user`) e seu identificador (caminho ou nome).
2. THE Manifesto_Estado SHALL ser gravado em um caminho estável e previsível, associado à Rotina_Instalacao e, quando aplicável, ao ambiente (ex.: dev vs prod).
3. WHEN uma Rotina_Instalacao instala um pacote de sistema, THE Rotina_Instalacao SHALL verificar se o pacote já estava instalado ANTES da operação e registrar no Manifesto_Estado APENAS os pacotes que ela própria instalou (não os Artefato_Preexistente).
4. WHEN uma Rotina_Instalacao cria um diretório, clona um repositório, copia um arquivo de configuração, instala um binário, habilita um serviço ou cria um usuário/grupo, THE Rotina_Instalacao SHALL registrar o Artefato_Criado correspondente no Manifesto_Estado.
5. IF um Artefato_Criado já constava no Manifesto_Estado de uma execução anterior, THEN THE Rotina_Instalacao SHALL evitar duplicação de registro no manifesto (idempotência do registro).
6. THE Manifesto_Estado SHALL ser ignorado pelo controle de versão (git) por ser estado local da máquina.
7. WHERE uma Rotina_Instalacao não cria nenhum Artefato_Criado novo (tudo já estava presente), THE Rotina_Instalacao SHALL manter o Manifesto_Estado consistente sem registrar artefatos que não criou.

### Requirement 2: Rotina de reversão por funcionalidade

**User Story:** Como operador do suap-setup, eu quero poder reverter cada funcionalidade aplicada, para restaurar o sistema a um estado próximo ao anterior à instalação quando precisar refazer ou limpar o ambiente.

#### Acceptance Criteria

1. THE suap-setup SHALL fornecer uma Rotina_Reversao correspondente para cada Rotina_Instalacao que cria artefatos persistentes: ambiente de desenvolvimento, ambiente de produção, Redis, Nginx, PostgreSQL, Docker dev, Docker prod, Dockhand e MinIO.
2. WHEN uma Rotina_Reversao é executada, THE Rotina_Reversao SHALL ler o Manifesto_Estado da Rotina_Instalacao correspondente e desfazer apenas os Artefato_Criado nele registrados.
3. WHEN uma Rotina_Reversao remove um Artefato_Criado com sucesso, THE Rotina_Reversao SHALL remover a entrada correspondente do Manifesto_Estado.
4. IF o Manifesto_Estado não existe ou está vazio para a Rotina_Instalacao solicitada, THEN THE Rotina_Reversao SHALL informar que não há nada registrado para reverter e encerrar sem erro.
5. THE Rotina_Reversao SHALL remover os Artefato_Criado em ordem inversa segura (ex.: parar serviços antes de remover arquivos; remover arquivos antes de remover diretórios pai).
6. WHEN a reversão de um Artefato_Criado falha, THE Rotina_Reversao SHALL exibir mensagem de erro clara, continuar com os demais artefatos quando seguro, e ao final reportar quais artefatos não puderam ser revertidos.

### Requirement 3: Política de reversão conservadora e segurança

**User Story:** Como operador do suap-setup, eu quero que a reversão nunca remova o que já existia antes nem quebre o sistema, para que desfazer uma instalação seja uma operação segura.

#### Acceptance Criteria

1. THE Rotina_Reversao SHALL remover exclusivamente Artefato_Criado registrado no Manifesto_Estado e NÃO SHALL remover Artefato_Preexistente.
2. WHEN a reversão envolve uma Operacao_Destrutiva (apagar banco de dados, remover diretório com conteúdo do usuário, desinstalar Servico_Compartilhado, remover usuário de sistema), THE Rotina_Reversao SHALL solicitar confirmação explícita do operador antes de executar, exibindo claramente o que será afetado.
3. WHERE a reversão desinstalaria um Servico_Compartilhado (PostgreSQL, Redis, Nginx, Docker), THE Rotina_Reversao SHALL, por padrão, preservar o serviço e remover apenas a configuração/dados específicos do SUAP que a Rotina_Instalacao criou, exigindo confirmação explícita adicional para desinstalar o serviço por completo.
4. THE Rotina_Reversao SHALL NÃO remover o usuário de sistema `www-data` por padrão, por ser um usuário padrão do sistema, mesmo que registrado como criado — exigindo confirmação explícita quando aplicável.
5. IF uma Operacao_Destrutiva afeta dados do usuário (ex.: diretório SUAP_DIR com `.env` editado ou alterações locais no código), THEN THE Rotina_Reversao SHALL avisar explicitamente e solicitar confirmação antes de remover.
6. THE Rotina_Reversao SHALL oferecer um modo de pré-visualização (dry-run) que lista o que seria removido sem executar nenhuma remoção.
7. WHEN executada sem privilégios suficientes para remover um Artefato_Criado que exige elevação, THE Rotina_Reversao SHALL informar a necessidade de privilégios e não falhar silenciosamente.

### Requirement 4: Acionamento via menu do Wrapper

**User Story:** Como operador do suap-setup, eu quero acionar as reversões pelo mesmo menu interativo que uso para instalar, para ter uma experiência consistente.

#### Acceptance Criteria

1. THE Wrapper SHALL apresentar, no menu principal, uma única entrada "Reverter" que abre um submenu de reversão listando as funcionalidades que suportam reversão.
2. WHEN o operador seleciona uma opção no submenu de reversão, THE Wrapper SHALL rotear para a Rotina_Reversao apropriada conforme a DISTRO_TYPE detectada, de forma análoga ao roteamento das rotinas de instalação.
3. THE submenu de reversão SHALL oferecer uma opção para voltar ao menu principal sem executar nenhuma reversão.
4. WHEN o operador seleciona uma reversão, THE Wrapper SHALL exibir um resumo do que será afetado e solicitar confirmação antes de executar, conforme a política de segurança do Requirement 3.
5. WHERE a DISTRO_TYPE não suporta uma determinada funcionalidade (ex.: produção no macOS), THE Wrapper SHALL não oferecer a reversão correspondente para aquela plataforma.

### Requirement 5: Reversão do ambiente de desenvolvimento

**User Story:** Como desenvolvedor, eu quero reverter o ambiente de desenvolvimento, para limpar o que foi instalado e poder recomeçar do zero.

#### Acceptance Criteria

1. WHEN a Rotina_Reversao do ambiente de desenvolvimento é executada, THE Rotina_Reversao SHALL remover o virtualenv criado (VENV_DIR) se registrado como Artefato_Criado.
2. WHEN a Rotina_Reversao do ambiente de desenvolvimento é executada, THE Rotina_Reversao SHALL remover o binário `wkhtmltopdf`/`wkhtmltoimage` de `/usr/local/bin` apenas se tiver sido instalado pela Rotina_Instalacao (registrado no Manifesto_Estado).
3. IF o diretório SUAP_DIR foi clonado pela Rotina_Instalacao, THEN THE Rotina_Reversao SHALL solicitar confirmação explícita antes de removê-lo, avisando sobre perda de `.env` e alterações locais (conforme Requirement 3.5).
4. THE Rotina_Reversao do ambiente de desenvolvimento SHALL, por padrão, NÃO desinstalar os pacotes de sistema de desenvolvimento, exceto se o operador confirmar explicitamente a remoção dos pacotes que foram instalados pela própria rotina (registrados no Manifesto_Estado).
5. THE Rotina_Reversao do ambiente de desenvolvimento SHALL, por padrão, NÃO remover o UV nem a versão de Python instalada via UV, por poderem ser usados por outros projetos.

### Requirement 6: Reversão de serviços de infraestrutura e ambientes

**User Story:** Como operador, eu quero reverter as instalações de serviços e demais ambientes de forma segura e específica ao SUAP, para não impactar outros sistemas no servidor.

#### Acceptance Criteria

1. WHEN a Rotina_Reversao do PostgreSQL é executada, THE Rotina_Reversao SHALL, por padrão, remover apenas o banco de dados e o usuário de aplicação do SUAP criados pela Rotina_Instalacao, preservando o serviço PostgreSQL e demais bancos, e SHALL exigir confirmação explícita para apagar o banco (Operacao_Destrutiva).
2. WHEN a Rotina_Reversao do Nginx é executada, THE Rotina_Reversao SHALL remover apenas a configuração do site SUAP criada pela Rotina_Instalacao, preservando a instalação do Nginx por padrão.
3. WHEN a Rotina_Reversao do Redis é executada, THE Rotina_Reversao SHALL preservar o serviço Redis por padrão e remover apenas ajustes específicos do SUAP que a Rotina_Instalacao tenha aplicado, exigindo confirmação explícita para desinstalar o serviço.
4. WHEN a Rotina_Reversao do ambiente de produção é executada, THE Rotina_Reversao SHALL parar e remover as configurações de Supervisor criadas pela Rotina_Instalacao, remover a configuração de Nginx do SUAP, e tratar SUAP_DIR, usuário e pacotes conforme a política conservadora e as confirmações do Requirement 3.
5. WHEN a Rotina_Reversao do Docker dev, Docker prod, Dockhand ou MinIO é executada, THE Rotina_Reversao SHALL parar e remover os containers/compose que a Rotina_Instalacao iniciou e remover os diretórios/repositórios clonados registrados, preservando a instalação do Docker por padrão e exigindo confirmação para remover volumes com dados.

### Requirement 7: Consistência, idempotência e mensagens

**User Story:** Como operador, eu quero que a reversão seja idempotente e com mensagens claras, para poder executá-la com segurança mesmo após uma reversão parcial.

#### Acceptance Criteria

1. WHEN uma Rotina_Reversao é executada mais de uma vez, THE Rotina_Reversao SHALL ser idempotente, não falhando ao tentar remover artefatos já removidos.
2. THE Rotina_Reversao SHALL utilizar as funções de mensagem padronizadas (`msg_action`, `msg_skip`, `msg_error`) para comunicar progresso, etapas puladas e erros, de forma consistente com as rotinas de instalação.
3. WHEN a reversão é concluída, THE Rotina_Reversao SHALL exibir um resumo do que foi removido e do que foi preservado.
4. THE Rotina_Reversao SHALL carregar as variáveis do Arquivo_Env_Central (quando necessárias para localizar caminhos) seguindo o mesmo mecanismo das rotinas de instalação.

### Requirement 8: Documentação e testes

**User Story:** Como mantenedor, eu quero que a funcionalidade de reversão esteja documentada e coberta por testes, para garantir qualidade e facilitar o uso.

#### Acceptance Criteria

1. THE documentação (README.md e docs/TECHNICAL.md) SHALL descrever a funcionalidade de reversão, as opções de menu correspondentes, a política conservadora e o comportamento do Manifesto_Estado.
2. THE documentação de produção (docs/DEPLOYMENT.md) SHALL descrever as implicações de reverter funcionalidades em ambiente de produção, incluindo os avisos de Operacao_Destrutiva.
3. THE suíte de testes SHALL incluir testes para as funções de manifesto (registro e leitura) e para o comportamento conservador da reversão (preservar Artefato_Preexistente, exigir confirmação para Operacao_Destrutiva, idempotência).
4. WHERE operações exigem elevação ou afetam o sistema real, THE testes SHALL simular/mockar as operações de forma análoga aos testes existentes, sem executar remoções reais no sistema de teste.
