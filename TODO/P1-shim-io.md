# Shim do pacote `io` (restante)

- **Prioridade:** P1 · **Área:** shim
- **Depende de:** — (`Pipe` depende de `P0-design-io-suspende`)

## Problema

O shim `io` tem as interfaces básicas, as sentinelas, `ReadFull`, `ReadAll`,
`WriteString` e `Discard`. O resto vira `shim-simbolo:io.<nome>`.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo
| `shim-simbolo:io.limitReader` | 13 | 11 | 1 |
| `shim-simbolo:io.LimitedReader` | 5 | 5 | 1 |
| `shim-simbolo:io.copyN` | 3 | 3 | 1 |
| `shim-simbolo:io.ByteScanner` | 2 | 2 | 1 |
| `shim-simbolo:io.SectionReader` | 1 | 1 | 1 |
| `shim-simbolo:io.multiWriter` | 1 | 1 | 1 |
| `shim-simbolo:io.copy` | 14 | 13 | 0 |
| `shim-simbolo:io.WriterTo` | 4 | 4 | 0 |
| `shim-simbolo:io.nopCloser` | 4 | 3 | 0 |
| `shim-simbolo:io.pipe` | 4 | 3 | 0 |
```

Somando os códigos `io.*`: 58 ocorrências, 6 na fronteira.

## Critério de pronto

- `LimitReader`/`LimitedReader`, `Copy`/`CopyN`/`CopyBuffer`,
  `MultiWriter`/`MultiReader`, `SectionReader`/`NewSectionReader`,
  `NopCloser`, `TeeReader` e as interfaces que faltam (`ByteScanner`,
  `RuneReader`, `RuneScanner`, `WriterTo`, `ReaderFrom`, `ReadSeekCloser`;
  quando entrarem, ligar `bytes.Reader`/`strings.Reader`, hoje marcados
  `ponytail:`). Porta do `io.go`, oráculo Go.
- `python -m g2d shims`; audit regerado.
