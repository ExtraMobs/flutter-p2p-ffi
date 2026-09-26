# Type switch/assertion sobre tipos func usa a subtipagem do Dart

- **Prioridade:** P2 · **Área:** runtime
- **Depende de:** —

## Problema

`x.(F)` e `case F:` com F um tipo func sem nome viram `go.isType<F>` (`x is F`), mas o Go exige o
tipo idêntico e o Dart testa subtipo: o retorno `void` é um tipo topo (`func() error` passa por
`case func():`) e os parâmetros são contravariantes (`func(any)` passa por `case func(int):`).
Em silêncio, o switch cai no case errado.

## Prova

```go
package main

import "fmt"

func kind(x any) string {
	switch x.(type) {
	case func():
		return "func()"
	case func() error:
		return "func() error"
	case func(int):
		return "func(int)"
	}
	return "outro"
}

func main() {
	fmt.Println(kind(func() error { return nil }), kind(func() {}), kind(func(any) {}))
}
```

```text
$ go run .
func() error func() outro

$ goast dump <dir> -o dump.json && python -m g2d transpile dump.json -o out && dart run out/lib/repro.dart
func() func() func(int)
```

No grafo: `go.uber.org/fx/internal/lifecycle` (`Wrap[T Callable]`, `switch fn := any(x).(type)`
com `case Func` / `case ErrorFunc` / `case ContextFunc`...), hoje bloqueado antes por `reflect`.

## Critério de pronto

- Teste de tipo exato para func: por exemplo um descritor do tipo func gerado pelo g2d (aridade,
  tipos dos parâmetros e dos resultados) comparado com o da closure, ou `Unsupported` explícito
  quando dois cases func do mesmo switch se sobrepõem na subtipagem do Dart.
- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm.
- `docs/mapping-spec.md` atualizado.
