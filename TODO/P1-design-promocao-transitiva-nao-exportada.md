# Método não exportado promovido através de dois pacotes (profundidade ≥ 2)

- **Prioridade:** P1 · **Área:** design
- **Depende de:** `TODO/P1-design-promocao-entre-pacotes` (resolvido: base de um salto)

## Problema

`mixin E$Promote` (o pacote que declara `E` sempre emite, `TODO/P1-design-promocao-entre-pacotes`)
só repassa um método não exportado quando é o próprio pacote de `E` quem o declara. Se `E` promoveu
esse método de um campo embutido seu de **outro** pacote (profundidade ≥ 2 através de dois saltos
de pacote), `E$Promote` não pode citar o nome (`_secret` escrito na library de `E` não é o mesmo
símbolo que `_secret` escrito na library de origem — ver a prova em `dart_priv_test` citada no
commit que resolveu o artefato-pai), então **não o repassa**. Quem embute `E` mais um nível continua
com `implements I` (a interface do dono original), mas sem implementação — e o Dart não recusa: a
checagem de `implements` não exige membro privado de outra library, então `dart analyze` fica limpo
e o programa só quebra em runtime, com saída diferente do Go (o Go não erra).

## Prova

`a/a.go`

```go
package a

type T struct{ Name string }

func (t T) secret() string { return "a:" + t.Name }

type I interface{ secret() string }

func Reveal(i I) string { return i.secret() }
```

`b/b.go`

```go
package b

import "repro.local/mp/a"

type W struct{ a.T }
```

`c/c.go`

```go
package c

import "repro.local/mp/b"
import "repro.local/mp/a"

type X struct{ b.W }

// RevealX força o goast a listar `a.I` no implements de X (import direto).
func RevealX(x X) string { return a.Reveal(x) }
```

`cmd/main.go`

```go
package main

import (
	"fmt"

	"repro.local/mp/c"
)

func main() {
	var x c.X
	fmt.Println(c.RevealX(x))
}
```

```text
$ go run ./cmd
a:
```

Dart gerado (`c.dart`, trecho): `X` tem `implements a.I` (goast resolveu por import direto de `c`),
mas nenhuma base dá `_secret`:

```dart
class X extends go.GoStruct<X> with b.W$Promote implements a.I {
  ...
}
```

(`b.W$Promote` não tem `_secret`: `W` promoveu de `a.T`, outro pacote — mesma regra do artefato-pai.)

```text
$ dart analyze --fatal-infos
No issues found!

$ dart run lib/repro.local/mp/cmd.dart
panic: NoSuchMethodError: Class 'X' has no instance method '_secret'.
Receiver: Instance of 'X'
Tried calling: _secret()
```

Divergência silenciosa (não é `dart analyze` sujo): o Go imprime `a:` sem erro.

## Critério de pronto

- Repro vira fixture multi-pacote em `tests/golden/`; e2e idêntico em VM × JS × Wasm;
  `dart analyze --fatal-infos` limpo (não só sem erro — o comportamento tem de bater com o Go).
- Caminho provável: quem embute `E` (aqui, `c.X` embutindo `b.W`) precisa, para cada método não
  exportado de `E$Promote` que `E` não pôde repassar, embutir também o mixin de quem de fato o
  declara (`a.T$Promote`), com um getter que encadeia pelo getter público que `E` já expõe
  (`a.T? get $T => $W?.$T;`, usando o `$W` que `b.W` já publica). Isso exige, em `promotion()`,
  resolver recursivamente — a partir do `index` do método no goast — a cadeia de campos embutidos
  até o pacote que de fato declara cada método não repassável, e gerar um `with` extra por
  ancestral necessário (não só pelo campo direto).
- `docs/mapping-spec.md` atualizado.

## Notas

`mixin` do Dart não aceita cláusula `with` (`A mixin can't have a with clause.`, verificado), então
`E$Promote` não pode encadear o mixin do dono de fato dentro de si mesmo — o encadeamento tem de
acontecer no `with` de quem embute, no critério de pronto acima.
