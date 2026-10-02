# Array nomeado com métodos não entra em interface

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

`type Arr [2]int` com métodos, convertido para interface, gera Dart inválido: a classe `Arr`
herda `$ifaceCopy()` de `GoValue<GoArray<T>>`, que devolve `GoArray`, e só sobrescreve `$copy`.

## Prova

```go
package main

import "fmt"

type Arr [2]int

func (a Arr) Sum() int { return a[0] + a[1] }

type Summer interface{ Sum() int }

func main() {
	var s Summer = Arr{1, 2}
	fmt.Println(s.Sum())
}
```

```text
go run: 3
dart analyze:
  error - A value of type 'GoArray<Int>' can't be assigned to a variable of type 'Summer?'
```

Onde: `named_array_class` em `g2d/behaviors/decls.py`, ou `$ifaceCopy` em
`golib_dart/lib/src/runtime/array.dart`.

## Critério de pronto

- `Arr` sobrescreve `$ifaceCopy` (ou a base devolve o tipo certo).
- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
