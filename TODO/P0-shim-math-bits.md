# Shim do pacote `math/bits`

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** —

## Problema

Sem shim, 53 pacotes do grafo do kubo que usam `math/bits` não transpilam (`shim-ausente:math/bits`).
São 25 símbolos distintos.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-ausente:math/bits` | 83 | 35 | 13 | `github.com/zeebo/blake3/internal/alg/compress/compress_pure` compress.go:28:6: pacote sem shim/transpilação: math/bits |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `math/bits` | 53 | ❌ | Len64(13), TrailingZeros64(10), Len32(8), OnesCount64(7), RotateLeft32(6), Len(5), RotateLeft64(5), UintSize(4), Add64(3), LeadingZeros64(3), Mul64(3), TrailingZeros(3), Sub(2), TrailingZeros32(2), Add(1), Div(1), Div64(1), LeadingZeros8(1), Mul(1), OnesCount32(1), OnesCount8(1), ReverseBytes16(1), ReverseBytes32(1), ReverseBytes64(1), Sub64(1) |
```

## Critério de pronto

- `golib_dart/lib/math/bits.dart` registrado em `STDLIB_SHIMS` (`g2d/config.py`), cobrindo os símbolos da
  linha `math/bits` de `docs/stdlib-coverage.md` a partir dos mais usados; os ausentes continuam
  `Unsupported` (nunca chamada a função inexistente).
- Semântica com oráculo Go nos testes do golib_dart; fixture e2e em VM × JS × Wasm.
- Audit regerado e commitado.

## Notas

`OnesCount*`, `LeadingZeros*`, `TrailingZeros*`, `RotateLeft*`, `Add64`/`Mul64`/`Sub64`... sobre os fixed_types (sem bitwise > 32 bits nativo no JS).
