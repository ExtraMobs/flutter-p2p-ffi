# Shim do pacote `time` (parcial)

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** —

## Problema

O shim `time` existe com parte dos símbolos (`Duration`); os que faltam viram
`Unsupported` `shim-simbolo:time.<nome>`. Somando as linhas abaixo: 273 ocorrências de pacote,
56 na fronteira (368 pacotes do grafo usam `time`).

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-simbolo:time.Time` | 525 | 161 | 33 | `github.com/cenkalti/backoff/v4` exponential.go:54:1: símbolo sem shim: time.Time |
| `shim-simbolo:time.now` | 70 | 53 | 6 | `github.com/cockroachdb/crlib/crtime` monotonic.go:59:5: símbolo sem shim: time.now |
| `shim-simbolo:time.Timer` | 13 | 11 | 5 | `github.com/cenkalti/backoff/v4` timer.go:12:1: símbolo sem shim: time.Timer |
| `shim-simbolo:time.unix` | 10 | 7 | 4 | `github.com/benbjohnson/clock` clock.go:87:6: símbolo sem shim: time.unix |
| `shim-simbolo:time.since` | 5 | 5 | 2 | `github.com/cockroachdb/crlib/crtime` monotonic.go:32:6: símbolo sem shim: time.since |
| `shim-simbolo:time.afterFunc` | 4 | 3 | 2 | `google.golang.org/grpc/balancer/pickfirst/internal` internal.go:33:2: símbolo sem shim: time.afterFunc |
| `shim-simbolo:time.sleep` | 3 | 3 | 2 | `github.com/benbjohnson/clock` clock.go:417:6: símbolo sem shim: time.sleep |
| `shim-simbolo:time.Location` | 6 | 6 | 1 | `go.opentelemetry.io/otel/trace` config.go:250:1: símbolo sem shim: time.Location |
| `shim-simbolo:time.local` | 1 | 1 | 1 | `github.com/huin/goupnp/soap` types.go:20:2: símbolo sem shim: time.local |
| `shim-simbolo:time.Ticker` | 6 | 6 | 0 | `go.uber.org/zap/zapcore` clock.go:30:1: símbolo sem shim: time.Ticker |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `time` | 368 | ✅ | Duration(236), Time(226), Now(181), Second(152), Stop(99), C(97), Add(87), Millisecond(80), Since(77), Minute(75), After(64), IsZero(60), NewTimer(59), NewTicker(58), Unix(54), Hour(52), Reset(51), Sub(50), Before(48), UnixNano(39), Seconds(38), Format(30), Until(29), Timer(28), UTC(26), Nanoseconds(24), Nanosecond(23), AfterFunc(22), String(21), Parse(17), Ticker(17), Microsecond(16), ParseDuration(16), Sleep(15), RFC3339Nano(14), Equal(8), Round(7), Truncate(7), RFC1123(5), Location(4), Milliseconds(4), RFC3339(4), AddDate(3), Date(3), MarshalJSON(3), Microseconds(3), Minutes(3), UnixMilli(3), AppendFormat(2), Day(2), Hours(2), In(2), Tick(2), Abs(1), Clock(1), Compare(1), FixedZone(1), Local(1), Month(1), Stamp(1), UnmarshalJSON(1), Year(1) |
```

## Critério de pronto

- Os símbolos da linha `time` de `docs/stdlib-coverage.md`, a partir dos que mais destravam a
  fronteira; semântica com oráculo Go (fixture e2e em VM × JS × Wasm ou teste no golib_dart).
- `python -m g2d shims`; audit regerado e commitado.

## Notas

Feito: `Duration` (fixture `tests/golden/timeduration`). `Time` é struct de shim
(`P1-design-structs-de-shim` resolvido: classe `extends go.GoStruct` no shim) com wall/ext/loc; `Now`
é não determinístico (o e2e só pode comparar forma ou diferenças); `Since`/`Until`/`Sub`/`Add`
derivam de `Time`; `Sleep`, `After`, `NewTimer`, `Ticker` dependem de goroutines/channels
(`P0-design-m4-concorrencia.md`); `Format`/`Parse` exigem a porta do layout do Go e de `Location`.
