# Shim do pacote `strconv` (parcial)

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** —

## Problema

O shim `strconv` existe com parte dos símbolos (`atoi`, `errRange`, `errSyntax`, `formatInt`, `formatUint`, `itoa`, `parseInt`, `parseUint`); os que faltam viram
`Unsupported` `shim-simbolo:strconv.<nome>`. Somando as linhas abaixo: 54 ocorrências de pacote,
14 na fronteira (190 pacotes do grafo usam `strconv`).

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-simbolo:strconv.parseFloat` | 15 | 12 | 6 | `github.com/munnerz/goautoneg` autoneg.go:93:6: símbolo sem shim: strconv.parseFloat |
| `shim-simbolo:strconv.appendInt` | 16 | 12 | 3 | `go.uber.org/zap/buffer` buffer.go:35:1: símbolo sem shim: strconv.appendInt |
| `shim-simbolo:strconv.formatFloat` | 12 | 7 | 3 | `github.com/dunglas/httpsfv` decimal.go:21:6: símbolo sem shim: strconv.formatFloat |
| `shim-simbolo:strconv.quote` | 7 | 5 | 1 | `go.opencensus.io/resource` resource.go:43:6: símbolo sem shim: strconv.quote |
| `shim-simbolo:strconv.appendUint` | 6 | 3 | 1 | `github.com/whyrusleeping/chunker` polynomials.go:12:1: símbolo sem shim: strconv.appendUint |
| `shim-simbolo:strconv.appendFloat` | 6 | 5 | 0 | `go.opentelemetry.io/otel/attribute` value.go:800:6: símbolo sem shim: strconv.appendFloat |
| `shim-simbolo:strconv.formatBool` | 3 | 3 | 0 | `go.opentelemetry.io/otel/attribute` value.go:29:1: símbolo sem shim: strconv.formatBool |
| `shim-simbolo:strconv.isPrint` | 3 | 3 | 0 | `github.com/go-logr/logr/funcr` funcr.go:702:6: símbolo sem shim: strconv.isPrint |
| `shim-simbolo:strconv.quoteToASCII` | 2 | 2 | 0 | `github.com/miekg/dns` scan.go:69:1: símbolo sem shim: strconv.quoteToASCII |
| `shim-simbolo:strconv.parseBool` | 2 | 1 | 0 | `github.com/grpc-ecosystem/grpc-gateway/v2/runtime` convert.go:28:6: símbolo sem shim: strconv.parseBool |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `strconv` | 190 | ✅ | Itoa(63), Atoi(60), ParseUint(55), ParseInt(50), FormatInt(44), ParseFloat(25), FormatUint(24), AppendInt(16), FormatFloat(15), AppendUint(12), AppendFloat(11), ParseBool(8), Quote(8), FormatBool(6), Unquote(5), Err(4), ErrRange(4), IsPrint(4), NumError(4), IntSize(3), AppendQuote(2), ErrSyntax(2), Func(2), Num(2), QuoteToASCII(2), AppendBool(1), AppendQuoteRune(1), AppendQuoteRuneToASCII(1), AppendQuoteToASCII(1), CanBackquote(1), FormatComplex(1) |
```

## Critério de pronto

- Os símbolos da linha `strconv` de `docs/stdlib-coverage.md`, a partir dos que mais destravam a
  fronteira; semântica com oráculo Go (fixture e2e em VM × JS × Wasm ou teste no golib_dart).
- `python -m g2d shims`; audit regerado e commitado.

## Notas

Feito: inteiros (`Itoa`, `FormatInt`/`FormatUint`, `ParseInt`/`ParseUint`/`Atoi`) com
oráculo de ~2500 casos (`golib_dart/test/strconv_test.dart`) e fixture `tests/golden/strconvint`.
Feito (segunda leva): `ParseBool`/`FormatBool`/`AppendBool`, `AppendInt`/`AppendUint`,
`Quote`/`QuoteToASCII`/`QuoteRune`/`QuoteRuneToASCII`/`AppendQuote*`, `Unquote`/`UnquoteChar`,
`IsPrint`, `CanBackquote`, `FormatFloat`/`AppendFloat` (`e E f g G`) e `ParseFloat` (32/64,
decimal e hexadecimal), `IntSize` (constante dobrada). Oráculo em
`golib_dart/test/strconv_misc_test.dart` (~5000 linhas comparadas ao Go) e fixture
`tests/golden/strconvmisc` (go run × VM × JS × Wasm). O núcleo de quote saiu do `fmt` para
`src/strconv/quote_core.dart`. Corrigido de passagem o `_roundDecimal` do `float_format.dart`
(valor logo abaixo de 10^e arredondando para cima com `%.17g`).
Falta: `FormatFloat` com `b`/`x`/`X` (`UnsupportedError`), `FormatComplex`, `Func`/`Num`/`Err`
(`NumError` exposto, depende de `P1-design-structs-de-shim.md`), `QuotedPrefix`, `QuoteToGraphic`.
Regerar o audit e remover/encolher este artefato depois.
