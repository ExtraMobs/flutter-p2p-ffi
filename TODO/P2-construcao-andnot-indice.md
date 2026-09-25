# `&^=` sobre expressão que não é identificador

- **Prioridade:** P2 · **Área:** construcao
- **Depende de:** —

## Problema

`s[i] &^= mask` / `x.f &^= mask` são recusados.

## Prova

```go
package main

import "fmt"

func main() {
	s := []uint8{0xff}
	s[0] &^= 0x0f
	fmt.Println(s[0])
}
```

```text
$ goast dump <dir> > dump.json && python -m g2d transpile dump.json
não suportado: &^= sobre expressão não-identificador
```

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.
