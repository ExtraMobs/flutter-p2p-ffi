# `Elem.copyOf` copia o objeto apontado por `*T`

- **Prioridade:** P1 · **Área:** runtime
- **Depende de:** —

## Problema

`go.Elem.copyOf` (`golib_dart/lib/src/runtime/elem.dart`) faz `v is GoValue ? v.$copy() : v`, mas
ponteiro para struct/array é o próprio objeto no Dart. Então `append` que realoca, `copy()` e cópia
de array de `[]*T`, `[N]*T` ou `[]any` duplicam os objetos apontados (o ponteiro deixa de apontar
para o original). Além disso, o `$copy()` zera `$isValue`, e uma struct guardada por valor em
`[]any` passa a parecer `*T` numa type assertion. Saída errada em silêncio.

## Prova

```go
package main

import "fmt"

type P struct{ X int }

func main() {
	p := &P{1}
	s := []*P{p}
	s = append(s, &P{2})
	s[0].X = 5
	fmt.Println(p.X, s[0] == p)
	d := make([]*P, 1)
	copy(d, s)
	d[0].X = 6
	fmt.Println(p.X)
	arrp := [2]*P{{1}, {3}}
	arrp2 := arrp
	arrp2[0].X = 9
	fmt.Println(arrp[0].X)
	var xs []interface{}
	xs = append(xs, P{1})
	xs = append(xs, 2, 3)
	_, ok := xs[0].(P)
	_, ok2 := xs[0].(*P)
	fmt.Println(ok, ok2)
}
```

```text
go run:   5 true / 6 / 9 / true false
dart run: 1 false / 1 / 1 / false true
```

Chamadores: `slice.dart` (append, copy) e `array.dart` (cópia de array).

## Critério de pronto

- `copyOf` copia só valores (struct/array guardados por valor), nunca o alvo de um ponteiro, e
  preserva `$isValue` de uma struct guardada em interface.
- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
