// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `payload_queue.go` (github.com/pion/sctp): [PayloadQueue], the
/// TSN-ordered [Queue] of `*chunkPayloadData` an `Association` uses as its
/// inflight (sent-but-not-yet-acked) queue.
///
/// `payloadQueue` is unexported in Go; [PayloadQueue] stays public within
/// `lib/src` (see util.dart's file-level doc comment) but is not exported
/// from `transpiled_pion_sctp.dart`.
library;

import 'dart:typed_data';

import 'chunk_payload_data.dart';
import 'queue.dart';

/// Port of `payloadQueue` (payload_queue.go:6-9).
final class PayloadQueue {
  /// Port of `newPayloadQueue` (payload_queue.go:11-13).
  PayloadQueue() : chunks = Queue<ChunkPayloadData>(128);

  /// Port of `payloadQueue.chunks` (payload_queue.go:7).
  final Queue<ChunkPayloadData> chunks;

  /// Port of `payloadQueue.nBytes` (payload_queue.go:8).
  int _nBytes = 0;

  /// Port of `payloadQueue.pushNoCheck` (payload_queue.go:15-18).
  void pushNoCheck(ChunkPayloadData p) {
    chunks.pushBack(p);
    _nBytes += p.userData.length;
  }

  /// Port of `payloadQueue.pop` (payload_queue.go:21-30): pops only if the
  /// oldest chunk's TSN matches the given TSN.
  ChunkPayloadData? pop(int tsn) {
    final front = chunks.front();
    if (chunks.len() > 0 && front != null && tsn == front.tsn) {
      final c = chunks.popFront()!;
      _nBytes -= c.userData.length;
      return c;
    }
    return null;
  }

  /// Port of `payloadQueue.get` (payload_queue.go:33-44): returns the
  /// `chunkPayloadData` with the given TSN value.
  ChunkPayloadData? get(int tsn) {
    final length = chunks.len();
    if (length == 0) {
      return null;
    }
    final head = chunks.front()!.tsn;
    if (tsn < head || (tsn - head) >= length) {
      return null;
    }
    return chunks.at(tsn - head);
  }

  /// Port of `payloadQueue.markAsAcked` (payload_queue.go:46-57).
  int markAsAcked(int tsn) {
    var nBytesAcked = 0;
    final c = get(tsn);
    if (c != null) {
      c.acked = true;
      c.retransmit = false;
      nBytesAcked = c.userData.length;
      _nBytes -= nBytesAcked;
      c.userData = Uint8List(0);
    }
    return nBytesAcked;
  }

  /// Port of `payloadQueue.markAllToRetrasmit` (payload_queue.go:59-67).
  void markAllToRetrasmit() {
    for (var i = 0; i < chunks.len(); i++) {
      final c = chunks.at(i)!;
      if (c.acked || c.abandoned()) {
        continue;
      }
      c.retransmit = true;
    }
  }

  /// Port of `payloadQueue.getNumBytes` (payload_queue.go:69-71).
  int getNumBytes() => _nBytes;

  /// Port of `payloadQueue.size` (payload_queue.go:73-75).
  int size() => chunks.len();
}
