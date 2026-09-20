// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunkheader.go` (github.com/pion/sctp): [ChunkHeader], the
/// common 4-byte SCTP chunk header (RFC 4960 section-3.2):
///
/// ```
///  0                   1                   2                   3
///  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |   Chunk Type  | Chunk  Flags  |        Chunk Length           |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                          Chunk Value                          |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// ```
///
/// `chunkHeader` is unexported in Go; see util.dart's file-level doc comment
/// for why [ChunkHeader] is still public within `lib/src`.
///
/// Regra 10: Go computes `valueLength := int(length - chunkHeaderSize)`
/// where `length` is a `uint16` read off the wire. When the sender claims a
/// length shorter than the 4-byte header (a malformed/malicious packet),
/// `length - chunkHeaderSize` **wraps** in the uint16 domain (e.g.
/// `0 - 4 = 65532`) before being widened to `int` -- it does not go
/// negative. That wrapped, large `valueLength` is what makes the subsequent
/// bounds check reliably reject the packet. A plain Dart `int` subtraction
/// would go negative instead and silently take a different, unintended
/// branch, so [Golang.Uint16] is used for this specific subtraction to
/// reproduce Go's wraparound exactly.
library;

import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;

import 'chunktype.dart';

/// Port of `ErrChunkHeaderTooSmall` (chunkheader.go:41).
final class ChunkHeaderTooSmallException implements Exception {
  const ChunkHeaderTooSmallException(this.actualLength, this.minimumLength);

  final int actualLength;
  final int minimumLength;

  @override
  String toString() =>
      'raw is too small for a SCTP chunk: raw only $actualLength bytes, $minimumLength is the minimum length';
}

/// Port of `ErrChunkHeaderNotEnoughSpace` (chunkheader.go:42).
final class ChunkHeaderNotEnoughSpaceException implements Exception {
  const ChunkHeaderNotEnoughSpaceException(this.remaining, this.requested);

  final int remaining;
  final int requested;

  @override
  String toString() =>
      'not enough data left in SCTP packet to satisfy requested length: remain $remaining req $requested ';
}

/// Port of `ErrChunkHeaderPaddingNonZero` (chunkheader.go:43).
final class ChunkHeaderPaddingNonZeroException implements Exception {
  const ChunkHeaderPaddingNonZeroException(this.offset);

  final int offset;

  @override
  String toString() => 'chunk padding is non-zero at offset: $offset ';
}

/// Port of `chunkHeaderSize` (chunkheader.go:36).
const int chunkHeaderSize = 4;

/// Port of `chunkHeader` (chunkheader.go:29-33).
final class ChunkHeader {
  ChunkHeader({required this.typ, required this.flags, required this.raw});

  /// Port of `chunkHeader.unmarshal` (chunkheader.go:46-85).
  factory ChunkHeader.unmarshal(Uint8List raw) {
    if (raw.length < chunkHeaderSize) {
      throw ChunkHeaderTooSmallException(raw.length, chunkHeaderSize);
    }

    final typ = ChunkType.fromValue(raw[0]);
    final flags = raw[1];
    final lengthField = Golang.Uint16(ByteData.sublistView(raw, 2, 4).getUint16(0, Endian.big));

    // Length includes Chunk header; see the file-level doc comment for why
    // this subtraction must wrap like Go's uint16 arithmetic.
    final valueLength = (lengthField - Golang.Uint16(chunkHeaderSize)).toBigInt().toInt();
    final lengthAfterValue = raw.length - (chunkHeaderSize + valueLength);

    if (lengthAfterValue < 0) {
      throw ChunkHeaderNotEnoughSpaceException(valueLength, raw.length - chunkHeaderSize);
    } else if (lengthAfterValue < 4) {
      // https://tools.ietf.org/html/rfc4960#section-3.2
      // The Chunk Length field does not count any chunk padding. The
      // receiver MUST ignore the padding, but it MUST be zero.
      for (var i = lengthAfterValue; i > 0; i--) {
        final paddingOffset = chunkHeaderSize + valueLength + (i - 1);
        if (raw[paddingOffset] != 0) {
          throw ChunkHeaderPaddingNonZeroException(paddingOffset);
        }
      }
    }

    return ChunkHeader(
      typ: typ,
      flags: flags,
      raw: Uint8List.sublistView(raw, chunkHeaderSize, chunkHeaderSize + valueLength),
    );
  }

  /// Port of `chunkHeader.typ` (chunkheader.go:30).
  ChunkType typ;

  /// Port of `chunkHeader.flags` (chunkheader.go:31).
  int flags;

  /// Port of `chunkHeader.raw` (chunkheader.go:32): the chunk value.
  Uint8List raw;

  /// Port of `chunkHeader.marshal` (chunkheader.go:87-96).
  Uint8List marshal() {
    final out = Uint8List(4 + raw.length);
    out[0] = typ.value;
    out[1] = flags;
    ByteData.sublistView(out).setUint16(2, (raw.length + chunkHeaderSize) & 0xFFFF, Endian.big);
    out.setRange(4, 4 + raw.length, raw);
    return out;
  }

  /// Port of `chunkHeader.valueLength` (chunkheader.go:98-100).
  int valueLength() => raw.length;

  /// Port of `chunkHeader.String` (chunkheader.go:103-105).
  @override
  String toString() => typ.toString();
}
