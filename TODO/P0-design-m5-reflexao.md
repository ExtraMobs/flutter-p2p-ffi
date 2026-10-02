# M5: reflexão estática (`reflect`)

- **Prioridade:** P0 · **Área:** design (decisão D1 do `TODO/README.md`)
- **Depende de:** — (dados em `docs/reflection-report.md`)

## Problema

Não há `reflect`. É o código que mais trava a fronteira, e `encoding/json`
(o 4º do ranking) depende dele. O caminho já fixado pelo `AGENTS.md` (regra
6) é descritor de tipo gerado pelo g2d, evolução de `go.Elem`, com
`dart:mirrors` proibido. O que falta decidir é o recorte e a ordem.

## Prova

```go
package main

import (
	"fmt"
	"reflect"
)

func main() {
	fmt.Println(reflect.TypeOf(3).Kind())
}
```

```text
$ goast dump <dir> -o dump.json && python -m g2d transpile dump.json -o out
não suportado: pacote sem shim/transpilação: reflect
```

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo
| `shim-ausente:reflect` | 925 | 126 | 21 | `github.com/cockroachdb/redact/internal/rfmt/fmtsort` sort.go:23:1: pacote sem shim/transpilação: reflect |
| `shim-ausente:encoding/json` | 212 | 62 | 12 | `github.com/ipfs/boxo/routing/http/internal/drjson` json.go:8:6: pacote sem shim/transpilação: encoding/json |
```

`docs/reflection-report.md`: 9666 usos em 134 pacotes. Os símbolos em mais
pacotes: `TypeOf` (87), `ValueOf` (61), `PkgPath` (58), `Elem` (52), `Kind`
(52), `Type` (50), `String` (43), `Interface` (41).

## Decisão pendente

1. **Shim `reflect` sobre descritores gerados, recorte por uso
   (recomendado).** O g2d emite um descritor por tipo usado em reflexão
   (kind, nome, pacote, campos com tags, métodos, elem/key); o shim
   implementa `Type`/`Value` sobre eles. Ordem: `TypeOf`/`Kind`/`Elem`/
   `Name`/`PkgPath`/`String`, depois `ValueOf`/`Interface`/`IsNil`/`Len`/
   `Index`/`Field`, depois o que `encoding/json` precisa. Escrita
   (`Set*`) e `MakeFunc`/`Call` por último.
2. **`encoding/json` gerado sem `reflect`** (codec por tipo gerado pelo g2d)
   e `reflect` depois. Destrava o JSON mais cedo, mas duplica trabalho: os
   demais 64 pacotes com `reflect` continuam esperando.

## Critério de pronto

- Recorte escolhido registrado em `docs/mapping-spec.md`; fixtures e2e por
  etapa; `docs/reflection-report.md` passa a mostrar o que está coberto.
- Quebrar em artefatos menores ao começar.
