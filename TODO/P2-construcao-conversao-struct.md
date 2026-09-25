# Conversão entre structs de mesmo subjacente

- **Prioridade:** P2 · **Área:** construcao
- **Depende de:** —

## Problema

`B(a)` com `A` e `B` structs idênticas é recusada.

## Prova

```go
package main

import "fmt"

type A struct{ X int }
type B struct{ X int }

func main() {
	b := B(A{5})
	fmt.Println(b.X)
}
```

```text
$ goast dump <dir> > dump.json && python -m g2d transpile dump.json
não suportado: conversão de tipo não-básico
```

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.
