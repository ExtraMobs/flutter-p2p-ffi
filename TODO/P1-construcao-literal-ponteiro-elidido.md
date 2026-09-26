# `&T` elidido em literal composto (`[]*P{{1, 2}}`)

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Em literais de slice/array/map cujo elemento é `*T`, o Go permite omitir `&T`; comum em tabelas.

## Prova

```go
package main

import "fmt"

type P struct{ X, Y int }

func main() {
	ps := []*P{{1, 2}, {3, 4}}
	fmt.Println(ps[1].Y)
}
```

```text
$ goast dump <dir> > dump.json && python -m g2d transpile dump.json
não suportado: literal composto de pointer
```

Medido no grafo do kubo:

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

| código | ocorrências | pacotes | na fronteira | exemplo |
| `literal-composto:pointer` | 12 | 9 | 2 | `golang.org/x/text/unicode/norm` forminfo.go:64:29: literal composto de pointer |
```

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.
