part of '../../net.dart';

// Erros da rede real (D4): o `sys` (src/net/sys/) lança exceções Dart; aqui
// elas viram os erros que o Go devolve (`*OpError` com `*os.SyscallError`
// sobre um `syscall.Errno`, `os.ErrDeadlineExceeded`, `ErrClosed`,
// `*DNSError`).

/// `syscall.Errno` com o texto do Go no linux (`connection refused`...).
/// O pacote `syscall` não tem shim: o tipo só aparece dentro dos erros.
final class _Errno implements GoError, Timeouter, Temporary, Golang.GoTyped {
  _Errno(this.code, this.text);

  /// Nome do errno (`ECONNREFUSED`).
  final String code;
  final String text;

  @override
  Golang.String error() => Golang.String.fromDart(text);

  /// `Errno.Timeout`: EAGAIN, EWOULDBLOCK, ETIMEDOUT.
  @override
  bool timeout() =>
      code == 'EAGAIN' || code == 'EWOULDBLOCK' || code == 'ETIMEDOUT';

  /// `Errno.Temporary`: EINTR, EMFILE, ENFILE, ECONNRESET, ECONNABORTED ou
  /// timeout.
  @override
  bool temporary() =>
      const {
        'EINTR',
        'EMFILE',
        'ENFILE',
        'ECONNRESET',
        'ECONNABORTED',
      }.contains(code) ||
      timeout();

  @override
  String get $goType => 'syscall.Errno';
  @override
  List<String> get $methods => const ['Error', 'Is', 'Temporary', 'Timeout'];

  @override
  bool operator ==(Object other) => other is _Errno && other.code == code;
  @override
  int get hashCode => code.hashCode;
}

/// `errTimeout` do Go (`*timeoutError`): o `Dial` que estourou o prazo.
final class _TimeoutError implements GoError, Timeouter, Temporary, Golang.GoTyped {
  const _TimeoutError();
  @override
  Golang.String error() => Golang.String.fromDart('i/o timeout');
  @override
  bool timeout() => true;
  @override
  bool temporary() => true;
  @override
  String get $goType => '*net.timeoutError';
  @override
  List<String> get $methods => const ['Error', 'Is', 'Temporary', 'Timeout'];
}

/// `errCanceled` do Go: o `Dial` cancelado pelo `context`.
final class _CanceledError implements GoError, Golang.GoTyped {
  const _CanceledError();
  @override
  Golang.String error() => Golang.String.fromDart('operation was canceled');
  @override
  String get $goType => '*net.canceledError';
  @override
  List<String> get $methods => const ['Error', 'Is'];
}

const GoError _errTimeout = _TimeoutError();
const GoError _errCanceled = _CanceledError();

/// O "operation not supported" do navegador e do que o shim não faz
/// (sockets Unix e IP brutos).
GoError _notSupported(String syscall) => os.newSyscallError(
  _s(syscall),
  _Errno('EOPNOTSUPP', 'operation not supported'),
)!;

Golang.String _s(String s) => Golang.String.fromDart(s);

/// A exceção do `sys` como o erro que vai no `Err` do `OpError`.
GoError _sysError(Object e) => switch (e) {
  sys.SysTimeout() => os.errDeadlineExceeded,
  sys.SysClosed() => errClosed,
  sys.SysCanceled() => _errCanceled,
  final sys.SysError x => os.newSyscallError(
    _s(x.syscall),
    _Errno(x.code, x.message),
  )!,
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
OpError _opError(String op, String net, Addr? source, Addr? addr, GoError err) =>
    OpError(op: _s(op), net: _s(net), source: source, addr: addr, err: err);
