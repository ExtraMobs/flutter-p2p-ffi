# Restrição de tipo não mapeada

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Parâmetro de tipo com restrição fora das mapeadas (`~uint8 | ~uint16`, interfaces com métodos e
termos, `cmp.Ordered`...) é recusado.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `constraint` | 55 | 12 | 3 | `github.com/rivo/uniseg` properties.go:137:6: constraint de tipo não mapeada |
```

## Critério de pronto

- Restrições de união de termos e de interface com métodos; fixture e2e com genéricos do grafo.
