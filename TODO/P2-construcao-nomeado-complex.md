# Tipo nomeado sobre complex

- **Prioridade:** P2 · **Área:** construcao
- **Depende de:** —

## Problema

`type Z complex128` é recusado.

## Prova

```go
package main

import "fmt"

type Z complex128

func main() {
	var z Z = 1 + 2i
	fmt.Println(z * z)
}
```

```text
$ goast dump <dir> > dump.json && python -m g2d transpile dump.json
não suportado: tipo nomeado sobre complex
```

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.
