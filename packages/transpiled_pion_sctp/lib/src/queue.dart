// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `queue.go` (github.com/pion/sctp): [Queue], a generic ring-buffer
/// FIFO. Its sole instantiation upstream is `*queue[*chunkPayloadData]`,
/// used by [PayloadQueue] (payload_queue.dart) to hold chunks awaiting
/// acknowledgement.
///
/// `queue[T]` is unexported in Go; [Queue] stays public within `lib/src`
/// (see util.dart's file-level doc comment) but is not exported from
/// `transpiled_pion_sctp.dart`.
///
/// Go's zero-initialized backing array lets `Front`/`Back`/`At`/`PopFront`
/// on an empty (or under-populated) queue return `T`'s zero value (`nil` for
/// the pointer element type this queue is actually instantiated with)
/// instead of panicking. Dart generics have no zero value for a
/// non-nullable `T`, so this port stores `T?` internally and every such
/// accessor returns `T?` -- preserving "never throws, caller must check
/// `len` first" as the observable contract. Every real call site
/// (`payload_queue.dart`) already checks `len`/compares TSNs before calling
/// these, exactly as `payload_queue.go` does, so this is not reachable with
/// a meaningfully different value than Go's `nil` would have been.
library;

/// Port of `queue[T]` (queue.go:6-11) and its `newQueue` constructor
/// (queue.go:15-24, ported as the default constructor per this project's
/// `NewX` convention).
final class Queue<T> {
  /// Port of `newQueue[T any](capacity int) *queue[T]` (queue.go:15-24).
  Queue(int capacity) : _buf = List<T?>.filled(_queueCap(capacity), null);

  static const int _minCap = 16;

  static int _queueCap(int capacity) {
    var queueCap = _minCap;
    while (queueCap < capacity) {
      queueCap <<= 1;
    }
    return queueCap;
  }

  List<T?> _buf;
  int _head = 0;
  int _tail = 0;
  int _count = 0;

  /// Port of `queue.Len` (queue.go:26-28).
  int len() => _count;

  /// Port of `queue.PushBack` (queue.go:30-35).
  void pushBack(T ele) {
    _growIfFull();
    _buf[_tail] = ele;
    _tail = (_tail + 1) % _buf.length;
    _count++;
  }

  /// Port of `queue.PopFront` (queue.go:37-44). See this file's doc comment
  /// for the `T?` return type adaptation.
  T? popFront() {
    final ele = _buf[_head];
    _buf[_head] = null;
    _head = (_head + 1) % _buf.length;
    _count--;
    return ele;
  }

  /// Port of `queue.Front` (queue.go:47-49).
  T? front() => _buf[_head];

  /// Port of `queue.Back` (queue.go:51-53).
  T? back() => _buf[(_tail - 1 + _buf.length) % _buf.length];

  /// Port of `queue.At` (queue.go:55-57).
  T? at(int i) => _buf[(_head + i) % _buf.length];

  /// Port of `queue.growIfFull` (queue.go:59-75).
  void _growIfFull() {
    if (_count < _buf.length) {
      return;
    }

    final newBuf = List<T?>.filled(_count << 1, null);
    if (_tail > _head) {
      newBuf.setRange(0, _count, _buf, _head);
    } else {
      final n = _buf.length - _head;
      newBuf.setRange(0, n, _buf, _head);
      newBuf.setRange(n, n + _tail, _buf, 0);
    }

    _head = 0;
    _tail = _count;
    _buf = newBuf;
  }
}
