# M5: reflexão estática (`reflect`)

- **Prioridade:** P1 · **Área:** design
- **Depende de:** P0-docs-reflection-report

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

## Critério de pronto

- Usos do corpus resolvidos segundo `docs/reflection-report.md`; fixtures e2e.

## Notas

Artefato guarda-chuva: quebrar pelos usos reais do relatório.
