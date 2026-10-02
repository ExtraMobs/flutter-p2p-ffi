# Ordem de avaliação em literais compostos e atribuição múltipla

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

O gc lê os operandos simples (`x`, `t.n`) **depois** de todas as chamadas da
mesma lista; a spec deixa isso em aberto, e o alvo é o `go run` de
referência. O `g2d/services/evalorder.py` já faz isso em argumentos de
chamada e em operandos de binário. Ainda leem da esquerda para a direita, e
dão saída diferente do Go em silêncio: elementos de literal de slice,
campos de literal de struct e o lado direito de atribuição múltipla.

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

## Critério de pronto

- `evalorder` aplicado também a literal de slice/array/struct e à
  atribuição múltipla, respeitando `&&`/`||` e sem duplicar efeitos.
- O repro vira fixture; e2e idêntico em VM × JS × Wasm.
- `docs/mapping-spec.md` documenta a regra (e o caso `a + await f()` da
  cor async).
