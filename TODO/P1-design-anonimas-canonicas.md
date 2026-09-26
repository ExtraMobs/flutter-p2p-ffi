# Structs/interfaces anônimas idênticas entre pacotes

- **Prioridade:** P1 · **Área:** design
- **Depende de:** —

## Problema

No Go, `struct{ X int }` é o mesmo tipo em qualquer pacote; o g2d gera uma classe `_anon$N` por library (índice da typeTable local), então valores de pacotes diferentes não se atribuem, não se comparam e falham em type assertion. O goast também não informa o pacote de campos/métodos não exportados, que entram na identidade do tipo.

## Prova

`a/a.go`

```go
package a

func Pair() struct{ X int } { return struct{ X int }{3} }
```

`b/b.go`

```go
package b

func Pair() struct{ X int } { return struct{ X int }{4} }
```

`cmd/main.go`

```go
package main

import (
	"fmt"

	"repro.local/mp/a"
	"repro.local/mp/b"
)

func main() {
	p, q := a.Pair(), b.Pair()
	p = q
	var v any = a.Pair()
	_, ok := v.(struct{ X int })
	fmt.Println(p.X, ok)
}
```

Reverificado com o import entre pacotes real (`goast dump -C` → `g2d transpile` → `dart analyze` / `dart run`):

```text
$ dart analyze
error - repro.local/mp/cmd.dart:16:12 - The argument type '_anon$1 (where _anon$1 is defined in .../b.dart)'
        can't be assigned to the parameter type '_anon$1 (where _anon$1 is defined in .../a.dart)'.
$ go run ./cmd
4 true
```

## Critério de pronto

- Repro vira fixture multi-pacote em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.

## Notas

Classe canônica (nome derivado da estrutura) numa library compartilhada; a com campo não exportado fica na library do pacote dono, com nome público.

## Nota de prioridade

Ainda invisível no `docs/audit.md`: os pacotes que expõem o problema param antes num shim
ausente. Volta a P0 quando o audit mostrar `dart-invalido` com este padrão na fronteira.
