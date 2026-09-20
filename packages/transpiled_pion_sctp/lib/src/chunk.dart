// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunk.go` (github.com/pion/sctp): the [Chunk] contract every
/// concrete `chunk_*.go` type implements.
///
/// `chunk` is unexported in Go; see util.dart's file-level doc comment for
/// why [Chunk] is still public within `lib/src`.
///
/// `check() (bool, error)`, `marshal() ([]byte, error)` and
/// `unmarshal(raw []byte) error` all use Go's `(value, error)` tuple
/// convention; per Regra "RULE_NO_GO_STYLE_ERROR_TUPLES" each becomes a
/// direct return with the error path expressed as a thrown typed exception
/// instead. Specifically for `check`: whenever Go returns `(true, err)`
/// with a non-nil `err`, [Chunk.check] throws the named exception for that
/// `err` instead of returning; whenever Go returns `(x, nil)` (`x` being
/// `true` or `false`), [Chunk.check] returns `x` directly. Every
/// `chunk_*.go` `check` follows this same nil-error-iff-no-throw shape,
/// including the two (`chunkForwardTSN`, `chunkReconfig`) that
/// unconditionally `return true, nil`.
///
/// All 16 concrete `chunk_*.go` types are ported (`chunk_abort.dart`
/// through `chunk_shutdown_complete.dart`); see
/// `transpiled_pion_sctp.dart`'s library doc comment for the full list.
library;

import 'dart:typed_data';

/// Port of `chunk` (chunk.go:6-11).
abstract interface class Chunk {
  /// Port of `chunk.unmarshal` (chunk.go:7).
  void unmarshal(Uint8List raw);

  /// Port of `chunk.marshal` (chunk.go:8).
  Uint8List marshal();

  /// Port of `chunk.check` (chunk.go:9).
  bool check();

  /// Port of `chunk.valueLength` (chunk.go:11).
  int valueLength();
}
