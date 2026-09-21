// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `packet.go` (github.com/pion/sctp): [Packet], the SCTP common
/// header plus chunk sequence (RFC 4960 section-3), and the CRC32C
/// (Castagnoli) packet checksum it uses.
///
/// `packet` is unexported in Go; [Packet] is public within `lib/src` (see
/// util.dart's file-level doc comment) but not exported from
/// `transpiled_pion_sctp.dart`.
///
/// [Packet.unmarshal]'s dispatch covers exactly the 14 concrete chunk types
/// `packet.go`'s own `switch` (packet.go:104-134) covers: [ChunkInit],
/// [ChunkInitAck], [ChunkAbort], [ChunkCookieEcho], [ChunkCookieAck],
/// [ChunkHeartbeat], [ChunkPayloadData], [ChunkSelectiveAck],
/// [ChunkReconfig], [ChunkForwardTsn], [ChunkError], [ChunkShutdown],
/// [ChunkShutdownAck] and [ChunkShutdownComplete]. [ChunkHeartbeatAck] is
/// ported (chunk_heartbeat_ack.dart) but, like upstream, is not one of
/// these cases -- see that file's doc comment.
///
/// Regra 16 note: Dart has no stdlib CRC32C. Go's `hash/crc32` package uses
/// a *reflected* input/output Castagnoli table (polynomial `0x82F63B78`,
/// the bit-reversal of the normal form `0x1EDC6F41`); the table-driven
/// implementation below follows the same reflected-table algorithm as
/// `transpiled_pion_stun`'s `fingerprint.dart` (`_crc32Ieee`, CRC-32 IEEE),
/// just with the Castagnoli polynomial.
library;

import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;

import 'chunk.dart';
import 'chunk_abort.dart';
import 'chunk_cookie_ack.dart';
import 'chunk_cookie_echo.dart';
import 'chunk_error.dart';
import 'chunk_forward_tsn.dart';
import 'chunk_heartbeat.dart';
import 'chunk_init.dart';
import 'chunk_init_ack.dart';
import 'chunk_payload_data.dart';
import 'chunk_reconfig.dart';
import 'chunk_selective_ack.dart';
import 'chunk_shutdown.dart';
import 'chunk_shutdown_ack.dart';
import 'chunk_shutdown_complete.dart';
import 'chunkheader.dart';
import 'chunktype.dart';
import 'util.dart';

/// Port of `packetHeaderSize` (packet.go:56-58).
const int packetHeaderSize = 12;

final Uint32List _castagnoliTable = _buildCastagnoliTable();

Uint32List _buildCastagnoliTable() {
  const poly = 0x82F63B78;
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (poly ^ (c >> 1)) : (c >> 1);
    }
    table[n] = c;
  }
  return table;
}

/// Port of Go's `crc32.Update(crc, castagnoliTable, data)`: continues a
/// running CRC32C computation over one more chunk of `data`, matching Go's
/// invert-on-entry/invert-on-exit convention so that chaining calls (as
/// [generatePacketChecksum] does) is equivalent to hashing the
/// concatenation of every chunk in one pass.
int _crc32cUpdate(int crc, Uint8List data) {
  var c = Golang.Uint32(~crc).toBigInt().toInt();
  for (final b in data) {
    c = _castagnoliTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return Golang.Uint32(~c).toBigInt().toInt();
}

/// Port of `generatePacketChecksum` (packet.go:187-194): the SCTP common
/// header checksum (RFC 4960 section-6.8), computed over the packet with
/// the 4-byte checksum field itself treated as zero.
///
/// Unexported in Go; kept public within `lib/src` rather than underscored,
/// matching util.dart's `sna32*`/`sna16*` convention for
/// Go-unexported-but-cross-file symbols -- [Packet.unmarshal] and
/// [Packet.marshal] call it from this same file.
int generatePacketChecksum(Uint8List raw) {
  var sum = 0;
  sum = _crc32cUpdate(sum, Uint8List.sublistView(raw, 0, 8));
  sum = _crc32cUpdate(sum, Uint8List.fromList(const [0, 0, 0, 0]));
  sum = _crc32cUpdate(sum, Uint8List.sublistView(raw, 12));
  return sum;
}

/// Port of `ErrPacketRawTooSmall` (packet.go:60-62).
final class PacketRawTooSmallException implements Exception {
  const PacketRawTooSmallException(this.actualLength, this.minimumLength);

  final int actualLength;
  final int minimumLength;

  @override
  String toString() =>
      'raw is smaller than the minimum length for a SCTP packet: raw only $actualLength bytes, $minimumLength is the minimum length';
}

/// Port of `ErrParseSCTPChunkNotEnoughData` (packet.go:63).
final class ParseSctpChunkNotEnoughDataException implements Exception {
  const ParseSctpChunkNotEnoughDataException(this.offset, this.remaining);

  final int offset;
  final int remaining;

  @override
  String toString() =>
      'unable to parse SCTP chunk, not enough data for complete header: offset $offset remaining $remaining';
}

/// Port of `ErrUnmarshalUnknownChunkType` (packet.go:64).
final class UnmarshalUnknownChunkTypeException implements Exception {
  const UnmarshalUnknownChunkTypeException(this.actual);

  final ChunkType actual;

  @override
  String toString() =>
      'failed to unmarshal, contains unknown chunk type: $actual';
}

/// Port of `ErrChecksumMismatch` (packet.go:65).
final class ChecksumMismatchException implements Exception {
  const ChecksumMismatchException(this.theirs, this.ours);

  final int theirs;
  final int ours;

  @override
  String toString() => 'checksum mismatch theirs: $theirs ours: $ours';
}

/// Port of `packet` (packet.go:44-49).
final class Packet {
  Packet({
    this.sourcePort = 0,
    this.destinationPort = 0,
    this.verificationTag = 0,
    List<Chunk>? chunks,
  }) : chunks = chunks ?? <Chunk>[];

  /// Port of `packet.sourcePort` (packet.go:45).
  int sourcePort;

  /// Port of `packet.destinationPort` (packet.go:46).
  int destinationPort;

  /// Port of `packet.verificationTag` (packet.go:47).
  int verificationTag;

  /// Port of `packet.chunks` (packet.go:48).
  List<Chunk> chunks;

  /// Port of `packet.unmarshal` (packet.go:68-159).
  void unmarshal(bool doChecksum, Uint8List raw) {
    if (raw.length < packetHeaderSize) {
      throw PacketRawTooSmallException(raw.length, packetHeaderSize);
    }

    var offset = packetHeaderSize;
    var shouldChecksum = doChecksum;

    // Check if doing CRC32c is required. Without having SCTP AUTH
    // implemented, this depends only on the type of the first chunk.
    if (offset + chunkHeaderSize <= raw.length) {
      final firstType = raw[offset];
      if (firstType == ChunkType.init.value ||
          firstType == ChunkType.cookieEcho.value) {
        shouldChecksum = true;
      }
    }
    final theirChecksum = ByteData.sublistView(
      raw,
      8,
      12,
    ).getUint32(0, Endian.little);
    if (theirChecksum != 0 || shouldChecksum) {
      final ourChecksum = generatePacketChecksum(raw);
      if (theirChecksum != ourChecksum) {
        throw ChecksumMismatchException(theirChecksum, ourChecksum);
      }
    }

    final headerView = ByteData.sublistView(raw, 0, 8);
    sourcePort = headerView.getUint16(0, Endian.big);
    destinationPort = headerView.getUint16(2, Endian.big);
    verificationTag = headerView.getUint32(4, Endian.big);

    final parsedChunks = <Chunk>[];
    while (true) {
      // Exact match, no more chunks
      if (offset == raw.length) {
        break;
      } else if (offset + chunkHeaderSize > raw.length) {
        throw ParseSctpChunkNotEnoughDataException(offset, raw.length - offset);
      }

      final Chunk dataChunk;
      switch (raw[offset]) {
        case 1:
          dataChunk = ChunkInit();
        case 2:
          dataChunk = ChunkInitAck();
        case 6:
          dataChunk = ChunkAbort();
        case 10:
          dataChunk = ChunkCookieEcho();
        case 11:
          dataChunk = ChunkCookieAck();
        case 4:
          dataChunk = ChunkHeartbeat();
        case 0:
          dataChunk = ChunkPayloadData();
        case 3:
          dataChunk = ChunkSelectiveAck();
        case 130:
          dataChunk = ChunkReconfig();
        case 192:
          dataChunk = ChunkForwardTsn();
        case 9:
          dataChunk = ChunkError();
        case 7:
          dataChunk = ChunkShutdown();
        case 8:
          dataChunk = ChunkShutdownAck();
        case 14:
          dataChunk = ChunkShutdownComplete();
        default:
          throw UnmarshalUnknownChunkTypeException(
            ChunkType.fromValue(raw[offset]),
          );
      }

      dataChunk.unmarshal(Uint8List.sublistView(raw, offset));

      parsedChunks.add(dataChunk);
      final chunkValuePadding = getPadding(dataChunk.valueLength());
      offset += chunkHeaderSize + dataChunk.valueLength() + chunkValuePadding;
    }
    chunks = parsedChunks;
  }

  /// Port of `packet.marshal` (packet.go:161-185).
  Uint8List marshal(bool doChecksum) {
    final out = BytesBuilder(copy: false);
    final header = Uint8List(packetHeaderSize);
    final headerView = ByteData.sublistView(header);
    headerView.setUint16(0, sourcePort & 0xFFFF, Endian.big);
    headerView.setUint16(2, destinationPort & 0xFFFF, Endian.big);
    headerView.setUint32(4, verificationTag, Endian.big);
    out.add(header);

    for (final c in chunks) {
      out.add(c.marshal());
      final padded = out.length;
      final paddingNeeded = getPadding(padded);
      if (paddingNeeded != 0) {
        out.add(Uint8List(paddingNeeded));
      }
    }

    final raw = out.toBytes();
    if (doChecksum) {
      // golang CRC32C uses reflected input and reflected output, the
      // net result of this is to have the bytes flipped compared to
      // the non reflected variant that the spec expects.
      //
      // Use little-endian to avoid flipping the bytes in to the spec
      // compliant checksum order.
      ByteData.sublistView(
        raw,
        8,
        12,
      ).setUint32(0, generatePacketChecksum(raw), Endian.little);
    }

    return raw;
  }

  /// Port of `packet.String` (packet.go:197-211).
  @override
  String toString() {
    var res =
        'Packet:\n'
        '\tsourcePort: $sourcePort\n'
        '\tdestinationPort: $destinationPort\n'
        '\tverificationTag: $verificationTag\n'
        '\t';
    for (var i = 0; i < chunks.length; i++) {
      res += 'Chunk $i:\n ${chunks[i]}';
    }
    return res;
  }
}

/// Port of `TryMarshalUnmarshal` (packet.go:214-225): attempts to marshal
/// and unmarshal a message, for fuzzing harnesses. Returns `1` on success,
/// `0` on any failure -- Go's fuzz-corpus-entrypoint convention.
int tryMarshalUnmarshal(Uint8List msg) {
  final p = Packet();
  try {
    p.unmarshal(false, msg);
  } on Object {
    return 0;
  }

  try {
    p.marshal(false);
  } on Object {
    return 0;
  }

  return 1;
}
