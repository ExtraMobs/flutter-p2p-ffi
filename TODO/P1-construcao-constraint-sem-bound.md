# Constraint sem bound Dart comum (união mista, ponteiro no core, união de funcs)

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Constraints com core type (`S ~[]E`), uniões de uma categoria (`IntBase`, `GoReal`, `GoOrdered`,
`StringBase`), interfaces aninhadas (`constraints.Integer`) e interfaces com métodos já têm bound.
Sobram três formas sem um tipo Dart comum para o bound:

- `constraint:mista`: `bool | int64 | float64 | string`, `[]byte | string`, `[3]int | [4]int`;
- `constraint:ponteiro`: `interface{ *P; Message }` (o parâmetro é ponteiro para o outro);
- `constraint:func`: `~Func | ~ErrorFunc | ...` (união de tipos func).

## Prova

```go
package main

import "fmt"

type sliceElem interface{ bool | int64 | float64 | string }

func first[T sliceElem](v []T) any { return v[0] }

func main() { fmt.Println(first([]string{"a"}), first([]bool{true})) }
```

```text
$ go run .
a true

$ goast dump <dir> -o dump.json && python -m g2d transpile dump.json -o out
repro: não suportado [constraint:mista]: constraint sem bound Dart comum (mista) em main.go:7:6
```

Nos dumps do grafo do kubo (`.g2d-cache`, `emit_collect` por pacote):

```text
go.opentelemetry.io/otel/attribute/internal  constraint:mista    attribute.go:21:6 (bool | int64 | float64 | string)
go.uber.org/zap/zapcore                      constraint:mista    json_encoder.go:509:6 ([]byte | string)
github.com/rivo/uniseg                       constraint:mista    properties.go:137:6 ([3]int | [4]int)
google.golang.org/protobuf/proto             constraint:ponteiro wrapperopaque.go:63:6 (interface{ *P; Message })
go.uber.org/zap                              constraint:ponteiro array.go:174:6 (ObjectMarshalerPtr[T])
github.com/quic-go/webtransport-go           constraint:ponteiro streams_map_incoming.go:57:1
go.uber.org/fx/internal/lifecycle            constraint:func     lifecycle.go:72:6 (~Func | ~ErrorFunc | ...)
```

## Critério de pronto

- Mista: sem bound (`Object`) quando o corpo só move valores (atribuição, `any(x)`, `==`, índice de
  slice/map de T), e `Unsupported` explícito se o corpo usar operador ou método; `[3]int | [4]int`
  pode usar `go.GoArray<Int>` (mesmo elemento).
- Ponteiro: `P interface{ *T; M }` → P é `T?` (struct) com os métodos de `M`; instanciação passa o
  dicionário de T.
- Func: bound `Function` com chamada por `Function.apply` ou uma classe comum aos func nomeados.
- Fixture com os três casos; `docs/mapping-spec.md`.
