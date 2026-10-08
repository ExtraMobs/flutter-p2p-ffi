# Shim parcial de `net/textproto` (MIMEHeader e chaves canônicas)

- **Prioridade:** P1 · **Área:** shim
- **Depende de:** —

## Problema

Não há shim de `net/textproto`; o grafo usa `CanonicalMIMEHeaderKey`,
`TrimString` e `MIMEHeader` (`Get`/`Set`) em 7 pacotes
(`golang.org/x/net/http/httpguts`, `x/net/internal/httpcommon`,
`boxo/gateway`...). `MIMEHeader` é `map[string][]string` nomeado com métodos.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo
| `shim-ausente:net/textproto` | 12 | 6 | 0 | `golang.org/x/net/http/httpguts` guts.go:20:6: pacote sem shim/transpilação: net/textproto |

$ G2D_UPDATE_GOLDEN=1 G2D_CASES=nettextproto python -m unittest tests.test_golden
g2d.model.Unsupported: não suportado [shim-ausente:net/textproto]: pacote sem shim/transpilação: net/textproto em nettextproto.go:14:6
```

## Critério de pronto

- `golib_dart/lib/net/textproto.dart`: `MIMEHeader` (classe gerada sobre
  `go.GoMap`, em `SHIM_NAMED_CLASSES`), `CanonicalMIMEHeaderKey`,
  `TrimString`/`TrimBytes`, `ProtocolError`, `Error`; vetores Go das chaves
  canônicas; fixture e2e `tests/golden/nettextproto`.
- `Reader`/`Writer`/`Conn`/`Pipeline`/`Dial` ficam ⚠️ (precisam de `bufio`).
