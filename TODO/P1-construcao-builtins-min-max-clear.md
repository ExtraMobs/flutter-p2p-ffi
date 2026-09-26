# Builtins `min`, `max` e `clear` (Go 1.21)

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Não há `BuiltinBehavior` para `min`/`max` (ordenados: inteiros, floats com NaN/±0, strings) nem para
`clear` (map: remove tudo; slice: zera os elementos).

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `builtin:min` | 31 | 20 | 5 | `github.com/cockroachdb/pebble/v2/internal/bitflip` bitflip.go:10:18: builtin min |
| `builtin:max` | 11 | 11 | 0 | `github.com/cockroachdb/pebble/v2/internal/binfmt` binfmt.go:23:30: builtin max |
| `builtin:clear` | 11 | 9 | 3 | `github.com/quic-go/quic-go/internal/utils/ringbuffer` ringbuffer.go:55:2: builtin clear |
```

## Critério de pronto

- Um `BuiltinBehavior` por builtin; semântica de NaN e de `-0.0` como no Go (oráculo); fixture e2e.
