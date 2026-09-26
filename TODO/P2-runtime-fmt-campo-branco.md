# Campo `_` some do `%v` de struct

- **Prioridade:** P2 · **Área:** runtime
- **Depende de:** —

## Problema

O g2d deixa o campo em branco (`_ T`) fora da classe (inacessível e fora da igualdade), então ele
também some do `$fields`; o Go imprime o zero dele no `%v`. Aparece em structs com padding ou com o
padrão `_ [0]func()` (não-comparável).

## Prova

```go
package main

import "fmt"

type Pad struct {
	A int
	_ int
	B int
}

func main() { fmt.Println(Pad{A: 1, B: 2}) }
```

```text
$ go run main.go
{1 0 2}
$ goast dump <dir> -o d.json && python -m g2d transpile d.json -o out && dart run out/lib/main.dart
{1 2}
```

## Critério de pronto

- `$fields`/`$fieldNames` incluem o zero de cada campo `_` (fora da igualdade, que o Go também
  ignora); fixture e2e com `_ int` e `_ [0]func()`.
