# Shim do pacote `time`

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** —

## Problema

Sem shim, 368 pacotes do grafo do kubo que usam `time` não transpilam (`shim-ausente:time`).
São 62 símbolos distintos.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-ausente:time` | 1416 | 277 | 42 | `github.com/cenkalti/backoff/v4` backoff.go:16:1: pacote sem shim/transpilação: time |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `time` | 368 | ❌ | Duration(236), Time(226), Now(181), Second(152), Stop(99), C(97), Add(87), Millisecond(80), Since(77), Minute(75), After(64), IsZero(60), NewTimer(59), NewTicker(58), Unix(54), Hour(52), Reset(51), Sub(50), Before(48), UnixNano(39), Seconds(38), Format(30), Until(29), Timer(28), UTC(26), … (+37) |
```

## Critério de pronto

- `golib_dart/lib/time.dart` registrado em `STDLIB_SHIMS` (`g2d/config.py`), cobrindo os símbolos da
  linha `time` de `docs/stdlib-coverage.md` a partir dos mais usados; os ausentes continuam
  `Unsupported` (nunca chamada a função inexistente).
- Semântica com oráculo Go nos testes do golib_dart; fixture e2e em VM × JS × Wasm.
- Audit regerado e commitado.

## Notas

`Duration`, `Time` (monotônico × parede), `Now`, `Since`, `Sleep`/`After`/`Timer`/`Ticker` (os três últimos dependem do M4).
