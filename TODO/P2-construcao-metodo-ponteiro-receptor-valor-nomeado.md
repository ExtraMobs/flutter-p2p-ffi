# Método de receptor ponteiro chamado no receptor valor (tipo nomeado não-struct)

- **Prioridade:** P2 · **Área:** construcao
- **Depende de:** —

## Problema

Dentro de um método de valor de `type Counter int`, `c.inc()` (receptor `*Counter`) gera Dart inválido em silêncio. O `mapping-spec.md` diz que é `Unsupported`; na prática não é. Com struct o caso funciona (verificado).

## Prova

```go
package main

import "fmt"

type Counter int

func (c *Counter) inc() { *c++ }

func (c Counter) Twice() Counter {
	c.inc()
	c.inc()
	return c
}

func main() {
	fmt.Println(Counter(1).Twice())
}
```

```text
$ dart analyze
error - main.dart:24:7 - The method '_inc' isn't defined for the type 'Counter'.
error - main.dart:25:7 - The method '_inc' isn't defined for the type 'Counter'.
error - main.dart:26:14 - The getter 'value' isn't defined for the type 'Counter'.
$ go run main.go
3
```

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.
