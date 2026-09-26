# Tipo nomeado sobre inteiro sem sinal gera Dart inválido

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

`type Command uint32` herda de `Golang.UInt32Base`, mas a classe dos fixed_types é `Uint32Base`
(`decls.py`: `('' if b.signed else 'U') + f'Int{b.width}Base'`). Dart inválido em silêncio para todo
nomeado sobre `uint8`/`uint16`/`uint32`/`uint64`/`uint`; os demais erros (`extra_positional_arguments`,
`Object.from`, `override_on_non_overriding_member`) são cascata.

## Prova

```go
package main

import "fmt"

type Command uint32

func (c Command) Next() Command { return c + 1 }

func main() { fmt.Println(Command(7).Next()) }
```

```text
$ go run main.go
8
$ python -m g2d transpile d.json -o out && dart analyze
  error - lib\main.dart:10:29 - Classes can only extend other classes. - extends_non_class
  error - lib\main.dart:11:32 - Too many positional arguments: 0 expected, but 1 found. - extra_positional_arguments
  error - lib\main.dart:12:36 - The class 'Object' doesn't have a constructor named 'from'. - undefined_constructor_in_initializer
```

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `dart:extends_non_class` | 5 | 5 | 5 | `github.com/hanwen/go-fuse/v2/internal/ioctl` 16:29: error: Classes can only extend other classes. |
| `dart:override_on_non_overriding_member` | 15 | 5 | 5 | `github.com/hanwen/go-fuse/v2/internal/ioctl` 21:9: warning: The method doesn't override an inherited method. |
```

## Critério de pronto

- Nome da base certo para todas as larguras sem sinal; fixture com nomeados sobre `uint8`...`uint64`
  e `uint` (métodos, aritmética com wrap, `fmt`); e2e VM × JS × Wasm.
