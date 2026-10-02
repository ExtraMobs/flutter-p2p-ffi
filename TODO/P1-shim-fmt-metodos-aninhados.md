# `fmt` erra métodos `String()`/`Error()` em valores aninhados

- **Prioridade:** P1 · **Área:** shim
- **Depende de:** —

## Problema

O printer do shim `fmt` (`golib_dart/lib/src/fmt/value.dart` `_hasMethod`, `print.dart`) diverge
do Go ao decidir quando chamar `String()`/`Error()`:

- `*T` dentro de slice, map, struct ou interface é tratado como valor `T` (`nested || $isValue`),
  então método de receptor ponteiro não é chamado;
- o Go não chama métodos em campo **não exportado** (`CanInterface` falso); o shim chama;
- `String()` que entra em panic, chamado pelo `Println`, derruba o programa (o `Printf("%v")`
  captura certo);
- receptor nil que desreferencia dentro de `String()` vira crash: só `Panic` é capturado, não o
  `TypeError` do Dart.

## Prova

```go
package main

import "fmt"

type T struct{ n int }

func (t *T) String() string { return fmt.Sprint("T", t.n) }

type K int

func (k K) String() string { return "K!" }

type W struct {
	k K
	E K
}

type Q struct{ n int }

func (q *Q) String() string { return fmt.Sprint("Q", q.n) }

type B struct{}

func (b *B) String() string { panic("boom") }

func main() {
	fmt.Println([]*T{{1}, {2}})
	fmt.Println(W{1, 2})
	var q *Q
	fmt.Printf("%v\n", q)
	fmt.Println(&B{})
	fmt.Println("after")
}
```

```text
go run:
[T1 T2]
{1 K!}
<nil>
%!v(PANIC=String method: boom)
after
dart run: [{1} {2}] / {K! K!} / panic: runtime error: invalid memory address ... (exit 2)
```

Também com `error`: `fmt.Println([]error{&E{"a"}})` imprime `[{a}]` em vez de `[E:a]`.

## Critério de pronto

- Regras do `handleMethods`/`printValue` do Go: `*T` aninhado chama o método de `*T`; campo não
  exportado não chama método; panic e nil deref dentro do método viram `%!v(PANIC=...)`/`<nil>`.
- Oráculo Go em `golib_dart/test`; fixture e2e com o repro.
