# Shim do pacote `sort`

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** —

## Problema

Sem shim, 111 pacotes do grafo do kubo que usam `sort` não transpilam (`shim-ausente:sort`).
São 15 símbolos distintos.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-ausente:sort` | 67 | 44 | 11 | `github.com/beorn7/perks/quantile` stream.go:125:1: pacote sem shim/transpilação: sort |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `sort` | 111 | ❌ | Sort(48), Slice(31), Strings(26), Search(25), Ints(7), Stable(7), Float64s(3), IsSorted(3), Reverse(3), SearchFloat64s(3), SliceStable(3), IntSlice(1), Interface(1), SearchStrings(1), StringSlice(1) |
```

## Critério de pronto

- `golib_dart/lib/sort.dart` registrado em `STDLIB_SHIMS` (`g2d/config.py`), cobrindo os símbolos da
  linha `sort` de `docs/stdlib-coverage.md` a partir dos mais usados; os ausentes continuam
  `Unsupported` (nunca chamada a função inexistente).
- Semântica com oráculo Go nos testes do golib_dart; fixture e2e em VM × JS × Wasm.
- Audit regerado e commitado.

## Notas

`Slice`, `SliceStable`, `Sort`/`Stable` sobre `sort.Interface`, `Search*`, `Strings`/`Ints`.
