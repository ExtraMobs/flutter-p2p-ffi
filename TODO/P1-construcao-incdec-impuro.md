# `m[f()]++` chama `f()` duas vezes

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

`x++`/`x--` vira `x = x + 1` sem checar se o alvo tem efeito. O `op_assign` (`+=`) já recusa esse
caso com `opassign-impuro`; o `IncDecStmt` não.

## Prova

```go
package main

import "fmt"

var calls int

func key() string { calls++; return "k" }

func main() {
	m := map[string]int{}
	m[key()]++
	fmt.Println(m, calls)
}
```

```text
go run:   map[k:1] 1
dart run: map[k:1] 2      (gerado: m[_key()] = (m[_key()]) + Golang.Int(1);)
```

Onde: `IncDecStmt` em `g2d/behaviors/stmts.py`.

## Critério de pronto

- Alvo impuro avaliado uma vez (temporário), ou recusado como no `op_assign`; fixture com o repro.
