# P1 — reflect: chamar funções, assinaturas e tipos de shim

## Problema

O shim `reflect` (D1, `golib_dart/lib/reflect.dart`) lê os descritores que o
g2d gera, mas três partes ainda faltam:

1. **Chamar por reflexão**: `Value.Call`, `Value.Method`/`MethodByName`,
   `Method.Func` e `reflect.MakeFunc` não existem (viram `Unsupported`
   `shim-simbolo:reflect.Value.*`).
2. **Assinatura de func**: o descritor de um tipo func guarda só o texto Go
   (`rtFunc('func(int) string')`); `NumIn`/`In`/`NumOut`/`Out`/`IsVariadic`
   dão panic explícito.
3. **Tipos de shim**: `time.Time`, `big.Int` e os outros tipos escritos à mão
   em `golib_dart` não têm descritor; o reflect usa um descritor opaco e
   listar os campos dá panic explícito (o `encoding/json` cai nele ao
   escrever um `time.Time`). Também opacas: instâncias de genérico sobre
   básico, array ou interface (a fábrica `$rtOf` cobre struct, slice, map e
   func).

## Prova

```go
package main

import (
	"fmt"
	"reflect"
)

type G struct{}

func (G) Hi(n int) string { return fmt.Sprint("hi ", n) }

func main() {
	t := reflect.TypeOf(G{}).Method(0).Type
	fmt.Println(t.NumIn())
	fmt.Println(reflect.ValueOf(G{}).MethodByName("Hi").Call([]reflect.Value{reflect.ValueOf(3)})[0])
}
```

```
$ /tmp/goast dump . -o dump.json && python -m g2d transpile dump.json -o out
rp: não suportado [shim-simbolo:reflect.Value.call$]: membro sem shim: reflect.Value.call$ (Call) em main.go:19:14
```

Sem a linha do `Call` (`go run` imprime `2`):

```
$ dart run out/lib/rp.dart
panic: reflect: NumIn de func(main.G, int) string: assinatura sem descritor (g2d)
```

## Critério de pronto

- O descritor de func traz os tipos dos parâmetros e resultados, e
  `NumIn`/`In`/`NumOut`/`Out`/`IsVariadic` funcionam.
- `Value.Call`, `Method`/`MethodByName` e `Method.Func` chamam a closure
  (com a cor `async` do D2 levada em conta: um método que suspende só pode
  ser chamado de um contexto async).
- Os tipos de shim usados pelo `encoding/json` (`time.Time`, `big.Int`)
  ganham descritor escrito à mão (`SHIM_RTYPES` em `g2d/config.py`).
- Repro como fixture em `tests/golden/`, e2e idêntico em VM × JS × Wasm.

## Depende de

Nada. O D1 está decidido (2026-10-04).
