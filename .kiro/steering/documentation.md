---
inclusion: fileMatch
fileMatchPattern: "**/*.sh,lib/**,setup.sh,docker/**,deb/**,rpm/**,arch/**,macos/**,nginx/**,supervisor/**"
---

# Regra de Documentação

Sempre que qualquer arquivo de código (.sh, configuração, scripts) for criado ou modificado, DEVE-SE atualizar os seguintes documentos para refletir as mudanças:

1. **README.md** (raiz do projeto) — Atualizar instruções de uso, opções do menu, variáveis de ambiente, pré-requisitos e comandos úteis conforme a alteração realizada.

2. **docs/TECHNICAL.md** — Atualizar a documentação técnica detalhada com: algoritmos de scripts modificados, tabelas de pacotes, fluxos de execução, variáveis de ambiente e qualquer seção afetada pela mudança.

## O que atualizar em cada documento

### README.md
- Tabela de opções do menu (se novas opções foram adicionadas/removidas)
- Lista de pré-requisitos (se novas dependências foram introduzidas)
- Seção de variáveis de ambiente (se novas variáveis foram adicionadas ao .env)
- Instruções de uso e exemplos (se o fluxo de execução mudou)
- Plataformas suportadas (se suporte a nova plataforma foi adicionado)

### docs/TECHNICAL.md
- Seção do componente modificado (algoritmo passo a passo)
- Tabelas de pacotes por distribuição (se pacotes foram adicionados/removidos)
- Seção de variáveis de ambiente (se novas variáveis foram adicionadas)
- Diagramas de fluxo (se o fluxo de execução mudou)
- Seção de códigos de saída (se novos exit codes foram introduzidos)
- Seção de testes (se novos testes foram adicionados)

## Regra
- NÃO deixar a documentação desatualizada em relação ao código.
- Atualizar a documentação NA MESMA operação que modifica o código.
- Se uma alteração não afeta nenhuma seção dos documentos, não é necessário modificá-los.
