part of '../runtime.dart';

/// `callback` event (WIRE.md): a batch of invocations of the call's Go
/// callback.
const _evCallback = 4;

/// CallbackAck function (WIRE.md): `u32` call id + `u8` verdict, no response.
const _fnCallbackAck = 5;

/// Verdicts of a batch: go on, the Dart function returned false, it threw.
const _cbContinue = 0, _cbStopped = 1, _cbThrew = 2;

/// Asynchronous call whose Go function receives a callback (WIRE.md,
/// "Callback"): Go sends the arguments of its invocations in batches; [item]
/// decodes one invocation and calls the Dart function, in order, one at a
/// time (awaiting it). After each batch the verdict goes back to Go, which
/// only goes on after it. A `false` stops the iteration; an exception too,
/// and it is what the call throws (the original Dart exception).
Future<$R> $callCb(int fn, $W w, FutureOr<Object?> Function($R r) item) {
  final cb = _Callback(item);
  final handles = [
    for (final h in w._keep)
      if (h is GoHandle) h
  ];
  _start(fn, _async, w, cb);
  // em uso só depois de mandar: o próprio pedido não é vigiado
  _setBusy(handles, true);
  return cb.done.future.whenComplete(() => _setBusy(handles, false));
}

/// A change of [P2pBusy]: [handle] entered or left use by a call with a
/// callback.
final class P2pBusy {
  const P2pBusy(this.handle, this.busy);

  /// The object (a generated handle class: an index, a blockstore...).
  final Object handle;
  final bool busy;
}

/// Objects in use by calls with callbacks, by handle (the host gives the
/// same Go object the same handle, whatever Dart object holds it), and how
/// many calls hold each one.
final _busy = <int, int>{};
final _busyChanges = StreamController<P2pBusy>.broadcast();

/// The changes of the objects in use (P2pService.busy).
Stream<P2pBusy> get $busyChanges => _busyChanges.stream;

void _setBusy(List<GoHandle> handles, bool busy) {
  for (final h in handles) {
    final n = (_busy[h.$h] ?? 0) + (busy ? 1 : -1);
    if (n > 0) {
      _busy[h.$h] = n;
    } else {
      _busy.remove(h.$h);
    }
    if ((busy && n == 1) || (!busy && n == 0)) {
      _busyChanges.add(P2pBusy(h, busy));
    }
  }
}

/// `modeWatch` (WIRE.md): the request touches an object in use, and the host
/// watches it for a deadlock.
int _watch($W? w) => w != null &&
        _busy.isNotEmpty &&
        w._keep.any((h) => h is GoHandle && _busy.containsKey(h.$h))
    ? 0x80
    : 0;

final class _Callback {
  _Callback(this.item);

  final FutureOr<Object?> Function($R r) item;
  final done = Completer<$R>();

  /// The batches and the result, in arrival order.
  var _queue = Future<void>.value();
  var _verdict = _cbContinue;
  Object? _error;
  StackTrace? _stack;

  void _batch(int id, Uint8List data) =>
      _queue = _queue.then((_) => _run(id, data));

  Future<void> _run(int id, Uint8List data) async {
    if (_verdict == _cbContinue) {
      final r = $R(data);
      final n = r.u32();
      for (var i = 0; i < n && _verdict == _cbContinue; i++) {
        try {
          if (await item(r) == false) _verdict = _cbStopped;
        } catch (e, st) {
          _error = e;
          _stack = st;
          _verdict = _cbThrew;
        }
      }
    }
    // Go waits for this one (or ignores it, if it already returned)
    try {
      _channel.send(
          0,
          _fnCallbackAck,
          _sync,
          ($W()
                ..u32(id)
                ..u8(_verdict))
              .take());
    } on P2pServiceException {
      // the service fell: the call fails through _onDead
    }
  }

  /// The call's response, after the batches that arrived before it: the
  /// Dart exception wins over whatever Go answered.
  void _finish(Object response) => _queue = _queue.then((_) {
        if (done.isCompleted) return;
        if (_error case final e?) {
          done.completeError(e, _stack);
        } else if (response is $R) {
          done.complete(response);
        } else {
          done.completeError(response);
        }
      });
}
