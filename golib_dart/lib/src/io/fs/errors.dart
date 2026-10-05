part of '../../../io/fs.dart';

GoError _e(String s) => ErrorString(Golang.String.fromDart(s));

/// `fs.ErrInvalid`.
final GoError errInvalid = _e('invalid argument');

/// `fs.ErrPermission`.
final GoError errPermission = _e('permission denied');

/// `fs.ErrExist`.
final GoError errExist = _e('file already exists');

/// `fs.ErrNotExist`.
final GoError errNotExist = _e('file does not exist');

/// `fs.ErrClosed`.
final GoError errClosed = _e('file already closed');

/// `interface{ Timeout() bool }` (não exportada no Go; o `os` a implementa):
/// a do runtime, que o g2d declara em todo tipo com `Timeout() bool`.
typedef TimeoutError = Timeouter;

/// `fs.PathError`: erro de operação sobre um caminho.
final class PathError extends GoStruct<PathError>
    implements GoError, Unwrapper, Timeouter {
  PathError({Golang.String? op, Golang.String? path, this.err})
    : op = op ?? Golang.String(),
      path = path ?? Golang.String();

  /// `(*PathError)(nil)` dentro de uma interface.
  static final PathError $nil = PathError()..$nilPtr = true;

  Golang.String op;
  Golang.String path;
  GoError? err;

  @override
  String get $goType => 'fs.PathError';
  @override
  List<String> get $ptrMethods => const ['Error', 'Timeout', 'Unwrap'];
  @override
  PathError $copy() => PathError(op: op, path: path, err: err);
  @override
  void $set(PathError o) {
    op = o.op;
    path = o.path;
    err = o.err;
  }

  @override
  List<Object?> get $fields => [op, path, err];
  @override
  List<String> get $fieldNames => const ['Op', 'Path', 'Err'];

  /// `Error()`: `op path: err`.
  @override
  Golang.String error() =>
      op +
      Golang.String.fromDart(' ') +
      path +
      Golang.String.fromDart(': ') +
      err!.error();

  /// `Unwrap()`.
  @override
  GoError? unwrap() => err;

  /// `Timeout()`: o erro embrulhado diz que é timeout.
  @override
  bool timeout() => switch (err) {
    final TimeoutError t => t.timeout(),
    _ => false,
  };
}
