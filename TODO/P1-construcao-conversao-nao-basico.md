# Conversão de tipo não-básico

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

`T(x)` entre tipos que não são básicos (ponteiros, funções, nomeados sobre composto, `unsafe.Pointer`)
cai no código genérico `conversao:nao-basico`. É um guarda-chuva: o primeiro passo é quebrar o código
por par de categorias para o audit mostrar quais conversões pesam. Inclui `P2-construcao-conversao-struct`.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `conversao:nao-basico` | 316 | 51 | 5 | `github.com/spaolacci/murmur3` murmur64.go:34:11: conversão de tipo não-básico |
```

## Critério de pronto

- `Unsupported` com o par (`conversao:<de>-<para>`) e audit regerado; depois, um artefato por par
  relevante.
