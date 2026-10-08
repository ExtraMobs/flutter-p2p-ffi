/// Chamadas da libc por `@Native`, resolvidas do próprio processo (JIT e
/// AOT; sem `package:ffi` nem biblioteca carregada à mão).
///
/// **Convenção:** toda função devolve o resultado da chamada (`>= 0`) ou
/// `-errno` (errno do linux, `int` cru). Nada lança por errno.
///
/// **Regra do errno (estrutural):** toda chamada que precisa de errno é
/// *leaf* e o ponteiro do `__errno_location` é pego **antes** dela; o errno
/// é lido logo depois, sem alocação nem outra chamada no meio:
///
/// ```dart
/// final e = _errnoLocation();
/// final r = _socket(...);
/// return r < 0 ? -e.value : r;
/// ```
///
/// Uma chamada leaf não passa por safepoint, então nem o GC nem outro código
/// da VM roda entre ela e a leitura e troca o errno da thread. Medido no
/// plano (D4/FFI): 0 errno errado com o ponteiro prévio; 1 em 1,1M sem ele;
/// 32 com alocação no meio. Só [close] e [poll] não são leaf: o `poll`
/// bloqueia (o poller roda num isolate auxiliar e só trata `EINTR`) e o
/// `close` bloqueia com `SO_LINGER > 0`; o errno deles é o melhor esforço.
///
/// Leaf exige fd não bloqueante (`SOCK_NONBLOCK`): uma chamada leaf que
/// bloqueia trava o isolate sem safepoint.
///
/// Buffers de dados vão direto do `Uint8List` (`TypedData.address`, só em
/// chamada leaf), sem cópia; para começar no meio, passe um
/// `Uint8List.sublistView`.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'alloc.dart';
import 'structs_linux.dart';

part 'libc/socket.dart';

// ---------------------------------------------------------------- natives

@Native<Pointer<Int32> Function()>(symbol: '__errno_location', isLeaf: true)
external Pointer<Int32> _errnoLocation();

/// Não leaf: bloqueia com `SO_LINGER > 0`.
@Native<Int32 Function(Int32)>(symbol: 'close')
external int _close(int fd);

@Native<Int32 Function(Pointer<Uint8>)>(symbol: 'unlink', isLeaf: true)
external int _unlink(Pointer<Uint8> path);

@Native<Int32 Function(Pointer<Uint8>, Pointer<Uint8>)>(
  symbol: 'link',
  isLeaf: true,
)
external int _link(Pointer<Uint8> from, Pointer<Uint8> to);

@Native<Int32 Function(Pointer<Uint8>, Pointer<Uint8>)>(
  symbol: 'rename',
  isLeaf: true,
)
external int _rename(Pointer<Uint8> from, Pointer<Uint8> to);

@Native<Int32 Function(Int32, Int32, VarArgs<(Int64,)>)>(
  symbol: 'fcntl',
  isLeaf: true,
)
external int _fcntl(int fd, int cmd, int arg);

/// Não leaf: bloqueia até o prazo.
@Native<Int32 Function(Pointer<PollFd>, Uint64, Int32)>(symbol: 'poll')
external int _poll(Pointer<PollFd> fds, int n, int timeoutMs);

@Native<Int32 Function(Uint32, Int32)>(symbol: 'eventfd', isLeaf: true)
external int _eventfd(int initval, int flags);

@Native<IntPtr Function(Int32, Pointer<Uint8>, Size)>(
  symbol: 'read',
  isLeaf: true,
)
external int _read(int fd, Pointer<Uint8> buf, int n);

@Native<IntPtr Function(Int32, Pointer<Uint8>, Size)>(
  symbol: 'write',
  isLeaf: true,
)
external int _write(int fd, Pointer<Uint8> buf, int n);

@Native<IntPtr Function(Int32, Pointer<IoVec>, Int32)>(
  symbol: 'writev',
  isLeaf: true,
)
external int _writev(int fd, Pointer<IoVec> iov, int cnt);

@Native<Int32 Function()>(symbol: 'getpid', isLeaf: true)
external int _getpid();

@Native<Int32 Function(Pointer<Pointer<IfAddrs>>)>(
  symbol: 'getifaddrs',
  isLeaf: true,
)
external int _getifaddrs(Pointer<Pointer<IfAddrs>> out);

@Native<Void Function(Pointer<IfAddrs>)>(symbol: 'freeifaddrs', isLeaf: true)
external void _freeifaddrs(Pointer<IfAddrs> p);

// ---------------------------------------------------------------- wrappers

/// Não leaf (bloqueia com `SO_LINGER > 0`); errno de melhor esforço. Nunca
/// repita o `close` depois de `-EINTR`: no linux o fd já foi liberado.
int close(int fd) {
  final e = _errnoLocation();
  final r = _close(fd);
  return r < 0 ? -e.value : r;
}

/// Endereço do `close` da libc, para um `NativeFinalizer` que fecha fd
/// esquecido (o token é o próprio número do fd, ver `poller.dart`).
Pointer<NativeFinalizerFunction> get closeFinalizer =>
    Native.addressOf<NativeFunction<Int32 Function(Int32)>>(_close).cast();

int unlink(String path) => _withPath(path, (p) {
  final e = _errnoLocation();
  final r = _unlink(p);
  return r < 0 ? -e.value : r;
});

int link(String from, String to) => _withPath(
  from,
  (a) => _withPath(to, (b) {
    final e = _errnoLocation();
    final r = _link(a, b);
    return r < 0 ? -e.value : r;
  }),
);

int rename(String from, String to) => _withPath(
  from,
  (a) => _withPath(to, (b) {
    final e = _errnoLocation();
    final r = _rename(a, b);
    return r < 0 ? -e.value : r;
  }),
);

/// `fcntl(fd, cmd, arg)` (`F_GETFL`/`F_SETFL`/`F_GETFD`/`F_SETFD`).
int fcntl(int fd, int cmd, [int arg = 0]) {
  final e = _errnoLocation();
  final r = _fcntl(fd, cmd, arg);
  return r < 0 ? -e.value : r;
}

/// Não leaf: bloqueia até [timeoutMs] (`-1`, sem prazo). Só no isolate do
/// poller.
int poll(Pointer<PollFd> fds, int n, int timeoutMs) {
  final e = _errnoLocation();
  final r = _poll(fds, n, timeoutMs);
  return r < 0 ? -e.value : r;
}

int eventfd(int initval, int flags) {
  final e = _errnoLocation();
  final r = _eventfd(initval, flags);
  return r < 0 ? -e.value : r;
}

int read(int fd, Uint8List buf) {
  final e = _errnoLocation();
  final r = _read(fd, buf.address, buf.length);
  return r < 0 ? -e.value : r;
}

int write(int fd, Uint8List buf) {
  final e = _errnoLocation();
  final r = _write(fd, buf.address, buf.length);
  return r < 0 ? -e.value : r;
}

int writev(int fd, Pointer<IoVec> iov, int cnt) {
  final e = _errnoLocation();
  final r = _writev(fd, iov, cnt);
  return r < 0 ? -e.value : r;
}

/// Nunca falha.
int getpid() => _getpid();

/// Lista em [out]; libere com [freeifaddrs].
int getifaddrs(Pointer<Pointer<IfAddrs>> out) {
  final e = _errnoLocation();
  final r = _getifaddrs(out);
  return r < 0 ? -e.value : r;
}

void freeifaddrs(Pointer<IfAddrs> p) => _freeifaddrs(p);

/// [path] em UTF-8 com NUL final, vivo durante [body].
int _withPath(String path, int Function(Pointer<Uint8>) body) {
  final bytes = utf8.encode(path);
  final p = libcAlloc<Uint8>(bytes.length + 1);
  try {
    p.asTypedList(bytes.length + 1)
      ..setAll(0, bytes)
      ..[bytes.length] = 0;
    return body(p);
  } finally {
    libcAlloc.free(p);
  }
}
