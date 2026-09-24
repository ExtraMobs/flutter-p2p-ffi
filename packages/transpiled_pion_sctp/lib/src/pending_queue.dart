// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `pending_queue.go` (github.com/pion/sctp): [PendingQueue], the
/// unsent-DATA queue an `Association` drains into its inflight queue
/// (`payload_queue.dart`) as `cwnd`/`rwnd` allow, keeping ordered and
/// unordered chunks in separate FIFOs so a partially-sent fragmented
/// message is never interleaved with another one on the same queue.
///
/// `pendingBaseQueue` and `pendingQueue` are unexported in Go.
/// `pendingBaseQueue` never crosses this file's boundary upstream (every
/// other file reaches it only through `pendingQueue`'s own methods), so it
/// is kept fully private here (`_PendingBaseQueue`) rather than given the
/// "public within `lib/src`" treatment `util.dart`'s doc comment describes
/// for cross-file-but-unexported Go symbols. [PendingQueue] itself does
/// cross into `association.dart` (an `Association` field) and stays public
/// within `lib/src` accordingly.
library;

import 'chunk_payload_data.dart';

/// Port of `ErrUnexpectedChuckPoppedUnordered` (pending_queue.go:58). The Go
/// name's "Chuck" (not "Chunk") is preserved verbatim per Regra 13's
/// `ErrX`-to-`XException` mapping.
final class UnexpectedChuckPoppedUnorderedException implements Exception {
  const UnexpectedChuckPoppedUnorderedException();

  @override
  String toString() => 'unexpected chunk popped (unordered)';
}

/// Port of `ErrUnexpectedChuckPoppedOrdered` (pending_queue.go:59).
final class UnexpectedChuckPoppedOrderedException implements Exception {
  const UnexpectedChuckPoppedOrderedException();

  @override
  String toString() => 'unexpected chunk popped (ordered)';
}

/// Port of `ErrUnexpectedQState` (pending_queue.go:60).
final class UnexpectedQStateException implements Exception {
  const UnexpectedQStateException();

  @override
  String toString() => "unexpected q state (should've been selected)";
}

/// Port of `pendingBaseQueue` (pending_queue.go:12-14). See this file's doc
/// comment for why this stays fully private.
final class _PendingBaseQueue {
  /// Port of `newPendingBaseQueue` (pending_queue.go:16-18).
  _PendingBaseQueue() : _queue = <ChunkPayloadData>[];

  List<ChunkPayloadData> _queue;

  /// Port of `pendingBaseQueue.push` (pending_queue.go:20-22).
  void push(ChunkPayloadData c) => _queue.add(c);

  /// Port of `pendingBaseQueue.pop` (pending_queue.go:24-32).
  ChunkPayloadData? pop() {
    if (_queue.isEmpty) {
      return null;
    }
    final c = _queue[0];
    _queue = _queue.sublist(1);
    return c;
  }

  /// Port of `pendingBaseQueue.get` (pending_queue.go:34-40).
  ChunkPayloadData? get(int i) {
    if (_queue.isEmpty || i < 0 || i >= _queue.length) {
      return null;
    }
    return _queue[i];
  }

  /// Port of `pendingBaseQueue.size` (pending_queue.go:42-44).
  int size() => _queue.length;
}

/// Port of `pendingQueue` (pending_queue.go:48-54).
final class PendingQueue {
  /// Port of `newPendingQueue` (pending_queue.go:63-68).
  PendingQueue()
    : _unorderedQueue = _PendingBaseQueue(),
      _orderedQueue = _PendingBaseQueue();

  final _PendingBaseQueue _unorderedQueue;
  final _PendingBaseQueue _orderedQueue;
  int _nBytes = 0;
  bool _selected = false;
  bool _unorderedIsSelected = false;

  /// Port of `pendingQueue.push` (pending_queue.go:70-77).
  void push(ChunkPayloadData c) {
    if (c.unordered) {
      _unorderedQueue.push(c);
    } else {
      _orderedQueue.push(c);
    }
    _nBytes += c.userData.length;
  }

  /// Port of `pendingQueue.peek` (pending_queue.go:79-93).
  ChunkPayloadData? peek() {
    if (_selected) {
      if (_unorderedIsSelected) {
        return _unorderedQueue.get(0);
      }
      return _orderedQueue.get(0);
    }

    final c = _unorderedQueue.get(0);
    if (c != null) {
      return c;
    }

    return _orderedQueue.get(0);
  }

  /// Port of `pendingQueue.pop` (pending_queue.go:95-139). Go's `popped !=
  /// chunkPayload` pointer comparison becomes Dart reference equality via
  /// [identical].
  void pop(ChunkPayloadData chunkPayload) {
    if (_selected) {
      ChunkPayloadData? popped;
      if (_unorderedIsSelected) {
        popped = _unorderedQueue.pop();
        if (!identical(popped, chunkPayload)) {
          throw const UnexpectedChuckPoppedUnorderedException();
        }
      } else {
        popped = _orderedQueue.pop();
        if (!identical(popped, chunkPayload)) {
          throw const UnexpectedChuckPoppedOrderedException();
        }
      }
      if (popped!.endingFragment) {
        _selected = false;
      }
    } else {
      if (!chunkPayload.beginningFragment) {
        throw const UnexpectedQStateException();
      }
      if (chunkPayload.unordered) {
        final popped = _unorderedQueue.pop();
        if (!identical(popped, chunkPayload)) {
          throw const UnexpectedChuckPoppedUnorderedException();
        }
        if (!popped!.endingFragment) {
          _selected = true;
          _unorderedIsSelected = true;
        }
      } else {
        final popped = _orderedQueue.pop();
        if (!identical(popped, chunkPayload)) {
          throw const UnexpectedChuckPoppedOrderedException();
        }
        if (!popped!.endingFragment) {
          _selected = true;
          _unorderedIsSelected = false;
        }
      }
    }
    _nBytes -= chunkPayload.userData.length;
  }

  /// Port of `pendingQueue.getNumBytes` (pending_queue.go:141-143).
  int getNumBytes() => _nBytes;

  /// Port of `pendingQueue.size` (pending_queue.go:145-147).
  int size() => _unorderedQueue.size() + _orderedQueue.size();
}
