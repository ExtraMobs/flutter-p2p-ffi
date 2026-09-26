# Instanciação explícita de genérico (`f[T]`, `f[K, V]`)

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

`f[int](x)` ou `New[K, V]()` aparece como `IndexExpr`/`IndexListExpr` sobre função: recusado
(`indice:func`, `expr:IndexListExpr`). O `$inst` do goast já traz os argumentos de tipo.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `indice:func` | 16 | 10 | 0 | `go.opentelemetry.io/otel/attribute` value.go:241:9: índice sobre func |
| `expr:IndexListExpr` | 6 | 4 | 0 | `github.com/libp2p/go-libp2p/p2p/http` libp2phttp.go:218:23: expressão IndexListExpr |
```

## Critério de pronto

- Instanciação explícita emitida como a implícita (argumentos do `$inst`); fixture e2e.
