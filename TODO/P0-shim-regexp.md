# Shim do pacote `regexp`

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** —

## Problema

Sem shim, 43 pacotes do grafo do kubo que usam `regexp` não transpilam (`shim-ausente:regexp`).
São 24 símbolos distintos.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-ausente:regexp` | 164 | 34 | 12 | `github.com/cockroachdb/redact/internal/markers` constants.go:33:1: pacote sem shim/transpilação: regexp |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `regexp` | 43 | ❌ | MustCompile(39), FindStringSubmatch(16), MatchString(16), Regexp(11), Compile(8), ReplaceAllString(4), FindStringSubmatchIndex(3), FindAllStringSubmatch(2), FindSubmatch(2), Match(2), QuoteMeta(2), ReplaceAllLiteralString(2), ExpandString(1), Find(1), FindAllString(1), FindAllStringIndex(1), FindString(1), NumSubexp(1), ReplaceAll(1), ReplaceAllLiteral(1), ReplaceAllStringFunc(1), Split(1), String(1), SubexpNames(1) |
```

## Critério de pronto

- `golib_dart/lib/regexp.dart` registrado em `STDLIB_SHIMS` (`g2d/config.py`), cobrindo os símbolos da
  linha `regexp` de `docs/stdlib-coverage.md` a partir dos mais usados; os ausentes continuam
  `Unsupported` (nunca chamada a função inexistente).
- Semântica com oráculo Go nos testes do golib_dart; fixture e2e em VM × JS × Wasm.
- Audit regerado e commitado.

## Notas

Sintaxe RE2 ≠ `RegExp` do Dart (ex.: classes POSIX, `(?P<n>)`, semântica leftmost-first): decidir entre port do `regexp` Go e tradução com lista de limites.

### Estado (branch `claude/pq1hu0-regexp`)

Feito: `golib_dart/lib/regexp.dart` (partes em `lib/src/regexp/`) com motor próprio
(parser RE2 + simulação Pike, sobre bytes UTF-8), registrado em `STDLIB_SHIMS`;
oráculo `golib_dart/test/regexp_test.dart` (~74 mil resultados iguais ao Go) e fixture
`tests/golden/regexpbasic` (go run × VM × JS × Wasm). Limites e símbolos fora estão em
`docs/mapping-spec.md` (`regexp`): `Longest`, `CompilePOSIX`, `MatchReader`/`RuneReader`,
`LiteralPrefix`, `Copy`, `(Un)MarshalText`. Falta só regerar o audit (o agente principal) e
apagar este artefato no commit que o fizer.
