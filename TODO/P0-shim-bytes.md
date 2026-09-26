# Shim do pacote `bytes` (parcial)

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** —

## Problema

O shim `bytes` existe com parte dos símbolos (`compare`, `count`, `equal`, `hasPrefix`, `hasSuffix`, `index`, `indexByte`, `split`, `trimLeft`); os que faltam viram
`Unsupported` `shim-simbolo:bytes.<nome>`. Somando as linhas abaixo: 122 ocorrências de pacote,
32 na fronteira (224 pacotes do grafo usam `bytes`).

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-simbolo:bytes.Buffer` | 88 | 56 | 15 | `github.com/cockroachdb/pebble/v2/internal/treeprinter` tree_printer.go:23:1: símbolo sem shim: bytes.Buffer |
| `shim-simbolo:bytes.Reader` | 50 | 23 | 6 | `github.com/quic-go/quic-go/quicvarint` io.go:14:5: símbolo sem shim: bytes.Reader |
| `shim-simbolo:bytes.trimSuffix` | 5 | 3 | 1 | `github.com/klauspost/compress/s2` index.go:547:6: símbolo sem shim: bytes.trimSuffix |
| `shim-simbolo:bytes.trimRight` | 3 | 3 | 1 | `github.com/getsentry/sentry-go/internal/traceparser` parser.go:22:1: símbolo sem shim: bytes.trimRight |
| `shim-simbolo:bytes.trimSpace` | 3 | 3 | 1 | `github.com/kr/text` wrap.go:23:6: símbolo sem shim: bytes.trimSpace |
| `shim-simbolo:bytes.join` | 4 | 2 | 1 | `golang.org/x/text/internal/language` parse.go:351:6: símbolo sem shim: bytes.join |
| `shim-simbolo:bytes.lastIndexByte` | 2 | 2 | 1 | `github.com/getsentry/sentry-go/internal/traceparser` parser.go:165:1: símbolo sem shim: bytes.lastIndexByte |
| `shim-simbolo:bytes.errTooLarge` | 2 | 1 | 1 | `github.com/syndtr/goleveldb/leveldb/util` buffer.go:21:1: símbolo sem shim: bytes.errTooLarge |
| `shim-simbolo:bytes.repeat` | 2 | 1 | 1 | `github.com/decred/dcrd/dcrec/secp256k1/v4` nonce.go:31:2: símbolo sem shim: bytes.repeat |
| `shim-simbolo:bytes.runes` | 2 | 1 | 1 | `golang.org/x/text/unicode/bidi` bidi.go:76:1: símbolo sem shim: bytes.runes |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `bytes` | 224 | ✅ | Buffer(110), Equal(76), Bytes(57), NewReader(52), String(48), Len(38), Write(33), WriteString(31), Reset(27), NewBuffer(26), Compare(24), WriteByte(22), HasPrefix(16), IndexByte(15), Index(8), Reader(8), Split(7), TrimSpace(7), HasSuffix(6), WriteTo(6), Clone(5), Next(5), Read(5), WriteRune(5), Count(4), CutPrefix(4), Join(4), LastIndexByte(4), NewBufferString(4), ReadFrom(4), TrimRight(4), Truncate(4), Contains(3), Grow(3), ReadByte(3), Seek(3), TrimLeft(3), TrimPrefix(3), TrimSuffix(3), ContainsAny(2), IndexAny(2), LastIndex(2), Repeat(2), Replace(2), SplitN(2), AvailableBuffer(1), ContainsFunc(1), ContainsRune(1), Cut(1), EqualFold(1), ErrTooLarge(1), IndexFunc(1), Map(1), ReadAt(1), ReplaceAll(1), Runes(1), SplitSeq(1), ToLower(1), Trim(1) |
```

## Critério de pronto

- Os símbolos da linha `bytes` de `docs/stdlib-coverage.md`, a partir dos que mais destravam a
  fronteira; semântica com oráculo Go (fixture e2e em VM × JS × Wasm ou teste no golib_dart).
- `python -m g2d shims`; audit regerado e commitado.

## Notas

`Buffer`, `Reader`, `NewReader`, `NewBuffer` são tipos struct de shim:
`P1-design-structs-de-shim.md`. `TrimSpace`, `ToLower`/`ToUpper`, `EqualFold`, `Fields` dependem de
tabelas Unicode do Go (gerar como `src/unicode/isprint.dart`, conferidas por teste). O resto
(`LastIndexByte`, `TrimRight`, `TrimPrefix`/`TrimSuffix`, `CutPrefix`, `Join`, `Contains`, `Repeat`,
`Clone`...) é barato: porta do fonte do Go, fixture em `tests/golden/bytesstrings`.
