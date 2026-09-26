# M5: reflexão estática (`reflect`)

- **Prioridade:** P0 · **Área:** design
- **Depende de:** — (dados em `docs/reflection-report.md`)

## Problema

Sem `reflect`; o plano é descritores estáticos gerados (evolução de `go.Elem`), `dart:mirrors` proibido.

## Prova

```go
package main

import (
	"fmt"
	"reflect"
)

func main() {
	fmt.Println(reflect.TypeOf(3).Kind())
}
```

```text
$ goast dump <dir> > dump.json && python -m g2d transpile dump.json
não suportado: pacote sem shim/transpilação: reflect
```

Medido no grafo do kubo:

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-ausente:reflect` | 585 | 110 | 13 | `github.com/cockroachdb/redact/internal/rfmt/fmtsort` sort.go:23:1: pacote sem shim/transpilação: reflect |
```

Usos por símbolo e por pacote: `docs/reflection-report.md`.

## Critério de pronto

- Usos do corpus resolvidos segundo `docs/reflection-report.md`; fixtures e2e.

## Notas

Artefato guarda-chuva: quebrar pelos usos reais do relatório.
