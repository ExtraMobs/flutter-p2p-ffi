// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunk_heartbeat.go` (github.com/pion/sctp): [ChunkHeartbeat],
/// the SCTP HEARTBEAT chunk (type 4, RFC 4960 section-3.3.5), which carries
/// a single mandatory Heartbeat Info parameter.
///
/// `chunkHeartbeat` is unexported in Go; see chunk.dart's file-level doc
/// comment for why [ChunkHeartbeat] is still public within `lib/src`, and
/// chunkheader.dart's for the `header`-field composition pattern used here.
///
/// **Verified upstream defect, ported as-is (not silently "fixed")**:
/// `chunkHeartbeat.Marshal` (chunk_heartbeat.go:81-83, capital `M`) is a
/// distinct Go method from the `chunk` interface's `marshal() ([]byte,
/// error)` (chunk.go:8, lowercase). Because the names differ only by case,
/// Go does *not* treat it as an override: `chunkHeartbeat` satisfies `chunk`
/// through the **promoted, embedded** `chunkHeader.marshal` instead, and the
/// capital `Marshal` -- which always returns `ErrUnimplemented` -- is
/// unreachable dead code whenever a `chunkHeartbeat` is used through the
/// `chunk` interface (as `packet.unmarshal`'s dispatch does for `ctHeartbeat`
/// -- see packet.dart). This was independently confirmed by running
/// `go build ./...` and `go vet ./...` against the pinned revision in
/// `go-ipfs-reference/pion-sctp` (both succeed): if the capital `Marshal`
/// were the interface implementation, `packet.go`'s `dataChunk =
/// &chunkHeartbeat{}` assignment (typed `chunk`) would fail to compile.
/// [ChunkHeartbeat.marshal] below ports the one Go actually calls -- the
/// promoted `chunkHeader.marshal`, i.e. `header.marshal()` -- not the dead
/// `Marshal`. Dart's `lowerCamelCase`-only member convention has no way to
/// spell both `marshal` and `Marshal` as distinct names, so the dead method
/// is not given a Dart symbol at all; this divergence is named here rather
/// than silently dropped.
library;

import 'dart:typed_data';

import 'chunk.dart';
import 'chunkheader.dart';
import 'chunktype.dart';
import 'param.dart';
import 'paramtype.dart';

/// Port of `ErrChunkTypeNotHeartbeat` (chunk_heartbeat.go:39).
final class ChunkTypeNotHeartbeatException implements Exception {
  const ChunkTypeNotHeartbeatException(this.actual);

  final ChunkType actual;

  @override
  String toString() =>
      'ChunkType is not of type HEARTBEAT: actually is $actual';
}

/// Port of `ErrHeartbeatNotLongEnoughInfo` (chunk_heartbeat.go:40).
final class HeartbeatNotLongEnoughInfoException implements Exception {
  const HeartbeatNotLongEnoughInfoException(this.length);

  final int length;

  @override
  String toString() =>
      'heartbeat is not long enough to contain Heartbeat Info: $length';
}

/// Port of `ErrParseParamTypeFailed` (chunk_heartbeat.go:41), wrapping the
/// error `parseParamType` raised.
final class ParseParamTypeFailedException implements Exception {
  const ParseParamTypeFailedException(this.cause);

  final Object cause;

  @override
  String toString() => 'failed to parse param type: $cause';
}

/// Port of `ErrHeartbeatParam` (chunk_heartbeat.go:42).
final class HeartbeatParamException implements Exception {
  const HeartbeatParamException(this.actual);

  final ParamType actual;

  @override
  String toString() =>
      'heartbeat should only have HEARTBEAT param: instead have $actual';
}

/// Port of `ErrHeartbeatChunkUnmarshal` (chunk_heartbeat.go:43), wrapping
/// the error `buildParam` raised.
final class HeartbeatChunkUnmarshalException implements Exception {
  const HeartbeatChunkUnmarshalException(this.cause);

  final Object cause;

  @override
  String toString() => 'failed unmarshalling param in Heartbeat Chunk: $cause';
}

/// Port of `chunkHeartbeat` (chunk_heartbeat.go:34-37).
final class ChunkHeartbeat implements Chunk {
  ChunkHeartbeat({List<Param>? params})
    : params = params ?? <Param>[],
      header = ChunkHeader(
        typ: ChunkType.heartbeat,
        flags: 0,
        raw: Uint8List(0),
      );

  /// Composition standing in for Go's embedded `chunkHeader`.
  ChunkHeader header;

  /// Port of `chunkHeartbeat.params` (chunk_heartbeat.go:36).
  List<Param> params;

  /// Port of `chunkHeartbeat.unmarshal` (chunk_heartbeat.go:53-77).
  @override
  void unmarshal(Uint8List raw) {
    header = ChunkHeader.unmarshal(raw);
    if (header.typ != ChunkType.heartbeat) {
      throw ChunkTypeNotHeartbeatException(header.typ);
    }
    if (raw.length <= chunkHeaderSize) {
      throw HeartbeatNotLongEnoughInfoException(raw.length);
    }

    final ParamType pType;
    try {
      pType = ParamType.parse(header.raw);
    } on Object catch (e) {
      throw ParseParamTypeFailedException(e);
    }
    if (pType != ParamType.heartbeatInfo) {
      throw HeartbeatParamException(pType);
    }

    final Param p;
    try {
      p = buildParam(pType, header.raw);
    } on Object catch (e) {
      throw HeartbeatChunkUnmarshalException(e);
    }
    params.add(p);
  }

  /// Port of the promoted `chunkHeader.marshal` -- see this file's doc
  /// comment for why `chunkHeartbeat.Marshal` (chunk_heartbeat.go:81-83)
  /// is *not* what this ports.
  @override
  Uint8List marshal() => header.marshal();

  /// Port of `chunkHeartbeat.check` (chunk_heartbeat.go:85-87).
  @override
  bool check() => false;

  @override
  int valueLength() => header.valueLength();

  @override
  String toString() => header.toString();
}
