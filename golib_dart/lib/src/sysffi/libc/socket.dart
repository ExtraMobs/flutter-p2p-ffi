part of '../libc.dart';

// Sockets: criação, endereços, envio/recepção e opções.

@Native<Int32 Function(Int32, Int32, Int32)>(symbol: 'socket', isLeaf: true)
external int _socket(int domain, int type, int protocol);

@Native<Int32 Function(Int32, Int32, Int32, Pointer<Int32>)>(
  symbol: 'socketpair',
  isLeaf: true,
)
external int _socketpair(int domain, int type, int protocol, Pointer<Int32> sv);

@Native<Int32 Function(Int32, Pointer<Uint8>, Uint32)>(
  symbol: 'bind',
  isLeaf: true,
)
external int _bind(int fd, Pointer<Uint8> sa, int len);

@Native<Int32 Function(Int32, Pointer<Uint8>, Uint32)>(
  symbol: 'connect',
  isLeaf: true,
)
external int _connect(int fd, Pointer<Uint8> sa, int len);

@Native<Int32 Function(Int32, Int32)>(symbol: 'listen', isLeaf: true)
external int _listen(int fd, int backlog);

@Native<Int32 Function(Int32, Pointer<Uint8>, Pointer<Uint32>, Int32)>(
  symbol: 'accept4',
  isLeaf: true,
)
external int _accept4(int fd, Pointer<Uint8> sa, Pointer<Uint32> len, int fl);

@Native<
  IntPtr Function(Int32, Pointer<Uint8>, Size, Int32, Pointer<Uint8>, Uint32)
>(symbol: 'sendto', isLeaf: true)
external int _sendto(
  int fd,
  Pointer<Uint8> buf,
  int n,
  int flags,
  Pointer<Uint8> sa,
  int salen,
);

@Native<
  IntPtr Function(
    Int32,
    Pointer<Uint8>,
    Size,
    Int32,
    Pointer<Uint8>,
    Pointer<Uint32>,
  )
>(symbol: 'recvfrom', isLeaf: true)
external int _recvfrom(
  int fd,
  Pointer<Uint8> buf,
  int n,
  int flags,
  Pointer<Uint8> sa,
  Pointer<Uint32> salen,
);

@Native<IntPtr Function(Int32, Pointer<MsgHdr>, Int32)>(
  symbol: 'sendmsg',
  isLeaf: true,
)
external int _sendmsg(int fd, Pointer<MsgHdr> msg, int flags);

@Native<IntPtr Function(Int32, Pointer<MsgHdr>, Int32)>(
  symbol: 'recvmsg',
  isLeaf: true,
)
external int _recvmsg(int fd, Pointer<MsgHdr> msg, int flags);

@Native<Int32 Function(Int32, Pointer<Uint8>, Pointer<Uint32>)>(
  symbol: 'getsockname',
  isLeaf: true,
)
external int _getsockname(int fd, Pointer<Uint8> sa, Pointer<Uint32> len);

@Native<Int32 Function(Int32, Pointer<Uint8>, Pointer<Uint32>)>(
  symbol: 'getpeername',
  isLeaf: true,
)
external int _getpeername(int fd, Pointer<Uint8> sa, Pointer<Uint32> len);

@Native<Int32 Function(Int32, Int32, Int32, Pointer<Uint8>, Uint32)>(
  symbol: 'setsockopt',
  isLeaf: true,
)
external int _setsockopt(int fd, int lvl, int opt, Pointer<Uint8> v, int len);

@Native<Int32 Function(Int32, Int32, Int32, Pointer<Uint8>, Pointer<Uint32>)>(
  symbol: 'getsockopt',
  isLeaf: true,
)
external int _getsockopt(
  int fd,
  int lvl,
  int opt,
  Pointer<Uint8> v,
  Pointer<Uint32> len,
);

@Native<Int32 Function(Int32, Int32)>(symbol: 'shutdown', isLeaf: true)
external int _shutdown(int fd, int how);

// ---------------------------------------------------------------- wrappers

int socket(int domain, int type, int protocol) {
  final e = _errnoLocation();
  final r = _socket(domain, type, protocol);
  return r < 0 ? -e.value : r;
}

/// Par de sockets em [sv] (2 `int32`); 0 ou `-errno`.
int socketpair(int domain, int type, int protocol, Pointer<Int32> sv) {
  final e = _errnoLocation();
  final r = _socketpair(domain, type, protocol, sv);
  return r < 0 ? -e.value : r;
}

int bind(int fd, Pointer<Uint8> sa, int len) {
  final e = _errnoLocation();
  final r = _bind(fd, sa, len);
  return r < 0 ? -e.value : r;
}

/// Num fd não bloqueante, `-EINPROGRESS` é o normal de TCP: espere `POLLOUT`
/// e leia `SO_ERROR`.
int connect(int fd, Pointer<Uint8> sa, int len) {
  final e = _errnoLocation();
  final r = _connect(fd, sa, len);
  return r < 0 ? -e.value : r;
}

int listen(int fd, int backlog) {
  final e = _errnoLocation();
  final r = _listen(fd, backlog);
  return r < 0 ? -e.value : r;
}

/// [sa]/[len] podem ser `nullptr`.
int accept4(int fd, Pointer<Uint8> sa, Pointer<Uint32> len, int flags) {
  final e = _errnoLocation();
  final r = _accept4(fd, sa, len, flags);
  return r < 0 ? -e.value : r;
}

/// Envia [buf] inteiro (para começar no meio, um `sublistView`); [sa] pode
/// ser `nullptr` (socket conectado).
int sendto(int fd, Uint8List buf, int flags, Pointer<Uint8> sa, int salen) {
  final e = _errnoLocation();
  final r = _sendto(fd, buf.address, buf.length, flags, sa, salen);
  return r < 0 ? -e.value : r;
}

/// Recebe até `buf.length` bytes; [sa]/[salen] podem ser `nullptr`.
int recvfrom(
  int fd,
  Uint8List buf,
  int flags,
  Pointer<Uint8> sa,
  Pointer<Uint32> salen,
) {
  final e = _errnoLocation();
  final r = _recvfrom(fd, buf.address, buf.length, flags, sa, salen);
  return r < 0 ? -e.value : r;
}

int sendmsg(int fd, Pointer<MsgHdr> msg, int flags) {
  final e = _errnoLocation();
  final r = _sendmsg(fd, msg, flags);
  return r < 0 ? -e.value : r;
}

int recvmsg(int fd, Pointer<MsgHdr> msg, int flags) {
  final e = _errnoLocation();
  final r = _recvmsg(fd, msg, flags);
  return r < 0 ? -e.value : r;
}

int getsockname(int fd, Pointer<Uint8> sa, Pointer<Uint32> len) {
  final e = _errnoLocation();
  final r = _getsockname(fd, sa, len);
  return r < 0 ? -e.value : r;
}

int getpeername(int fd, Pointer<Uint8> sa, Pointer<Uint32> len) {
  final e = _errnoLocation();
  final r = _getpeername(fd, sa, len);
  return r < 0 ? -e.value : r;
}

/// `setsockopt` com o valor em [v] (bytes na ordem do host): 0 ou `-errno`.
int setsockopt(int fd, int level, int opt, Uint8List v) {
  final e = _errnoLocation();
  final r = _setsockopt(fd, level, opt, v.address, v.length);
  return r < 0 ? -e.value : r;
}

/// `getsockopt` em [out]: o tamanho gravado ou `-errno`.
int getsockopt(int fd, int level, int opt, Uint8List out) {
  final l = Uint32List(1)..[0] = out.length;
  final e = _errnoLocation();
  final r = _getsockopt(fd, level, opt, out.address, l.address);
  return r < 0 ? -e.value : l[0];
}

/// `setsockopt` de um `int`: 0 ou `-errno`.
int setsockoptInt(int fd, int level, int opt, int value) {
  final v = Uint8List(4);
  ByteData.sublistView(v).setInt32(0, value, Endian.host);
  return setsockopt(fd, level, opt, v);
}

/// `getsockopt` de um `int`: `(valor, 0)` ou `(0, errno)`.
(int, int) getsockoptInt(int fd, int level, int opt) {
  final v = Uint8List(4);
  final r = getsockopt(fd, level, opt, v);
  if (r < 0) return (0, -r);
  return (ByteData.sublistView(v).getInt32(0, Endian.host), 0);
}

int shutdown(int fd, int how) {
  final e = _errnoLocation();
  final r = _shutdown(fd, how);
  return r < 0 ? -e.value : r;
}
