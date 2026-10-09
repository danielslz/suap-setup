---
inclusion: auto
name: Fluxo de commit com atualização de documentação
description: Ativar SOMENTE quando o usuário pedir para gerar/fazer o commit do que foi feito. Define o fluxo de commit único (código e documentação juntos).
---

# Fluxo de commit com atualização de documentação

Esta regra se aplica **somente quando o usuário pedir explicitamente para gerar/fazer o commit** do que foi feito. Fora desse momento, NÃO atualize a documentação automaticamente a cada alteração de código. O usuário trabalha no código à vontade, sem edições de documentação não solicitadas.

## Fluxo de commit único

Quando o usuário pedir para commitar o trabalho realizado:

1. **Atualizar a documentação:** antes de commitar, verifique se as mudanças de código/configuração afetam a documentação e, se afetarem, atualize os documentos relevantes:
   - **README.md** — instruções de uso, opções do menu, variáveis de ambiente, pré-requisitos, comandos úteis, plataformas suportadas.
   - **docs/TECHNICAL.md** — algoritmo passo a passo dos scripts modificados, tabelas de pacotes por distribuição, fluxos de execução, variáveis de ambiente, códigos de saída, seção de testes.
   - **docs/DEPLOYMENT.md** — scripts/opções de provisionamento, variáveis de ambiente de produção, arquitetura de referência, procedimentos de atualização, checklist de go-live, configurações de banco/Nginx/Supervisor/mídia.

2. **Commit único:** faça um único commit contendo o código/configuração **e** as atualizações de documentação juntos. A documentação faz parte da mesma mudança e deve viajar no mesmo commit, mantendo a história consistente e os reverts limpos.

## Regras

- Documentação e código vão no **mesmo commit** (commit único).
- Se as alterações de código **não afetam** nenhuma seção dos documentos, apenas commite o código e informe que não houve mudança de documentação a fazer.
- Não atualize a documentação fora do fluxo de commit (nenhuma atualização automática a cada edição).
