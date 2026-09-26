# Shim do pacote `strconv`

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** —

## Problema

Sem shim, 190 pacotes do grafo do kubo que usam `strconv` não transpilam (`shim-ausente:strconv`).
São 31 símbolos distintos.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-ausente:strconv` | 144 | 60 | 18 | `github.com/multiformats/go-base32` base32.go:272:1: pacote sem shim/transpilação: strconv |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `strconv` | 190 | ❌ | Itoa(63), Atoi(60), ParseUint(55), ParseInt(50), FormatInt(44), ParseFloat(25), FormatUint(24), AppendInt(16), FormatFloat(15), AppendUint(12), AppendFloat(11), ParseBool(8), Quote(8), FormatBool(6), Unquote(5), Err(4), ErrRange(4), IsPrint(4), NumError(4), IntSize(3), AppendQuote(2), ErrSyntax(2), Func(2), Num(2), QuoteToASCII(2), … (+6) |
```

## Critério de pronto

- `golib_dart/lib/strconv.dart` registrado em `STDLIB_SHIMS` (`g2d/config.py`), cobrindo os símbolos da
  linha `strconv` de `docs/stdlib-coverage.md` a partir dos mais usados; os ausentes continuam
  `Unsupported` (nunca chamada a função inexistente).
- Semântica com oráculo Go nos testes do golib_dart; fixture e2e em VM × JS × Wasm.
- Audit regerado e commitado.

## Notas

`Itoa`, `Atoi`, `ParseInt`/`ParseUint`/`FormatInt`, `Quote`; erros `*NumError` como no Go.
