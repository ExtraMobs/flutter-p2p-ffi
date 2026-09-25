# Tipo não exportado nomeado por outra library

- **Prioridade:** P0 · **Área:** design
- **Depende de:** P0-infra-import-entre-pacotes

## Problema

Tipo não exportado vira `_T` (privado da library Dart). Outro pacote não pode nomeá-lo no Go, mas o recebe por inferência (`x := a.New()`), e o g2d declara locais com tipo explícito e descritores `go.Elem<T>`: o Dart gerado referencia `a._impl`, inacessível.

## Prova

`a/a.go`

```go
package a

type impl struct{ n int }

func (i *impl) Get() int { return i.n }

func New() *impl { return &impl{7} }
```

`cmd/main.go`

```go
package main

import (
	"fmt"

	"repro.local/mp/a"
)

func main() {
	x := a.New()
	fmt.Println(x.Get())
}
```

Com a sonda de import (plugin que qualifica os pacotes do módulo como `package:out/<path>.dart`), para expor a camada abaixo do import:

```text
$ dart analyze
error - repro.local/mp/cmd.dart:13:5 - Undefined class '_impl'.
error - repro.local/mp/cmd.dart:14:47 - The name '_impl' is being referenced through the prefix 'a',
        but it isn't defined in any of the libraries imported using that prefix.
$ go run ./cmd
7
```

## Critério de pronto

- Repro vira fixture multi-pacote em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.

## Notas

Nome Dart público para tipos não exportados (a privacidade já é garantida pelo compilador Go), sem colidir com os membros exportados em lowerCamel (`type foo` × `func Foo` → `foo`).
