# Shim do pacote `strconv` (parcial)

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** —

## Problema

O shim `strconv` existe com parte dos símbolos (`atoi`, `errRange`, `errSyntax`, `formatInt`, `formatUint`, `itoa`, `parseInt`, `parseUint`); os que faltam viram
`Unsupported` `shim-simbolo:strconv.<nome>`. Somando as linhas abaixo: 35 ocorrências de pacote,
10 na fronteira (190 pacotes do grafo usam `strconv`).

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-simbolo:strconv.parseFloat` | 14 | 11 | 6 | `github.com/munnerz/goautoneg` autoneg.go:93:6: símbolo sem shim: strconv.parseFloat |
| `shim-simbolo:strconv.formatFloat` | 10 | 6 | 2 | `go.opentelemetry.io/otel/attribute` value.go:745:6: símbolo sem shim: strconv.formatFloat |
| `shim-simbolo:strconv.appendInt` | 8 | 6 | 1 | `github.com/hashicorp/go-version` version.go:70:1: símbolo sem shim: strconv.appendInt |
| `shim-simbolo:strconv.quote` | 4 | 4 | 1 | `go.opencensus.io/resource` resource.go:43:6: símbolo sem shim: strconv.quote |
| `shim-simbolo:strconv.appendFloat` | 3 | 2 | 0 | `github.com/prometheus/common/expfmt` openmetrics_create.go:655:6: símbolo sem shim: strconv.appendFloat |
| `shim-simbolo:strconv.appendUint` | 3 | 2 | 0 | `github.com/pion/sdp/v3` session_description.go:186:1: símbolo sem shim: strconv.appendUint |
| `shim-simbolo:strconv.isPrint` | 2 | 2 | 0 | `github.com/go-logr/logr/funcr` funcr.go:702:6: símbolo sem shim: strconv.isPrint |
| `shim-simbolo:strconv.parseBool` | 2 | 1 | 0 | `github.com/grpc-ecosystem/grpc-gateway/v2/runtime` convert.go:28:6: símbolo sem shim: strconv.parseBool |
| `shim-simbolo:strconv.quoteToASCII` | 1 | 1 | 0 | `github.com/pion/sdp/v3` base_lexer.go:16:1: símbolo sem shim: strconv.quoteToASCII |
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
Baratos a seguir: `ParseBool`/`FormatBool`, `Quote`/`QuoteRune`/`AppendQuote` (o `%q` do `fmt` já
é o `strconv.Quote`), `AppendInt`/`AppendUint`, `Unquote`/`UnquoteChar`. `FormatFloat` reusa o
formatador de float do `fmt`/fixed_types. `ParseFloat` exige a porta exata do Go (Eisel-Lemire +
decimal lento) com oráculo. O tipo `NumError` exposto (campos, type assertion) depende de
`P1-design-structs-de-shim.md`.
