# `x.([]int)` aceita tipo nomeado de mesmo subjacente

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Type assertion e type switch para slice, map ou array sem nome usam `is go.Slice<...>`, que aceita
a subclasse gerada para um tipo nomeado (`type IntList []int`). O Go exige o tipo idêntico.

## Prova

```go
package main

import "fmt"

type IntList []int

func main() {
	var e interface{} = IntList{1}
	_, ok := e.([]int)
	fmt.Println(ok)
	switch e.(type) {
	case []int:
		fmt.Println("[]int")
	default:
		fmt.Println("other")
	}
	defer func() { fmt.Println("rec:", recover()) }()
	fmt.Println(e.([]int))
}
```

```text
go run:   false / other / rec: interface conversion: interface {} is main.IntList, not []int
dart run: true / []int / [1] / rec: <nil>          (VM e JS)
```

Idem para `map[string]int` × `type Set map[string]int` e `[2]int` × `type Arr [2]int`. Onde:
`assert_parts` em `g2d/services/assertions.py`.

## Critério de pronto

- Teste exato de tipo (descritor ou `$goType`) para os tipos sem nome.
- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
