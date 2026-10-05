/// Shim do pacote Go `net/netip`: porta fiel de `netip.go` e `uint128.go` do
/// Go 1.26.
///
/// `Addr`, `AddrPort` e `Prefix` são structs por valor ([GoStruct]):
/// comparáveis com `==` e chave de map, como no Go. O `uint128` guarda as
/// duas metades em [Golang.Uint64] (aritmética de 64 bits igual em VM, JS e
/// Wasm). A zona (`unique.Handle[addrDetail]` no Go) é um [_Z] comparado por
/// valor; `z0` é `null`.
// ignore_for_file: library_prefixes
library;

import 'dart:typed_data';

import '../builtin.dart' hide Addr;
import '../encoding.dart' as encoding;
import '../fixed_types/golang.dart' as Golang;
import '../fmt.dart' show Stringer;
import '../strconv.dart' as strconv;

part '../src/net/netip/uint128.dart';
part '../src/net/netip/addr.dart';
part '../src/net/netip/addr_from.dart';
part '../src/net/netip/parse.dart';
part '../src/net/netip/format.dart';
part '../src/net/netip/addr_port.dart';
part '../src/net/netip/prefix.dart';

const _byteElem = Elem<Golang.Uint8>(
  1,
  Golang.Uint8.new,
  ofInt: Golang.Uint8.from,
);

typedef _Bytes = Slice<Golang.Uint8>;

Golang.String _gs(String s) => Golang.String.fromDart(s);

Golang.String _str(List<int> b) =>
    Golang.String.fromBytes(Uint8List.fromList(b));

/// `append(b, bytes...)`: um `append` do Go (mesmo crescimento de cap).
_Bytes _app(_Bytes b, List<int> bytes) =>
    b.append([for (final x in bytes) Golang.Uint8(x)]);

/// `make([]byte, 0, n)`.
_Bytes _make0(int n) => Slice.make(0, n, _byteElem);

GoError _errNew(String s) => ErrorString(_gs(s));

/// `[N]byte` a partir de inteiros.
GoArray<Golang.Uint8> _array(List<int> b) =>
    GoArray.of([for (final x in b) Golang.Uint8(x)], _byteElem);

/// `byteorder.BEUint64(b[off:off+8])` sobre uma lista de bytes.
Golang.Uint64 _beUint64(List<int> b, int off) =>
    (Golang.Uint64(_be32(b, off)) << 32) | Golang.Uint64(_be32(b, off + 4));

/// Os 4 bytes de [b] a partir de [off], big-endian (sem bitwise de 32 bits:
/// igual no JS).
int _be32(List<int> b, int off) =>
    b[off] * 0x1000000 + b[off + 1] * 0x10000 + b[off + 2] * 0x100 + b[off + 3];

/// `byteorder.BEPutUint64`: os 8 bytes big-endian de [v].
List<int> _beBytes64(Golang.Uint64 v) => [
  (v.$hi >> 24) & 0xff,
  (v.$hi >> 16) & 0xff,
  (v.$hi >> 8) & 0xff,
  v.$hi & 0xff,
  (v.$lo >> 24) & 0xff,
  (v.$lo >> 16) & 0xff,
  (v.$lo >> 8) & 0xff,
  v.$lo & 0xff,
];

/// Os 4 bytes big-endian de `uint32(v)`.
List<int> _beBytes32(Golang.Uint64 v) => [
  (v.$lo >> 24) & 0xff,
  (v.$lo >> 16) & 0xff,
  (v.$lo >> 8) & 0xff,
  v.$lo & 0xff,
];

List<int> _bytesOf(_Bytes b) => [for (final x in b.items) x.toInt()];
