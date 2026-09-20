// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunktype.go` (github.com/pion/sctp): [ChunkType], the SCTP
/// Chunk Type field (RFC 4960 section-3.2).
///
/// `chunkType` and its `ct*` constants are unexported in Go; [ChunkType] is
/// public within `lib/src` (Dart has no narrower package-private
/// visibility -- see util.dart's file-level doc comment) but is not
/// exported from `transpiled_pion_sctp.dart`. The Go `ct` disambiguation
/// prefix (needed because Go constants are package- not type-scoped) is
/// dropped in favor of `ChunkType.<name>` static members, mirroring how
/// `transpiled_pion_stun`'s `MessageClass`/`Method` are ported.
library;

/// Port of `chunkType` (chunktype.go:11) and its `ct*` constants
/// (chunktype.go:14-31).
final class ChunkType {
  const ChunkType._(this.value);

  /// The raw wire value (a Go `uint8`).
  final int value;

  static const ChunkType payloadData = ChunkType._(0);
  static const ChunkType init = ChunkType._(1);
  static const ChunkType initAck = ChunkType._(2);
  static const ChunkType sack = ChunkType._(3);
  static const ChunkType heartbeat = ChunkType._(4);
  static const ChunkType heartbeatAck = ChunkType._(5);
  static const ChunkType abort = ChunkType._(6);
  static const ChunkType shutdown = ChunkType._(7);
  static const ChunkType shutdownAck = ChunkType._(8);
  static const ChunkType error = ChunkType._(9);
  static const ChunkType cookieEcho = ChunkType._(10);
  static const ChunkType cookieAck = ChunkType._(11);
  static const ChunkType cwr = ChunkType._(13);
  static const ChunkType shutdownComplete = ChunkType._(14);
  static const ChunkType reconfig = ChunkType._(130);
  static const ChunkType forwardTsn = ChunkType._(192);

  /// Constructs from the raw wire byte, mirroring Go's `chunkType(raw[0])`
  /// conversion (an unchecked, always-succeeding numeric cast in Go).
  factory ChunkType.fromValue(int value) => ChunkType._(value);

  @override
  bool operator ==(Object other) => other is ChunkType && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// Port of `chunkType.String` (chunktype.go:33-70).
  @override
  String toString() {
    switch (value) {
      case 0:
        return 'DATA';
      case 1:
        return 'INIT';
      case 2:
        return 'INIT-ACK';
      case 3:
        return 'SACK';
      case 4:
        return 'HEARTBEAT';
      case 5:
        return 'HEARTBEAT-ACK';
      case 6:
        return 'ABORT';
      case 7:
        return 'SHUTDOWN';
      case 8:
        return 'SHUTDOWN-ACK';
      case 9:
        return 'ERROR';
      case 10:
        return 'COOKIE-ECHO';
      case 11:
        return 'COOKIE-ACK';
      case 13:
        return 'ECNE'; // Explicit Congestion Notification Echo
      case 14:
        return 'SHUTDOWN-COMPLETE';
      case 130:
        return 'RECONFIG'; // Re-configuration
      case 192:
        return 'FORWARD-TSN';
      default:
        return 'Unknown ChunkType: $value';
    }
  }
}
