# `fmt.Formatter` e `fmt.State` (método `Format` chamado pelo `fmt`)

- **Prioridade:** P1 · **Área:** shim
- **Depende de:** `P1-design-interfaces-entre-pacotes.md` (o tipo que implementa `Format` costuma estar
  em pacote que o `fmt` do chamador não vê pelo `implements`), `P0-shim-io.md` (`State` é um
  `io.Writer`; `Fprintf(f, ...)` escreve nele)

## Problema

Tipo com `Format(f fmt.State, verb rune)` troca a formatação de **todos** os verbos no `fmt`
(`Printf`, `Println`, `%v`...). O shim não tem `State`/`Formatter`: o g2d recusa
(`shim-simbolo:fmt.State`). Implementar pede: `fmt.State` como interface de shim (`Write`, `Width`,
`Precision`, `Flag`) com uma implementação no `fmt` que acumula a saída do `Format`; `fmt.Formatter` em
`SHIM_INTERFACES`; o `_appendV`/`printf` chamando `format(state, verb)` antes de `Error`/`String`, como o
`handleMethods` do Go; `Fprintf`/`Fprint` sobre `io.Writer`.

## Prova

```go
package main

import "fmt"

type Safe string

func (s Safe) Format(f fmt.State, verb rune) {
	w, ok := f.Width()
	fmt.Fprintf(f, "<%s|%c|%d|%v|%v>", string(s), verb, w, ok, f.Flag('+'))
}

func main() {
	fmt.Printf("%v %+8s\n", Safe("a"), Safe("b"))
	fmt.Println(Safe("c"))
}
```

```text
$ go run main.go
<a|v|0|false|false> <b|s|8|true|true>
<c|v|0|false|false>

$ goast dump <dir> -o dump.json && python -m g2d transpile dump.json -o out
main: não suportado [shim-simbolo:fmt.State]: símbolo sem shim: fmt.State em main.go:5:1
```

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| `shim-simbolo:fmt.State` | 55 | 26 | 6 | `github.com/cockroachdb/redact/interfaces` interfaces.go:41:1: símbolo sem shim: fmt.State |
| `shim-simbolo:fmt.Formatter` | 5 | 5 | 0 | `github.com/kr/pretty` formatter.go:29:6: símbolo sem shim: fmt.Formatter |
```

## Critério de pronto

- Repro vira fixture em `tests/golden/` (inclusive tipo de outro pacote e `%+v`/largura/flags);
  e2e idêntico em VM × JS × Wasm.
- `docs/mapping-spec.md` (seção Stdlib, linha do `fmt`) atualizado.
