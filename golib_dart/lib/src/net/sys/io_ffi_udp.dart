part of 'sys_io.dart';

// UDP pela rede FFI (VM no linux, etapa E7 e decisão F2): o socket nasce no
// `net` pela ordem do Go (`IPV6_V6ONLY` e `SO_BROADCAST` antes do `bind`,
// `Control` antes do `bind`), e aqui vira a conexão: `recvfrom`/`sendto`
// sobre o poller do FFI, `read`/`write` no socket conectado (o kernel
// filtra o par e entrega o `ECONNREFUSED` do ICMP), `recvmsg`/`sendmsg` com
// dados de controle (`ReadMsgUDP`/`WriteMsgUDP`) e o fd real do
// `SyscallConn`.

final class _FfiUdpConn implements SysUdpConn, SysUdpMsg, SysRawFd {
  _FfiUdpConn(this._fd, this.family)
    : local = _fd.localAddr() == null
          ? SysAddr(Uint8List(0), 0)
          : _sysAddrIn(_fd.localAddr()!),
      remote = _fd.peerAddr() == null ? null : _sysAddrIn(_fd.peerAddr()!);

  final ffi.FfiFd _fd;

  @override
  final int family;

  @override
  final SysAddr local;

  @override
  final SysAddr? remote;

  @override
  int get rawFd => _fd.fd;

  @override
  bool get rawReadExpired => _fd.readExpired;

  @override
  bool get rawWriteExpired => _fd.writeExpired;

  @override
  Future<void> rawWaitRead() => _fd.waitRead();

  @override
  Future<void> rawWaitWrite() => _fd.waitWrite();

  @override
  Future<(int, SysAddr)> readFrom(Uint8List buf) => _ffiIo(() async {
    final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
    final len = sf.libcAlloc<Uint32>();
    try {
      final n = await _fd.io(sf.POLLIN, 'recvfrom', (fd) {
        len.value = sf.sockaddrStorageSize;
        return sf.recvfrom(fd, buf, 0, sa, len);
      });
      return (n, _sysAddrIn(sf.decodeSockaddr(sa, len.value)));
    } finally {
      sf.libcAlloc.free(sa);
      sf.libcAlloc.free(len);
    }
  });

  @override
  Future<int> writeTo(Uint8List data, SysAddr to) => _ffiIo(() async {
    final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
    try {
      final len = sf.encodeSockaddr(_sockaddrIn(to, family), sa);
      if (len < 0) throw ffi.FfiErrno('sendto', -len);
      return await _fd.io(
        sf.POLLOUT,
        'sendto',
        (fd) => sf.sendto(fd, data, sf.MSG_NOSIGNAL, sa, len),
      );
    } finally {
      sf.libcAlloc.free(sa);
    }
  });

  @override
  Future<int> recv(Uint8List buf) =>
      _ffiIo(() => _fd.io(sf.POLLIN, 'read', (fd) => sf.read(fd, buf)));

  @override
  Future<int> send(Uint8List data) => _ffiIo(
    () => _fd.io(
      sf.POLLOUT,
      'write',
      (fd) => sf.sendto(fd, data, sf.MSG_NOSIGNAL, nullptr, 0),
    ),
  );

  @override
  Future<(int, int, int, SysAddr?)> readMsg(Uint8List buf, Uint8List oob) =>
      _ffiIo(() async {
        final m = _Msg(buf.length, oob.length);
        try {
          final n = await _fd.io(sf.POLLIN, 'recvmsg', (fd) {
            m.reset(withName: true);
            return sf.recvmsg(fd, m.hdr, 0);
          });
          buf.setRange(0, n < buf.length ? n : buf.length, m.data);
          final oobn = m.hdr.ref.controllen;
          oob.setRange(0, oobn, m.control);
          final nameLen = m.hdr.ref.namelen;
          return (
            n,
            oobn,
            m.hdr.ref.flags,
            nameLen == 0
                ? null
                : _sysAddrIn(sf.decodeSockaddr(m.name, nameLen)),
          );
        } finally {
          m.free();
        }
      });

  @override
  Future<(int, int)> writeMsg(Uint8List data, Uint8List oob, SysAddr? to) =>
      _ffiIo(() async {
        final m = _Msg(data.length, oob.length);
        try {
          m.data.setAll(0, data);
          m.control.setAll(0, oob);
          var nameLen = 0;
          if (to != null) {
            nameLen = sf.encodeSockaddr(_sockaddrIn(to, family), m.name);
            if (nameLen < 0) throw ffi.FfiErrno('sendmsg', -nameLen);
          }
          final n = await _fd.io(sf.POLLOUT, 'sendmsg', (fd) {
            m.reset(withName: to != null, nameLen: nameLen);
            return sf.sendmsg(fd, m.hdr, sf.MSG_NOSIGNAL);
          });
          return (n, oob.length);
        } finally {
          m.free();
        }
      });

  @override
  void close() => _fd.close();

  @override
  set readDeadline(DateTime? d) => _fd.readDeadline = d;

  @override
  set writeDeadline(DateTime? d) => _fd.writeDeadline = d;
}

/// `msghdr` de um `iovec` só, com dados, controle e endereço em memória
/// nativa (o `msghdr` guarda ponteiros: um `Uint8List` do heap do Dart não
/// pode ficar lá dentro).
final class _Msg {
  _Msg(this._dataLen, this._ctlLen)
    : _mem = sf.libcAlloc<Uint8>(
        sf.sockaddrStorageSize +
            sizeOf<sf.IoVec>() +
            sizeOf<sf.MsgHdr>() +
            _dataLen +
            _ctlLen +
            32,
      ) {
    var at = _mem.address;
    name = Pointer<Uint8>.fromAddress(at);
    at = _align(at + sf.sockaddrStorageSize);
    _iov = Pointer<sf.IoVec>.fromAddress(at);
    at = _align(at + sizeOf<sf.IoVec>());
    hdr = Pointer<sf.MsgHdr>.fromAddress(at);
    at = _align(at + sizeOf<sf.MsgHdr>());
    _ctl = Pointer<Uint8>.fromAddress(at);
    at = _align(at + _ctlLen);
    _data = Pointer<Uint8>.fromAddress(at);
  }

  final int _dataLen;
  final int _ctlLen;
  final Pointer<Uint8> _mem;
  late final Pointer<Uint8> name;
  late final Pointer<sf.IoVec> _iov;
  late final Pointer<sf.MsgHdr> hdr;
  late final Pointer<Uint8> _ctl;
  late final Pointer<Uint8> _data;

  Uint8List get data => _data.asTypedList(_dataLen);
  Uint8List get control => _ctl.asTypedList(_ctlLen);

  /// Prepara o `msghdr` para uma tentativa (o `recvmsg` muda os tamanhos).
  void reset({required bool withName, int nameLen = 0}) {
    _iov.ref
      ..base = _data.cast()
      ..len = _dataLen;
    hdr.ref
      ..name = withName ? name.cast() : nullptr
      ..namelen = withName
          ? (nameLen == 0 ? sf.sockaddrStorageSize : nameLen)
          : 0
      ..iov = _iov
      ..iovlen = 1
      ..control = _ctlLen == 0 ? nullptr : _ctl.cast()
      ..controllen = _ctlLen
      ..flags = 0;
  }

  void free() => sf.libcAlloc.free(_mem);

  static int _align(int a) => (a + 7) & ~7;
}
