// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `param_chunk_list.go` (github.com/pion/sctp): [ParamChunkList],
/// the Chunk List parameter (RFC 4895), a list of [ChunkType] wire values.
///
/// `paramChunkList` is unexported in Go; see paramheader.dart's file-level
/// doc comment for the `header`-field composition pattern used here instead
/// of Go's struct embedding.
library;

import 'dart:typed_data';

import 'chunktype.dart';
import 'param.dart';
import 'paramheader.dart';
import 'paramtype.dart';

/// Port of `paramChunkList` (param_chunk_list.go:7-10).
final class ParamChunkList implements Param {
  ParamChunkList({List<ChunkType>? chunkTypes})
    : chunkTypes = chunkTypes ?? <ChunkType>[],
      header = ParamHeader(typ: ParamType.chunkList, len: 0, raw: Uint8List(0));

  /// Composition standing in for Go's embedded `paramHeader`.
  ParamHeader header;

  /// Port of `paramChunkList.chunkTypes` (param_chunk_list.go:9).
  List<ChunkType> chunkTypes;

  /// Port of `paramChunkList.marshal` (param_chunk_list.go:12-20).
  @override
  Uint8List marshal() {
    header.typ = ParamType.chunkList;
    header.raw = Uint8List.fromList([
      for (final t in chunkTypes) t.value & 0xFF,
    ]);
    return header.marshal();
  }

  /// Port of `paramChunkList.unmarshal` (param_chunk_list.go:22-30).
  void unmarshal(Uint8List raw) {
    header = ParamHeader.unmarshal(raw);
    chunkTypes = [for (final t in header.raw) ChunkType.fromValue(t)];
  }

  /// Port of `paramHeader.length` (param.go's `param.length`), promoted in
  /// Go via `paramChunkList`'s embedded `paramHeader`.
  @override
  int length() => header.length();
}
