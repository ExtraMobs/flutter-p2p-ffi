// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `receive_payload_queue.go` (github.com/pion/sctp):
/// [ReceivePayloadQueue], the bitmask-backed structure an `Association` uses
/// to track which inbound TSNs have been received (for SACK gap-ack-block
/// generation and cumulative TSN advancement) without keeping the payload
/// bytes themselves.
///
/// `receivePayloadQueue` is unexported in Go; [ReceivePayloadQueue] stays
/// public within `lib/src` (see util.dart's file-level doc comment) but is
/// not exported from `transpiled_pion_sctp.dart`.
///
/// This port models the Go `uint32` TSN domain as a plain Dart `int` (always
/// kept in `0..2^32-1`) and masks with `& 0xffffffff` at the handful of
/// additions that Go performs in `uint32` arithmetic and that can wrap
/// (`cumulativeTSN + maxTSNOffset`, `tsn + 1`) -- Dart's 64-bit `int` already
/// exceeds the 32-bit domain and never silently overflows the way Go's
/// `uint32` does, so an explicit mask after the addition reproduces Go's
/// wraparound bit-for-bit without boxing every arithmetic op in
/// `Golang.Uint32`. `getFirstNonZeroBit`/`getFirstZeroBit`'s `val uint64`
/// parameter uses Dart's unsigned right-shift operator (`>>>`) in place of
/// Go's `>>` on an already-unsigned type, since Dart's plain `>>` performs a
/// sign-extending arithmetic shift once bit 63 is set.
library;

import 'package:boilerplate/fixed_types/golang.dart' as Golang;

import 'chunk_selective_ack.dart' show GapAckBlock;
import 'util.dart';

const int _mask32 = 0xFFFFFFFF;

bool _sna32Lte(int i1, int i2) =>
    sna32Lte(Golang.Uint32(i1), Golang.Uint32(i2));
bool _sna32Gt(int i1, int i2) => sna32Gt(Golang.Uint32(i1), Golang.Uint32(i2));

/// Port of `getFirstNonZeroBit` (receive_payload_queue.go:193-197).
(int, bool) _getFirstNonZeroBit(int val, int start, int end) {
  final i = _trailingZeros64(val >>> start);
  return (i + start, i + start < end);
}

/// Port of `getFirstZeroBit` (receive_payload_queue.go:199-201).
(int, bool) _getFirstZeroBit(int val, int start, int end) =>
    _getFirstNonZeroBit(~val, start, end);

/// Port of `bits.TrailingZeros64` as used by `getFirstNonZeroBit`.
int _trailingZeros64(int v) {
  if (v == 0) {
    return 64;
  }
  var value = v;
  var n = 0;
  while (value & 1 == 0) {
    value = value >>> 1;
    n++;
  }
  return n;
}

/// Port of `receivePayloadQueue` (receive_payload_queue.go:11-19).
final class ReceivePayloadQueue {
  /// Port of `newReceivePayloadQueue` (receive_payload_queue.go:21-28).
  ReceivePayloadQueue(int maxTSNOffset)
    : maxTSNOffset = (((maxTSNOffset + 63) ~/ 64) * 64) & _mask32,
      tsnBitmask = List<int>.filled(
        (((maxTSNOffset + 63) ~/ 64) * 64) ~/ 64,
        0,
      );

  /// Port of `receivePayloadQueue.tailTSN` (receive_payload_queue.go:12).
  int tailTsn = 0;

  /// Port of `receivePayloadQueue.chunkSize` (receive_payload_queue.go:13).
  int chunkSize = 0;

  /// Port of `receivePayloadQueue.tsnBitmask` (receive_payload_queue.go:14),
  /// a Go `[]uint64`.
  List<int> tsnBitmask;

  /// Port of `receivePayloadQueue.dupTSN` (receive_payload_queue.go:15).
  List<int> dupTsn = <int>[];

  /// Port of `receivePayloadQueue.maxTSNOffset` (receive_payload_queue.go:16).
  final int maxTSNOffset;

  /// Port of `receivePayloadQueue.cumulativeTSN` (receive_payload_queue.go:18).
  int cumulativeTsn = 0;

  /// Port of `receivePayloadQueue.init` (receive_payload_queue.go:30-38).
  void init(int cumulativeTSN) {
    cumulativeTsn = cumulativeTSN;
    tailTsn = cumulativeTSN;
    chunkSize = 0;
    for (var i = 0; i < tsnBitmask.length; i++) {
      tsnBitmask[i] = 0;
    }
    dupTsn = <int>[];
  }

  /// Port of `receivePayloadQueue.hasChunk` (receive_payload_queue.go:40-48).
  bool hasChunk(int tsn) {
    if (chunkSize == 0 ||
        _sna32Lte(tsn, cumulativeTsn) ||
        _sna32Gt(tsn, tailTsn)) {
      return false;
    }

    final index = (tsn ~/ 64) % tsnBitmask.length;
    final offset = tsn % 64;

    return tsnBitmask[index] & (1 << offset) != 0;
  }

  /// Port of `receivePayloadQueue.canPush` (receive_payload_queue.go:50-57).
  bool canPush(int tsn) {
    final ok = hasChunk(tsn);
    if (ok ||
        _sna32Lte(tsn, cumulativeTsn) ||
        _sna32Gt(tsn, (cumulativeTsn + maxTSNOffset) & _mask32)) {
      return false;
    }
    return true;
  }

  /// Port of `receivePayloadQueue.push` (receive_payload_queue.go:62-82): if
  /// the payload data is already in the queue or older than the cumulative
  /// TSN marker, it is recorded as a duplicate, retrievable via
  /// [popDuplicates].
  bool push(int tsn) {
    if (_sna32Gt(tsn, (cumulativeTsn + maxTSNOffset) & _mask32)) {
      return false;
    }

    if (_sna32Lte(tsn, cumulativeTsn) || hasChunk(tsn)) {
      // Found the packet, log in dups
      dupTsn.add(tsn);
      return false;
    }

    final index = (tsn ~/ 64) % tsnBitmask.length;
    final offset = tsn % 64;
    tsnBitmask[index] |= (1 << offset);
    chunkSize++;
    if (_sna32Gt(tsn, tailTsn)) {
      tailTsn = tsn;
    }

    return true;
  }

  /// Port of `receivePayloadQueue.pop` (receive_payload_queue.go:84-103):
  /// advances the cumulative TSN and pops the oldest chunk's TSN if it
  /// matches the given TSN or `force` is true.
  bool pop(bool force) {
    final tsn = (cumulativeTsn + 1) & _mask32;
    if (hasChunk(tsn)) {
      final index = (tsn ~/ 64) % tsnBitmask.length;
      final offset = tsn % 64;
      tsnBitmask[index] &= ~(1 << offset);
      chunkSize--;
      cumulativeTsn = (cumulativeTsn + 1) & _mask32;
      return true;
    }
    if (force) {
      cumulativeTsn = (cumulativeTsn + 1) & _mask32;
      if (chunkSize == 0) {
        tailTsn = cumulativeTsn;
      }
    }

    return false;
  }

  /// Port of `receivePayloadQueue.popDuplicates`
  /// (receive_payload_queue.go:106-111).
  List<int> popDuplicates() {
    final dups = dupTsn;
    dupTsn = <int>[];
    return dups;
  }

  /// Port of `receivePayloadQueue.getGapAckBlocks`
  /// (receive_payload_queue.go:113-165).
  List<GapAckBlock> getGapAckBlocks() {
    final gapAckBlocks = <GapAckBlock>[];
    var ackBlockStart = 0;
    var ackBlockEnd = 0;

    if (chunkSize == 0) {
      return gapAckBlocks;
    }

    final startTsn = (cumulativeTsn + 1) & _mask32;
    final endTsn = tailTsn;
    var findEnd = false;
    var tsn = startTsn;
    while (_sna32Lte(tsn, endTsn)) {
      final index = (tsn ~/ 64) % tsnBitmask.length;
      final offset = tsn % 64;
      if (!findEnd) {
        // find first received tsn as start
        final (nonZeroBit, ok) = _getFirstNonZeroBit(
          tsnBitmask[index],
          offset,
          64,
        );
        if (ok) {
          ackBlockStart =
              (tsn + (nonZeroBit - offset) - cumulativeTsn) & 0xFFFF;
          tsn = (tsn + (nonZeroBit - offset)) & _mask32;
          findEnd = true;
        } else {
          // no result, find start bits in next uint64 bitmask
          tsn = (tsn + (64 - offset)) & _mask32;
        }
      } else {
        final (zeroBit, ok) = _getFirstZeroBit(tsnBitmask[index], offset, 64);
        if (ok) {
          ackBlockEnd = (tsn + (zeroBit - offset) - 1 - cumulativeTsn) & 0xFFFF;
          tsn = (tsn + (zeroBit - offset)) & _mask32;
          if (_sna32Lte(tsn, endTsn)) {
            gapAckBlocks.add(
              GapAckBlock(start: ackBlockStart, end: ackBlockEnd),
            );
          }
          findEnd = false;
        } else {
          tsn = (tsn + (64 - offset)) & _mask32;
        }

        // no zero bit at the end, close and append the last gap
        if (_sna32Gt(tsn, endTsn)) {
          ackBlockEnd = (endTsn - cumulativeTsn) & 0xFFFF;
          gapAckBlocks.add(GapAckBlock(start: ackBlockStart, end: ackBlockEnd));
          break;
        }
      }
    }

    return gapAckBlocks;
  }

  /// Port of `receivePayloadQueue.getGapAckBlocksString`
  /// (receive_payload_queue.go:167-175).
  String getGapAckBlocksString() {
    final gapAckBlocks = getGapAckBlocks();
    var str = 'cumTSN=$cumulativeTsn';
    for (final b in gapAckBlocks) {
      str += ',${b.start}-${b.end}';
    }
    return str;
  }

  /// Port of `receivePayloadQueue.getLastTSNReceived`
  /// (receive_payload_queue.go:177-183). Returns `null` where Go returns
  /// `(0, false)`.
  int? getLastTSNReceived() {
    if (chunkSize == 0) {
      return null;
    }
    return tailTsn;
  }

  /// Port of `receivePayloadQueue.getcumulativeTSN`
  /// (receive_payload_queue.go:185-187).
  int getcumulativeTSN() => cumulativeTsn;

  /// Port of `receivePayloadQueue.size` (receive_payload_queue.go:189-191).
  int size() => chunkSize;
}
