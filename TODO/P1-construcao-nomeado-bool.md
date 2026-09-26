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

Medido no grafo do kubo:

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

| código | ocorrências | pacotes | na fronteira | exemplo |
| `tipo-nomeado:bool` | 21 | 13 | 2 | `github.com/ipld/go-ipld-prime/fluent/qp` qp.go:120:1: tipo nomeado sobre bool |
| `conversao:bool-bool` | 8 | 5 | 0 | `github.com/ipld/go-ipld-prime/fluent/qp` qp.go:129:9: conversão bool → bool |
```

`conversao:bool-bool` é a conversão para o nomeado (`boolParam(b)` em go-ipld-prime/fluent/qp).

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.

## Notas

Decidir entre classe intermediária (`Golang.Bool` já existe em fixed_types) e extension type; afeta type switch/assertion.
