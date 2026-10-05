part of '../../net.dart';

// `notFoundError`, `temporaryError` e `newDNSError` servem ao DNS (parte de
// rede desta library).
// ignore_for_file: unused_element

/// `notFoundError` (não exportado).
final class _NotFoundError implements GoError, Golang.GoTyped {
  _NotFoundError(this.s);
  final Golang.String s;

  @override
  String get $goType => '*net.notFoundError';
  @override
  List<String> get $methods => const ['Error'];
  @override
  Golang.String error() => s;
}

/// `errNoSuchHost`.
final GoError _errNoSuchHost = _NotFoundError(_gs('no such host'));

/// `errUnknownPort`.
final GoError _errUnknownPort = _NotFoundError(_gs('unknown port'));

/// `temporaryError` (não exportado).
final class _TemporaryError implements Error, Golang.GoTyped {
  _TemporaryError(this.s);
  final Golang.String s;

  @override
  String get $goType => '*net.temporaryError';
  @override
  List<String> get $methods => const ['Error', 'Temporary', 'Timeout'];
  @override
  Golang.String error() => s;
  @override
  bool timeout() => false;
  @override
  bool temporary() => true;
}

/// `net.DNSError`: erro de consulta DNS.
final class DNSError extends GoStruct<DNSError> implements Error, Unwrapper {
  DNSError({
    this.unwrapErr,
    Golang.String? err,
    Golang.String? name,
    Golang.String? server,
    this.isTimeout = false,
    this.isTemporary = false,
    this.isNotFound = false,
  }) : err = err ?? Golang.String(),
       name = name ?? Golang.String(),
       server = server ?? Golang.String();

  /// `(*DNSError)(nil)` dentro de uma interface.
  static final DNSError $nil = DNSError()..$nilPtr = true;

  /// `UnwrapErr`: o que `Unwrap` devolve (pode ser nil).
  GoError? unwrapErr;

  /// `Err`: a descrição.
  Golang.String err;

  /// `Name`: o nome consultado.
  Golang.String name;

  /// `Server`: o servidor usado.
  Golang.String server;

  /// `IsTimeout`.
  bool isTimeout;

  /// `IsTemporary`.
  bool isTemporary;

  /// `IsNotFound`: o nome não existe (NXDOMAIN ou sem registros).
  bool isNotFound;

  @override
  String get $goType => 'net.DNSError';
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
  DNSError $copy() => DNSError(
    unwrapErr: unwrapErr,
    err: err,
    name: name,
    server: server,
    isTimeout: isTimeout,
    isTemporary: isTemporary,
    isNotFound: isNotFound,
  );
  @override
  void $set(DNSError o) {
    unwrapErr = o.unwrapErr;
    err = o.err;
    name = o.name;
    server = o.server;
    isTimeout = o.isTimeout;
    isTemporary = o.isTemporary;
    isNotFound = o.isNotFound;
  }

  @override
  List<Object?> get $fields => [
    dynField(unwrapErr),
    err,
    name,
    server,
    isTimeout,
    isTemporary,
    isNotFound,
  ];
  @override
  List<String> get $fieldNames => const [
    'UnwrapErr',
    'Err',
    'Name',
    'Server',
    'IsTimeout',
    'IsTemporary',
    'IsNotFound',
  ];
  @override
  List<String> get $fieldTypes => const [
    'error',
    'string',
    'string',
    'string',
    'bool',
    'bool',
    'bool',
  ];

  /// `Unwrap()`.
  @override
  GoError? unwrap() {
    final DNSError? e = $nilPtr ? null : this;
    return e!.unwrapErr;
  }

  /// `Error()`: `lookup <Name>[ on <Server>]: <Err>`.
  @override
  Golang.String error() {
    if ($nilPtr) return _gs('<nil>');
    var s = _gs('lookup ') + name;
    if (server.length != 0) s += _gs(' on ') + server;
    return s + _gs(': ') + err;
  }

  @override
  bool timeout() {
    final DNSError? e = $nilPtr ? null : this;
    return e!.isTimeout;
  }

  @override
  bool temporary() {
    final DNSError? e = $nilPtr ? null : this;
    return e!.isTimeout || e.isTemporary;
  }
}

/// `newDNSError(err, name, server)`.
DNSError _newDNSError(GoError err, Golang.String name, Golang.String server) {
  var isTimeout = false, isTemporary = false;
  GoError? unwrapErr;
  if (err is Timeouter && err is Temporary) {
    isTimeout = (err as Timeouter).timeout();
    isTemporary = (err as Temporary).temporary();
  }
  if (errors.is$(err, context.deadlineExceeded) ||
      errors.is$(err, context.canceled)) {
    unwrapErr = err;
  }
  return DNSError(
    unwrapErr: unwrapErr,
    err: err.error(),
    name: name,
    server: server,
    isTimeout: isTimeout,
    isTemporary: isTemporary,
    isNotFound: err is _NotFoundError,
  );
}
