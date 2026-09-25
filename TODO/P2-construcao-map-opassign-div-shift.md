# `/=`, `%=`, `<<=`, `>>=`, `&^=` sobre índice de map

- **Prioridade:** P2 · **Área:** construcao
- **Depende de:** —

## Problema

`+=`/`-=`/`++` em `m[k]` funcionam; os demais operadores compostos são recusados.

## Prova

```go
package main

import "fmt"

func main() {
	m := map[string]int{"a": 3}
	m["a"] <<= 2
	m["a"] /= 3
	fmt.Println(m["a"])
}
```

```text
$ goast dump <dir> > dump.json && python -m g2d transpile dump.json
não suportado: <<= sobre índice de map
```

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.
