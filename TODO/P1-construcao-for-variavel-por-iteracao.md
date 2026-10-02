# `for` de três cláusulas compartilha a variável entre iterações

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Desde o Go 1.22 cada iteração de `for i := ...; ...; ...` tem a sua variável. O g2d declara o init
no `for(...)` do Dart, que copia por iteração só a referência: quando a variável mora numa caixa
(`go.Box`, por ter o endereço tomado) ou é struct/array, todas as iterações compartilham o mesmo
objeto. O `range` está certo (declara dentro do corpo).

## Prova

```go
package main

import "fmt"

type P struct{ X int }

func main() {
	var ps []*int
	for i := 0; i < 3; i++ {
		ps = append(ps, &i)
	}
	for _, p := range ps {
		fmt.Print(*p, " ")
	}
	fmt.Println()
	var fs []func()
	for p := (P{0}); p.X < 3; p.X++ {
		fs = append(fs, func() { fmt.Print(p.X, " ") })
	}
	for _, f := range fs {
		f()
	}
	fmt.Println()
}
```

```text
go run:   0 1 2 / 0 1 2
dart run: 3 3 3 / 3 3 3
```

Onde: `ForStmt.emit` em `g2d/behaviors/stmts.py`.

## Critério de pronto

- Cópia nova da variável no início de cada iteração (como o Go especifica: cópia antes do post).
- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
