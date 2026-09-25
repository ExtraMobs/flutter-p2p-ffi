# Shim do pacote `errors`

- **Prioridade:** P1 · **Área:** shim
- **Depende de:** —

## Problema

Sem shim, qualquer pacote que importe `errors` não transpila (quase todo pacote real).

## Prova

```go
package main

import "errors"

import "fmt"

func main() {
	fmt.Println(errors.New("boom"))
}
```

```text
$ goast dump <dir> > dump.json && python -m g2d transpile dump.json
não suportado: pacote sem shim/transpilação: errors
```

## Critério de pronto

- `errors.New`, `Is`, `As`, `Unwrap`, `Join` com oráculo Go; fixture e2e.

## Notas

Símbolos exatos a cobrir virão de `P0-docs-stdlib-coverage`.
