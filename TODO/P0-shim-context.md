# Shim do pacote `context`

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** P0-design-m4-concorrencia (`Done() <-chan struct{}`)

## Problema

Sem shim, 380 pacotes do grafo do kubo que usam `context` não transpilam (`shim-ausente:context`).
São 20 símbolos distintos.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-ausente:context` | 1540 | 307 | 26 | `github.com/cenkalti/backoff/v4` context.go:10:1: pacote sem shim/transpilação: context |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `context` | 380 | ❌ | Context(370), Done(145), Background(114), Err(113), WithCancel(107), CancelFunc(65), WithTimeout(65), Value(46), WithValue(45), Canceled(26), DeadlineExceeded(25), Deadline(21), TODO(17), AfterFunc(11), WithDeadline(10), Cause(7), WithCancelCause(5), WithTimeoutCause(3), WithoutCancel(3), CancelCauseFunc(2) |
```

## Critério de pronto

- `golib_dart/lib/context.dart` registrado em `STDLIB_SHIMS` (`g2d/config.py`), cobrindo os símbolos da
  linha `context` de `docs/stdlib-coverage.md` a partir dos mais usados; os ausentes continuam
  `Unsupported` (nunca chamada a função inexistente).
- Semântica com oráculo Go nos testes do golib_dart; fixture e2e em VM × JS × Wasm.
- Audit regerado e commitado.

## Notas

`Context` é interface com canal; `Background`/`TODO`/`WithCancel`/`WithTimeout`/`WithValue`.
