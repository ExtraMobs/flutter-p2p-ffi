# Constante nomeada sem tipo usada em contexto tipado

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Constante de pacote sem tipo (`const IV0 = 0x6A09E667`) é declarada com o tipo padrão (`Golang.Int`)
e referenciada pelo nome; num contexto tipado (`[...]uint32{IV0}`, `x < breakpoint` com `x uint16`)
o Go a converte implicitamente, o Dart gerado não: Dart inválido em silêncio.

## Prova

```go
package main

import "fmt"

const (
	IV0 = 0x6A09E667
	IV1 = 0xBB67AE85
)

var IV = [...]uint32{IV0, IV1}

const breakpoint = 32768

func isNewer(v, p uint16) bool { return (v - p) < breakpoint }

func main() { fmt.Println(IV[1], isNewer(40000, 1)) }
```

```text
$ go run main.go
3144134277 false
$ python -m g2d transpile d.json -o out && dart analyze
  error - lib\main.dart:18:20 - The argument type 'Int' can't be assigned to the parameter type 'Uint16'. - argument_type_not_assignable
  error - lib\main.dart:39:38 - The element type 'Int' can't be assigned to the list type 'Uint32'. - list_element_type_not_assignable
```

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `dart:list_element_type_not_assignable` | 8 | 1 | 1 | `github.com/zeebo/blake3/internal/consts` 42:36: error: The element type 'Int' can't be assigned to the list type 'Uint32'. |
| `dart:argument_type_not_assignable` | 2 | 2 | 2 | `github.com/pion/interceptor/internal/sequencenumber` 74:50: error: The argument type 'Int' can't be assigned to the parameter type 'Uint16'.  |
```

## Critério de pronto

- Referência a constante sem tipo cujo `$type` difere do tipo padrão vira o literal no tipo do
  contexto (o `go/types` já dá o valor exato e o tipo); fixture e2e VM × JS × Wasm.
