# Chave struct/array de map guardada por referência

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

`m[k] = v`, `m[k]++` e a leitura `m[k]` usam o objeto `k` como chave, sem copiar. Se `k` muda
depois, o hash da entrada muda e ela se perde. O literal `map[P]int{k: 1}` copia certo. A variável
de chave do `range` também aponta para o objeto guardado. Vale para chave struct, array e interface
com struct dentro (falta o `$ifaceCopy`).

## Prova

```go
package main

import "fmt"

type S struct{ a int }

func main() {
	m := map[S]int{}
	s := S{1}
	m[s] = 1
	s.a = 2
	m[s] = 2
	fmt.Println(len(m), m[S{1}], m[S{2}])
	for k := range m {
		k.a = 100
	}
	fmt.Println(m[S{1}], m[S{2}])
}
```

```text
go run:   2 1 2 / 1 2
dart run: 2 0 2 / 0 0       (VM e JS)
```

Onde: `g2d/services/operands.py` (`lvalue` de índice de map) e `IndexExpr` em
`g2d/behaviors/exprs.py` emitem `self.expr(index)` em vez de `values.coerce(index, keytype)`.

## Critério de pronto

- Chave de map passa por `coerce` (cópia de valor) em escrita, leitura e `range`.
- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
