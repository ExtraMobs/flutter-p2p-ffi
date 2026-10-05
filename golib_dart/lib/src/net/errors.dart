part of '../../net.dart';

// Os não exportados (`errTimeout`, `mapErr`, `newDNSError`...) servem à parte
// de rede (conexões, DNS), que mora nesta mesma library.
// ignore_for_file: unused_element

/// `net.Error`: erro de rede com `Timeout()` e `Temporary()`.
abstract interface class Error implements GoError, Timeouter, Temporary {}

/// `ErrWriteToConnected`.
final GoError errWriteToConnected = _errNew(
  'use of WriteTo with pre-connected connection',
);

/// `errNoSuitableAddress` (não exportado; para a parte de rede).
final GoError _errNoSuitableAddress = _errNew('no suitable address found');

/// `errMissingAddress` (não exportado; para a parte de rede).
final GoError _errMissingAddress = _errNew('missing address');

/// `poll.errNetClosing`: o erro por trás de [errClosed].
final class _ErrNetClosing implements Error, Golang.GoTyped {
  const _ErrNetClosing();

  @override
  String get $goType => 'poll.errNetClosing';
  @override
  List<String> get $methods => const ['Error', 'Temporary', 'Timeout'];

  /// O texto é estável no Go (issue 4373: programas o procuram).
  @override
  Golang.String error() => _gs('use of closed network connection');
  @override
  bool timeout() => false;
  @override
  bool temporary() => false;

  @override
  bool operator ==(Object other) => other is _ErrNetClosing;
  @override
  int get hashCode => 0;
}

/// `ErrClosed`: conexão de rede já fechada (`poll.ErrNetClosing`).
final GoError errClosed = const _ErrNetClosing();

/// `canceledError` (não exportado): `Is(context.Canceled)`.
final class _CanceledError implements GoError, ErrorIs, Golang.GoTyped {
  const _CanceledError();

  @override
  String get $goType => 'net.canceledError';
  @override
  List<String> get $methods => const ['Error', 'Is'];
  @override
  Golang.String error() => _gs('operation was canceled');
  @override
  bool is$(GoError? err) => err == context.canceled;

  @override
  bool operator ==(Object other) => other is _CanceledError;
  @override
  int get hashCode => 1;
}

/// `errCanceled`.
const GoError _errCanceled = _CanceledError();

/// `timeoutError` (não exportado): `i/o timeout`, `Is(DeadlineExceeded)`.
final class _TimeoutError implements Error, ErrorIs, Golang.GoTyped {
  const _TimeoutError();

  @override
  String get $goType => '*net.timeoutError';
  @override
  List<String> get $methods => const ['Error', 'Is', 'Temporary', 'Timeout'];
  @override
  Golang.String error() => _gs('i/o timeout');
  @override
  bool timeout() => true;
  @override
  bool temporary() => true;
  @override
  bool is$(GoError? err) => err == context.deadlineExceeded;
}

/// `errTimeout`.
const GoError _errTimeout = _TimeoutError();

/// `mapErr(err)`: erros do context vistos como os do net.
GoError? _mapErr(GoError? err) {
  if (err == context.canceled) return _errCanceled;
  if (err == context.deadlineExceeded) return _errTimeout;
  return err;
}

/// `net.OpError`: erro de uma operação de rede (`dial tcp a->b: err`).
final class OpError extends GoStruct<OpError> implements Error, Unwrapper {
  OpError({
    Golang.String? op,
    Golang.String? net,
    this.source,
    Addr? addr,
    this.err,
  }) : op = op ?? Golang.String(),
       net = net ?? Golang.String(),
       addr$ = addr;

  /// `(*OpError)(nil)` dentro de uma interface.
  static final OpError $nil = OpError()..$nilPtr = true;

  /// `Op`: `read`, `write`, `dial`...
  Golang.String op;

  /// `Net`: `tcp`, `udp6`...
  Golang.String net;

  /// `Source`: endereço local (opcional).
  Addr? source;

  /// `Addr`: endereço remoto (opcional).
  Addr? addr$;

  /// `Err`.
  GoError? err;

  @override
  String get $goType => 'net.OpError';
  @override
  List<String> get $valueMethods => const [];
  @override
  List<String> get $ptrMethods => const [
    'Error',
    'Temporary',
    'Timeout',
    'Unwrap',
  ];
  @override
  OpError $copy() =>
      OpError(op: op, net: net, source: source, addr: addr$, err: err);
  @override
  void $set(OpError o) {
    op = o.op;
    net = o.net;
    source = o.source;
    addr$ = o.addr$;
    err = o.err;
  }

  @override
  List<Object?> get $fields => [
    op,
    net,
    dynField(source),
    dynField(addr$),
    dynField(err),
  ];
  @override
  List<String> get $fieldNames => const ['Op', 'Net', 'Source', 'Addr', 'Err'];
  @override
  List<String> get $fieldTypes => const [
    'string',
    'string',
    'net.Addr',
    'net.Addr',
    'error',
  ];

  /// `Unwrap()`.
  @override
  GoError? unwrap() {
    final OpError? e = $nilPtr ? null : this;
    return e!.err;
  }

  /// `Error()`: `op net source->addr: err`.
  @override
  Golang.String error() {
    if ($nilPtr) return _gs('<nil>');
    var s = op;
    if (net.length != 0) s += _gs(' ') + net;
    if (source != null) s += _gs(' ') + source!.string();
    if (addr$ != null) {
      s += source != null ? _gs('->') : _gs(' ');
      s += addr$!.string();
    }
    return s + _gs(': ') + err!.error();
  }

  /// `Timeout()`.
  // ponytail: o ramo `*os.SyscallError` do Go entra quando o shim `os` tiver
  // o tipo.
  @override
  bool timeout() {
    final OpError? e = $nilPtr ? null : this;
    return switch (e!.err) {
      final Timeouter t => t.timeout(),
      _ => false,
    };
  }

  /// `Temporary()`.
  // ponytail: `Op == "accept" && isConnError(Err)` (ECONNRESET/ECONNABORTED
  // de `syscall.Errno`) e o ramo `*os.SyscallError` entram com esses tipos.
  @override
  bool temporary() {
    final OpError? e = $nilPtr ? null : this;
    return switch (e!.err) {
      final Temporary t => t.temporary(),
      _ => false,
    };
  }
}
