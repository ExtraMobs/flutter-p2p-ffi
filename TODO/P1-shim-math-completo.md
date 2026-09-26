# Shim `math` sem as funções que o grafo usa

- **Prioridade:** P1 · **Área:** shim
- **Depende de:** —

## Problema

O shim `math` existe mas só com parte das funções; o g2d emite a chamada assim mesmo (`math.pow`,
`math.sqrt`, `math.exp`, `math.log`, `math.expm1`, `math.log1p`, `math.isInf`...): Dart inválido em
silêncio (`undefined_function`) em vez de `Unsupported`. Mesmo defeito do `fmt.Sprintf`/`Errorf`
(`P1-shim-fmt-printf`), que responde pelo resto dos `undefined_function`.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `dart:undefined_function` | 33 | 9 | 9 | `github.com/klauspost/compress` 49:34: error: The function 'pow' isn't defined. |
```

```text
.g2d-cache/out (dart analyze --format=machine):
github.com/klauspost/compress.dart 49:34 The function 'pow' isn't defined.
github.com/petar/GoLLRB/llrb.dart 79:13 The function 'sqrt' isn't defined.
github.com/cockroachdb/pebble/v2/internal/ewma.dart 64:19 The function 'expm1' isn't defined.
gonum.org/v1/gonum/mathext/internal/gonum.dart 40:11 The function 'isInf' isn't defined.
```

## Critério de pronto

- ~~Símbolo de shim inexistente vira `Unsupported`~~: feito junto com `P1-shim-fmt-printf`
  (`shim-simbolo:<pkg>.<nome>`, `g2d/shim_symbols.json`). Agora o audit lista cada função de `math`
  que falta (`shim-simbolo:math.float64bits`, `math.log`, `math.inf`, `math.pow`...).
- Funções da linha `math` de `docs/stdlib-coverage.md` com oráculo Go (bits exatos de float64).
