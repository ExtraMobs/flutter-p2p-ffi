// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunk_init_common.go` (github.com/pion/sctp):
/// [ChunkInitCommon], the shared fixed+variable body of the INIT and
/// INIT-ACK chunks (RFC 4960 section-3.3.2/3.3.3).
///
/// `chunkInitCommon` is unexported in Go and embedded by both `chunkInit`
/// and `chunkInitAck` *in addition to* `chunkHeader` (Go's "double
/// embedding"). Dart has no struct embedding, so [ChunkInit] and
/// [ChunkInitAck] each hold a `header` field ([ChunkHeader]) *and* a
/// `common` field (this type), delegating to both explicitly -- the same
/// composition pattern chunkheader.dart's doc comment describes for
/// [ChunkHeader] alone.
library;

import 'dart:typed_data';

import 'param.dart';
import 'paramheader.dart';
import 'util.dart';

/// Port of `ErrInitChunkParseParamTypeFailed` (chunk_init_common.go:57),
/// wrapping the error `paramHeader.unmarshal` raised.
final class InitChunkParseParamTypeFailedException implements Exception {
  const InitChunkParseParamTypeFailedException(this.cause);

  final Object cause;

  @override
  String toString() => 'failed to parse param type: $cause';
}

/// Port of `ErrInitAckMarshalParam` (chunk_init_common.go:58), wrapping the
/// error a param's `marshal` raised.
final class InitAckMarshalParamException implements Exception {
  const InitAckMarshalParamException(this.cause);

  final Object cause;

  @override
  String toString() => 'unable to marshal parameter for INIT/INITACK: $cause';
}

/// Port of `initChunkMinLength` (chunk_init_common.go:53).
const int initChunkMinLength = 16;

/// Port of `initOptionalVarHeaderLength` (chunk_init_common.go:54).
const int initOptionalVarHeaderLength = 4;

/// Port of `chunkInitCommon` (chunk_init_common.go:43-51).
final class ChunkInitCommon {
  ChunkInitCommon({
    this.initiateTag = 0,
    this.advertisedReceiverWindowCredit = 0,
    this.numOutboundStreams = 0,
    this.numInboundStreams = 0,
    this.initialTsn = 0,
    List<Param>? params,
    List<ParamHeader>? unrecognizedParams,
  }) : params = params ?? <Param>[],
       unrecognizedParams = unrecognizedParams ?? <ParamHeader>[];

  /// Port of `chunkInitCommon.initiateTag` (chunk_init_common.go:44).
  int initiateTag;

  /// Port of `chunkInitCommon.advertisedReceiverWindowCredit`
  /// (chunk_init_common.go:45).
  int advertisedReceiverWindowCredit;

  /// Port of `chunkInitCommon.numOutboundStreams` (chunk_init_common.go:46).
  int numOutboundStreams;

  /// Port of `chunkInitCommon.numInboundStreams` (chunk_init_common.go:47).
  int numInboundStreams;

  /// Port of `chunkInitCommon.initialTSN` (chunk_init_common.go:48).
  int initialTsn;

  /// Port of `chunkInitCommon.params` (chunk_init_common.go:49).
  List<Param> params;

  /// Port of `chunkInitCommon.unrecognizedParams` (chunk_init_common.go:50).
  List<ParamHeader> unrecognizedParams;

  /// Port of `chunkInitCommon.unmarshal` (chunk_init_common.go:74-112).
  void unmarshal(Uint8List raw) {
    final view = ByteData.sublistView(raw);
    initiateTag = view.getUint32(0, Endian.big);
    advertisedReceiverWindowCredit = view.getUint32(4, Endian.big);
    numOutboundStreams = view.getUint16(8, Endian.big);
    numInboundStreams = view.getUint16(10, Endian.big);
    initialTsn = view.getUint32(12, Endian.big);

    var offset = initChunkMinLength;
    var remaining = raw.length - offset;
    final parsedParams = <Param>[];
    final parsedUnrecognized = <ParamHeader>[];
    while (remaining > 0) {
      if (remaining <= initOptionalVarHeaderLength) {
        break;
      }

      final ParamHeader pHeader;
      try {
        pHeader = ParamHeader.unmarshal(Uint8List.sublistView(raw, offset));
      } on Object catch (e) {
        throw InitChunkParseParamTypeFailedException(e);
      }

      try {
        parsedParams.add(buildParam(pHeader.typ, Uint8List.sublistView(raw, offset)));
      } on Object {
        parsedUnrecognized.add(pHeader);
      }

      final padding = getPadding(pHeader.length());
      offset += pHeader.length() + padding;
      remaining -= pHeader.length() + padding;
    }
    params = parsedParams;
    unrecognizedParams = parsedUnrecognized;
  }

  /// Port of `chunkInitCommon.marshal` (chunk_init_common.go:114-141).
  Uint8List marshal() {
    final out = BytesBuilder(copy: false);
    final fixed = Uint8List(initChunkMinLength);
    final view = ByteData.sublistView(fixed);
    view.setUint32(0, initiateTag, Endian.big);
    view.setUint32(4, advertisedReceiverWindowCredit, Endian.big);
    view.setUint16(8, numOutboundStreams & 0xFFFF, Endian.big);
    view.setUint16(10, numInboundStreams & 0xFFFF, Endian.big);
    view.setUint32(12, initialTsn, Endian.big);
    out.add(fixed);

    for (var idx = 0; idx < params.length; idx++) {
      final Uint8List pp;
      try {
        pp = params[idx].marshal();
      } on Object catch (e) {
        throw InitAckMarshalParamException(e);
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

    return out.toBytes();
  }

  /// Port of `chunkInitCommon.String` (chunk_init_common.go:144-163).
  @override
  String toString() {
    var res =
        'initiateTag: $initiateTag\n'
        '\tadvertisedReceiverWindowCredit: $advertisedReceiverWindowCredit\n'
        '\tnumOutboundStreams: $numOutboundStreams\n'
        '\tnumInboundStreams: $numInboundStreams\n'
        '\tinitialTSN: $initialTsn';
    for (var i = 0; i < params.length; i++) {
      res += 'Param $i:\n ${params[i]}';
    }
    return res;
  }
}
