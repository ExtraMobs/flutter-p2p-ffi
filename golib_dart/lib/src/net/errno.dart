part of '../../net.dart';

// Erros da rede real (D4): o `sys` (src/net/sys/) lança exceções Dart; aqui
// elas viram os erros que o Go devolve (`*OpError` com `*os.SyscallError`
// sobre um `syscall.Errno`, `os.ErrDeadlineExceeded`, `ErrClosed`,
// `*DNSError`).

/// O erro do sistema de um [sys.SysError]: o `syscall.Errno` do número
/// (numeração do linux em toda plataforma). ⚠️ Falha sem errno (`EOTHER`:
/// exceção do `dart:io`/Node sem código conhecido) vira um erro de texto,
/// como `errors.New`.
GoError _errnoOf(sys.SysError x) {
  final n = x.errno;
  return n != null ? syscall.Errno(n) : _errNew(x.message);
}

/// O "operation not supported" do navegador e do que o shim não faz
/// (sockets Unix e IP brutos).
GoError _notSupported(String call) =>
    os.newSyscallError(_s(call), syscall.eopnotsupp)!;

Golang.String _s(String s) => Golang.String.fromDart(s);

/// A exceção do `sys` como o erro que vai no `Err` do `OpError`.
GoError _sysError(Object e) => switch (e) {
  sys.SysTimeout() => os.errDeadlineExceeded,
  sys.SysClosed() => errClosed,
  sys.SysCanceled() => _errCanceled,
  final sys.SysError x => os.newSyscallError(_s(x.syscall), _errnoOf(x))!,
  final sys.SysDnsError x => _dnsError(x),
  _ => throw e,
};

DNSError _dnsError(sys.SysDnsError x, [String? name]) => DNSError(
  err: _s(x.message),
  name: _s(name ?? x.name),
  server: _s(x.server),
  isTimeout: x.isTimeout,
  isTemporary: x.isTemporary,
  isNotFound: x.isNotFound,
);

/// `*OpError` montado como o Go (`Source`/`Addr` nil viram interface nil).
OpError _opError(
  String op,
  String net,
  Addr? source,
  Addr? addr,
  GoError err,
) => OpError(op: _s(op), net: _s(net), source: source, addr: addr, err: err);
