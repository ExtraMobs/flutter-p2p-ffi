// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunk_cookie_ack.go` (github.com/pion/sctp): [ChunkCookieAck],
/// the SCTP COOKIE-ACK chunk (type 11, RFC 4960 section-3.3.12), which
/// carries no value beyond its 4-byte header.
///
/// `chunkCookieAck` is unexported in Go; see chunk.dart's file-level doc
/// comment for why [ChunkCookieAck] is still public within `lib/src`, and
/// chunkheader.dart's for the `header`-field composition pattern used here
/// instead of Go's struct embedding.
library;

import 'dart:typed_data';

import 'chunk.dart';
import 'chunkheader.dart';
import 'chunktype.dart';

/// Port of `ErrChunkTypeNotCookieAck` (chunk_cookie_ack.go:23-25).
final class ChunkTypeNotCookieAckException implements Exception {
  const ChunkTypeNotCookieAckException(this.actual);

  final ChunkType actual;

  @override
  String toString() => 'ChunkType is not of type COOKIEACK: actually is $actual';
}

/// Port of `chunkCookieAck` (chunk_cookie_ack.go:16-18).
final class ChunkCookieAck implements Chunk {
  ChunkCookieAck() : header = ChunkHeader(typ: ChunkType.cookieAck, flags: 0, raw: Uint8List(0));

  /// Composition standing in for Go's embedded `chunkHeader`.
  ChunkHeader header;

  /// Port of `chunkCookieAck.unmarshal` (chunk_cookie_ack.go:27-35).
  @override
  void unmarshal(Uint8List raw) {
    header = ChunkHeader.unmarshal(raw);
    if (header.typ != ChunkType.cookieAck) {
      throw ChunkTypeNotCookieAckException(header.typ);
    }
  }

  /// Port of `chunkCookieAck.marshal` (chunk_cookie_ack.go:37-41).
  @override
  Uint8List marshal() {
    header.typ = ChunkType.cookieAck;
    return header.marshal();
  }

  /// Port of `chunkCookieAck.check` (chunk_cookie_ack.go:43-45).
  @override
  bool check() => false;

  @override
  int valueLength() => header.valueLength();

  /// Port of `chunkCookieAck.String` (chunk_cookie_ack.go:48-50).
  @override
  String toString() => header.toString();
}
