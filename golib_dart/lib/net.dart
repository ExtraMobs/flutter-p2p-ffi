/// Shim do pacote Go `net`: a parte sem rede (endereços e erros), porta fiel
/// de `ip.go`, `ipsock.go` (`SplitHostPort`/`JoinHostPort`), `mac.go`,
/// `net.go` (erros), `parse.go` (auxiliares) e dos tipos de endereço de
/// `tcpsock.go`, `udpsock.go`, `iprawsock.go` e `unixsock.go` do Go 1.26.
///
/// `IP`, `IPMask` e `HardwareAddr` têm a forma que o g2d gera para um tipo
/// nomeado sobre slice (`SHIM_NAMED_CLASSES` em `g2d/config.py`): subclasse
/// de [Slice] com `super.alias` e a vista `N$Ptr` para `*N`. As structs
/// (`IPNet`, `TCPAddr`, `OpError`...) seguem a forma de [GoStruct] das
/// structs geradas; as interfaces `Addr` e `Error` entram em
/// `SHIM_INTERFACES`.
// ignore_for_file: library_prefixes
library;

import 'dart:async';
import 'dart:typed_data';

import 'builtin.dart' hide Addr;
import 'context.dart' as context;
import 'encoding.dart' as encoding;
import 'errors.dart' as errors;
import 'fixed_types/golang.dart' as Golang;
import 'fmt.dart' as fmt show Stringer;
import 'fmt.dart' show Stringer;
import 'io.dart' as io;
import 'net/netip.dart' as netip;
import 'os.dart' as os;
import 'src/net/sys/sys.dart' as sys;
import 'strconv.dart' as strconv;
import 'time.dart' as time;

part 'src/net/ip.dart';
part 'src/net/ip_funcs.dart';
part 'src/net/ip_mask.dart';
part 'src/net/mac.dart';
part 'src/net/addrs.dart';
part 'src/net/errors.dart';
part 'src/net/addr_errors.dart';
part 'src/net/dns_error.dart';
part 'src/net/parse.dart';
part 'src/net/errno.dart';
part 'src/net/conn.dart';
part 'src/net/dial.dart';
part 'src/net/lookup.dart';
part 'src/net/interfaces.dart';

const _byteElem = Elem<Golang.Uint8>(
  1,
  Golang.Uint8.new,
  ofInt: Golang.Uint8.from,
);

typedef _Bytes = Slice<Golang.Uint8>;

Golang.String _gs(String s) => Golang.String.fromDart(s);

Golang.String _str(List<int> b) =>
    Golang.String.fromBytes(Uint8List.fromList(b));

List<int> _bytesOf(_Bytes b) => [for (final x in b.items) x.toInt()];

/// `make([]byte, n)` com o conteúdo [b].
_Bytes _bytes(List<int> b) =>
    Slice.of([for (final x in b) Golang.Uint8(x)], _byteElem);

/// `make([]byte, 0, n)`.
_Bytes _make0(int n) => Slice.make(0, n, _byteElem);

GoError _errNew(String s) => ErrorString(_gs(s));

/// `bytealg.IndexByteString(s, c)`.
int _indexByte(Golang.String s, int c) {
  for (var i = 0; i < s.length; i++) {
    if (s[i] == c) return i;
  }
  return -1;
}

/// `bytealg.LastIndexByteString(s, c)`.
int _lastIndexByte(Golang.String s, int c) {
  for (var i = s.length - 1; i >= 0; i--) {
    if (s[i] == c) return i;
  }
  return -1;
}
