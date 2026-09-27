part of '../../os.dart';

// -------------------------------------------------------------- sentinelas
//
// `os.ErrNotExist`... são `var`s do pacote `os` (não apelidos): identificador
// próprio, mas a mesma instância de `fs.ErrNotExist` (`errors.Is` entre um
// erro do `os` e `fs.ErrNotExist` tem que dar `true`, como no Go).

/// `os.ErrInvalid`.
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

/// `os.ErrDeadlineExceeded`: `Timeout()` (e `Temporary()`, sem equivalente
/// aqui) verdadeiro, como `internal/poll.DeadlineExceededError` no Go.
final GoError errDeadlineExceeded = _DeadlineExceededError();

final class _DeadlineExceededError implements GoError, Timeouter, Golang.GoTyped {
  @override
  Golang.String error() => Golang.String.fromDart('i/o timeout');
  @override
  bool timeout() => true;
  @override
  String get $goType => '*poll.DeadlineExceededError';
  @override
  List<String> get $methods => const ['Error', 'Timeout'];
}

/// `os.ErrProcessDone`.
final GoError errProcessDone = ErrorString(
  Golang.String.fromDart('os: process already finished'),
);

// ---------------------------------------------------------------- errno
//
// Texto exato de `syscall.Errno.Error()` (porta de
// `syscall/zerrors_linux_amd64.go`, Go 1.26, GOOS=linux do `BUILD_ENV`):
// as mensagens de `*PathError`/`*SyscallError` batem com o oráculo Go byte a
// byte quando o erro vem de uma chamada real (`backend_io.dart`).
const _errnoText = <int, String>{
  1: 'operation not permitted', 2: 'no such file or directory', 3: 'no such process',
  4: 'interrupted system call', 5: 'input/output error', 6: 'no such device or address',
  7: 'argument list too long', 8: 'exec format error', 9: 'bad file descriptor',
  10: 'no child processes', 11: 'resource temporarily unavailable', 12: 'cannot allocate memory',
  13: 'permission denied', 14: 'bad address', 15: 'block device required',
  16: 'device or resource busy', 17: 'file exists', 18: 'invalid cross-device link',
  19: 'no such device', 20: 'not a directory', 21: 'is a directory',
  22: 'invalid argument', 23: 'too many open files in system', 24: 'too many open files',
  25: 'inappropriate ioctl for device', 26: 'text file busy', 27: 'file too large',
  28: 'no space left on device', 29: 'illegal seek', 30: 'read-only file system',
  31: 'too many links', 32: 'broken pipe', 33: 'numerical argument out of domain',
  34: 'numerical result out of range', 35: 'resource deadlock avoided', 36: 'file name too long',
  37: 'no locks available', 38: 'function not implemented', 39: 'directory not empty',
  40: 'too many levels of symbolic links', 95: 'operation not supported',
  110: 'connection timed out',
};

/// `syscall.Errno` (Linux, amd64): mensagem exata do Go, `Is`/`Timeout`
/// como em `syscall_unix.go`.
final class _Errno implements GoError, ErrorIs, Timeouter, Golang.GoTyped {
  const _Errno(this.code);

  final int code;

  @override
  Golang.String error() =>
      Golang.String.fromDart(_errnoText[code] ?? 'errno $code');

  /// `Errno.Is`: `EACCES`/`EPERM` → `ErrPermission`; `EEXIST`/`ENOTEMPTY` →
  /// `ErrExist`; `ENOENT` → `ErrNotExist`; `ENOSYS`/`ENOTSUP`/`EOPNOTSUPP`
  /// (mesmo valor 95 no Linux) → `errors.ErrUnsupported`.
  @override
  bool is$(GoError? target) {
    if (identical(target, fs.errPermission)) return code == 13 || code == 1;
    if (identical(target, fs.errExist)) return code == 17 || code == 39;
    if (identical(target, fs.errNotExist)) return code == 2;
    if (identical(target, errorspkg.errUnsupported)) return code == 38 || code == 95;
    return false;
  }

  /// `Errno.Timeout`: `EAGAIN`/`EWOULDBLOCK` (mesmo valor 11) ou `ETIMEDOUT`.
  @override
  bool timeout() => code == 11 || code == 110;

  @override
  String get $goType => 'syscall.Errno';
  @override
  List<String> get $methods => const ['Error', 'Is', 'Timeout'];
}

/// `backend.OsFail` → erro Go: `errno == -1` (sem suporte na plataforma) vira
/// `errors.ErrUnsupported`; `errno` conhecido vira [_Errno]; sem `errno`
/// (falha sem número, ex. `chmod` externo), a mensagem crua.
GoError _fromFail(backend.OsFail e) {
  if (e.errno == -1) return errorspkg.errUnsupported;
  if (e.errno != null) return _Errno(e.errno!);
  return ErrorString(Golang.String.fromDart(e.message));
}

/// `*PathError` a partir de uma falha do backend.
PathError _pathError(String op, Golang.String path, backend.OsFail e) =>
    fs.PathError(op: Golang.String.fromDart(op), path: path, err: _fromFail(e));

T _wrapPath<T>(String op, Golang.String path, T Function() f, T Function(GoError) onFail) {
  try {
    return f();
  } on backend.OsFail catch (e) {
    return onFail(_pathError(op, path, e));
  }
}

// ------------------------------------------------------------- LinkError

/// `os.LinkError`: erro de `Link`/`Symlink`/`Rename`.
final class LinkError extends GoStruct<LinkError> implements GoError, Unwrapper, Golang.GoTyped {
  LinkError({Golang.String? op, Golang.String? old, Golang.String? new$, GoError? err})
    : op = op ?? Golang.String(),
      old = old ?? Golang.String(),
      new$ = new$ ?? Golang.String(),
      err = err;

  /// `(*LinkError)(nil)` dentro de uma interface (não é nil no Go).
  static final LinkError $nil = LinkError()..$nilPtr = true;

  Golang.String op;
  Golang.String old;
  Golang.String new$;
  GoError? err;

  @override
  String get $goType => 'os.LinkError';
  @override
  List<String> get $valueMethods => const [];
  @override
  List<String> get $ptrMethods => const ['Error', 'Unwrap'];

  @override
  LinkError $copy() => LinkError(op: op, old: old, new$: new$, err: err);
  @override
  void $set(LinkError o) {
    op = o.op;
    old = o.old;
    new$ = o.new$;
    err = o.err;
  }

  @override
  List<Object?> get $fields => [op, old, new$, err];
  @override
  List<String> get $fieldNames => const ['Op', 'Old', 'New', 'Err'];

  /// `Error()`: `op old new: err`.
  Golang.String error() =>
      op +
      Golang.String.fromDart(' ') +
      old +
      Golang.String.fromDart(' ') +
      new$ +
      Golang.String.fromDart(': ') +
      err!.error();

  /// `Unwrap() error`.
  GoError? unwrap() => err;
}

// ---------------------------------------------------------- SyscallError

/// `os.SyscallError`: erro de uma chamada de sistema nomeada.
final class SyscallError extends GoStruct<SyscallError> implements GoError, Unwrapper, Timeouter, Golang.GoTyped {
  SyscallError({Golang.String? syscall, GoError? err}) : syscall = syscall ?? Golang.String(), err = err;

  /// `(*SyscallError)(nil)` dentro de uma interface (não é nil no Go).
  static final SyscallError $nil = SyscallError()..$nilPtr = true;

  Golang.String syscall;
  GoError? err;

  @override
  String get $goType => 'os.SyscallError';
  @override
  List<String> get $valueMethods => const [];
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
  Golang.String error() => syscall + Golang.String.fromDart(': ') + err!.error();

  /// `Unwrap() error`.
  GoError? unwrap() => err;

  /// `Timeout()`.
  @override
  bool timeout() {
    final e = err;
    return e is Timeouter && goHasMethod(e, 'Timeout') && e.timeout();
  }
}

/// `os.NewSyscallError(syscall, err)`: nil se `err` for nil.
GoError? newSyscallError(Golang.String syscall, GoError? err) =>
    err == null ? null : SyscallError(syscall: syscall, err: err);

// ------------------------------------------------------------- Is* / underlying

GoError? _underlyingError(GoError? err) => switch (err) {
  fs.PathError p => p.err,
  LinkError l => l.err,
  SyscallError s => s.err,
  _ => err,
};

bool _underlyingErrorIs(GoError? err, GoError target) {
  final u = _underlyingError(err);
  if (u == null) return false;
  if (ifaceEq(u, target)) return true;
  return u is ErrorIs && goHasMethod(u, 'Is') && u.is$(target);
}

/// `os.IsExist`.
bool isExist(GoError? err) => _underlyingErrorIs(err, errExist);

/// `os.IsNotExist`.
bool isNotExist(GoError? err) => _underlyingErrorIs(err, errNotExist);

/// `os.IsPermission`.
bool isPermission(GoError? err) => _underlyingErrorIs(err, errPermission);

/// `os.IsTimeout`.
bool isTimeout(GoError? err) {
  final u = _underlyingError(err);
  return u is Timeouter && goHasMethod(u, 'Timeout') && u.timeout();
}
