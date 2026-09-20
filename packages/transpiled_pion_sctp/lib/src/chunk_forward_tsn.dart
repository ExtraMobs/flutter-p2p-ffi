// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunk_forward_tsn.go` (github.com/pion/sctp): [ChunkForwardTsn],
/// the SCTP FORWARD-TSN chunk (type 192, RFC 3758 section-3.2), and
/// [ChunkForwardTsnStream], the per-stream skip record it carries.
///
/// `chunkForwardTSN` and `chunkForwardTSNStream` are unexported in Go; see
/// chunk.dart's file-level doc comment for why [ChunkForwardTsn] is still
/// public within `lib/src`, and chunkheader.dart's for the `header`-field
/// composition pattern used here.
library;

import 'dart:typed_data';

import 'chunk.dart';
import 'chunkheader.dart';
import 'chunktype.dart';

/// Port of `ErrMarshalStreamFailed` (chunk_forward_tsn.go:50), wrapping the
/// error `chunkForwardTSNStream.unmarshal`/`marshal` raised.
final class MarshalStreamFailedException implements Exception {
  const MarshalStreamFailedException(this.cause);

  final Object cause;

  @override
  String toString() => 'failed to marshal stream: $cause';
}

/// Port of `ErrChunkTooShort` (chunk_forward_tsn.go:51).
final class ChunkTooShortException implements Exception {
  const ChunkTooShortException();

  @override
  String toString() => 'chunk too short';
}

/// Port of `newCumulativeTSNLength` (chunk_forward_tsn.go:45).
const int newCumulativeTsnLength = 4;

/// Port of `forwardTSNStreamLength` (chunk_forward_tsn.go:46).
const int forwardTsnStreamLength = 4;

/// Port of `chunkForwardTSNStream` (chunk_forward_tsn.go:116-129).
final class ChunkForwardTsnStream {
  ChunkForwardTsnStream({this.identifier = 0, this.sequence = 0});

  /// Port of `chunkForwardTSNStream.identifier` (chunk_forward_tsn.go:119).
  int identifier;

  /// Port of `chunkForwardTSNStream.sequence` (chunk_forward_tsn.go:128).
  int sequence;

  /// Port of `chunkForwardTSNStream.length` (chunk_forward_tsn.go:131-133).
  int length() => forwardTsnStreamLength;

  /// Port of `chunkForwardTSNStream.unmarshal` (chunk_forward_tsn.go:135-142).
  void unmarshal(Uint8List raw) {
    if (raw.length < forwardTsnStreamLength) {
      throw const ChunkTooShortException();
    }
    final view = ByteData.sublistView(raw, 0, forwardTsnStreamLength);
    identifier = view.getUint16(0, Endian.big);
    sequence = view.getUint16(2, Endian.big);
  }

  /// Port of `chunkForwardTSNStream.marshal` (chunk_forward_tsn.go:144-150).
  Uint8List marshal() {
    final out = Uint8List(forwardTsnStreamLength);
    final view = ByteData.sublistView(out);
    view.setUint16(0, identifier & 0xFFFF, Endian.big);
    view.setUint16(2, sequence & 0xFFFF, Endian.big);
    return out;
  }
}

/// Port of `chunkForwardTSN` (chunk_forward_tsn.go:31-41).
final class ChunkForwardTsn implements Chunk {
  ChunkForwardTsn({this.newCumulativeTsn = 0, List<ChunkForwardTsnStream>? streams})
    : streams = streams ?? <ChunkForwardTsnStream>[],
      header = ChunkHeader(typ: ChunkType.forwardTsn, flags: 0, raw: Uint8List(0));

  /// Composition standing in for Go's embedded `chunkHeader`.
  ChunkHeader header;

  /// Port of `chunkForwardTSN.newCumulativeTSN` (chunk_forward_tsn.go:37).
  int newCumulativeTsn;

  /// Port of `chunkForwardTSN.streams` (chunk_forward_tsn.go:39).
  List<ChunkForwardTsnStream> streams;

  /// Port of `chunkForwardTSN.unmarshal` (chunk_forward_tsn.go:56-79).
  @override
  void unmarshal(Uint8List raw) {
    header = ChunkHeader.unmarshal(raw);

    if (header.raw.length < newCumulativeTsnLength) {
      throw const ChunkTooShortException();
    }

    newCumulativeTsn = ByteData.sublistView(header.raw, 0, 4).getUint32(0, Endian.big);

    var offset = newCumulativeTsnLength;
    var remaining = header.raw.length - offset;
    final parsed = <ChunkForwardTsnStream>[];
    while (remaining > 0) {
      final s = ChunkForwardTsnStream();
      try {
        s.unmarshal(Uint8List.sublistView(header.raw, offset));
      } on Object catch (e) {
        throw MarshalStreamFailedException(e);
      }
      parsed.add(s);
      offset += s.length();
      remaining -= s.length();
    }
    streams = parsed;
  }

  /// Port of `chunkForwardTSN.marshal` (chunk_forward_tsn.go:81-96).
  @override
  Uint8List marshal() {
    final out = BytesBuilder(copy: false);
    final fixed = Uint8List(newCumulativeTsnLength);
    ByteData.sublistView(fixed).setUint32(0, newCumulativeTsn, Endian.big);
    out.add(fixed);

    for (final s in streams) {
      final Uint8List b;
      try {
        b = s.marshal();
      } on Object catch (e) {
        throw MarshalStreamFailedException(e);
      }
      out.add(b);
    }

    header.typ = ChunkType.forwardTsn;
    header.raw = out.toBytes();
    return header.marshal();
  }

  /// Port of `chunkForwardTSN.check` (chunk_forward_tsn.go:101-103). Ported
  /// as-is: unlike every other codec-layer chunk type, this one
  /// unconditionally requests abort with no attached reason
  /// (`return true, nil`), which the RFC 6525 `// TODO` sibling in
  /// [ChunkReconfig.check] shares -- see that file's doc comment.
  @override
  bool check() => true;

  @override
  int valueLength() => header.valueLength();

  /// Port of `chunkForwardTSN.String` (chunk_forward_tsn.go:106-113).
  @override
  String toString() {
    var res = 'New Cumulative TSN: $newCumulativeTsn\n';
    for (final s in streams) {
      res += ' - si=${s.identifier}, ssn=${s.sequence}\n';
    }
    return res;
  }
}
