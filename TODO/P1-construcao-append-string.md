# `append([]byte, s...)` com string

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Anexar os bytes de uma string a um `[]byte` é idiomático em código de protocolo.

## Prova

```go
package main

import "fmt"

func main() {
	b := []byte("ab")
	b = append(b, "cd"...)
	fmt.Println(string(b))
}
```

```text
$ goast dump <dir> > dump.json && python -m g2d transpile dump.json
não suportado: append([]byte, string...)
```

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.
