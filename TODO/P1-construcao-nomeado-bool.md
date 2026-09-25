# Tipo nomeado sobre bool

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

`type Flag bool` (com métodos) é recusado; o g2d usa `bool` nativo, sem classe onde pendurar métodos e identidade de tipo.

## Prova

```go
package main

import "fmt"

type Flag bool

func (f Flag) String() string {
	if f {
		return "on"
	}
	return "off"
}

func main() {
	var f Flag = true
	fmt.Println(f, !f)
}
```

```text
$ goast dump <dir> > dump.json && python -m g2d transpile dump.json
não suportado: tipo nomeado sobre bool
```

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.

## Notas

Decidir entre classe intermediária (`Golang.Bool` já existe em fixed_types) e extension type; afeta type switch/assertion.
