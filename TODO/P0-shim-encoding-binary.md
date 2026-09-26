# Shim do pacote `encoding/binary` (parcial)

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** —

## Problema

O shim `encoding/binary` existe com parte dos símbolos (`ByteOrder`, `bigEndian`, `littleEndian`); os que faltam viram
`Unsupported` `shim-simbolo:encoding/binary.<nome>`. Somando as linhas abaixo: 27 ocorrências de pacote,
8 na fronteira (142 pacotes do grafo usam `encoding/binary`).

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-simbolo:encoding/binary.putUvarint` | 26 | 13 | 5 | `github.com/golang/snappy` encode.go:20:6: símbolo sem shim: encoding/binary.putUvarint |
| `shim-simbolo:encoding/binary.uvarint` | 13 | 10 | 3 | `github.com/golang/snappy` decode.go:32:6: símbolo sem shim: encoding/binary.uvarint |
| `shim-simbolo:encoding/binary._bigEndian` | 2 | 2 | 0 | `github.com/libp2p/go-msgio` num.go:9:1: símbolo sem shim: encoding/binary._bigEndian |
| `shim-simbolo:encoding/binary.nativeEndian` | 4 | 1 | 0 | `golang.org/x/net/ipv6` control_rfc3542_unix.go:20:6: símbolo sem shim: encoding/binary.nativeEndian |
| `shim-simbolo:encoding/binary.appendUvarint` | 1 | 1 | 0 | `github.com/libp2p/go-libp2p/core/record` envelope.go:268:6: símbolo sem shim: encoding/binary.appendUvarint |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `encoding/binary` | 142 | ✅ | BigEndian(79), Uint32(67), PutUint32(57), Uint64(57), LittleEndian(56), PutUint64(51), Uint16(46), PutUint16(40), PutUvarint(22), MaxVarintLen64(18), Uvarint(18), Read(9), NativeEndian(6), AppendUvarint(5), MaxVarintLen32(5), AppendUint32(4), ReadUvarint(4), Write(4), PutVarint(3), Varint(3), AppendUint16(2), ByteOrder(2), AppendVarint(1), MaxVarintLen16(1) |
```

## Critério de pronto

- Os símbolos da linha `encoding/binary` de `docs/stdlib-coverage.md`, a partir dos que mais destravam a
  fronteira; semântica com oráculo Go (fixture e2e em VM × JS × Wasm ou teste no golib_dart).
- `python -m g2d shims`; audit regerado e commitado.

## Notas

Feito: `BigEndian`/`LittleEndian` (`uint16/32/64`, `putUint16/32/64`). Baratos a seguir:
`Uvarint`/`PutUvarint`/`AppendUvarint`/`Varint`/`PutVarint`/`AppendVarint` e `AppendUint16/32/64`
(multi-retorno em record, fixture em `tests/golden/byteorder`); `ReadUvarint`, `Read`, `Write`
dependem de `io` (`P0-shim-io.md`); `NativeEndian` e `ByteOrder` como tipo de parâmetro exigem o
`ByteOrder` exposto como interface de shim.
