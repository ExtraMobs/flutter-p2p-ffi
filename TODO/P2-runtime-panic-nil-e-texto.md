# `panic(nil)` e o texto do panic não recuperado

- **Prioridade:** P2 · **Área:** runtime
- **Depende de:** —

## Problema

Desde o Go 1.21, `panic(nil)` vira `*runtime.PanicNilError` ("panic called with nil argument"); o
g2d emite `throw go.Panic(null)` e o `recover()` devolve nil. O texto do panic não recuperado
(`describePanic` em `golib_dart/lib/src/runtime/panic.dart`) também difere do Go para vários
valores; esse só aparece no stderr (o e2e compara só o stdout).

## Prova

```go
package main

import "fmt"

func main() {
	defer func() { r := recover(); fmt.Println(r == nil, r) }()
	panic(nil)
}
```

```text
go run:   false panic called with nil argument
dart run: true <nil>
```

Texto no stderr (`panic(v)` sem recover):

| `v` | go | dart |
|---|---|---|
| `V{}` com `String()` | `panic: stringer` | `panic: Instance of 'V'` |
| `N(42)` (nomeado) | `panic: main.N(42)` | `panic: 42` |
| `1.5` | `panic: +1.500000e+000` | `panic: 1.5` |
| `"a\nb"` | segunda linha com `\t` | sem indentação |
| panic dentro de defer | `panic: first [recovered]` + `panic: second` | só o último |

## Critério de pronto

- `panic(nil)` como no Go ≥ 1.21; `describePanic` com o `printpanicval` do Go.
- Teste de
  subprocesso no golib_dart comparando o stderr com `go run`.
