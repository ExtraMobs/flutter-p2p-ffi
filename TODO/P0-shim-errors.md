# Shim do pacote `errors` (parcial)

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** —

## Problema

O shim `errors` existe com parte dos símbolos (`new$`); os que faltam viram
`Unsupported` `shim-simbolo:errors.<nome>`. Somando as linhas abaixo: 59 ocorrências de pacote,
9 na fronteira (425 pacotes do grafo usam `errors`).

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-simbolo:errors.is$` | 31 | 20 | 4 | `github.com/pkg/errors` go113.go:16:6: símbolo sem shim: errors.is$ |
| `shim-simbolo:errors.as` | 23 | 19 | 3 | `github.com/jbenet/go-temp-err-catcher` temp_err_catcher.go:26:6: símbolo sem shim: errors.as |
| `shim-simbolo:errors.unwrap` | 4 | 3 | 2 | `github.com/pkg/errors` go113.go:36:6: símbolo sem shim: errors.unwrap |
| `shim-simbolo:errors.join` | 18 | 13 | 0 | `github.com/pion/interceptor/pkg/flexfec` encoder_interceptor.go:22:1: símbolo sem shim: errors.join |
| `shim-simbolo:errors.asType` | 5 | 4 | 0 | `github.com/quic-go/quic-go/internal/handshake` crypto_setup.go:688:6: símbolo sem shim: errors.asType |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `errors` | 425 | ✅ | New(391), Is(93), Join(45), As(35), AsType(8), Unwrap(7) |
```

## Critério de pronto

- Os símbolos da linha `errors` de `docs/stdlib-coverage.md`, a partir dos que mais destravam a
  fronteira; semântica com oráculo Go (fixture e2e em VM × JS × Wasm ou teste no golib_dart).
- `python -m g2d shims`; audit regerado e commitado.

## Notas

`Is`/`As`/`Unwrap`/`Join` precisam achar, no valor dinâmico, os métodos `Unwrap() error`,
`Unwrap() []error`, `Is(error) bool` e `As(any) bool` de **qualquer** tipo gerado. Interfaces Dart são
nominais: o g2d teria de declarar `implements` de interfaces do runtime (`go.Unwrapper`,
`go.MultiUnwrapper`, `go.ErrorIs`, `go.ErrorAs`) em todo tipo cujo method set tem essas assinaturas
(hoje o `implements` só cobre interfaces nomeadas dos imports diretos, `SHIM_INTERFACES`). `As` ainda
precisa do alvo como ponteiro para variável de tipo arbitrário (`go.Ptr` + teste de tipo pelo
descritor): decisão de design junto com `P0-design-m5-reflexao.md`. `WrapError`/`WrapErrors` do
runtime já expõem `unwrap()`.
