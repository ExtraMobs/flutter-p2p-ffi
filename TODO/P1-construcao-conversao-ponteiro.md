# Conversão entre ponteiros de mesmo subjacente (`(*uint64)(bs)`)

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

`(*U)(p)` com `*T` e `*U` de mesmo subjacente reinterpreta a **mesma** variável com outro tipo
(`*(*uint64)(bs) |= 1 << n` com `bs *int64s`). No g2d cada tipo é uma classe e o ponteiro para
escalar é um `go.Ptr` (Box/ElemPtr/FieldPtr ou `N$Ptr`): falta uma vista de ponteiro que converta na
leitura e na escrita (`Uint64.from(v)` / `int64s.from(u)`). Para structs (`(*B)(pa)`) o objeto é o
próprio endereço e as classes diferem: não há aliasing possível sem design. Recusado como
`conversao:pointer-pointer` / `conversao:pointer-named-pointer`; `(*[N]T)(s)` (slice → ponteiro para
array, Go 1.17) é `conversao:slice-pointer`.

## Prova

```go
package main

import "fmt"

type int64s uint64

func (bs *int64s) Set(n uint64) { *(*uint64)(bs) |= uint64(1) << n }

func main() {
	var bs int64s
	bs.Set(3)
	fmt.Println(bs)
}
```

```text
$ go run .
8

$ goast dump <dir> -o dump.json && python -m g2d transpile dump.json -o out
repro: não suportado [conversao:pointer-pointer]: conversão pointer → pointer em main.go:7:36
```

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| `conversao:pointer-pointer` | 135 | 24 | 3 | `google.golang.org/protobuf/internal/set` ints.go:20:3: conversão pointer → pointer |
| `conversao:pointer-named-pointer` | 8 | 2 | 2 | `go.opentelemetry.io/auto/sdk/internal/telemetry` value.go:84:8: conversão pointer → named-pointer |
| `conversao:slice-pointer` | 3 | 2 | 0 | `github.com/klauspost/compress/zstd` enc_dfast.go:1099:18: conversão slice → pointer |
```

## Critério de pronto

- Escalares: `go.ConvPtr<U, T>(p, read, write)` (vista que converte), `==` por endereço do alvo.
- `(*[N]T)(s)`: GoArray sobre o armazenamento do slice (offset) ou `Unsupported` explícito.
- Structs: decisão registrada no `mapping-spec` (provável `Unsupported`, substituição).
- Repro vira fixture; e2e VM × JS × Wasm.
