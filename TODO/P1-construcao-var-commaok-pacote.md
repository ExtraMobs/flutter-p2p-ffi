# `var v, ok = m[k]` em nível de pacote gera Dart inválido

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Comma-ok de map em inicializador de pacote é emitido como tupla sobre o valor (`$t1.$1`), sem erro do g2d: Dart inválido em silêncio.

## Prova

```go
package main

import "fmt"

var m = map[string]int{"a": 1}
var v, ok = m["a"]

func main() {
	fmt.Println(v, ok)
}
```

```text
$ dart analyze
error - main.dart:33:12 - The getter '$1' isn't defined for the type 'Int'.
error - main.dart:34:13 - The getter '$2' isn't defined for the type 'Int'.
$ go run main.go
1 true
```

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.

## Notas

Emissão silenciosa de Dart inválido viola a regra do `AGENTS.md` (deveria ser `Unsupported`). Verificar também type assertion e recepção de canal comma-ok em nível de pacote.
