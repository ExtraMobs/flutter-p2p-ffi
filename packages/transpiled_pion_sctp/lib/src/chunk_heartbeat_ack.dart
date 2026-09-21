// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunk_heartbeat_ack.go` (github.com/pion/sctp):
/// [ChunkHeartbeatAck], the SCTP HEARTBEAT-ACK chunk (type 5, RFC 4960
/// section-3.3.6), which echoes back a single Heartbeat Info parameter.
///
/// `chunkHeartbeatAck` is unexported in Go; see chunk.dart's file-level doc
/// comment for why [ChunkHeartbeatAck] is still public within `lib/src`,
/// and chunkheader.dart's for the `header`-field composition pattern used
/// here.
///
/// **Not reachable from `packet.unmarshal`'s dispatch**: unlike the other
/// 14 concrete chunk types this codec-layer pass ports, `ctHeartbeatAck` is
/// not one of the cases in `packet.go`'s chunk-type `switch`
/// (packet.go:104-134 -- see packet.dart's own doc comment) -- only
/// `ctHeartbeat` (`ChunkHeartbeat`) is. `chunkHeartbeatAck` is ported here
/// for completeness of the concrete-chunk-type set (there are 16
/// `chunk_*.go` files on disk, not 14; `chunk_init_common.go` supplies
/// `ChunkInitCommon`, not itself a `chunk`), reachable only from the
/// out-of-scope `association`/`stream` layer that builds one to *send*.
///
/// **Verified upstream defect, ported as-is**: `chunkHeartbeatAck.unmarshal`
/// (chunk_heartbeat_ack.go:53-55) unconditionally returns `ErrUnimplemented`
/// regardless of its input -- there is no partial or best-effort parsing to
/// preserve, just the permanent stub.
library;

import 'dart:typed_data';

import 'chunk.dart';
import 'chunkheader.dart';
import 'chunktype.dart';
import 'param.dart';
import 'param_heartbeat_info.dart';
import 'util.dart';

/// Port of `ErrUnimplemented` (chunk_heartbeat_ack.go:34).
final class UnimplementedException implements Exception {
  const UnimplementedException();

  @override
  String toString() => 'unimplemented';
}

/// Port of `ErrHeartbeatAckParams` (chunk_heartbeat_ack.go:35).
final class HeartbeatAckParamsException implements Exception {
  const HeartbeatAckParamsException();

  @override
  String toString() => 'heartbeat Ack must have one param';
}

/// Port of `ErrHeartbeatAckNotHeartbeatInfo` (chunk_heartbeat_ack.go:36).
final class HeartbeatAckNotHeartbeatInfoException implements Exception {
  const HeartbeatAckNotHeartbeatInfoException();

  @override
  String toString() =>
      'heartbeat Ack must have one param, and it should be a HeartbeatInfo';
}

/// Port of `ErrHeartbeatAckMarshalParam` (chunk_heartbeat_ack.go:37),
/// wrapping the error a param's `marshal` raised.
final class HeartbeatAckMarshalParamException implements Exception {
  const HeartbeatAckMarshalParamException(this.cause);

  final Object cause;

  @override
  String toString() => 'unable to marshal parameter for Heartbeat Ack: $cause';
}

/// Port of `chunkHeartbeatAck` (chunk_heartbeat_ack.go:30-33).
final class ChunkHeartbeatAck implements Chunk {
  ChunkHeartbeatAck({List<Param>? params})
    : params = params ?? <Param>[],
      header = ChunkHeader(
        typ: ChunkType.heartbeatAck,
        flags: 0,
        raw: Uint8List(0),
      );

  /// Composition standing in for Go's embedded `chunkHeader`.
  ChunkHeader header;

  /// Port of `chunkHeartbeatAck.params` (chunk_heartbeat_ack.go:32).
  List<Param> params;

  /// Port of `chunkHeartbeatAck.unmarshal` (chunk_heartbeat_ack.go:53-55).
  @override
  void unmarshal(Uint8List raw) => throw const UnimplementedException();

  /// Port of `chunkHeartbeatAck.marshal` (chunk_heartbeat_ack.go:57-84).
  @override
  Uint8List marshal() {
    if (params.length != 1) {
      throw const HeartbeatAckParamsException();
    }
    if (params[0] is! ParamHeartbeatInfo) {
      throw const HeartbeatAckNotHeartbeatInfoException();
    }

    final out = BytesBuilder(copy: false);
    for (var idx = 0; idx < params.length; idx++) {
      final Uint8List pp;
      try {
        pp = params[idx].marshal();
      } on Object catch (e) {
        throw HeartbeatAckMarshalParamException(e);
      }

      out.add(pp);

      // Chunks (including Type, Length, and Value fields) are padded out
      // by the sender with all zero bytes to be a multiple of 4 bytes
      // long. This padding MUST NOT be more than 3 bytes in total. The
      // Chunk Length value does not include terminating padding of the
      // chunk. *However, it does include padding of any variable-length
      // parameter except the last parameter in the chunk.* The receiver
      // MUST ignore the padding.
      if (idx != params.length - 1) {
        out.add(Uint8List(getPadding(pp.length)));
      }
    }

    header.typ = ChunkType.heartbeatAck;
    header.raw = out.toBytes();
    return header.marshal();
  }

  /// Port of `chunkHeartbeatAck.check` (chunk_heartbeat_ack.go:86-88).
  @override
  bool check() => false;

  @override
  int valueLength() => header.valueLength();

  @override
  String toString() => header.toString();
}
