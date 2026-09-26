# Identificador Go com letra não-ASCII

- **Prioridade:** P1 · **Área:** construcao
- **Depende de:** —

## Problema

Go aceita letras Unicode em identificadores (`Δ := ...`); o Dart só `[A-Za-z0-9_$]`. O g2d copia o
nome: Dart inválido em silêncio (`illegal_character`).

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (github.com/klauspost/compress, dart-invalido):
| `dart:illegal_character` | 3 | 1 | 1 | ...

.g2d-cache/out/lib/github.com/klauspost/compress.dart:58:
Golang.Float64 Δ = Golang.Float64.fromInt64(Golang.Int64.from(v)) - avg;
  error - Illegal character '916'. - illegal_character
```

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `dart:illegal_character` | 3 | 1 | 1 | `github.com/klauspost/compress` 58:16: error: Illegal character '916'. |
```

## Critério de pronto

- `Naming` escapa letras não-ASCII de forma determinística e sem colisão (ex.: `$u0394`); teste de
  unidade de naming; fixture e2e.
