# Import `_` (só pelos efeitos do `init`)

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** P0-infra-init-entre-pacotes

## Problema

`import _ "pkg"` é recusado; no kubo é o mecanismo de registro de plugins/codecs.

## Prova

```go
package main

import _ "math"

import "fmt"

func main() {
	fmt.Println("ok")
}
```

```text
$ goast dump <dir> > dump.json && python -m g2d transpile dump.json
não suportado: import _ math
```

## Critério de pronto

- Repro vira fixture em `tests/golden/`; e2e idêntico em VM × JS × Wasm; `dart analyze --fatal-infos` limpo.
- `docs/mapping-spec.md` atualizado.
