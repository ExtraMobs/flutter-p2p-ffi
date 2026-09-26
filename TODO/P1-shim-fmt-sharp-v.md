# `%#v` (sintaxe Go do valor)

- **Prioridade:** P1 · **Área:** shim
- **Depende de:** — (os nomes de tipo de slice/map/ponteiro combinam com os descritores do `P0-design-m5-reflexao`)

## Problema

`%#v` imprime o valor em sintaxe Go (`main.P{X:1, Y:2}`, `[]int{1, 2}`, `map[string]int{"a":1}`,
`(*main.P)(nil)`) e chama `GoString()` quando existe. O shim não porta: com formato constante e tipo
conhecido o g2d recusa na transpilação (`fmt-verbo:%#v`); com operando interface ou formato dinâmico
o shim lança `UnimplementedError` em runtime.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

| código | ocorrências | pacotes | na fronteira | exemplo |
| `fmt-verbo:%#v` | 39 | 8 | 2 | `github.com/cockroachdb/swiss` map.go:1006:21: fmt: %#v não portado no shim |
```

Medição sobre todas as chamadas Printf-like dos dumps (não só o primeiro problema de cada
declaração): 293 ocorrências de `%#v` em 31 pacotes, entre eles `github.com/ipfs/boxo/mfs`,
`github.com/ipfs/go-ipfs-cmds` e `github.com/ipfs/kubo/core/coreunix`.

## Critério de pronto

- `%#v` de básicos, structs (`$fieldNames` já existe), slices, arrays, maps, ponteiros e nil com os
  nomes de tipo do Go; interface `GoStringer` no shim (`GoString()` gerado para quem implementa).
- Fixture com oráculo Go (VM × JS × Wasm); a regra `%#v` sai do `g2d/behaviors/fmtcheck.py`.
