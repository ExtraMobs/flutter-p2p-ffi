// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunk_reconfig.go` (github.com/pion/sctp): [ChunkReconfig], the
/// SCTP RE-CONFIG chunk (type 130, RFC 6525 section-3.1), carrying one or
/// two Re-configuration Parameters.
///
/// `chunkReconfig` is unexported in Go; see chunk.dart's file-level doc
/// comment for why [ChunkReconfig] is still public within `lib/src`, and
/// chunkheader.dart's for the `header`-field composition pattern used here.
library;

import 'dart:typed_data';

import 'chunk.dart';
import 'chunkheader.dart';
import 'chunktype.dart';
import 'param.dart';
import 'paramtype.dart';
import 'util.dart';

/// Port of `ErrChunkParseParamTypeFailed` (chunk_reconfig.go:34), wrapping
/// the error `parseParamType` raised.
final class ChunkParseParamTypeFailedException implements Exception {
  const ChunkParseParamTypeFailedException(this.cause);

  final Object cause;

  @override
  String toString() => 'failed to parse param type: $cause';
}

/// Port of `chunkReconfig` (chunk_reconfig.go:28-31).
final class ChunkReconfig implements Chunk {
  ChunkReconfig({this.paramA, this.paramB}) : header = ChunkHeader(typ: ChunkType.reconfig, flags: 0, raw: Uint8List(0));

  /// Composition standing in for Go's embedded `chunkHeader`.
  ChunkHeader header;

  /// Port of `chunkReconfig.paramA` (chunk_reconfig.go:29).
  Param? paramA;

  /// Port of `chunkReconfig.paramB` (chunk_reconfig.go:30).
  Param? paramB;

  /// Port of `chunkReconfig.unmarshal` (chunk_reconfig.go:38-66).
  @override
  void unmarshal(Uint8List raw) {
    header = ChunkHeader.unmarshal(raw);

    final ParamType pTypeA;
    try {
      pTypeA = ParamType.parse(header.raw);
    } on Object catch (e) {
      throw ChunkParseParamTypeFailedException(e);
    }
    final a = buildParam(pTypeA, header.raw);
    paramA = a;

    final padding = getPadding(a.length());
    final offset = a.length() + padding;
    if (header.raw.length > offset) {
      final ParamType pTypeB;
      try {
        pTypeB = ParamType.parse(Uint8List.sublistView(header.raw, offset));
      } on Object catch (e) {
        throw ChunkParseParamTypeFailedException(e);
      }
      paramB = buildParam(pTypeB, Uint8List.sublistView(header.raw, offset));
    } else {
      paramB = null;
    }
  }

  /// Port of `chunkReconfig.marshal` (chunk_reconfig.go:68-87).
  @override
  Uint8List marshal() {
    var out = paramA!.marshal();
    final b = paramB;
    if (b != null) {
      // Pad param A
      out = padByte(out, getPadding(out.length));
      out = Uint8List.fromList([...out, ...b.marshal()]);
    }

    header.typ = ChunkType.reconfig;
    header.raw = out;
    return header.marshal();
  }

  /// Port of `chunkReconfig.check` (chunk_reconfig.go:89-94). Ported as-is:
  /// unconditionally requests abort with no attached reason (`return true,
  /// nil`) -- the RFC 6525 section-3.1 combination checks upstream still
  /// marks `// TODO` were never written, and [ChunkForwardTsn.check] shares
  /// the same unconditional shape.
  @override
  bool check() => true;

  @override
  int valueLength() => header.valueLength();

  /// Port of `chunkReconfig.String` (chunk_reconfig.go:97-104).
  @override
  String toString() {
    var res = 'Param A:\n $paramA';
    if (paramB != null) {
      res += 'Param B:\n $paramB';
    }
    return res;
  }
}
