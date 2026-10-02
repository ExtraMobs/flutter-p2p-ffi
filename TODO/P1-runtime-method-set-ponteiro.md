# Valor `T` em interface satisfaz interface que exige método de `*T`

- **Prioridade:** P1 · **Área:** runtime
- **Depende de:** —

## Problema

O method set de `T` não inclui os métodos de receptor `*T`. No Dart a classe é a mesma para `T` e
`*T`, e a type assertion para interface (e o type switch) é só `x is I`. Assim `P{}` guardado em
`any` passa como `Incer` mesmo com `Inc` em `*P`, e `fmt` chama `String()`/`Error()` de receptor
ponteiro num valor.

## Prova

```go
package main

import "fmt"

type P struct{ X int }

func (p *P) Inc() {}

type Incer interface{ Inc() }

type A [1]int

func (a *A) String() string { return "A!" }

func main() {
	var x interface{} = P{}
	_, ok := x.(Incer)
	fmt.Println(ok)
	switch x.(type) {
	case Incer:
		fmt.Println("incer")
	default:
		fmt.Println("not")
	}
	fmt.Println(A{1})
}
```

```text
go run:   false / not / [1]
dart run: true / incer / A!
```

Onde: `tryIface`/`assertIface` (`iface.dart`), `type_test` modo `iface` em
`g2d/services/assertions.py` e `_hasMethod` em `golib_dart/lib/src/fmt/value.dart` (devolve
`true` para `GoArray`).

## Critério de pronto

- Teste de interface considera `$isValue` e o method set de valor (`$valueMethods`).
- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
