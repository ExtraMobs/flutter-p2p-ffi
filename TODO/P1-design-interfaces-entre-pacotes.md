# Interface satisfeita por tipo de outro pacote

- **Prioridade:** P1 · **Área:** design (decisão D8 do `TODO/README.md`)
- **Depende de:** —

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

Reverificado com o import entre pacotes real (`goast dump -C` → `g2d transpile` → `dart analyze` / `dart run`):

```text
$ dart analyze
error - repro.local/mp/cmd.dart:17:17 - The argument type 'T' can't be assigned to the parameter type 'Namer?'.
error - repro.local/mp/cmd.dart:20:24 - A value of type 'T' can't be assigned to a variable of type '_anonIface$11?'.
$ go run ./cmd
hi t
hi anon
```

### Variante silenciosa: `fmt.Stringer`

Tipo com `String() string` num pacote que **não importa `fmt`**: o goast não lista `fmt.Stringer`
no `implements`, a classe não declara `implements fmt.Stringer` e o `fmt.Println` de outro pacote
formata os campos em vez de chamar `String()`. Não é Dart inválido: saída errada em silêncio.

```go
// tok/tok.go (sem import "fmt")
type Token struct{ Type byte; Str string }

func (t Token) String() string { return "<" + string(t.Type) + ">" }

// cmd/main.go
fmt.Println(tok.Token{Type: '{'})
```

```text
$ go run ./cmd                     →  <{>
$ dart run (g2d, VM/JS/Wasm)       →  {123 }
```

(Achado no fixture `tests/golden/dotimport`, cujo `tok` passou a importar `fmt` como o
`github.com/polydawn/refmt/tok` real.)

## Critério de pronto

- Repro vira fixture multi-pacote em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- Inclui a variante `fmt.Stringer` (e as demais interfaces de shim, como `sort.Interface`).
- `docs/mapping-spec.md` atualizado.

### Variante: tipo de shim em interface local

O sentido contrário também falha: classe de shim escrita à mão não declara as
interfaces locais ou anônimas que satisfaz (`err.(interface{ Unwrap() error })`,
`Timeout() bool`). Comum no kubo/libp2p. O `implements` sobre o grafo não
resolve, porque as classes de shim não são geradas.

```go
type timeouter interface{ Timeout() bool }

func main() {
	var err error = context.DeadlineExceeded
	_, ok := err.(timeouter)
	fmt.Println("assert:", ok)
	w := fmt.Errorf("x: %w", io.EOF)
	_, ok = w.(interface{ Unwrap() error })
	fmt.Println("unwrap:", ok)
}
```

```text
go run:   assert: true / unwrap: true
dart run: assert: false / unwrap: false
```

## Prioridade

Ainda invisível no `docs/audit.md`: os pacotes que expõem o problema param
antes num shim ausente. Volta a P0 quando o audit mostrar `dart-invalido` com
este padrão na fronteira. A variante `fmt.Stringer` é saída errada em
silêncio, e o audit nunca vai mostrá-la.

## Decisão pendente

1. **`implements` sobre o grafo, restrito (recomendado).** Só as interfaces
   para as quais o grafo de fato converte o tipo (atribuição, argumento,
   retorno, type assertion), e só com dono da interface fora da stdlib e
   visível para a library do tipo. Corrige as duas causas da tentativa
   abaixo. O Dart aceita imports cíclicos, então a library do tipo pode
   importar a da interface.
2. **Adaptador no ponto da conversão** (`b.Namer$Of(a.T)`). Não mexe nos
   imports, mas quebra a identidade: type assertion de volta para `a.T` e
   `==` de interface precisam desembrulhar.

A interface anônima com métodos continua uma classe por library (`$_anonIface$N`); as structs anônimas já são canônicas (`lib/_anon/<hash>.dart`, `g2d/services/anon.py`), e a interface anônima pode seguir o mesmo esquema quando a regra de interfaces entre pacotes existir.

## Tentativa anterior: `implements` sobre o grafo inteiro (branch `claude/wip-ifacecross`)

Integrada em 2026-10-02 sobre o main (cor async do M4 já mesclada), a wip passou nos
goldens e no e2e, mas o audit caiu de 126 para **88** verdes (44 perdidos, 6 ganhos):

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo
| `shim-ausente:archive/tar` | 1170 | 267 | 55 | `github.com/cockroachdb/pebble/v2/sstable/block/blockkind` kind.go:10:1: pacote sem shim/transpilação: archive/tar |
| `dart:uri_does_not_exist` | 30 | 14 | 14 | `github.com/pion/rtp/codecs/vp9` 10:8: error: Target of URI doesn't exist: 'package:out/github.com/gogo/protobuf/proto.dart'. |
| `shim-simbolo:bytes.AnonIface_819f61b7a0` | 159 | 43 | 9 | `go.uber.org/dig/internal/graph` graph.go:108:1: símbolo sem shim: bytes.AnonIface_819f61b7a0 |
```

Duas causas: o dono de uma interface anônima compartilhada (`findAnonOwner`) pode cair num
pacote da stdlib (`archive/tar`, `bufio`, `flag`, `bytes`...), que não é transpilado; e o
`implements` sobre o grafo inteiro faz uma library importar pacotes que não são dependência
Go dela (`github.com/kr/text` passa a importar `github.com/miekg/dns`), então ela só fica
verde se esse pacote não relacionado também for emitido. Falta restringir o `implements` às
conversões que acontecem de fato (ou a donos que a library já enxerga) antes de reintegrar.
