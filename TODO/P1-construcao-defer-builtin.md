# `defer` de builtin

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

`defer delete(m, k)`, `defer panic(v)`, `defer close(ch)` são recusados.

## Prova

```go
package main

import "fmt"

func main() {
	m := map[string]int{"a": 1}
	func() {
		defer delete(m, "a")
	}()
	fmt.Println(len(m))
}
```

```text
$ goast dump <dir> > dump.json && python -m g2d transpile dump.json
não suportado: defer de builtin
```

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.

## Notas

`defer close(ch)` (o mais comum) também depende do M4 (`P1-design-m4-concorrencia`).
