# Comparar interface com tipo dinâmico incomparável não dá panic

- **Prioridade:** P1 · **Área:** runtime
- **Depende de:** —

## Problema

O Go entra em panic ao comparar duas interfaces cujo tipo dinâmico é incomparável (slice, map,
func, struct com campo assim) e ao usar um valor assim como chave de map. O runtime do Dart devolve
`false` (ou aceita a chave) sem erro.

## Prova

```go
package main

import "fmt"

type S struct{ A []int }

func try(n string, f func()) {
	defer func() {
		if r := recover(); r != nil {
			fmt.Println(n, "panic:", r)
		}
	}()
	f()
	fmt.Println(n, "ok")
}

func main() {
	try("a", func() { var a, b interface{} = []int{1}, []int{1}; fmt.Println(a == b) })
	try("b", func() { var a, b interface{} = S{}, S{}; fmt.Println(a == b) })
	try("d", func() { m := map[interface{}]int{}; m[[]int{1}] = 1 })
}
```

```text
go run:   a panic: runtime error: comparing uncomparable type []int
          b panic: runtime error: comparing uncomparable type main.S
          d panic: runtime error: hash of unhashable type []int
dart run: false / a ok / false / b ok / d ok
```

Onde: `ifaceEq` em `golib_dart/lib/src/runtime/iface.dart` (o `goComparable` existe e não é usado)
e `GoMap` em `map.dart`.

## Critério de pronto

- `ifaceEq` e as chaves de `GoMap` entram em panic com as mensagens do Go.
- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
