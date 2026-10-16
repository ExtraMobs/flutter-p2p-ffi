/// Runtime of the generated libraries (go/gen): encodes the arguments in
/// binary (WIRE.md), sends the request to the ipfs_host through the
/// shared memory channel (shm.dart) and delivers the response. The app does
/// not load Go. Not public API.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'shm.dart';

part 'runtime/callback.dart';
part 'runtime/codec.dart';
part 'runtime/commands.dart';

/// Error returned by Go (the `error` of a `(T, error)`, or a panic inside a
/// call).
class IpfsException implements Exception {
  IpfsException(this.message);

  final String message;

  @override
  String toString() => 'IpfsException: $message';
}

/// Go's `io.EOF`: the end of what is being read (`BlockReader.next`). Like
/// `errors.Is(err, io.EOF)`, it is also thrown when the error wraps it.
class IpfsEof extends IpfsException {
  IpfsEof(super.message);
}

/// Go's `io.ErrUnexpectedEOF`: the data ended in the middle (a truncated CAR).
class IpfsUnexpectedEof extends IpfsException {
  IpfsUnexpectedEof(super.message);
}

/// Go's `context.Canceled`: the context was canceled (`cancel()`).
class IpfsCanceled extends IpfsException {
  IpfsCanceled(super.message);
}

/// Go's `context.DeadlineExceeded`: the context deadline passed
/// (`withTimeout`, `withDeadline`).
class IpfsDeadlineExceeded extends IpfsException {
  IpfsDeadlineExceeded(super.message);
}

/// Not found (`ipld.ErrNotFound`, the CAR storage's `ErrNotFound`): the block
/// or node is not in the store.
class IpfsNotFound extends IpfsException {
  IpfsNotFound(super.message);
}

/// A call made from inside a Dart callback waited for a lock that the Go
/// function of that callback holds: the host broke the deadlock (WIRE.md,
/// "Callback"). The message carries the Go stack. Thrown inside the callback;
/// if it escapes, the call with the callback throws it.
class IpfsDeadlockException extends IpfsException {
  IpfsDeadlockException(super.message);
}

/// The `error` event of the host (WIRE.md): the sentinel code that the Go
/// error wraps (`errors.Is`) and the message.
IpfsException $goError(Uint8List data) {
  final message = utf8.decode(data.length > 1 ? data.sublist(1) : const []);
  return switch (data.isEmpty ? 0 : data[0]) {
    1 => IpfsEof(message),
    2 => IpfsUnexpectedEof(message),
    3 => IpfsCanceled(message),
    4 => IpfsDeadlineExceeded(message),
    5 => IpfsNotFound(message),
    6 => IpfsDeadlockException(message),
    _ => IpfsException(message),
  };
}

/// Why the service stopped.
enum IpfsStopReason {
  /// The ipfs_host crashed (a Go panic, or the system killed it).
  crash,

  /// The app went to the background and the package stopped the service
  /// (`IpfsService.background` = `IpfsBackground.stop`).
  background,
}

/// The service stopped ([reason]: crashed or stopped in the background), the
/// channel closed, the service was not started or the handle belongs to a
/// previous service ([reason] null in these two). Relaunch with
/// `IpfsService.restart()`.
class IpfsServiceException extends IpfsException {
  IpfsServiceException(super.message, {this.reason});

  final IpfsStopReason? reason;

  @override
  String toString() => 'IpfsServiceException: $message';
}

// Request modes and response types (WIRE.md).
const _sync = 0, _async = 1, _streamMode = 2;
const _evValue = 0, _evItem = 1, _evEnd = 2, _evError = 3;

/// Free function (WIRE.md): `u32 n` + n × `i64`, no response (id 0).
const _fnFree = 3;

/// This isolate's service channel (null = not started or stopped).
ShmChannel? _ch;

/// Service epoch: increases on each [$attach]. A handle keeps the epoch it
/// was born in and is only valid in it (the host's objects die with the
/// process).
var _epoch = 0;

/// Why the service stopped (until the next [$attach]); null if it never
/// started or was stopped by the app.
IpfsServiceException? _stopped;

ShmChannel get _channel =>
    _ch ??
    (throw _stopped ??
        IpfsServiceException(
            'the service was not started (await IpfsService.start())'));

/// Binds the runtime to a freshly opened channel (IpfsService.start, after
/// the Hello).
void $attach(ShmChannel ch) {
  _ch = ch;
  _stopped = null;
  _epoch++;
  _toFree.clear();
  ch
    ..onMessage = _onMessage
    ..onDead = _onDead;
}

/// Unbinds the runtime from the channel (IpfsService.stop); pending calls fail
/// when the channel closes. [why]: the stop (crash, background), which new
/// calls receive until the service starts again.
void $detach([IpfsServiceException? why]) {
  _ch = null;
  _stopped = why;
  _toFree.clear();
}

/// Pending call: the Completer (async), StreamController (stream) or GoSink;
/// the argument writer (keeps the sent handles alive until the response, so
/// the Finalizer does not release them earlier) and the ids of its sinks.
final class _Pending {
  _Pending(this.sink, this.keep, this.sinks);

  final Object sink;
  final Object? keep;
  final List<int> sinks;
}

final _pending = <int, _Pending>{};

/// Sinks already closed by Go, waiting for the response of their call:
/// `close()` only completes once the listener has received the end.
final _sinkDone = <int, Future<void>>{};

void _onMessage(int id, int kind, Uint8List data) {
  final p = _pending[id];
  if (p == null) return; // sink already closed by the end of the call
  switch ((kind, p.sink)) {
    case (_evCallback, _Callback cb):
      cb._batch(id, data);
      return;
    case (_evValue, _Callback cb):
      final r = $R(data);
      _finish(id, p).then((_) => cb._finish(r));
      return;
    case (_evError, _Callback cb):
      final e = $goError(data);
      _finish(id, p).then((_) => cb._finish(e));
      return;
    case (_evValue, Completer<$R> c):
      final r = $R(data);
      _finish(id, p).then((_) => c.complete(r));
      return;
    case (_evItem, StreamController<$R> s):
      s.add($R(data));
      return;
    case (_evItem, GoSink<Object?> s):
      s._add($R(data));
      return;
    case (_evEnd, StreamController<$R> s):
      s.close();
    case (_evEnd, GoSink<Object?> s):
      _sinkDone[id] = s.sink.close();
    case (_evError, GoSink<Object?> s):
      s.sink.addError($goError(data));
      _sinkDone[id] = s.sink.close();
    case (_evError, Completer<$R> c):
      final e = $goError(data);
      _finish(id, p).then((_) => c.completeError(e));
      return;
    case (_evError, final sink):
      _failSink(sink, $goError(data));
    default:
      return; // type that does not fit this pending call: ignored
  }
  _finish(id, p);
}

/// End of a call: the sinks Go did not close are closed now (Go closes them
/// before the response; WIRE.md). Completes when the listeners of all its
/// sinks have received the end, so the call responds after them.
Future<void> _finish(int id, _Pending p) {
  _pending.remove(id);
  final done = [
    for (final s in p.sinks)
      if (_sinkDone.remove(s) case final f?) f
  ];
  _closeSinks(p.sinks, null, done);
  return done.isEmpty ? Future.value() : Future.wait(done);
}

void _closeSinks(List<int> sinks, [Object? error, List<Future<void>>? done]) {
  for (final s in sinks) {
    _sinkDone.remove(s);
    if (_pending.remove(s)?.sink case final GoSink<Object?> sink) {
      if (error != null) sink.sink.addError(error);
      final f = sink.sink.close();
      done?.add(f);
    }
  }
}

void _failSink(Object sink, Object e, [StackTrace? st]) {
  switch (sink) {
    case _Callback cb:
      if (!cb.done.isCompleted) cb.done.completeError(e, st);
    case Completer<$R> c:
      c.completeError(e, st);
    case StreamController<$R> s:
      s
        ..addError(e, st)
        ..close();
    case GoSink<Object?> s:
      s.sink
        ..addError(e, st)
        ..close();
  }
}

void _onDead(IpfsServiceException e) {
  final all = [..._pending.values];
  _pending.clear();
  _sinkDone.clear();
  _toFree.clear();
  for (final p in all) {
    _failSink(p.sink, e);
  }
}

/// Registers the writer's sinks as pending and returns their ids.
List<int> _register($W? w) {
  if (w == null || w._sinks.isEmpty) return const [];
  for (final (id, s) in w._sinks) {
    _pending[id] = _Pending(s, null, const []);
  }
  return [for (final (id, _) in w._sinks) id];
}

/// Synchronous call: blocks the isolate until the host responds (spins, then
/// sleeps), delivering the other messages along the way.
$R $callSync(int fn, [$W? w]) {
  final ch = _channel;
  w?._check();
  final id = ch.newId();
  final sinks = _register(w);
  try {
    ch.send(id, fn, _sync | _watch(w), w?.take());
    final (kind, data) = ch.waitFor(id);
    if (kind == _evError) throw $goError(data);
    return $R(data);
  } catch (e) {
    _closeSinks(sinks, e);
    rethrow;
  } finally {
    _closeSinks(sinks);
  }
}

/// Asynchronous call: the response arrives through the channel.
Future<$R> $call(int fn, [$W? w]) {
  final c = Completer<$R>();
  _start(fn, _async, w, c);
  return c.future;
}

/// Stream: one `item` per value of the Go channel, until `end` or `error`.
Stream<$R> $stream(int fn, [$W? w]) {
  final s = StreamController<$R>();
  _start(fn, _streamMode, w, s);
  return s.stream;
}

void _start(int fn, int mode, $W? w, Object sink) {
  var sinks = const <int>[];
  try {
    final ch = _channel;
    w?._check();
    final id = ch.newId();
    sinks = _register(w);
    _pending[id] = _Pending(sink, w, sinks);
    try {
      ch.send(id, fn, mode | _watch(w), w?.take());
    } catch (_) {
      _pending.remove(id);
      rethrow;
    }
  } catch (e, st) {
    _closeSinks(sinks, e);
    _failSink(sink, e, st); // fails through the Future/Stream, not right away
  }
}

/// `chan<- T` channel that Go receives in an option (options.Unixfs.Events):
/// the sink is registered with its own id in the call; the items go to
/// [sink], which closes when the call ends.
final class GoSink<T> {
  GoSink(this.sink, this.decode);

  final StreamSink<T> sink;
  final T Function($R r) decode;

  void _add($R r) => sink.add(decode(r));
}

// Handles released by the Finalizer, sent in batches to the host (Free
// function).
final _toFree = <int>[];
final _finalizer = Finalizer<(int, int)>((t) {
  final (epoch, h) = t;
  // the service the handle was born in is gone: the object died with it
  if (epoch != _epoch || _ch == null) return;
  if (_toFree.isEmpty) Timer.run(_flushFree);
  _toFree.add(h);
});

void _flushFree() {
  final ch = _ch;
  if (ch == null || _toFree.isEmpty) return;
  final w = $W()..u32(_toFree.length);
  for (final h in _toFree) {
    w.i64(h);
  }
  _toFree.clear();
  try {
    ch.send(0, _fnFree, _sync, w.take());
  } on IpfsServiceException {
    // the host crashed: the objects went with it
  }
}

/// Object that lives in the host: Dart keeps the handle and the service
/// epoch; the Finalizer releases it (in batches) when the Dart object goes
/// away.
abstract class GoHandle {
  GoHandle(this.$h) : $e = _epoch {
    _finalizer.attach(this, ($e, $h));
  }

  final int $h;

  /// The service epoch in which the handle was born.
  final int $e;

  /// In use by a call with a callback that is still running (its receiver
  /// or an argument): calling it from inside the callback may wait for a
  /// lock that call holds (the host detects it: [IpfsDeadlockException]).
  bool get isBusy => _busy.containsKey($h);
}

/// Go value type (CID, path, peer ID, multiaddr) stored as a string.
abstract class GoValue {
  const GoValue(this.value);

  final String value;

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      other is GoValue &&
      other.runtimeType == runtimeType &&
      other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);
}

/// Go value that crosses as kubo's own JSON (config.Config).
abstract class GoJsonValue {
  GoJsonValue(this.json);

  final Map<String, Object?> json;
}

/// Go struct (DTO): writes the fields that cross, in order.
abstract interface class GoDto {
  void $enc($W w);
}

/// Go functional option: the constructor index (in the generator's
/// `tinfo.ctors`) and the function that writes its parameters.
abstract class GoOption {
  GoOption(this.$i, this.$a);

  final int $i;
  final void Function($W w) $a;
}

/// Non-null result: a Go nil becomes an IpfsException.
Never $nil() => throw IpfsException('Go returned nil');

/// Snapshot getter with an error: the value, or null if Go returned an error.
T? $orErr<T>(T v, String? err) => err == null ? v : null;
