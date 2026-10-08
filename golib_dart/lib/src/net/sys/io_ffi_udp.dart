part of 'sys_io.dart';

// UDP pela rede FFI (VM no linux, etapa E7 e decisão F2): o socket nasce no
// `net` pela ordem do Go (`IPV6_V6ONLY` e `SO_BROADCAST` antes do `bind`,
// `Control` antes do `bind`), e aqui vira a conexão UDP do motor sobre o
// `FfiSock` (`ffi/sock.dart`, o mesmo `netFD` dos sockets Unix e do IP
// bruto): `recvfrom`/`sendto` sobre o poller do FFI, `read`/`write` no
// socket conectado (o kernel filtra o par e entrega o `ECONNREFUSED` do
// ICMP), `recvmsg`/`sendmsg` com dados de controle (`ReadMsgUDP`/
// `WriteMsgUDP`) e o fd real do `SyscallConn`.

final class _FfiUdpConn implements SysUdpConn, SysUdpMsg, SysRawFd, SysWritev {
  _FfiUdpConn(this._s);

  final ffi.FfiSock _s;

  @override
  int get family => _s.family;

  @override
  SysAddr get local => _s.localAddr ?? SysAddr(Uint8List(0), 0);

  @override
  SysAddr? get remote => _s.remoteAddr;

  @override
  int get rawFd => _s.rawFd;

  @override
  bool get rawReadExpired => _s.rawReadExpired;

  @override
  bool get rawWriteExpired => _s.rawWriteExpired;

  @override
  Future<void> rawWaitRead() => _s.rawWaitRead();

  @override
  Future<void> rawWaitWrite() => _s.rawWaitWrite();

  @override
  Future<(int, SysAddr)> readFrom(Uint8List buf) async {
    final (n, from) = await _s.readFrom(buf);
    return (n, from ?? SysAddr(Uint8List(0), 0));
  }

  @override
  Future<int> writeTo(Uint8List data, SysAddr to) => _s.writeTo(data, to);

  @override
  Future<int> recv(Uint8List buf) => _s.read(buf);

  @override
  Future<int> send(Uint8List data) => _s.write(data);

  @override
  Future<int> writev(List<Uint8List> chunks) => _s.writev(chunks);

  @override
  Future<(int, int, int, SysAddr?)> readMsg(Uint8List buf, Uint8List oob) =>
      _s.readMsg(buf, oob);

  @override
  Future<(int, int)> writeMsg(Uint8List data, Uint8List oob, SysAddr? to) =>
      _s.writeMsg(data, oob, to);

  @override
  void close() => _s.close();

  @override
  set readDeadline(DateTime? d) => _s.readDeadline = d;

  @override
  set writeDeadline(DateTime? d) => _s.writeDeadline = d;
}
