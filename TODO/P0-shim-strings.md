# Shim do pacote `strings`

- **Prioridade:** P0 · **Área:** shim
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

Medido no grafo do kubo:

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-ausente:strings` | 570 | 204 | 45 | `github.com/anmitsu/go-shlex` shlex.go:74:6: pacote sem shim/transpilação: strings |
```

## Critério de pronto

- Símbolos usados pelo corpus (linha `strings` de `docs/stdlib-coverage.md`) com oráculo Go; fixture e2e.
