# `iter.Seq` e as funções `Seq` dos shims

- **Prioridade:** P1 · **Área:** shim
- **Depende de:** —

## Problema

Não há shim de `iter`, e as funções da stdlib que devolvem `iter.Seq`
(`strings.SplitSeq`, `strings.Lines`, `strings.FieldsSeq`, `bytes.SplitSeq`,
`maps.Keys`, `slices.All`...) viram `Unsupported`. O `range` sobre valor
`func` já funciona no g2d (`range_func` em `g2d/behaviors/stmts.py`), então o
que falta é só o lado do shim.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo
| `shim-ausente:iter` | 36 | 19 | 4 | `github.com/cockroachdb/pebble/v2/sstable/block/blockkind` kind.go:46:6: pacote sem shim/transpilação: iter |
| `shim-simbolo:strings.splitSeq` | 13 | 10 | 3 | `github.com/klauspost/cpuid/v2` cpuid.go:478:6: símbolo sem shim: strings.splitSeq |
```

## Critério de pronto

- `golib_dart/lib/iter.dart` com `Seq`/`Seq2` (tipos func com a assinatura
  estrutural de `func(yield func(V) bool)`) e `Pull` se o grafo usar; as
  funções `Seq` de `strings`/`bytes`; fixture e2e em VM × JS × Wasm.
- `python -m g2d shims`; audit regerado.
