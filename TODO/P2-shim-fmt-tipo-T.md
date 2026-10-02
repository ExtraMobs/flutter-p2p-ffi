# `%T` falha para complex, erros de runtime e genéricos

- **Prioridade:** P2 · **Área:** shim
- **Depende de:** —

## Problema

`_typeName` (`golib_dart/lib/src/fmt/print.dart`) não sabe o nome de alguns tipos e o `$goType`
de instância genérica não leva os argumentos de tipo:

- `%T` de `complex128` e de um erro de runtime recuperado lança `UnimplementedError` em runtime
  (sem `Unsupported` na transpilação);
- `%T` de `Box[int]` imprime `main.Box` (`$goType` vem da declaração genérica em
  `g2d/behaviors/decls.py`).

## Prova

```go
package main

import "fmt"

type Box[T any] struct{ V T }

func main() {
	fmt.Printf("%T\n", Box[int]{})
	defer func() { r := recover(); fmt.Printf("%T\n", r) }()
	var a []int
	i := 5
	_ = a[i]
}
```

```text
go run:   main.Box[int] / runtime.boundsError
dart run: main.Box / UnimplementedError: fmt: nome do tipo de RuntimeError
```

E `fmt.Printf("%T\n", complex(1, 2))`: Go `complex128`, Dart `UnimplementedError: fmt: nome do
tipo de Complex128`.

## Critério de pronto

- Nomes do Go para complex e para os erros de runtime; `$goType` por instância.
- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
