# P1 — reflect: `Value.Call` de função que suspende num contexto síncrono

## Problema

`Value.Call`/`CallSlice` chamam a closure Dart por `Function.apply`. Num
contexto `async` o g2d emite `await v.call$async(...)` e a função que
suspende (cor `async`, D2) é esperada. Num contexto síncrono não há como
esperar: a cor não atravessa a reflexão (o g2d não sabe, na chamada, qual
função o `Value` guarda), e o shim dá panic explícito em vez de descartar o
`Future`.

No grafo do kubo isso pesa em `go.uber.org/dig` e `go.uber.org/fx`, que
chamam os construtores registrados por `reflect.Value.Call`: um construtor
que faz I/O que suspende só funciona se a cadeia até o `Call` for `async`.

Também ficam de fora deste item (limites documentados ⚠️ em
`docs/mapping-spec.md` § Reflexão):

- `NewAt`, `UnsafeAddr`, `UnsafePointer`, `SliceHeader`/`StringHeader.Data`:
  dependem do `unsafe` (D5).
- Métodos promovidos de tipo genérico não entram em `Method`/`MethodByName`.
- `StructOf`: sem métodos promovidos e não idêntico ao tipo do compilador.
- Tipos de shim sem descritor escrito à mão em `SHIM_RTYPES` continuam
  opacos.

## Prova

```go
package main

import (
	"fmt"
	"reflect"
	"time"
)

func slow() int { time.Sleep(time.Millisecond); return 7 }

type S struct{}

func (S) String() string {
	return fmt.Sprint(reflect.ValueOf(slow).Call(nil)[0].Int())
}

func main() { fmt.Println(S{}) }
```

```
$ go run .
7
$ goast dump . -o dump.json && python -m g2d transpile dump.json -o out
$ dart run out/lib/example.com/rc.dart
%!v(PANIC=String method: reflect: Call de função que suspende (cor `async`) num contexto síncrono)
```

(`String` é chamado pelo shim `fmt`, então fica síncrono.)

## Caminhos

1. **`Call` sempre suspende**: todo `Value.Call` vira `await call$async`,
   e o chamador ganha a cor `async`. Espalha `async` por todo pacote que
   chama por reflexão (dig/fx inteiros), inclusive onde nada suspende.
2. **Manter o panic** e tornar `async` só o que o grafo exigir, caso a caso.

Recomendação: caminho 1. O kubo monta o nó inteiro pelo `fx`, e com o
D3/D4 os construtores que abrem o repositório e a rede passam a suspender;
sem o caminho 1 o `fx.New` daria panic no primeiro deles.

Precisa da escolha do dono antes de andar (D9 em `TODO/README.md`).

## Depende de

Decisão do dono (caminho 1 ou 2).
