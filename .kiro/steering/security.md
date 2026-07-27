---
inclusion: auto
---

# Regra de Segurança — Credenciais e URLs

NUNCA expor credenciais reais, URLs/IPs de ambientes reais ou informações sensíveis em documentação, exemplos ou código commitado.

## O que é proibido em documentação e exemplos

- URLs reais de servidores (ex: `suap.ifma.edu.br`, `gitlab.ifma.edu.br`)
- Endereços IP de ambientes reais (ex: `192.168.10.60`)
- Senhas, tokens, chaves de API reais
- Nomes de usuários de banco de dados reais
- URLs de Sentry, Vault, ou outros serviços internos reais
- Nomes de domínio internos da organização

## O que usar no lugar (valores fictícios)

| Tipo | Valor fictício |
|------|---------------|
| URL do repositório | `https://gitlab.exemplo.com/org/suap.git` |
| URL SSH do repositório | `git@gitlab.exemplo.com:org/suap.git` |
| Domínio do SUAP | `suap.instituicao.edu.br` |
| IP de banco de dados | `192.168.1.100` ou `db.exemplo.local` |
| Senha de banco | `senha_segura_aqui` |
| Usuário de banco | `suap_user` |
| URL do Sentry | `https://sentry.exemplo.com/4` |
| Chave secreta Django | `gere-uma-chave-em-djecrety.ir` |
| Token de API | `seu-token-aqui` |
| URL do registry Docker | `registry.exemplo.com:5000/org/suap` |
| Email institucional | `admin@instituicao.edu.br` |
| URL do Vault | `https://vault.exemplo.local` |

## Onde a regra se aplica

- `README.md`
- `docs/TECHNICAL.md`
- `docker/README.md`
- Qualquer arquivo `.md` no repositório
- Exemplos em arquivos `.sample` (ex: `env.prod.sample`)
- Comentários em código que contenham URLs de exemplo
- Specs (`.kiro/specs/`)

## Onde a regra NÃO se aplica

- `.env` local do desenvolvedor (gitignored)
- Arquivos em `.gitignore` que não são commitados

## Ação ao encontrar credencial real

Se ao editar documentação ou código você encontrar uma credencial real, URL interna ou IP de produção, substitua imediatamente pelo valor fictício equivalente da tabela acima.
