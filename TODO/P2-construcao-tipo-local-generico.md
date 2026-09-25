# Tipo local que usa parâmetro de tipo da função

- **Prioridade:** P2 · **Área:** construcao
- **Depende de:** —

## Problema

O tipo é içado para a library, fora do escopo de `T`: Dart inválido em silêncio (o `mapping-spec.md` anota ⚠️, mas não há `Unsupported`).

## Prova

```go
package main

import "fmt"

func Wrap[T any](v T) any {
	type box struct{ v T }
	return box{v}
}

func main() {
	fmt.Println(Wrap(3))
}
```

```text
$ dart analyze
error - main.dart:24:14 - Undefined class 'T'.
error - main.dart:24:33 - Undefined name '$T'.
error - main.dart:29:3 - Undefined class 'T'.
$ go run main.go
{3}
```

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.
