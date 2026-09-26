# `range` sobre função (iteradores do Go 1.23)

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

`for x := range seq` com `func(yield func(T) bool)` é recusado.

## Prova

```go
package main

import "fmt"

func seq(n int) func(func(int) bool) {
	return func(yield func(int) bool) {
		for i := 0; i < n; i++ {
			if !yield(i) {
				return
			}
		}
	}
}

func main() {
	for i := range seq(3) {
		fmt.Println(i)
	}
}
```

```text
$ goast dump <dir> > dump.json && python -m g2d transpile dump.json
não suportado: range sobre func
```

Medido no grafo do kubo:

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

| código | ocorrências | pacotes | na fronteira | exemplo |
| `range:func` | 13 | 8 | 0 | `github.com/prometheus/procfs` mountinfo.go:150:2: range sobre func |
```

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.
