/// O pacote `context` do Go (escrito à mão; ver go/manual_context.go): o `Context`
/// que os métodos assíncronos recebem e o cancelamento deles.
///
/// ```dart
/// import 'package:ipfs_ffi/context.dart' as context;
///
/// final (ctx, cancel) = context.withTimeout(context.background(), Duration(seconds: 30));
/// try {
///   await api.unixfs().get(ctx, path);
/// } finally {
///   cancel();
/// }
/// ```
library;

import 'dart:ffi';

import 'package:ipfs_ffi/src/runtime.dart';

// Exports diretos (sem JSON): toda operação com prazo cria e cancela um
// contexto. Os dois handles de um WithX voltam em $out e $outN.

/// Go: `context.Context` (handle).
class Context extends GoHandle {
  Context.$h(super.$h);

  /// Go: `func (context.Context).Err() error`: null enquanto não cancelado.
  String? err() {
    final out = $out.cast<Pointer<Uint8>>();
    $check(_err($h, out));
    return out.value == nullptr ? null : $take(out.value);
  }
}

/// Go: `context.CancelFunc`: chame `cancel()` para cancelar.
class CancelFunc extends GoHandle {
  CancelFunc.$h(super.$h);

  void call() => $check(_cancel($h));
}

/// Go: `func context.Background() context.Context`.
Context background() {
  $check(_background($out));
  return Context.$h($nnH($out.value));
}

(Context, CancelFunc) _pair(Pointer<Uint8> err) {
  $check(err);
  return (Context.$h($nnH($out.value)), CancelFunc.$h($nnH($outN.value)));
}

/// Go: `func context.WithCancel(parent Context) (ctx Context, cancel CancelFunc)`.
(Context, CancelFunc) withCancel(Context parent) =>
    _pair(_withCancel(parent.$h, $out, $outN));

/// Go: `func context.WithTimeout(parent Context, timeout time.Duration) (Context, CancelFunc)`.
(Context, CancelFunc) withTimeout(Context parent, Duration timeout) =>
    _pair(_withTimeout(parent.$h, timeout.inMicroseconds * 1000, $out, $outN));

/// Go: `func context.WithDeadline(parent Context, d time.Time) (Context, CancelFunc)`.
(Context, CancelFunc) withDeadline(Context parent, DateTime d) => _pair(
    _withDeadline(parent.$h, d.microsecondsSinceEpoch * 1000, $out, $outN));

typedef _WithN = Pointer<Uint8> Function(
    Int64, Int64, Pointer<Int64>, Pointer<Int64>);
typedef _WithD = Pointer<Uint8> Function(
    int, int, Pointer<Int64>, Pointer<Int64>);

final _background = $dylib.lookupFunction<
    Pointer<Uint8> Function(Pointer<Int64>),
    Pointer<Uint8> Function(Pointer<Int64>)>('IpfsCtxBackground');
final _withCancel = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Int64>, Pointer<Int64>),
    Pointer<Uint8> Function(
        int, Pointer<Int64>, Pointer<Int64>)>('IpfsCtxWithCancel');
final _withTimeout =
    $dylib.lookupFunction<_WithN, _WithD>('IpfsCtxWithTimeout');
final _withDeadline =
    $dylib.lookupFunction<_WithN, _WithD>('IpfsCtxWithDeadline');
final _cancel = $dylib.lookupFunction<Pointer<Uint8> Function(Int64),
    Pointer<Uint8> Function(int)>('IpfsCtxCancel');
final _err = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Pointer<Uint8>>),
    Pointer<Uint8> Function(int, Pointer<Pointer<Uint8>>)>('IpfsCtxErr');
