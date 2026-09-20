// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `chunk_cookie_echo.go` (github.com/pion/sctp): [ChunkCookieEcho],
/// the SCTP COOKIE-ECHO chunk (type 10, RFC 4960 section-3.3.11), which
/// carries the state cookie previously sent in an INIT-ACK.
///
/// `chunkCookieEcho` is unexported in Go; see chunk.dart's file-level doc
/// comment for why [ChunkCookieEcho] is still public within `lib/src`, and
/// chunkheader.dart's for the `header`-field composition pattern used here.
library;

import 'dart:typed_data';

import 'chunk.dart';
import 'chunkheader.dart';
import 'chunktype.dart';

/// Port of `ErrChunkTypeNotCookieEcho` (chunk_cookie_echo.go:19-21).
final class ChunkTypeNotCookieEchoException implements Exception {
  const ChunkTypeNotCookieEchoException(this.actual);

  final ChunkType actual;

  @override
  String toString() => 'ChunkType is not of type COOKIEECHO: actually is $actual';
}

/// Port of `chunkCookieEcho` (chunk_cookie_echo.go:12-15).
final class ChunkCookieEcho implements Chunk {
  ChunkCookieEcho({Uint8List? cookie})
    : cookie = cookie ?? Uint8List(0),
      header = ChunkHeader(typ: ChunkType.cookieEcho, flags: 0, raw: Uint8List(0));

  /// Composition standing in for Go's embedded `chunkHeader`.
  ChunkHeader header;

  /// Port of `chunkCookieEcho.cookie` (chunk_cookie_echo.go:14).
  Uint8List cookie;

  /// Port of `chunkCookieEcho.unmarshal` (chunk_cookie_echo.go:23-32).
  @override
  void unmarshal(Uint8List raw) {
    header = ChunkHeader.unmarshal(raw);
    if (header.typ != ChunkType.cookieEcho) {
      throw ChunkTypeNotCookieEchoException(header.typ);
    }
    cookie = header.raw;
  }

  /// Port of `chunkCookieEcho.marshal` (chunk_cookie_echo.go:34-38).
  @override
  Uint8List marshal() {
    header.typ = ChunkType.cookieEcho;
    header.raw = cookie;
    return header.marshal();
  }

  /// Port of `chunkCookieEcho.check` (chunk_cookie_echo.go:40-42).
  @override
  bool check() => false;

  @override
  int valueLength() => header.valueLength();

  /// `chunkCookieEcho` defines no `String` method, so Go's `%v`/`Stringer`
  /// resolution falls through to the promoted `chunkHeader.String`.
  @override
  String toString() => header.toString();
}
