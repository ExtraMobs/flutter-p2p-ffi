# Genéricos que geram Dart inválido

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Três construções genéricas passam pelo g2d e falham no `dart analyze`:

- `*T` com `T` parâmetro de tipo, instanciado com struct: o genérico emite `go.Ptr<T>`, mas `&struct`
  é o próprio objeto (`g2d/services/types.py`);
- `/=` (e outros operadores compostos que viram método) sobre `T`: `op_assign` em
  `g2d/behaviors/stmts.py` não tem o caso `typeparam` → `$quo` que o `BinaryExpr` tem;
- `+` sobre `T cmp.Ordered` ou `T ~string`: `bound()` em `g2d/services/functions.py` testa
  `cats <= {"wint","float","string"}` antes de `{"string"}` (o ramo `StringBase` nunca roda) e
  `GoOrdered` não declara `+`.

## Prova

```go
package main

import (
	"cmp"
	"fmt"
)

type P struct{ X int }

func Swap[T any](a, b *T) { *a, *b = *b, *a }

func div[T int | float64](a, b T) T { a /= b; return a }

func add[T cmp.Ordered](a, b T) T { return a + b }

func main() {
	x, y := P{1}, P{2}
	Swap(&x, &y)
	fmt.Println(x, y, div(7, 2), add("a", "b"))
}
```

```text
go run: {2} {1} 3 ab
dart analyze:
  error - The argument type 'P' can't be assigned to the parameter type 'Ptr<P>?'
  error - The operator '/' isn't defined for the type 'T'
  error - The operator '+' isn't defined for the type 'T'
```

## Critério de pronto

- Os três casos emitem Dart válido e igual ao Go, ou viram `Unsupported`.
- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
