part of '../../syscall.dart';

// Dados de controle de socket (`sockcmsg_unix.go`,
// `sockcmsg_unix_other.go` e `ztypes_linux_amd64.go` do Go 1.26.5): só
// bytes, sem syscall; o layout é o do linux/amd64 em toda plataforma
// (`Cmsghdr` de 16 bytes, alinhamento de 8).

/// `syscall.sizeofCmsghdr`.
const sizeofCmsghdr = 0x10;

/// `cmsgAlignOf` do linux/amd64: múltiplo do tamanho do ponteiro.
int _cmsgAlign(int n) => (n + 7) & ~7;

/// `syscall.CmsgLen(datalen)`.
Golang.Int cmsgLen(Golang.Int datalen) =>
    Golang.Int(_cmsgAlign(sizeofCmsghdr) + datalen.toInt());

/// `syscall.CmsgSpace(datalen)`.
Golang.Int cmsgSpace(Golang.Int datalen) =>
    Golang.Int(_cmsgAlign(sizeofCmsghdr) + _cmsgAlign(datalen.toInt()));

/// `syscall.Cmsghdr`.
final class Cmsghdr extends GoStruct<Cmsghdr> {
  Cmsghdr({Golang.Uint64? len, Golang.Int32? level, Golang.Int32? type})
    : len = len ?? Golang.Uint64(0),
      level = level ?? Golang.Int32(0),
      type = type ?? Golang.Int32(0);

  /// `(*Cmsghdr)(nil)` dentro de uma interface.
  static final Cmsghdr $nil = Cmsghdr()..$nilPtr = true;

  Golang.Uint64 len;
  Golang.Int32 level;
  Golang.Int32 type;

  @override
  String get $goType => 'syscall.Cmsghdr';
  @override
  List<String> get $valueMethods => const [];
  @override
  List<String> get $ptrMethods => const ['SetLen'];
  @override
  Cmsghdr $copy() => Cmsghdr(len: len, level: level, type: type);
  @override
  void $set(Cmsghdr o) {
    len = o.len;
    level = o.level;
    type = o.type;
  }

  @override
  List<Object?> get $fields => [len, level, type];
  @override
  List<String> get $fieldNames => const ['Len', 'Level', 'Type'];
  @override
  List<String> get $fieldTypes => const ['uint64', 'int32', 'int32'];

  /// `SetLen(length)`.
  void setLen(Golang.Int length) => len = Golang.Uint64(length.toInt());
}

/// `syscall.SocketControlMessage`: um cabeçalho e os dados (fatia do
/// buffer analisado, como no Go).
final class SocketControlMessage extends GoStruct<SocketControlMessage> {
  SocketControlMessage({Cmsghdr? header, Slice<Golang.Uint8>? data})
    : header = header ?? Cmsghdr(),
      data = data ?? Slice.nil(_byteElem);

  /// `(*SocketControlMessage)(nil)` dentro de uma interface.
  static final SocketControlMessage $nil = SocketControlMessage()
    ..$nilPtr = true;

  Cmsghdr header;
  Slice<Golang.Uint8> data;

  @override
  String get $goType => 'syscall.SocketControlMessage';
  @override
  List<String> get $valueMethods => const [];
  @override
  List<String> get $ptrMethods => const [];
  @override
  SocketControlMessage $copy() =>
      SocketControlMessage(header: header.$copy(), data: data);
  @override
  void $set(SocketControlMessage o) {
    header.$set(o.header);
    data = o.data;
  }

  @override
  List<Object?> get $fields => [header, data];
  @override
  List<String> get $fieldNames => const ['Header', 'Data'];
  @override
  List<String> get $fieldTypes => const ['syscall.Cmsghdr', '[]uint8'];
}

const _byteElem = Elem<Golang.Uint8>(
  1,
  Golang.Uint8.new,
  ofInt: Golang.Uint8.from,
);

final _scmElem = Elem<SocketControlMessage>(
  sizeofCmsghdr + 24,
  SocketControlMessage.new,
  pointers: true,
  value: true,
);

const _intElem = Elem<Golang.Int>(8, Golang.Int.new, ofInt: Golang.Int.from);

int _u32(Slice<Golang.Uint8> b, int at) =>
    b[at].toInt() |
    b[at + 1].toInt() << 8 |
    b[at + 2].toInt() << 16 |
    b[at + 3].toInt() << 24;

/// `syscall.ParseSocketControlMessage(b)`: as mensagens de controle de
/// `b`; cabeçalho inválido é `EINVAL`.
(Slice<SocketControlMessage>, GoError?) parseSocketControlMessage(
  Slice<Golang.Uint8> b,
) {
  var msgs = Slice<SocketControlMessage>.nil(_scmElem);
  var i = 0;
  final hdr = _cmsgAlign(sizeofCmsghdr);
  while (i + hdr <= b.length) {
    // `socketControlMessageHeaderAndData`: `Len` é um uint64 da ordem do
    // host (little-endian no amd64).
    final lo = _u32(b, i), hi = _u32(b, i + 4);
    if (hi != 0 || lo < sizeofCmsghdr || lo > b.length - i) {
      return (Slice<SocketControlMessage>.nil(_scmElem), einval);
    }
    final h = Cmsghdr(
      len: Golang.Uint64(lo),
      level: Golang.Int32(_u32(b, i + 8).toSigned(32)),
      type: Golang.Int32(_u32(b, i + 12).toSigned(32)),
    );
    msgs = msgs.append([
      SocketControlMessage(header: h, data: b.slice(i + hdr, i + lo)),
    ]);
    i += _cmsgAlign(lo);
  }
  return (msgs, null);
}

/// `syscall.UnixRights(fds...)`: uma mensagem `SCM_RIGHTS` com os fds.
Slice<Golang.Uint8> unixRights(Slice<Golang.Int> fds) {
  final datalen = fds.length * 4;
  final b = Slice.make(
    cmsgSpace(Golang.Int(datalen)).toInt(),
    cmsgSpace(Golang.Int(datalen)).toInt(),
    _byteElem,
  );
  void put32(int at, int v) {
    for (var k = 0; k < 4; k++) {
      b[at + k] = Golang.Uint8((v >> (8 * k)) & 0xff);
    }
  }

  put32(0, cmsgLen(Golang.Int(datalen)).toInt()); // `Len` (uint64)
  put32(8, sol_SOCKET);
  put32(12, scm_RIGHTS);
  final hdr = _cmsgAlign(sizeofCmsghdr);
  for (var i = 0; i < fds.length; i++) {
    put32(hdr + 4 * i, fds[i].toInt());
  }
  return b;
}

/// `syscall.ParseUnixRights(m)`: os fds de uma mensagem `SCM_RIGHTS`.
(Slice<Golang.Int>, GoError?) parseUnixRights(SocketControlMessage? m) {
  if (m == null || m.$nilPtr) nilDeref();
  if (m.header.level.toInt() != sol_SOCKET ||
      m.header.type.toInt() != scm_RIGHTS) {
    return (Slice<Golang.Int>.nil(_intElem), einval);
  }
  final n = m.data.length >> 2;
  final fds = Slice.make(n, n, _intElem);
  for (var i = 0, j = 0; i < m.data.length; i += 4) {
    fds[j++] = Golang.Int(_u32(m.data, i).toSigned(32));
  }
  return (fds, null);
}
