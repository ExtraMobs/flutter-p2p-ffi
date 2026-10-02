# `goto`

- **Prioridade:** P0 · **Área:** design (decisão D6 do `TODO/README.md`)
- **Depende de:** —

## Problema

`goto` está marcado ❌ por decisão no `docs/mapping-spec.md` § "Statements",
medido quando eram 14 pacotes e 3 na fronteira. Com o grafo andando, a conta
mudou: hoje são 28 pacotes e 10 na fronteira, o que pela regra de prioridade
já é P0.

## Prova

```go
package main

import "fmt"

func find(xs []int, v int) int {
	i := 0
loop:
	if i < len(xs) {
		if xs[i] == v {
			goto found
		}
		i++
		goto loop
	}
	return -1
found:
	return i
}

func main() { fmt.Println(find([]int{4, 5, 6}, 6), find(nil, 1)) }
```

```text
$ go run .
2 -1
$ goast dump . -o dump.json && python -m g2d transpile dump.json -o out
goto: não suportado [branch:goto]: goto em main.go:10:4
```

No grafo do kubo (`docs/audit.md`):

```text
| `branch:goto` | 74 | 28 | 10 | `gonum.org/v1/gonum/mathext/internal/cephes` hyp2f1.go:106:4: goto |
```

Na fronteira: `gonum/mathext/internal/cephes`, `beorn7/perks/quantile`,
`gabriel-vasile/mimetype/internal/{json,scan}`, `golang/snappy`,
`klauspost/compress/internal/snapref`, `golang.org/x/text/unicode/norm`,
`golang.org/x/xerrors` e outros.

## Decisão pendente

1. **Implementar no g2d (recomendado).** Primeiro os saltos que viram
   controle estruturado do Dart: `goto` para frente até um rótulo no mesmo
   bloco vira `break` de um bloco rotulado; para trás, laço rotulado com
   `continue`. O que sobrar vira máquina de estados (`while (true) switch
   (estado)`). Quanto dos 74 cai no primeiro caso ainda não foi medido.
2. **Substituição manual** dos pacotes afetados (depende de D5).
3. **Manter ❌.**

## Critério de pronto

- Repro vira fixture; e2e idêntico em VM × JS × Wasm.
- `docs/mapping-spec.md` § "Statements" atualizado; audit regerado.
