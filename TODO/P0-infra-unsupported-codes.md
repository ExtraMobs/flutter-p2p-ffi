# `Unsupported` sem posição e sem código estável

- **Prioridade:** P0 · **Área:** infra
- **Depende de:** —

## Problema

Nenhum `Unsupported` sai com posição: `g2d/model.py` lê `node["pos"]`, campo que o goast nunca emite (as posições da AST vêm em `namePos`, `tokPos`, `lparen`, `lbrace`...). Sem posição não dá para localizar a ocorrência no código real; e a auditoria só tem o texto livre da mensagem para agrupar.

## Prova

Todas as mensagens reais coletadas neste backlog (nenhuma com `em arquivo:linha:coluna`):

```text
não suportado: append([]byte, string...)
não suportado: literal composto de pointer
não suportado: range sobre func
não suportado: tipo genérico não-struct
não suportado: pacote sem shim/transpilação: errors
```

Campos de posição presentes na AST do goast (dump do repro `append-string`):

```text
['closing', 'ellipsis', 'fileEnd', 'fileStart', 'func', 'lbrace', 'lbrack', 'lparen', 'namePos',
 'opening', 'package', 'rbrace', 'rparen', 'tokPos', 'valuePos']
```

## Critério de pronto

- `Unsupported(code, msg, node)` com código estável por caso e posição real (primeiro campo de posição do nó, ou do nó pai mais próximo); teste unitário garantindo posição.
