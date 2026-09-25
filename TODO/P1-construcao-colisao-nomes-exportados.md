# Colisão `FOO` × `Foo` (lowerCamel)

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Identificadores exportados que diferem só por caixa viram o mesmo nome Dart: Dart inválido em silêncio (limite ⚠️ já anotado no `mapping-spec.md`).

## Prova

```go
package main

import "fmt"

const FOO = 1
const Foo = 2

func main() {
	fmt.Println(FOO, Foo)
}
```

```text
$ dart analyze
error - main.dart:12:18 - The name 'foo' is already defined.
$ go run main.go
1 2
```

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.
