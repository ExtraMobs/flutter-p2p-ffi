# Campos que só diferem por caixa colidem no construtor

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

O construtor de uma struct gerada usa um parâmetro nomeado por campo. Campos
como `C` e `c` (o padrão do `time.Ticker` copiado por bibliotecas de relógio)
dão o mesmo nome de parâmetro, e o g2d recusa a struct inteira
(`g2d/behaviors/decls.py`, `construtor-ambiguo`).

## Prova

```go
package main

import "fmt"

type Ticker struct {
	C <-chan int
	c chan int
}

func main() {
	c := make(chan int, 1)
	t := Ticker{C: c, c: c}
	t.c <- 7
	fmt.Println(<-t.C)
}
```

```text
$ go run .
7
$ goast dump . -o dump.json && python -m g2d transpile dump.json -o out
ctor: não suportado [construtor-ambiguo]: parâmetro de construtor ambíguo para campo c em main.go:5:1
```

No grafo do kubo (`docs/audit.md`):

```text
| `construtor-ambiguo` | 13 | 7 | 4 | `github.com/cenkalti/backoff/v4` ticker.go:13:1: parâmetro de construtor ambíguo para campo c |
```

Na fronteira: `cenkalti/backoff` (v4 e v5), `benbjohnson/clock`,
`filecoin-project/go-clock`.

## Critério de pronto

- Parâmetros de construtor com nome único mesmo quando os campos só diferem
  por caixa (a mesma regra de `fold` que o goast já marca para nomes de
  pacote); fixture com o repro; e2e idêntico em VM × JS × Wasm.
