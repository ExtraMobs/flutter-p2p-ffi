# Shim do pacote `io` (parcial)

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** —

## Problema

O shim `io` existe com parte dos símbolos (`ByteReader`, `ByteWriter`, `Reader`, `StringWriter`, `Writer`, `eof`, `errClosedPipe`, `errNoProgress`, `errShortBuffer`, `errShortWrite`, `errUnexpectedEOF`); os que faltam viram
`Unsupported` `shim-simbolo:io.<nome>`. Somando as linhas abaixo: 204 ocorrências de pacote,
27 na fronteira (367 pacotes do grafo usam `io`).

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-simbolo:io.readFull` | 49 | 30 | 6 | `github.com/ipld/go-car/v2/internal/io` converter.go:18:1: símbolo sem shim: io.readFull |
| `shim-simbolo:io.ReadSeeker` | 21 | 11 | 3 | `github.com/ipld/go-car/v2/internal/io` converter.go:62:6: símbolo sem shim: io.ReadSeeker |
| `shim-simbolo:io.writeString` | 5 | 5 | 3 | `github.com/go-logfmt/logfmt` encode.go:239:6: símbolo sem shim: io.writeString |
| `shim-simbolo:io.Closer` | 81 | 51 | 2 | `github.com/libp2p/go-msgio` msgio.go:30:1: símbolo sem shim: io.Closer |
| `shim-simbolo:io.WriteCloser` | 21 | 15 | 2 | `github.com/multiformats/go-base32` base32.go:255:6: símbolo sem shim: io.WriteCloser |
| `shim-simbolo:io.ReaderAt` | 17 | 8 | 2 | `github.com/ipld/go-car/v2/internal/io` converter.go:72:6: símbolo sem shim: io.ReaderAt |
| `shim-simbolo:io.readAtLeast` | 7 | 3 | 2 | `github.com/multiformats/go-base32` base32.go:412:1: símbolo sem shim: io.readAtLeast |
| `shim-simbolo:io.ReadCloser` | 33 | 18 | 1 | `github.com/klauspost/compress/zstd` zip.go:31:6: símbolo sem shim: io.ReadCloser |
| `shim-simbolo:io.discard` | 15 | 12 | 1 | `google.golang.org/grpc/grpclog/internal` loggerv2.go:236:6: símbolo sem shim: io.discard |
| `shim-simbolo:io.readAll` | 16 | 8 | 1 | `github.com/grpc-ecosystem/grpc-gateway/v2/utilities` readerfactory.go:10:6: símbolo sem shim: io.readAll |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `io` | 367 | ✅ | Writer(155), Reader(147), Close(142), Write(125), EOF(122), Closer(79), Read(60), ErrUnexpectedEOF(55), ReadFull(53), ReadAll(40), Copy(36), Discard(26), LimitReader(25), ReadCloser(23), WriteString(23), SeekStart(22), ErrShortBuffer(18), Seek(18), WriteCloser(17), ByteReader(16), SeekCurrent(15), SeekEnd(14), ReadByte(13), ReadSeeker(13), ReaderAt(11), ReadWriteCloser(10), Seeker(10), CopyN(9), ReadAt(9), ErrClosedPipe(8), ErrShortWrite(8), LimitedReader(8), N(8), R(8), WriterAt(7), ReadWriter(6), WriterTo(6), NopCloser(5), TeeReader(5), WriteAt(5), ErrNoProgress(4), MultiReader(4), NewSectionReader(4), Pipe(4), ReaderFrom(4), CloseWithError(3), CopyBuffer(3), ReadAtLeast(3), ReadFrom(3), StringWriter(3), ByteScanner(2), MultiWriter(2), ReadSeekCloser(2), UnreadByte(2), ByteWriter(1), PipeReader(1), WriteSeeker(1), WriteTo(1) |
```

## Critério de pronto

- Os símbolos da linha `io` de `docs/stdlib-coverage.md`, a partir dos que mais destravam a
  fronteira; semântica com oráculo Go (fixture e2e em VM × JS × Wasm ou teste no golib_dart).
- `python -m g2d shims`; audit regerado e commitado.

## Notas

Feito: sentinelas (`EOF`...) e `Reader`/`Writer`/`ByteReader`/`ByteWriter`/`StringWriter` como
interfaces de shim; `bytes.Buffer`/`strings.Builder` as implementam. Baratos a seguir: `ReadFull`,
`ReadAll`, `Copy`/`CopyN`, `WriteString`, `MultiWriter`, `LimitReader`, `Discard`, `NopCloser`,
`Closer`/`ReadCloser`/`ReadWriter`... (porta do `io.go`, oráculo Go). `Pipe` depende de goroutines.
