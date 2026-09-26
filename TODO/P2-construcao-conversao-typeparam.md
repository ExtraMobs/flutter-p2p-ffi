# Conversão para parâmetro de tipo numérico (`N(float64(x) * f)`)

- **Prioridade:** P2 · **Área:** construcao
- **Depende de:** —

## Problema

`T(v)` com `T` parâmetro de tipo e `v` float (ou vice-versa) precisa de um construtor que só o
dicionário `$T` conhece: o `go.Elem` tem `ofInt` (inteiro → T), mas não `ofFloat` nem o caminho
T → float/inteiro para floats. Recusado como `conversao:float-typeparam`,
`conversao:typeparam-wint` etc.

## Prova

```go
package main

import "fmt"

type Number interface{ ~int64 | ~float64 }

func scale[N Number](x N, f float64) N { return N(float64(x) * f) }

func width[I ~int32 | ~int64](x I) int { return int(x) * 2 }

func main() { fmt.Println(scale(int64(3), 1.5), scale(2.0, 0.25), width(int32(4))) }
```

```text
$ go run .
4 0.5 8

$ goast dump <dir> -o dump.json && python -m g2d transpile dump.json -o out
repro: não suportado [conversao:float-typeparam]: conversão float → typeparam em main.go:7:49
```

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| `conversao:float-typeparam` | 1 | 1 | 0 | `go.opentelemetry.io/otel/sdk/metric/internal/aggregate` exemplar.go:40:22: conversão float → typeparam |
| `conversao:typeparam-wint` | 1 | 1 | 0 | `github.com/cockroachdb/pebble/v2/sstable/colblk` prefix_bytes.go:1030:39: conversão typeparam → wint |
```

## Critério de pronto

- `go.Elem` ganha `ofFloat` (e o g2d gera nos descritores numéricos); `float64(x)`/`int(x)` com x
  parâmetro de tipo via as bases (`GoReal`/`IntBase`); fixture com oráculo; `mapping-spec`.
