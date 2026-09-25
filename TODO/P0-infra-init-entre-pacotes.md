# Inicialização das dependências antes do pacote

- **Prioridade:** P0 · **Área:** infra
- **Depende de:** P0-infra-import-entre-pacotes

## Problema

Cada library gerada tem `$goInit()` com guarda, mas o `main` só chama o do próprio pacote: variáveis e `init()` das dependências nunca rodam. O Go inicializa as dependências primeiro, na ordem dos imports.

## Prova

`a/a.go`

```go
package a

var Registry = map[string]int{}

func init() { Registry["a"] = 1 }
```

`cmd/main.go`

```go
package main

import (
	"fmt"

	"repro.local/mp/a"
)

func main() {
	fmt.Println(a.Registry["a"], len(a.Registry))
}
```

Com a sonda de import (plugin que qualifica os pacotes do módulo como `package:out/<path>.dart`), para expor a camada abaixo do import:

```text
$ dart analyze
No issues found!
$ go run ./cmd
1 1
$ dart run lib/repro.local/mp/cmd.dart
0 0
```

## Critério de pronto

- Repro vira fixture multi-pacote em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.

## Notas

Pré-requisito também de `P1-construcao-import-blank` (import só pelos efeitos do `init`).
