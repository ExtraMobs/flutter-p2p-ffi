// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `param_supported_extensions.go` (github.com/pion/sctp):
/// [ParamSupportedExtensions], the Supported Extensions parameter
/// (RFC 5061), a list of [ChunkType] wire values the sender supports.
///
/// `paramSupportedExtensions` is unexported in Go, so despite its
/// `ChunkTypes` field being capitalized upstream (param_supported_extensions.go:8)
/// the type itself never escapes the Go package boundary; this port uses
/// the package's normal `lowerCamelCase` member convention (`chunkTypes`)
/// rather than preserving that capitalization, since no external Go caller
/// could ever observe it. See paramheader.dart's file-level doc comment for
/// the `header`-field composition pattern used here.
library;

import 'dart:typed_data';

import 'chunktype.dart';
import 'param.dart';
import 'paramheader.dart';
import 'paramtype.dart';

/// Port of `paramSupportedExtensions` (param_supported_extensions.go:7-10).
final class ParamSupportedExtensions implements Param {
  ParamSupportedExtensions({List<ChunkType>? chunkTypes})
    : chunkTypes = chunkTypes ?? <ChunkType>[],
      header = ParamHeader(typ: ParamType.supportedExt, len: 0, raw: Uint8List(0));

  /// Composition standing in for Go's embedded `paramHeader`.
  ParamHeader header;

  /// Port of `paramSupportedExtensions.ChunkTypes` (param_supported_extensions.go:9).
  List<ChunkType> chunkTypes;

  /// Port of `paramSupportedExtensions.marshal` (param_supported_extensions.go:12-20).
  @override
  Uint8List marshal() {
    header.typ = ParamType.supportedExt;
    header.raw = Uint8List.fromList([for (final t in chunkTypes) t.value & 0xFF]);
    return header.marshal();
  }

  /// Port of `paramSupportedExtensions.unmarshal` (param_supported_extensions.go:22-31).
  void unmarshal(Uint8List raw) {
    header = ParamHeader.unmarshal(raw);
    chunkTypes = [for (final t in header.raw) ChunkType.fromValue(t)];
  }

  @override
  int length() => header.length();
}
