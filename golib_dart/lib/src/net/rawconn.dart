part of '../../net.dart';

// `SyscallConn`: o `rawConn`/`rawListener` do Go (`rawconn.go`) sobre o
// socket do `sys`, por dono do descritor (plano D10, §1.4):
//
// - fd real (rede FFI: UDP da VM no linux, listener com `Control`, o socket
//   no meio do `Control`): `Control`, `Read` e `Write` de verdade, com os
//   prazos da conexão.
// - socket do `dart:io` (TCP, Unix, UDP fora do linux): o `dart:io` não
//   expõe o fd. `Control` passa ao `f` um descritor virtual
//   (`src/syscall/vfd.dart`) cujas opções (`syscall.SetsockoptInt`/
//   `GetsockoptInt`) vão ao `setRawOption`/`getRawOption` do socket. Em
//   TCP e Unix de fluxo, `Read`/`Write` são o `FD.RawRead`/`RawWrite` do Go
//   sobre o `Fd` da conexão (mesmas travas e prazos, esperando a prontidão
//   do `RawSocket`), e o `syscall.Read`/`Write` do `f` no descritor virtual
//   lê e escreve no mesmo `RawSocket` sem esperar (`EAGAIN`, 0 no EOF): o
//   padrão do `readyreader` do gRPC. ⚠️ No UDP do `dart:io` (fora do
//   linux), `Read`/`Write` dão `operation not supported`.
// - Node e navegador (F4): o descritor virtual responde `ENOPROTOOPT` a
//   toda opção; `Read`/`Write` dão `operation not supported`.

/// Descritores virtuais por socket do `sys` (um por socket, liberado no
/// `Close` da conexão).
final _vfds = Expando<int>('vfd');

int _vfdOf(Object s) => _vfds[s] ??= vfd.vfdOpen(_VfdOwner(s));

void _vfdRelease(Object? s) {
  if (s == null) return;
  final n = _vfds[s];
  if (n == null) return;
  vfd.vfdClose(n);
  _vfds[s] = null;
}

/// Responde pelas opções de um descritor virtual.
final class _VfdOwner implements vfd.VirtualFd {
  _VfdOwner(this._s);

  final Object _s;

  static const _enoprotoopt = 92;

  @override
  int setsockopt(int level, int opt, Uint8List value) {
    final s = _s;
    return s is sys.SysSockopts
        ? s.rawSetsockopt(level, opt, value)
        : -_enoprotoopt;
  }

  @override
  int getsockopt(int level, int opt, Uint8List out) {
    final s = _s;
    return s is sys.SysSockopts
        ? s.rawGetsockopt(level, opt, out)
        : -_enoprotoopt;
  }

  static const _eopnotsupp = 95;

  @override
  int read(Uint8List buf) {
    final s = _s;
    return s is sys.SysVfdIo ? s.vfdRead(buf) : -_eopnotsupp;
  }

  @override
  int write(Uint8List data) {
    final s = _s;
    return s is sys.SysVfdIo ? s.vfdWrite(data) : -_eopnotsupp;
  }
}

/// `rawConn` (ou `rawListener`, com [listener]) do Go.
final class _RawConn implements syscall.RawConn {
  _RawConn(
    this._sys,
    this._net,
    this._laddr,
    this._raddr,
    this._closed, {
    this.listener = false,
  });

  final Object _sys;
  final String _net;
  final Addr? _laddr;
  final Addr? _raddr;
  final bool Function() _closed;

  /// `rawListener`: `Read`/`Write` dão `EINVAL`.
  final bool listener;

  /// O número que o `f` recebe, ou `null` com o socket fechado.
  int? _fd() {
    if (_closed()) return null;
    final s = _sys;
    if (s is sys.SysRawFd) return s.rawFd < 0 ? null : s.rawFd;
    return _vfdOf(s);
  }

  /// `Control(f)`: chama `f(fd)` na hora.
  @override
  GoError? control(void Function(Golang.Uintptr fd)? f) {
    final fd = _fd();
    if (fd == null) {
      return _opError('raw-control', _net, null, _laddr, errClosed);
    }
    f!(Golang.Uintptr(fd));
    return null;
  }

  /// `Read(f)`: `f(fd)` até devolver `true`, esperando leitura entre as
  /// tentativas.
  @override
  Future<GoError?> read(bool Function(Golang.Uintptr fd)? f) =>
      _io(f, read: true);

  /// `Write(f)`: idem, esperando escrita.
  @override
  Future<GoError?> write(bool Function(Golang.Uintptr fd)? f) =>
      _io(f, read: false);

  Future<GoError?> _io(
    bool Function(Golang.Uintptr fd)? f, {
    required bool read,
  }) async {
    if (listener) return syscall.einval;
    GoError fail(GoError err) =>
        _opError(read ? 'raw-read' : 'raw-write', _net, _laddr, _raddr, err);
    if (_closed()) return fail(errClosed);
    final s = _sys;
    if (s is sys.SysVfdIo) {
      // Descritor virtual (`dart:io` de fluxo): o `FD.RawRead`/`RawWrite`.
      final fd = _vfdOf(s);
      bool g() => f!(Golang.Uintptr(fd));
      try {
        await (read ? s.rawRead(g) : s.rawWrite(g));
        return null;
      } on sys.SysException catch (e) {
        return fail(_sysError(e));
      }
    }
    if (s is! sys.SysRawFd) return fail(syscall.eopnotsupp);
    try {
      // `prepareRead`/`prepareWrite`: prazo vencido falha antes do `f`.
      if (read ? s.rawReadExpired : s.rawWriteExpired) {
        throw const sys.SysTimeout();
      }
      while (true) {
        final fd = s.rawFd;
        if (fd < 0 || _closed()) throw const sys.SysClosed();
        if (f!(Golang.Uintptr(fd))) return null;
        await (read ? s.rawWaitRead() : s.rawWaitWrite());
      }
    } on sys.SysException catch (e) {
      return fail(_sysError(e));
    }
  }
}
