# Embedding de tipo de outro pacote (métodos promovidos)

- **Prioridade:** P0 · **Área:** design
- **Depende de:** —

## Problema

Com o tipo embutido de outro pacote, o g2d gera forwarders inline na classe externa; o forwarder de método não exportado chama `_secret` de outra library (inacessível), e a classe não satisfaz a interface do pacote de origem que tem método não exportado.

## Prova

`a/a.go`

```go
package a

type T struct{ Name string }

func (t T) Hello() string  { return "hi " + t.Name }
func (t T) secret() string { return "s:" + t.Name }

type I interface{ secret() string }

func Reveal(i I) string { return i.secret() }
```

`b/b.go`

```go
package b

import "repro.local/mp/a"

type W struct {
	a.T
	Extra int
}
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
	w := b.W{T: a.T{Name: "w"}}
	fmt.Println(w.Hello(), a.Reveal(w))
}
```

Reverificado com o import entre pacotes real (`goast dump -C` → `g2d transpile` → `dart analyze` / `dart run`):

```text
$ dart analyze
error - repro.local/mp/b.dart:28:32 - The method '_secret' isn't defined for the type 'T'.
error - repro.local/mp/cmd.dart:17:51 - The argument type 'W' can't be assigned to the parameter type 'I?'.
$ go run ./cmd
hi w s:w
```

## Critério de pronto

- Repro vira fixture multi-pacote em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.

## Notas

Caminho provável: o pacote de origem sempre emite o mixin `T$Promote` (ele carrega os membros privados da própria library); a classe externa usa o mixin.
