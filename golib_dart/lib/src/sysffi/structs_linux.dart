/// Layouts do linux/amd64 (glibc) das structs de socket, e a conversão entre
/// `sockaddr_*` e o [Sockaddr] neutro.
///
/// ⚠️ Só linux (decisão F3). No macOS (E8) mudam: `sin_len`/`sun_len` no
/// começo dos `sockaddr_*` (família em 1 byte), `sun_path` de 104 bytes,
/// `cmsghdr` com `socklen_t` e alinhamento a 4, `msghdr` com `int` nos
/// comprimentos. Entram num `structs_darwin.dart` com a mesma API
/// ([encodeSockaddr], [decodeSockaddr], [cmsgSpace]...).
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'consts_linux.dart';

/// `struct sockaddr_in` (16 bytes). Porta e endereço na ordem da rede.
final class SockaddrIn extends Struct {
  @Uint16()
  external int family;
  @Array(2)
  external Array<Uint8> port;
  @Array(4)
  external Array<Uint8> addr;
  @Array(8)
  external Array<Uint8> zero;
}

/// `struct sockaddr_in6` (28 bytes).
final class SockaddrIn6 extends Struct {
  @Uint16()
  external int family;
  @Array(2)
  external Array<Uint8> port;
  @Uint32()
  external int flowinfo;
  @Array(16)
  external Array<Uint8> addr;
  @Uint32()
  external int scopeId;
}

/// `struct sockaddr_un` (110 bytes; `sun_path` de 108).
final class SockaddrUn extends Struct {
  @Uint16()
  external int family;
  @Array(108)
  external Array<Uint8> path;
}

/// `struct iovec`.
final class IoVec extends Struct {
  external Pointer<Void> base;
  @Size()
  external int len;
}

/// `struct msghdr` (56 bytes; `msg_iovlen` e `msg_controllen` são `size_t`
/// na glibc).
final class MsgHdr extends Struct {
  external Pointer<Void> name;
  @Uint32()
  external int namelen;
  external Pointer<IoVec> iov;
  @Size()
  external int iovlen;
  external Pointer<Void> control;
  @Size()
  external int controllen;
  @Int32()
  external int flags;
}

/// `struct cmsghdr` (16 bytes; `cmsg_len` é `size_t`).
final class CmsgHdr extends Struct {
  @Size()
  external int len;
  @Int32()
  external int level;
  @Int32()
  external int type;
}

/// `struct pollfd`.
final class PollFd extends Struct {
  @Int32()
  external int fd;
  @Int16()
  external int events;
  @Int16()
  external int revents;
}

/// `struct ifaddrs` (`ifa_ifu` é a união broadaddr/dstaddr).
final class IfAddrs extends Struct {
  external Pointer<IfAddrs> next;
  external Pointer<Uint8> name;
  @Uint32()
  external int flags;
  external Pointer<Uint8> addr;
  external Pointer<Uint8> netmask;
  external Pointer<Uint8> ifu;
  external Pointer<Void> data;
}

/// `struct ucred` (resposta do `SO_PEERCRED`).
final class UCred extends Struct {
  @Int32()
  external int pid;
  @Uint32()
  external int uid;
  @Uint32()
  external int gid;
}

/// `struct linger`.
final class Linger extends Struct {
  @Int32()
  external int onoff;
  @Int32()
  external int linger;
}

/// `sizeof(struct sockaddr_storage)`: buffer que cabe qualquer endereço.
const sockaddrStorageSize = 128;

/// Tamanho máximo do `sun_path`.
const sunPathMax = 108;

/// Alinhamento dos dados de controle (`CMSG_ALIGN`: `size_t`).
int cmsgAlign(int n) => (n + 7) & ~7;

/// `CMSG_SPACE(n)`.
int cmsgSpace(int n) => cmsgAlign(sizeOf<CmsgHdr>()) + cmsgAlign(n);

/// `CMSG_LEN(n)`.
int cmsgLen(int n) => cmsgAlign(sizeOf<CmsgHdr>()) + n;

/// `CMSG_DATA` de [h].
Pointer<Uint8> cmsgData(Pointer<CmsgHdr> h) =>
    Pointer<Uint8>.fromAddress(h.address + cmsgAlign(sizeOf<CmsgHdr>()));

/// Endereço de socket neutro (sem layout): IPv4/IPv6 ([ip] de 4/16 bytes,
/// [port], [scopeId]) ou Unix ([path]: caminho, `@nome` abstrato, `''` sem
/// nome).
final class Sockaddr {
  Sockaddr.inet(this.ip, this.port, {this.scopeId = 0})
    : family = ip.length == 4 ? AF_INET : AF_INET6,
      path = null {
    if (ip.length != 4 && ip.length != 16) {
      throw ArgumentError.value(ip.length, 'ip.length', 'esperado 4 ou 16');
    }
  }

  Sockaddr.unix(String this.path)
    : family = AF_UNIX,
      ip = Uint8List(0),
      port = 0,
      scopeId = 0;

  /// Família sem endereço reconhecido (o `getsockname` de outra família).
  Sockaddr.other(this.family)
    : ip = Uint8List(0),
      port = 0,
      scopeId = 0,
      path = null;

  final int family;
  final Uint8List ip;
  final int port;
  final int scopeId;
  final String? path;

  @override
  String toString() => switch (family) {
    AF_UNIX => 'unix:$path',
    AF_INET || AF_INET6 =>
      'inet:${ip.join(ip.length == 4 ? '.' : ',')}'
          '${scopeId == 0 ? '' : '%$scopeId'}:$port',
    _ => 'family:$family',
  };
}

/// Grava [a] em [out] (pelo menos [sockaddrStorageSize] bytes) no layout do
/// kernel e devolve o `socklen_t`; `-EINVAL` se o caminho Unix não cabe
/// (como o Go: nome não abstrato precisa do NUL final).
int encodeSockaddr(Sockaddr a, Pointer<Uint8> out) {
  final b = out.asTypedList(sockaddrStorageSize);
  b.fillRange(0, sockaddrStorageSize, 0);
  final d = ByteData.sublistView(b);
  d.setUint16(0, a.family, Endian.host);
  switch (a.family) {
    case AF_INET:
      d.setUint16(2, a.port, Endian.big);
      b.setRange(4, 8, a.ip);
      return sizeOf<SockaddrIn>();
    case AF_INET6:
      d.setUint16(2, a.port, Endian.big);
      b.setRange(8, 24, a.ip);
      d.setUint32(24, a.scopeId, Endian.host);
      return sizeOf<SockaddrIn6>();
    case AF_UNIX:
      final name = utf8.encode(a.path!);
      final n = name.length;
      final abstract = n > 0 && (name[0] == 0x40 /* @ */ || name[0] == 0);
      if (n > sunPathMax || (n == sunPathMax && !abstract)) return -EINVAL;
      b.setRange(2, 2 + n, name);
      if (abstract) {
        b[2] = 0;
        return 2 + n;
      }
      // `sun_path` com NUL final; sem nome, só a família (autobind).
      return n == 0 ? 2 : 2 + n + 1;
  }
  throw ArgumentError.value(a.family, 'family');
}

/// Lê o `sockaddr` de [len] bytes em [p] (o que `accept4`, `getsockname`,
/// `recvfrom`... devolveram).
Sockaddr decodeSockaddr(Pointer<Uint8> p, int len) {
  if (len < 2) return Sockaddr.unix('');
  final b = p.asTypedList(len);
  final d = ByteData.sublistView(b);
  final family = d.getUint16(0, Endian.host);
  switch (family) {
    case AF_INET when len >= 8:
      return Sockaddr.inet(
        Uint8List.fromList(b.sublist(4, 8)),
        d.getUint16(2, Endian.big),
      );
    case AF_INET6 when len >= 28:
      return Sockaddr.inet(
        Uint8List.fromList(b.sublist(8, 24)),
        d.getUint16(2, Endian.big),
        scopeId: d.getUint32(24, Endian.host),
      );
    case AF_UNIX:
      if (len <= 2) return Sockaddr.unix('');
      final raw = b.sublist(2, len);
      if (raw[0] == 0) {
        // Abstrato: o nome é tudo depois do NUL inicial (pode ter NULs).
        return Sockaddr.unix(
          '@${utf8.decode(raw.sublist(1), allowMalformed: true)}',
        );
      }
      final z = raw.indexOf(0);
      return Sockaddr.unix(
        utf8.decode(z < 0 ? raw : raw.sublist(0, z), allowMalformed: true),
      );
  }
  return Sockaddr.other(family);
}
