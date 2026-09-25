# `copy([]byte, s)` com string

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Copiar os bytes de uma string para um `[]byte`.

## Prova

```go
package main

import "fmt"

func main() {
	b := make([]byte, 3)
	n := copy(b, "xyz!")
	fmt.Println(n, string(b))
}
```

```text
$ goast dump <dir> > dump.json && python -m g2d transpile dump.json
não suportado: copy([]byte, string)
```

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.
