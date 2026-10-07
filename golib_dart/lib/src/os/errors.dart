part of '../../os.dart';

/// `os.ErrInvalid` (`fs.ErrInvalid`).
final GoError errInvalid = fs.errInvalid;

/// `os.ErrPermission`.
final GoError errPermission = fs.errPermission;

/// `os.ErrExist`.
final GoError errExist = fs.errExist;

/// `os.ErrNotExist`.
final GoError errNotExist = fs.errNotExist;

/// `os.ErrClosed`.
final GoError errClosed = fs.errClosed;

/// `os.ErrNoDeadline`.
final GoError errNoDeadline = ErrorString(
  Golang.String.fromDart('file type does not support deadline'),
);

/// `*poll.DeadlineExceededError`.
final class _DeadlineExceeded
    implements GoError, Timeouter, Temporary, Golang.GoTyped {
  @override
  Golang.String error() => Golang.String.fromDart('i/o timeout');

  @override
  bool timeout() => true;

  @override
  bool temporary() => true;

  @override
  String get $goType => '*poll.DeadlineExceededError';

  @override
  List<String> get $methods => const ['Error', 'Temporary', 'Timeout'];
}

/// `os.ErrDeadlineExceeded`.
final GoError errDeadlineExceeded = _DeadlineExceeded();

/// `underlyingError` do Go: o erro de dentro de `*PathError`/`*SyscallError`.
GoError? _underlying(GoError? err) => switch (err) {
  final fs.PathError e => e.err,
  final SyscallError e => e.err,
  _ => err,
};

/// `underlyingErrorIs` do Go: o erro de dentro é o alvo, ou é um
/// `syscall.Errno` que diz ser (`ENOENT` é `ErrNotExist`...).
bool _underlyingIs(GoError? err, GoError target) {
  final e = _underlying(err);
  if (identical(e, target)) return true;
  return e is syscall.Errno && e.is$(target);
}

/// `os.IsExist(err)`.
bool isExist(GoError? err) => _underlyingIs(err, errExist);

/// `os.IsNotExist(err)`.
bool isNotExist(GoError? err) => _underlyingIs(err, errNotExist);

/// `os.IsPermission(err)`.
bool isPermission(GoError? err) => _underlyingIs(err, errPermission);

/// `os.IsTimeout(err)`.
bool isTimeout(GoError? err) => switch (_underlying(err)) {
  final fs.TimeoutError t => t.timeout(),
  _ => false,
};

/// `os.SyscallError`: o erro de uma chamada de sistema (`connect`,
/// `read`...), como a rede do shim `net` (D4) devolve dentro do `OpError`.
final class SyscallError extends GoStruct<SyscallError>
    implements GoError, Unwrapper, Timeouter {
  SyscallError({Golang.String? syscall, this.err})
    : syscall = syscall ?? Golang.String();

  /// `(*SyscallError)(nil)` dentro de uma interface.
  static final SyscallError $nil = SyscallError()..$nilPtr = true;

  Golang.String syscall;
  GoError? err;

  @override
  String get $goType => 'os.SyscallError';
  @override
  List<String> get $ptrMethods => const ['Error', 'Timeout', 'Unwrap'];
  @override
  SyscallError $copy() => SyscallError(syscall: syscall, err: err);
  @override
  void $set(SyscallError o) {
    syscall = o.syscall;
    err = o.err;
  }

  @override
  List<Object?> get $fields => [syscall, err];
  @override
  List<String> get $fieldNames => const ['Syscall', 'Err'];

  /// `Error()`: `syscall: err`.
  @override
  Golang.String error() =>
      syscall + Golang.String.fromDart(': ') + err!.error();

  /// `Unwrap()`.
  @override
  GoError? unwrap() => err;

  /// `Timeout()`: o erro embrulhado diz que é timeout.
  @override
  bool timeout() => switch (err) {
    final Timeouter t => t.timeout(),
    _ => false,
  };
}

/// `os.NewSyscallError(syscall, err)`: nil se err é nil.
GoError? newSyscallError(Golang.String syscall, GoError? err) =>
    err == null ? null : SyscallError(syscall: syscall, err: err);
