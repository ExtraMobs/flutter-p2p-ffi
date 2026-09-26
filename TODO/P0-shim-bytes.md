# Shim do pacote `bytes`

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** —

## Problema

Sem shim, 224 pacotes do grafo do kubo que usam `bytes` não transpilam (`shim-ausente:bytes`).
São 59 símbolos distintos.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-ausente:bytes` | 368 | 117 | 27 | `github.com/getsentry/sentry-go/internal/traceparser` parser.go:14:6: pacote sem shim/transpilação: bytes |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `bytes` | 224 | ❌ | Buffer(110), Equal(76), Bytes(57), NewReader(52), String(48), Len(38), Write(33), WriteString(31), Reset(27), NewBuffer(26), Compare(24), WriteByte(22), HasPrefix(16), IndexByte(15), Index(8), Reader(8), Split(7), TrimSpace(7), HasSuffix(6), WriteTo(6), Clone(5), Next(5), Read(5), WriteRune(5), Count(4), … (+34) |
```

## Critério de pronto

- `golib_dart/lib/bytes.dart` registrado em `STDLIB_SHIMS` (`g2d/config.py`), cobrindo os símbolos da
  linha `bytes` de `docs/stdlib-coverage.md` a partir dos mais usados; os ausentes continuam
  `Unsupported` (nunca chamada a função inexistente).
- Semântica com oráculo Go nos testes do golib_dart; fixture e2e em VM × JS × Wasm.
- Audit regerado e commitado.

## Notas

`Buffer`, `Equal`, `Compare`, `HasPrefix`, `Index`... sobre `go.Slice<Golang.Uint8>`.
