import 'dart:async';

/// Closer implements a coordination closer mirroring Go's internal/closer.
class Closer {
  final Completer<void> _done = Completer<void>();
  Object? _err;
  bool _closed = false;

  /// Creates a new Closer.
  Closer();

  /// Creates a new Closer chained with a parent.
  Closer.withParent(Closer parent) {
    parent
        .done()
        .then((_) {
          close();
        })
        .catchError((Object err) {
          _err = err;
          close();
        });
  }

  /// Factory constructor for CloserWithParent.
  factory Closer.closerWithParent(Closer parent) => Closer.withParent(parent);

  /// Returns a future that completes when close has been called.
  Future<void> done() => _done.future;

  /// Returns the error if any.
  Object? err() => _err;

  /// Closes the Closer.
  void close([Object? error]) {
    if (_closed) return;
    _closed = true;
    _err ??= error;
    if (!_done.isCompleted) {
      _done.complete();
    }
  }
}
