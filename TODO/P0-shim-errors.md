# Shim do pacote `errors`

- **Prioridade:** P0 · **Área:** shim
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

Medido no grafo do kubo:

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-ausente:errors` | 1516 | 305 | 54 | `github.com/hashicorp/golang-lru/simplelru` lru.go:26:6: pacote sem shim/transpilação: errors |
```

## Critério de pronto

- `errors.New`, `Is`, `As`, `Unwrap`, `Join` com oráculo Go; fixture e2e.

## Notas

Símbolos exatos a cobrir: linha `errors` de `docs/stdlib-coverage.md`.
