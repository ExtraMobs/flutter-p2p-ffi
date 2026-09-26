# Tipo genérico sobre map/slice (`type Set[T] map[T]struct{}`)

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Só structs genéricas são suportadas; tipos nomeados genéricos sobre map/slice/func (comuns em utilitários) são recusados.

## Prova

```go
package main

import "fmt"

type Set[T comparable] map[T]struct{}

func (s Set[T]) Add(v T) { s[v] = struct{}{} }

func main() {
	s := Set[string]{}
	s.Add("x")
	fmt.Println(len(s))
}
```

```text
$ goast dump <dir> > dump.json && python -m g2d transpile dump.json
não suportado: tipo genérico não-struct
```

```go
package main

import "fmt"

type List[T any] []T

func (l List[T]) Len() int { return len(l) }

func main() {
	fmt.Println(List[int]{1, 2}.Len())
}
```

```text
$ goast dump <dir> > dump.json && python -m g2d transpile dump.json
não suportado: tipo genérico não-struct
```

Medido no grafo do kubo:

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

| código | ocorrências | pacotes | na fronteira | exemplo |
| `generico-nao-struct` | 44 | 23 | 9 | `github.com/ipfs/go-libdht/kad` kad.go:16:6: tipo genérico não-struct |
```

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.
