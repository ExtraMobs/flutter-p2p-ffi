# Método ou campo `*T` de tipo genérico instanciado com struct gera Dart inválido

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

A fronteira `*T` ↔ objeto (`go.valPtr`/`go.ptrTarget`, `g2d/services/genptr.py`) só é aplicada
em chamada de **função** genérica. Métodos e campos `*T` de um **tipo** genérico instanciado com
struct ou array (`Box[P].Set(&x)`, `b.Get().X`) passam direto: o dump não liga a instância
(`Box[P]`) à origem (`Box[T]`), então o g2d não sabe que o parâmetro é `*T`. Sai Dart inválido,
sem `Unsupported` (marcado ⚠️ em `docs/mapping-spec.md` e `ponytail:` em `genptr.py`).

## Prova

```go
package main

import "fmt"

type P struct{ X int }

type Box[T any] struct{ p *T }

func (b *Box[T]) Set(p *T) { b.p = p }

func (b *Box[T]) Get() *T { return b.p }

func main() {
	x := P{1}
	var b Box[P]
	b.Set(&x)
	b.Get().X = 5
	fmt.Println(x)
}
```

```text
$ go run .
{5}
$ goast dump . -o dump.json && python -m g2d transpile dump.json -o out && (cd out && dart analyze --fatal-infos)
  error - lib/repro.local/gbox.dart:87:11 - The argument type 'P' can't be assigned to the parameter type 'Ptr<P>?'.  - argument_type_not_assignable
  error - lib/repro.local/gbox.dart:88:14 - The setter 'x' isn't defined for the type 'Ptr<P>'. ... - undefined_setter
```

## Critério de pronto

- O goast liga método/campo de instância à declaração de origem (ou o g2d deduz), e a fronteira
  de `genptr.py` vale também para métodos e campos; o que não der vira `Unsupported`
  `generico:ptr-valor`.
- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
