// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `reassembly_queue.go` (github.com/pion/sctp): [ReassemblyQueue],
/// the per-`Stream` structure that reassembles fragmented DATA chunks (RFC
/// 4960 section-6.9) back into whole messages, in both ordered (by SSN) and
/// unordered (by contiguous TSN run) delivery, plus [ChunkSet], one
/// same-SSN/same-fragment-run group of chunks.
///
/// `reassemblyQueue` and `chunkSet` are unexported in Go; both stay public
/// within `lib/src` (see util.dart's file-level doc comment) but are not
/// exported from `transpiled_pion_sctp.dart`.
///
/// `reassemblyQueue.read` returns `(int, PayloadProtocolIdentifier, error)`
/// in Go, where the `error` is either `nil`, the sentinel `errTryAgain`
/// (nothing to read yet -- [Stream.readSctp] loops on this rather than
/// surfacing it), or `io.ErrShortBuffer` (some bytes *were* written before
/// the destination ran out of room -- Go's caller still wants that partial
/// count and the `ppi`, unlike every other `(T, error)` tuple in this
/// package). Per Regra 8 the two real error paths become thrown exceptions:
/// [TryAgainException] (no payload) and [ShortBufferException] (carries the
/// partial `bytesWritten` and `payloadType` the Go tuple would have
/// returned alongside the error), so [read]'s success path can return a
/// plain `(int, PayloadProtocolIdentifier)` record.
library;

import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;

import 'chunk_payload_data.dart';
import 'chunk_selective_ack.dart' show GapAckBlock;
import 'util.dart';

bool _sna32Lt(int i1, int i2) => sna32Lt(Golang.Uint32(i1), Golang.Uint32(i2));
bool _sna32Gt(int i1, int i2) => sna32Gt(Golang.Uint32(i1), Golang.Uint32(i2));
bool _sna16Lt(int i1, int i2) => sna16Lt(Golang.Uint16(i1), Golang.Uint16(i2));
bool _sna16Lte(int i1, int i2) =>
    sna16Lte(Golang.Uint16(i1), Golang.Uint16(i2));
bool _sna16Gt(int i1, int i2) => sna16Gt(Golang.Uint16(i1), Golang.Uint16(i2));

/// Port of `sortChunksByTSN` (reassembly_queue.go:13-17).
void _sortChunksByTsn(List<ChunkPayloadData> a) {
  a.sort((x, y) => _sna32Lt(x.tsn, y.tsn) ? -1 : (x.tsn == y.tsn ? 0 : 1));
}

/// Port of `sortChunksBySSN` (reassembly_queue.go:19-23).
void _sortChunksBySsn(List<ChunkSet> a) {
  a.sort((x, y) => _sna16Lt(x.ssn, y.ssn) ? -1 : (x.ssn == y.ssn ? 0 : 1));
}

/// Port of `errTryAgain` (reassembly_queue.go:112): nothing complete to read
/// yet. See this file's doc comment.
final class TryAgainException implements Exception {
  const TryAgainException();

  @override
  String toString() => 'try again';
}

/// Port of the `io.ErrShortBuffer` case of `reassemblyQueue.read`'s error
/// return. See this file's doc comment for why the partial result is
/// carried on the exception.
final class ShortBufferException implements Exception {
  const ShortBufferException(this.bytesWritten, this.payloadType);

  /// The `nTotal` Go would have returned alongside this error.
  final int bytesWritten;

  /// The `cset.ppi` Go would have returned alongside this error.
  final PayloadProtocolIdentifier payloadType;

  @override
  String toString() => 'short buffer';
}

/// Port of `chunkSet` (reassembly_queue.go:26-30).
final class ChunkSet {
  /// Port of `newChunkSet` (reassembly_queue.go:32-38).
  ChunkSet(this.ssn, this.ppi) : chunks = <ChunkPayloadData>[];

  /// Port of `chunkSet.ssn` (reassembly_queue.go:27): used only with the
  /// ordered chunks.
  int ssn;

  /// Port of `chunkSet.ppi` (reassembly_queue.go:28).
  PayloadProtocolIdentifier ppi;

  /// Port of `chunkSet.chunks` (reassembly_queue.go:29).
  List<ChunkPayloadData> chunks;

  /// Port of `chunkSet.push` (reassembly_queue.go:40-56).
  bool push(ChunkPayloadData chunk) {
    // check if dup
    for (final c in chunks) {
      if (c.tsn == chunk.tsn) {
        return false;
      }
    }

    // append and sort
    chunks.add(chunk);
    _sortChunksByTsn(chunks);

    // Check if we now have a complete set
    return isComplete();
  }

  /// Port of `chunkSet.isComplete` (reassembly_queue.go:58-101).
  bool isComplete() {
    // Condition for complete set
    //   0. Has at least one chunk.
    //   1. Begins with beginningFragment set to true
    //   2. Ends with endingFragment set to true
    //   3. TSN monotonically increase by 1 from beginning to end

    final nChunks = chunks.length;
    if (nChunks == 0) {
      return false;
    }

    if (!chunks[0].beginningFragment) {
      return false;
    }

    if (!chunks[nChunks - 1].endingFragment) {
      return false;
    }

    var lastTsn = 0;
    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      if (i > 0) {
        // Fragments must have contiguous TSN
        if (chunk.tsn !=
            (Golang.Uint32(lastTsn) + Golang.Uint32(1)).toBigInt().toInt()) {
          // mid or end fragment is missing
          return false;
        }
      }

      lastTsn = chunk.tsn;
    }

    return true;
  }
}

/// Port of `reassemblyQueue` (reassembly_queue.go:103-110).
final class ReassemblyQueue {
  /// Port of `newReassemblyQueue` (reassembly_queue.go:114-126).
  ReassemblyQueue(this.si)
    : nextSsn = 0, // RFC 4960 Sec 6.5: SSN starts from 0.
      ordered = <ChunkSet>[],
      unordered = <ChunkSet>[],
      unorderedChunks = <ChunkPayloadData>[];

  /// Port of `reassemblyQueue.si` (reassembly_queue.go:104).
  int si;

  /// Port of `reassemblyQueue.nextSSN` (reassembly_queue.go:105): expected
  /// SSN for next ordered chunk.
  int nextSsn;

  /// Port of `reassemblyQueue.ordered` (reassembly_queue.go:106).
  List<ChunkSet> ordered;

  /// Port of `reassemblyQueue.unordered` (reassembly_queue.go:107).
  List<ChunkSet> unordered;

  /// Port of `reassemblyQueue.unorderedChunks` (reassembly_queue.go:108).
  List<ChunkPayloadData> unorderedChunks;

  /// Port of `reassemblyQueue.nBytes` (reassembly_queue.go:109). Go guards
  /// this with `sync/atomic`; this project drops that per
  /// `RULE_NO_ARTIFICIAL_CONCURRENCY` -- Dart has no concurrent mutation
  /// within a single isolate.
  int _nBytes = 0;

  /// Port of `reassemblyQueue.push` (reassembly_queue.go:128-192).
  bool push(ChunkPayloadData chunk) {
    ChunkSet? cset;

    if (chunk.streamIdentifier != si) {
      return false;
    }

    if (chunk.unordered) {
      // First, insert into unorderedChunks array
      unorderedChunks.add(chunk);
      _nBytes += chunk.userData.length;
      _sortChunksByTsn(unorderedChunks);

      // Scan unorderedChunks that are contiguous (in TSN)
      cset = _findCompleteUnorderedChunkSet();

      // If found, append the complete set to the unordered array
      if (cset != null) {
        unordered.add(cset);
        return true;
      }

      return false;
    }

    // This is an ordered chunk

    if (_sna16Lt(chunk.streamSequenceNumber, nextSsn)) {
      return false;
    }

    // Check if a fragmented chunkSet with the fragmented SSN already exists
    if (chunk.isFragmented()) {
      for (final set in ordered) {
        if (set.ssn == chunk.streamSequenceNumber &&
            set.chunks[0].isFragmented()) {
          cset = set;
          break;
        }
      }
    }

    // If not found, create a new chunkSet
    if (cset == null) {
      cset = ChunkSet(chunk.streamSequenceNumber, chunk.payloadType);
      ordered.add(cset);
      if (!chunk.unordered) {
        _sortChunksBySsn(ordered);
      }
    }

    _nBytes += chunk.userData.length;

    return cset.push(chunk);
  }

  /// Port of `reassemblyQueue.findCompleteUnorderedChunkSet`
  /// (reassembly_queue.go:194-253).
  ChunkSet? _findCompleteUnorderedChunkSet() {
    var startIdx = -1;
    var nChunks = 0;
    var lastTsn = 0;
    var found = false;

    for (var i = 0; i < unorderedChunks.length; i++) {
      final chunk = unorderedChunks[i];
      // seek beginning
      if (chunk.beginningFragment) {
        startIdx = i;
        nChunks = 1;
        lastTsn = chunk.tsn;

        if (chunk.endingFragment) {
          found = true;
          break;
        }

        continue;
      }

      if (startIdx < 0) {
        continue;
      }

      // Check if contiguous in TSN
      if (chunk.tsn !=
          (Golang.Uint32(lastTsn) + Golang.Uint32(1)).toBigInt().toInt()) {
        startIdx = -1;
        continue;
      }

      lastTsn = chunk.tsn;
      nChunks++;

      if (chunk.endingFragment) {
        found = true;
        break;
      }
    }

    if (!found) {
      return null;
    }

    // Extract the range of chunks
    final chunks = unorderedChunks.sublist(startIdx, startIdx + nChunks);

    unorderedChunks = [
      ...unorderedChunks.sublist(0, startIdx),
      ...unorderedChunks.sublist(startIdx + nChunks),
    ];

    final chunkSet = ChunkSet(0, chunks[0].payloadType);
    chunkSet.chunks = chunks;

    return chunkSet;
  }

  /// Port of `reassemblyQueue.isReadable` (reassembly_queue.go:255-273).
  bool isReadable() {
    // Check unordered first
    if (unordered.isNotEmpty) {
      // The chunk sets in unordered should all be complete.
      return true;
    }

    // Check ordered sets
    if (ordered.isNotEmpty) {
      final cset = ordered[0];
      if (cset.isComplete()) {
        if (_sna16Lte(cset.ssn, nextSsn)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Port of `reassemblyQueue.read` (reassembly_queue.go:275-324). Returns
  /// `(bytesRead, payloadType)` on success; throws [TryAgainException] or
  /// [ShortBufferException] otherwise -- see this file's doc comment.
  (int, PayloadProtocolIdentifier) read(Uint8List buf) {
    ChunkSet cset;
    bool isUnordered;

    if (unordered.isNotEmpty) {
      cset = unordered[0];
      isUnordered = true;
    } else if (ordered.isNotEmpty) {
      cset = ordered[0];
      if (!cset.isComplete()) {
        throw const TryAgainException();
      }
      if (_sna16Gt(cset.ssn, nextSsn)) {
        throw const TryAgainException();
      }
      isUnordered = false;
    } else {
      throw const TryAgainException();
    }

    var nTotal = 0;
    var shortBuffer = false;
    for (final c in cset.chunks) {
      if (buf.length - nTotal < c.userData.length) {
        shortBuffer = true;
      } else {
        buf.setRange(nTotal, nTotal + c.userData.length, c.userData);
      }
      nTotal += c.userData.length;
    }

    if (shortBuffer) {
      throw ShortBufferException(nTotal, cset.ppi);
    }

    if (isUnordered) {
      unordered = unordered.sublist(1);
    } else {
      ordered = ordered.sublist(1);
      if (cset.ssn == nextSsn) {
        nextSsn = (Golang.Uint16(nextSsn) + Golang.Uint16(1))
            .toBigInt()
            .toInt();
      }
    }

    _subtractNumBytes(nTotal);

    return (nTotal, cset.ppi);
  }

  /// Port of `reassemblyQueue.forwardTSNForOrdered`
  /// (reassembly_queue.go:326-349).
  void forwardTsnForOrdered(int lastSsn) {
    // Use lastSSN to locate a chunkSet then remove it if the set has
    // not been complete
    final keep = <ChunkSet>[];
    for (final set in ordered) {
      if (_sna16Lte(set.ssn, lastSsn)) {
        if (!set.isComplete()) {
          // drop the set
          for (final c in set.chunks) {
            _subtractNumBytes(c.userData.length);
          }
          continue;
        }
      }
      keep.add(set);
    }
    ordered = keep;

    // Finally, forward nextSSN
    if (_sna16Lte(nextSsn, lastSsn)) {
      nextSsn = (Golang.Uint16(lastSsn) + Golang.Uint16(1)).toBigInt().toInt();
    }
  }

  /// Port of `reassemblyQueue.forwardTSNForUnordered`
  /// (reassembly_queue.go:351-370).
  void forwardTsnForUnordered(int newCumulativeTsn) {
    // Remove all fragments in the unordered sets that contains chunks
    // equal to or older than `newCumulativeTsn`.
    var lastIdx = -1;
    for (var i = 0; i < unorderedChunks.length; i++) {
      if (_sna32Gt(unorderedChunks[i].tsn, newCumulativeTsn)) {
        break;
      }
      lastIdx = i;
    }
    if (lastIdx >= 0) {
      for (final c in unorderedChunks.sublist(0, lastIdx + 1)) {
        _subtractNumBytes(c.userData.length);
      }
      unorderedChunks = unorderedChunks.sublist(lastIdx + 1);
    }
  }

  /// Port of `reassemblyQueue.subtractNumBytes` (reassembly_queue.go:372-379).
  void _subtractNumBytes(int nBytes) {
    if (_nBytes >= nBytes) {
      _nBytes -= nBytes;
    } else {
      _nBytes = 0;
    }
  }

  /// Port of `reassemblyQueue.getNumBytes` (reassembly_queue.go:381-383).
  int getNumBytes() => _nBytes;
}
