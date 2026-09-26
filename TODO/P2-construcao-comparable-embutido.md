# `comparable` embutido em interface de restrição

- **Prioridade:** P2 · **Área:** construcao
- **Depende de:** —

## Problema

`type Key interface { comparable; ... }` faz o g2d qualificar o `comparable` do universo como se
fosse de um pacote de path vazio: `shim-ausente:` (código sem pacote).

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-ausente:` | 1 | 1 | 0 | `github.com/cockroachdb/pebble/v2/internal/genericcache` cache.go:25:1: pacote sem shim/transpilação:  |
```

```text
github.com/cockroachdb/pebble/v2/internal/genericcache cache.go:25:
type Key interface {
	comparable
```

## Critério de pronto

- `comparable` embutido tratado na restrição (sem import); fixture com genérico de chave comparável.
