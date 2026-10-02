# `defer iface.M()` com `recover()` dentro de `M` não recupera

- **Prioridade:** P2 · **Área:** construcao
- **Depende de:** —

## Problema

`Calls.known_recoverer` (`g2d/services/calls.py`) só reconhece funções e métodos concretos. Para
método de interface o `decl` é o da interface, que não está em `facts.recoverers`, e o `DeferStmt`
cai no ramo sem o teste em runtime que o ramo de valor de função tem. O panic escapa.

## Prova

```go
package main

import "fmt"

type R interface{ Rec() }

type T struct{}

func (T) Rec() { fmt.Println("rec:", recover()) }

func a() {
	var r R = T{}
	defer r.Rec()
	panic("a")
}

func main() { a(); fmt.Println("fim") }
```

```text
go run:   rec: a / fim
dart run: rec: <nil> / panic: a (exit 2)
```

## Critério de pronto

- Método de interface adiado recebe o quadro de recover como o valor de função.
- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
