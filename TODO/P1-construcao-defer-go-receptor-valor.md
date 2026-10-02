# `defer x.M()` e `go x.M()` não copiam o receptor valor na hora

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

O Go avalia (e copia) o receptor de um método de receptor valor no momento do `defer`/`go`. O g2d
guarda só a referência (`final tmp = recv`), então o método vê as mudanças feitas depois. Com
`pp.Show()` (`pp` ponteiro, `Show` de receptor valor), o Go desreferencia e copia na hora.

## Prova

```go
package main

import "fmt"

type P struct{ X int }

func (p P) Show() { fmt.Println("show", p.X) }

func main() {
	p := P{1}
	defer p.Show()
	pp := &P{2}
	defer pp.Show()
	p.X = 50
	pp.X = 60
}
```

```text
go run:   show 2 / show 1
dart run: show 60 / show 50
```

Onde: `DeferStmt` em `g2d/behaviors/stmts.py` (`pre.append(f"final {tmp} = {self.expr(recv)};")`
sem cópia) e o mesmo padrão em `GoStmt`.

## Critério de pronto

- Receptor de método de receptor valor copiado (e desreferenciado, se for `*T`) no `defer`/`go`.
- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
