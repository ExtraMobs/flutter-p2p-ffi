# Shim do pacote `io`

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** —

## Problema

Sem shim, 367 pacotes do grafo do kubo que usam `io` não transpilam (`shim-ausente:io`).
São 58 símbolos distintos.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-ausente:io` | 916 | 227 | 40 | `github.com/ipld/go-car/v2/internal/io` converter.go:18:1: pacote sem shim/transpilação: io |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `io` | 367 | ❌ | Writer(155), Reader(147), Close(142), Write(125), EOF(122), Closer(79), Read(60), ErrUnexpectedEOF(55), ReadFull(53), ReadAll(40), Copy(36), Discard(26), LimitReader(25), ReadCloser(23), WriteString(23), SeekStart(22), ErrShortBuffer(18), Seek(18), WriteCloser(17), ByteReader(16), SeekCurrent(15), SeekEnd(14), ReadByte(13), ReadSeeker(13), ReaderAt(11), … (+33) |
```

## Critério de pronto

- `golib_dart/lib/io.dart` registrado em `STDLIB_SHIMS` (`g2d/config.py`), cobrindo os símbolos da
  linha `io` de `docs/stdlib-coverage.md` a partir dos mais usados; os ausentes continuam
  `Unsupported` (nunca chamada a função inexistente).
- Semântica com oráculo Go nos testes do golib_dart; fixture e2e em VM × JS × Wasm.
- Audit regerado e commitado.

## Notas

Interfaces `Reader`/`Writer`/`Closer`... como interfaces Go (implementáveis por tipos do grafo), `EOF`, `ReadFull`, `Copy`, `MultiWriter`, `Pipe` (depende do M4).
