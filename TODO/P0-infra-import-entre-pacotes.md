# Import de pacote não-stdlib (library gerada)

- **Prioridade:** P0 · **Área:** infra
- **Depende de:** —

## Problema

O `ImportTable` recusa qualquer import que não seja shim da stdlib; um pacote que importa outro pacote do grafo não transpila. Precisa qualificar pacotes do grafo como `package:out/<import path>.dart` (o mono-repo que o `WriteStage` já escreve).

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

```text
$ goast dump repro.local/mp/...   (dentro do módulo) → python -m g2d transpile
repro.local/mp/a: ok
repro.local/mp/cmd: não suportado: pacote sem shim/transpilação: repro.local/mp/a
```

## Critério de pronto

- Repro vira fixture multi-pacote em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.

## Notas

Todos os repros multi-pacote deste backlog falham primeiro aqui.
