# Constante declarada dentro de função

- **Prioridade:** P0 · **Área:** construcao
- **Depende de:** —

## Problema

`const` local (`func f() { const n = 10; ... }`) é recusada ao ser referenciada: o identificador
`const` só é tratado em nível de pacote.

## Prova

```go
package main

import "fmt"

func main() {
	const upper = 10
	fmt.Println(upper * 2)
	x := 3
	fmt.Println(x < upper)
}
```

```text
$ go run main.go
20
true
$ goast dump <dir> -o d.json && python -m g2d transpile d.json -o out
main: não suportado [ident:const]: identificador const upper em main.go:9:18
```

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `ident:const` | 106 | 58 | 21 | `gonum.org/v1/gonum/mathext` ell_carlson.go:40:5: identificador const upper |
```

## Critério de pronto

- Constante local vira o literal exato do `go/types` (como a de pacote) ou `const` Dart local;
  fixture e2e VM × JS × Wasm.
