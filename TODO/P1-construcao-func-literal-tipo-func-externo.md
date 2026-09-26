# Func literal atribuída a tipo func nomeado de outro pacote

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

No `github.com/ipfs/kubo/core/commands` (o pacote dos comandos do kubo), `cmds.Command{Run: func(...)
error {...}}` derruba o g2d: `TypeMapper.func_type` recebe o nomeado `cmds.Function` (agora
"nomeado composto" por ser de pacote transpilado) em vez da assinatura, e lê `results` dele.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `erro-interno:KeyError` | 3 | 1 | 0 | `github.com/ipfs/kubo/core/commands` update.go:103:5: services/types.py:105: 'results' |
```

```text
não suportado [erro-interno:KeyError]: services/types.py:105: 'results' em update.go:103:5
não suportado [erro-interno:KeyError]: services/types.py:105: 'results' em update.go:171:5
não suportado [erro-interno:KeyError]: services/types.py:105: 'results' em update.go:235:5
```

## Critério de pronto

- Repro multi-pacote mínimo (tipo func nomeado em `a`, literal em campo de struct de `a` usado em
  `cmd`) como fixture; e2e VM × JS × Wasm.
