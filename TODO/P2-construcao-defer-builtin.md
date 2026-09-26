# `defer` de builtin

- **Prioridade:** P2 · **Área:** construcao
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

Medido no grafo do kubo:

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

| código | ocorrências | pacotes | na fronteira | exemplo |
| `defer-builtin` | 1 | 1 | 0 | `golang.org/x/net/http2` transport.go:1781:2: defer de builtin |
```

Raro no grafo: 1 pacote.

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.

## Notas

`defer close(ch)` (o mais comum) também depende do M4 (`P0-design-m4-concorrencia`).
