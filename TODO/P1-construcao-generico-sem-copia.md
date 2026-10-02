# Corpo genérico não copia valores do tipo `T`

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Dentro de função ou método genérico, atribuir ou devolver um valor de tipo `T` não copia, porque
`values.coerce` só copia quando `typesys.is_value(src)`, e para `typeparam` isso é falso. Instanciado
com struct ou array, o chamador recebe um alias do original.

## Prova

```go
package main

import "fmt"

type P struct{ X int }

func First[T any](xs []T) T { return xs[0] }

func Dup[T any](v T) (T, T) { c := v; return v, c }

func main() {
	s := []P{{1}}
	v := First(s)
	v.X = 5
	fmt.Println(s[0].X)
	a, b := Dup(P{1})
	a.X = 9
	fmt.Println(b.X)
}
```

```text
go run:   1 / 1
dart run: 5 / 9
```

O mesmo vale para método de struct genérica (`func (b Box[T]) Get() T { return b.V }`).

## Critério de pronto

- Atribuição, argumento e retorno de `T` não fresco copiam pelo descritor (`$T.copyOf`).
- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
