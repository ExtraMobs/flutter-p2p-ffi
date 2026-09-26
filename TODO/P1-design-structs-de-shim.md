# Tipos struct declarados em shim (`strings.Builder`, `bytes.Buffer`, `bytes.Reader`...)

- **Prioridade:** P1 · **Área:** design
- **Depende de:** —

## Problema

Os shims só têm funções, constantes e interfaces. Tipos struct da stdlib usados **por valor** no código
gerado (`var b strings.Builder`, campo `buf bytes.Buffer`, `[]bytes.Reader`) precisam de uma classe no
shim que o g2d trate como struct de outro pacote: zero value `strings.Builder()`, semântica de valor
do `go.GoStruct` (`$copy`/`$set`/`==`), descritor `go.Elem` para slices/maps/arrays, métodos com
receptor ponteiro sobre a própria instância, nome Go em `$goType` (`strings.Builder`) para `%v`/`%T`,
e as checagens do Go (ex.: `strings: illegal use of non-zero Builder copied by value`). Falta decidir
como o g2d sabe que o tipo é de shim (o dump traz o subjacente com campos não exportados da stdlib,
que não devem ser emitidos nem acessados).

## Prova

```go
package main

import (
	"bytes"
	"fmt"
	"strings"
)

func main() {
	var b strings.Builder
	b.WriteString("a")
	var buf bytes.Buffer
	buf.WriteByte(98)
	fmt.Println(b.String(), buf.String())
}
```

```text
$ go run main.go
a b

$ goast dump <dir> -o dump.json && python -m g2d transpile dump.json -o out
main: não suportado [shim-simbolo:strings.Builder]: símbolo sem shim: strings.Builder em main.go:9:6
```

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| `shim-simbolo:bytes.Buffer` | 87 | 55 | 14 | `github.com/cockroachdb/pebble/v2/internal/binfmt` binfmt.go:32:1: símbolo sem shim: bytes.Buffer |
| `shim-simbolo:strings.Builder` | 81 | 32 | 12 | `github.com/ucarion/urlpath` urlpath.go:14:1: símbolo sem shim: strings.Builder |
| `shim-simbolo:bytes.Reader` | 50 | 23 | 6 | `github.com/quic-go/quic-go/quicvarint` io.go:14:5: símbolo sem shim: bytes.Reader |
```

## Critério de pronto

- Regra no `docs/mapping-spec.md`: tipo nomeado de pacote com shim → classe do shim (`extends
  go.GoStruct<T>`), sem olhar o subjacente do dump; o `TypeMapper`/`DescriptorRegistry` geram zero e
  `go.Elem` a partir dela.
- `strings.Builder` e `bytes.Buffer` com os métodos usados pelo grafo, oráculo Go; fixture e2e com
  valor, ponteiro, campo de struct e cópia.
- O mesmo caminho serve depois a `sync.Mutex`, `sync.Pool`, `atomic.Int64`, `time.Time` (M4/`time`).
