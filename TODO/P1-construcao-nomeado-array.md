# Tipo nomeado sobre array

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

`type Hash [32]byte` (com métodos) é recusado; comum em crypto/hash e protobuf.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `tipo-nomeado:array` | 35 | 27 | 8 | `google.golang.org/protobuf/internal/pragma` pragma.go:22:6: tipo nomeado sobre array |
```

## Critério de pronto

- Classe gerada sobre `go.GoArray` (como os nomeados sobre slice/map), semântica de valor (cópia,
  `==`); fixture e2e.
