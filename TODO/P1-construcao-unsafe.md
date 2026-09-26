# `unsafe` (Pointer, Slice, String, Sizeof...)

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

`unsafe.Pointer` cai em `tipo-basico:Pointer` e os builtins do pacote `unsafe` chamados por seletor
(`unsafe.Slice`, `unsafe.String`, `unsafe.StringData`, `unsafe.Add`) caem em `builtin:None` (o nome do
builtin é lido só de `Ident`: código errado no audit). Sem `dart:ffi` (não existe no JS/Wasm), a maior
parte vira substituição à mão; `Sizeof`/`Alignof`/`Offsetof` são constantes do `go/types`.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `tipo-basico:Pointer` | 352 | 66 | 7 | `github.com/cockroachdb/pebble/v2/internal/rawalloc` rawalloc.go:21:6: tipo básico Pointer |
| `builtin:None` | 37 | 29 | 5 | `filippo.io/bigmod` nat_noasm.go:12:19: builtin None |
```

```text
filippo.io/bigmod nat_noasm.go:12:
	return addMulVVW(unsafe.Slice(z, 1024/_W), unsafe.Slice(x, 1024/_W), y)
```

## Critério de pronto

- Código de `Unsupported` com o nome real (`unsafe:Slice`, `unsafe:Pointer`); decidir no
  `mapping-spec.md` o que é traduzível (conversões `[]byte`↔`string` via `unsafe.String`/`StringData`
  têm equivalente seguro) e o que marca o pacote para substituição.
