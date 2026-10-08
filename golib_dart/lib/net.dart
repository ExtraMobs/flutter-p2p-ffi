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
///
/// `Pipe` (conexão em memória) em `src/net/pipe.dart`.
///
/// Rede real em `src/net/{conn,unix*,dial,lookup,interfaces}.dart` (D4);
/// o `socket()` do Go, `Control`, `SyscallConn` e o UDP da VM no linux pela
/// rede FFI em `src/net/{control,rawconn,udp_msg}.dart` (D10, E2–E7); IP
/// bruto (`ResolveIPAddr`, `IPConn`, `SOCK_RAW` pela rede FFI) em
/// `src/net/{iprawsock,iprawsock_sock,ipconn}.dart`; os erros de sistema
/// são `syscall.Errno` (shim `syscall`).
// ignore_for_file: library_prefixes
library;

import 'dart:async';
import 'dart:math' show Random;
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
import 'src/net/sys/dns_rr.dart' as dns;
import 'src/net/sys/sys.dart' as sys;
import 'src/syscall/vfd.dart' as vfd;
import 'strconv.dart' as strconv;
import 'sync.dart' as sync;
import 'syscall.dart' as syscall;
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
part 'src/net/unix.dart';
part 'src/net/unix_conn.dart';
part 'src/net/unix_msg.dart';
part 'src/net/dial.dart';
part 'src/net/iprawsock.dart';
part 'src/net/ipconn.dart';
part 'src/net/iprawsock_sock.dart';
part 'src/net/dial_parallel.dart';
part 'src/net/keepalive.dart';
part 'src/net/lookup.dart';
part 'src/net/lookup_ip.dart';
part 'src/net/lookup_port.dart';
part 'src/net/lookup_types.dart';
part 'src/net/lookup_go.dart';
part 'src/net/dns_conf.dart';
part 'src/net/dns_hosts.dart';
part 'src/net/dns_go.dart';
part 'src/net/addrselect.dart';
part 'src/net/interfaces.dart';
part 'src/net/control.dart';
part 'src/net/rawconn.dart';
part 'src/net/udp_msg.dart';
part 'src/net/pipe.dart';

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
