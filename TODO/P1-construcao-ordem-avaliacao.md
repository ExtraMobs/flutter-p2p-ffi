# Ordem de avaliação fora dos argumentos de chamada

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

O gc lê os operandos simples (`x`, `t.n`) **depois** de todas as chamadas da
mesma lista; a spec deixa isso em aberto, e o alvo é o `go run` de
referência. O `g2d/services/evalorder.py` só é chamado para argumentos de
chamada (`CallExpr`). Fora disso o g2d lê da esquerda para a direita e dá
saída diferente do Go em silêncio:

- elementos de literal de slice e campos de literal de struct;
- lado direito de atribuição múltipla;
- binário fora de argumento (`y := x + f()`, `return x + f()`) e o alvo de
  `x += f()`;
- índice e ponteiro do lado esquerdo: `arr[i] = f()` com `f` mudando `i`,
  `p.n = f()` com `f` mudando `p`, e `i, a[i] = 1, 9` (o Go fixa os
  operandos do lado esquerdo antes de atribuir).

## Prova

```go
package main

import "fmt"

var x int

func bump() int { x++; return x }

type P struct{ A, B int }

func main() {
	fmt.Println(x, bump())  // já certo
	a := []int{x, bump()}
	fmt.Println(a)
	p := P{x, bump()}
	fmt.Println(p)
	u, v := x, bump()
	fmt.Println(u, v)
}
```

```text
$ go run .            $ dart run (g2d)
1 1                   1 1
[2 2]                 [1 2]
{3 3}                 {2 3}
4 4                   3 4
```

(Literal de map bate com o Go: o gc lê na ordem ali.)

```go
var x, i int
var arr = []int{10, 20, 30}

func bump() int  { x += 10; return 1 }
func bumpI() int { i++; return 5 }

func main() {
	x = 1
	y := x + bump()
	fmt.Println(y) // go 12, dart 2
	x = 1
	x += bump()
	fmt.Println(x) // go 12, dart 2
	arr[i] = bumpI()
	fmt.Println(arr) // go [10 5 30], dart [5 20 30]
	j := 0
	a := []int{0, 0}
	j, a[j] = 1, 9
	fmt.Println(j, a) // go 1 [9 0], dart 1 [0 9]
}
```

## Critério de pronto

- `evalorder` aplicado a todos os casos acima, respeitando `&&`/`||` e sem
  duplicar efeitos; lado esquerdo com índice e ponteiro fixados antes da
  atribuição.
- O repro vira fixture; e2e idêntico em VM × JS × Wasm.
- `docs/mapping-spec.md` documenta a regra (e o caso `a + await f()` da
  cor async).
