# Shim do pacote `encoding/binary`

- **Prioridade:** P0 · **Área:** shim
- **Depende de:** —

## Problema

Sem shim, 142 pacotes do grafo do kubo que usam `encoding/binary` não transpilam (`shim-ausente:encoding/binary`).
São 24 símbolos distintos.

## Prova

```text
$ python -m g2d audit github.com/ipfs/kubo/cmd/ipfs -C tests/corpus/kubo

docs/audit.md (ranking):
| código | ocorrências | pacotes | na fronteira | exemplo |
| `shim-ausente:encoding/binary` | 241 | 74 | 19 | `filippo.io/bigmod` nat.go:214:6: pacote sem shim/transpilação: encoding/binary |
```

```text
docs/stdlib-coverage.md:
| pacote | pacotes do grafo | shim | símbolos |
| `encoding/binary` | 142 | ❌ | BigEndian(79), Uint32(67), PutUint32(57), Uint64(57), LittleEndian(56), PutUint64(51), Uint16(46), PutUint16(40), PutUvarint(22), MaxVarintLen64(18), Uvarint(18), Read(9), NativeEndian(6), AppendUvarint(5), MaxVarintLen32(5), AppendUint32(4), ReadUvarint(4), Write(4), PutVarint(3), Varint(3), AppendUint16(2), ByteOrder(2), AppendVarint(1), MaxVarintLen16(1) |
```

## Critério de pronto

- `golib_dart/lib/encoding/binary.dart` registrado em `STDLIB_SHIMS` (`g2d/config.py`), cobrindo os símbolos da
  linha `encoding/binary` de `docs/stdlib-coverage.md` a partir dos mais usados; os ausentes continuam
  `Unsupported` (nunca chamada a função inexistente).
- Semântica com oráculo Go nos testes do golib_dart; fixture e2e em VM × JS × Wasm.
- Audit regerado e commitado.

## Notas

`BigEndian`/`LittleEndian` (`ByteOrder`), `Uvarint`/`PutUvarint`, `AppendUvarint`.
