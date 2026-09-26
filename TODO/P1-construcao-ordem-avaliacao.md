# Ordem de avaliação entre operandos e chamadas (como o gc)

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

A spec do Go só fixa a ordem das chamadas (esquerda → direita); a leitura de um operando simples
(`x`, `t.n`) em relação às chamadas da mesma expressão fica em aberto. O gc lê esses operandos
**depois** de todas as chamadas (argumentos de chamada, literais compostos, atribuição múltipla).
O g2d avalia tudo da esquerda para a direita: saída diferente do `go run` em silêncio sempre que
uma chamada da expressão altera um operando lido antes dela.

## Prova

```go
package main

import "fmt"

type T struct{ n int }

func (t *T) inc() int { t.n++; return t.n }

var x int

func bump() int { x++; return x }

func main() {
	t := &T{}
	fmt.Println(t.n, t.inc())
	fmt.Println(x, bump())
	a := []int{x, bump()}
	fmt.Println(a)
}
```

```text
$ GOTOOLCHAIN=go1.26.5 go run main.go
1 1
1 1
[2 2]

$ goast dump <dir> -o dump.json && python -m g2d transpile dump.json -o out && dart run out/lib/main.dart
0 1
0 1
[1 2]
```

Também em atribuição múltipla: `calls, h, ok := t.calls, t.h, sort.IsSorted(t)` lê `t.calls`
depois de `IsSorted` no gc (achado no fixture `tests/golden/sorting`, que separa as leituras).

## Critério de pronto

- Quando uma lista de operandos (argumentos, elementos de literal composto, lado direito de
  atribuição múltipla, operandos de binário) tem chamada, o g2d avalia as chamadas primeiro, em
  ordem, para temporários, e só então lê os operandos simples, como o gc. Respeitar `&&`/`||`
  (curto-circuito) e não duplicar efeitos.
- O repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm.
- `docs/mapping-spec.md` documenta a regra.

## Notas

É comportamento do gc, não da spec; o gccgo pode diferir. O alvo é o `go run` de referência.
