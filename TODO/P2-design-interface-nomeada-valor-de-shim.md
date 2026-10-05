# Interface nomeada do pacote testada contra valor de classe de shim

- **Prioridade:** P2 · **Área:** design
- **Depende de:** —

## Problema

As classes dos shims são escritas à mão e não declaram as interfaces
nomeadas que os pacotes do grafo criam. A interface **anônima** de um método
com a assinatura de uma do runtime já funciona (vira `go.Timeouter`,
`go.Unwrapper`...; D8, `docs/mapping-spec.md` § "Interfaces entre pacotes
(D8)"), mas a nomeada é uma classe Dart própria do pacote, que o objeto do
shim não implementa: a type assertion dá `false`.

## Prova

```go
package main

import (
	"context"
	"fmt"
)

type timeouter interface{ Timeout() bool }

func main() {
	var err error = context.DeadlineExceeded
	_, ok := err.(timeouter)
	fmt.Println("assert:", ok)
}
```

```text
$ go run .
assert: true
$ goast dump . > nl.json && python -m g2d transpile nl.json -o out && dart run out/lib/nl.dart
assert: false
```

## Caminhos

1. A interface nomeada cujo method set é o de uma interface do runtime vira
   `typedef timeouter = go.Timeouter;` (o nome de uma interface não aparece
   em `%T` nem em `==`; a reflexão dela precisaria de cuidado), com o
   `implements` deduplicado.
2. Adaptador na type assertion quando o valor é de classe de shim.

## Prioridade

No cache de módulos do corpus, `interface{ Timeout() bool }`,
`Temporary() bool`, `Unwrap() error` e `Unwrap() []error` aparecem 38 vezes
como interface anônima (já resolvidas) e nenhuma como
`type X interface{ ... }` de uma linha. Sobe se o audit ou um repro do grafo
mostrar o padrão.
