# Shim do pacote `strings`

- **Prioridade:** P1 · **Área:** shim
- **Depende de:** —

## Problema

Sem shim, pacotes que importam `strings` não transpilam.

## Prova

```go
package main

import "strings"

import "fmt"

func main() {
	fmt.Println(strings.Contains("abc", "b"))
}
```

```text
$ goast dump <dir> > dump.json && python -m g2d transpile dump.json
não suportado: pacote sem shim/transpilação: strings
```

## Critério de pronto

- Símbolos usados pelo corpus (ver `P0-docs-stdlib-coverage`) com oráculo Go; fixture e2e.
