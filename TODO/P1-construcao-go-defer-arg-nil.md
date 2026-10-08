# `go f(nil)` / `defer f(nil)`: argumento `nil` fixado com o tipo "untyped nil"

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

`go` e `defer` avaliam os argumentos na hora e os fixam em temporários
(`GoStmt.emit`, `g2d/behaviors/stmts.py:663`; `DeferStmt.emit`, `:592`):

```python
pre.append(f"final {tmp} = {self.values.coerce(a, self.pkg.type_of(a))};")
```

O destino da coerção é o tipo do **próprio argumento**, não o do parâmetro.
Para `nil` esse tipo é o basic "untyped nil", e `zero` cai em
`raise Unsupported("zero-value:basic")` (`g2d/services/types.py:191`). Só os
argumentos com `$value` (constantes) escapam do temporário; `nil` não tem
`$value`. Vale para parâmetro slice, map, ponteiro, func, interface e para o
variádico (`go fmt.Println(x, nil)` dá o mesmo erro). A posição do
`Unsupported` é a da declaração (`main.go:7:6`), não a do `nil`.

## Prova

```go
package main

import "fmt"

func f(p []byte, done chan bool) { fmt.Println(p == nil); done <- true }

func main() {
	done := make(chan bool)
	go f(nil, done)
	<-done
}
```

```text
$ go run main.go
true
$ (cd tools/goast && go run . dump <dir> -o <dir>/d.json)
$ python -m g2d transpile <dir>/d.json -o <dir>/out
main: não suportado [zero-value:basic]: zero value de basic em main.go:7:6
```

`defer` tem o mesmo defeito:

```go
package main

import "fmt"

func f(p []byte) { fmt.Println(p == nil) }

func main() {
	defer f(nil)
}
```

```text
$ go run main.go
true
$ python -m g2d transpile d.json -o out
main: não suportado [zero-value:basic]: zero value de basic em main.go:7:6
```

## No corpus

Grep de uma linha (`^\s*(go|defer) <chamada>(...)` com `nil` como argumento
de nível superior) nos 1108 diretórios não-stdlib de
`go list -deps github.com/ipfs/kubo/cmd/ipfs` (sem `_test.go`) em
`tests/corpus/kubo`: **3 `go`, 0 `defer`** (chamadas em várias linhas não
contadas):

```text
github.com/minio/minlz@v1.0.1-0.20250507153514-87eb42fe8882/reader.go:664: go writeBuf(nil, seed)
github.com/cockroachdb/pebble/v2@v2.1.7/compaction.go:2242: go d.compact(c, nil)
golang.org/x/net@v0.59.0/http2/server.go:1188: go sc.writeFrameAsync(wr, nil)
```

## Critério de pronto

- `go`/`defer` fixam cada argumento com o tipo do parâmetro correspondente
  (elemento do variádico quando for o caso), como a chamada normal faz.
- Os dois repros acima viram fixture golden (e2e idêntico ao `go run`).
