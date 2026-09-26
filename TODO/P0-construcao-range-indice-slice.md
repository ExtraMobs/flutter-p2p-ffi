# `for i := range slice` quebra o g2d (TypeError)

- **Prioridade:** P0 · **Área:** construcao
- **Depende de:** —

## Problema

Range sobre slice/array com chave declarada (`for i := range xs`, `for i, v := range xs`) derruba o
Engine: `stmts.py` pega o tipo da chave com `type_of(key)`, que é `None` numa definição (`:=`), e
`Operands.from_int` → `TypeMapper.cls(None)`. Os goldens só tinham `for _, v := range`. Idioma
comum: é o 2º código do ranking.

## Prova

```go
package main

import "fmt"

func main() {
	for i := range []int{7, 8} {
		fmt.Println(i)
	}
}
```

```text
$ goast dump <dir> -o d.json && python -c "... Engine(pkg).emit_package()"
TypeError 'NoneType' object is not subscriptable
  stmts.py 232 emit | pre = ([bind(key, self.operands.from_int(i, key_t))] ...
  operands.py 34 from_int | return f"{self.types.cls(t)}({dart_int})"
  types.py 67 cls | if t["kind"] == "named":
```

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `erro-interno:TypeError` | 386 | 188 | 47 | `go.uber.org/dig/internal/graph` graph.go:108:1: services/types.py:67: 'NoneType' object is not subscriptable |
```

## Critério de pronto

- Tipo da chave pelo objeto (`key["$obj"]["type"]`, como já faz o range sobre string); fixture com
  `for i := range`, `for i, v := range` sobre slice, array e slice nomeado; e2e VM × JS × Wasm.
- Conferir se o `TypeError` de `functions.py:161` (pacotes com assembly, função sem corpo) ainda
  aparece com `purego,noasm`; se sim, vira `Unsupported` próprio.
