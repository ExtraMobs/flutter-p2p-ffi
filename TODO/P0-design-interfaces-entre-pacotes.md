# Interface satisfeita por tipo de outro pacote

- **Prioridade:** P0 · **Área:** design
- **Depende de:** P0-infra-import-entre-pacotes

## Problema

O Go satisfaz interfaces estruturalmente; o g2d usa `implements` nominal calculado pelo goast só com as interfaces do próprio pacote, dos imports diretos e `error`. Um tipo de `a` passado como interface de `b` (que `a` não importa) não é atribuível no Dart. Idem para interface anônima usada em outro pacote.

## Prova

`a/a.go`

```go
package a

type T struct{ Name string }

func (t T) Hello() string { return "hi " + t.Name }
```

`b/b.go`

```go
package b

type Namer interface{ Hello() string }

func Greet(n Namer) string { return n.Hello() }
```

`cmd/main.go`

```go
package main

import (
	"fmt"

	"repro.local/mp/a"
	"repro.local/mp/b"
)

func main() {
	fmt.Println(b.Greet(a.T{Name: "t"}))
	var e interface{ Hello() string } = a.T{Name: "anon"}
	fmt.Println(e.Hello())
}
```

Com a sonda de import (plugin que qualifica os pacotes do módulo como `package:out/<path>.dart`), para expor a camada abaixo do import:

```text
$ dart analyze
error - repro.local/mp/cmd.dart:17:17 - The argument type 'T' can't be assigned to the parameter type 'Namer?'.
error - repro.local/mp/cmd.dart:20:24 - A value of type 'T' can't be assigned to a variable of type '_anonIface$11?'.
$ go run ./cmd
hi t
hi anon
```

## Critério de pronto

- Repro vira fixture multi-pacote em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.

## Notas

Caminho provável: `implements` calculado sobre o grafo inteiro (o Dart aceita imports cíclicos). A parte da interface anônima também depende de `P0-design-anonimas-canonicas`.
