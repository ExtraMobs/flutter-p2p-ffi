/// A libc pelo `sysffi` (VM no linux/amd64, F3). Fora do linux (macOS,
/// Windows) a VM também chega aqui, mas sem as constantes e os layouts
/// certos: tudo falha como em `stub.dart`.
///
/// `Read`/`Write` do Go bloqueiam a thread num fd bloqueante; aqui a
/// chamada da libc é leaf (não pode bloquear), então num fd bloqueante a
/// espera é um `poll` não leaf antes dela. ⚠️ Esse `poll` segura o isolate
/// inteiro (no Go, só a goroutine). Num fd não bloqueante (os sockets do
/// `net`, o `RawConn`), a chamada volta na hora, com `EAGAIN` se for o caso.
library;

import 'dart:ffi';
import 'dart:typed_data';

import '../../sysffi/sysffi.dart' as sf;
import 'stub.dart' as stub;

int sysSetsockopt(int fd, int level, int opt, Uint8List value) =>
    sf.sysFfiSupported
    ? sf.setsockopt(fd, level, opt, value)
    : stub.sysSetsockopt(fd, level, opt, value);

int sysGetsockopt(int fd, int level, int opt, Uint8List out) =>
    sf.sysFfiSupported
    ? sf.getsockopt(fd, level, opt, out)
    : stub.sysGetsockopt(fd, level, opt, out);

int sysRead(int fd, Uint8List buf) {
  if (!sf.sysFfiSupported) return stub.sysRead(fd, buf);
  final w = _waitBlocking(fd, sf.POLLIN);
  if (w < 0) return w;
  return sf.read(fd, buf);
}

int sysWrite(int fd, Uint8List data) {
  if (!sf.sysFfiSupported) return stub.sysWrite(fd, data);
  final w = _waitBlocking(fd, sf.POLLOUT);
  if (w < 0) return w;
  return sf.write(fd, data);
}

int sysSocketpair(int domain, int type, int proto, Int32List out) {
  if (!sf.sysFfiSupported) return stub.sysSocketpair(domain, type, proto, out);
  final sv = sf.libcAlloc<Int32>(2);
  try {
    final r = sf.socketpair(domain, type, proto, sv);
    if (r < 0) return r;
    out[0] = sv[0];
    out[1] = sv[1];
    return r;
  } finally {
    sf.libcAlloc.free(sv);
  }
}

int sysClose(int fd) => sf.sysFfiSupported ? sf.close(fd) : stub.sysClose(fd);

/// Num fd bloqueante, espera [events] com `poll` não leaf (sem prazo; o
/// `EINTR` repete). 0, ou `-errno` do `fcntl`/`poll` (`EBADF`...).
int _waitBlocking(int fd, int events) {
  final fl = sf.fcntl(fd, sf.F_GETFL);
  if (fl < 0) return fl;
  if (fl & sf.O_NONBLOCK != 0) return 0;
  final p = sf.libcAlloc<sf.PollFd>();
  try {
    p.ref
      ..fd = fd
      ..events = events;
    while (true) {
      final r = sf.poll(p, 1, -1);
      if (r == -sf.EINTR) continue;
      return r < 0 ? r : 0;
    }
  } finally {
    sf.libcAlloc.free(p);
  }
}
