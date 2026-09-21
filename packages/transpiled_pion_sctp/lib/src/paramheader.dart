// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `paramheader.go` (github.com/pion/sctp): [ParamHeader], the
/// common 4-byte SCTP parameter TLV header (RFC 9260 section-3.2.1).
///
/// `paramHeader` and `paramHeaderUnrecognizedAction` are unexported in Go;
/// [ParamHeader] and [ParamHeaderUnrecognizedAction] are public within
/// `lib/src` (see util.dart's file-level doc comment) but not exported from
/// `transpiled_pion_sctp.dart`.
///
/// Every concrete `param_*.go` type embeds `paramHeader`, so its promoted
/// `typ`/`raw` fields and `marshal`/`unmarshal`/`length` methods are read
/// and called directly by the embedding type. Dart has no struct embedding,
/// so each concrete `Param*` type in this package instead holds a `header`
/// field of type [ParamHeader] and delegates to it explicitly -- the same
/// adaptation `chunkheader.dart`'s doc comment describes for [ChunkHeader].
library;

import 'dart:typed_data';

import 'paramtype.dart';

/// Port of `ErrParamHeaderTooShort` (paramheader.go:52).
final class ParamHeaderTooShortException implements Exception {
  const ParamHeaderTooShortException();

  @override
  String toString() => 'param header too short';
}

/// Port of `ErrParamHeaderSelfReportedLengthShorter` (paramheader.go:53).
final class ParamHeaderSelfReportedLengthShorterException implements Exception {
  const ParamHeaderSelfReportedLengthShorterException(
    this.reportedLength,
    this.headerLength,
  );

  final int reportedLength;
  final int headerLength;

  @override
  String toString() =>
      'param self reported length is shorter than header length: param self reported length ($reportedLength) shorter than header length ($headerLength)';
}

/// Port of `ErrParamHeaderSelfReportedLengthLonger` (paramheader.go:54).
final class ParamHeaderSelfReportedLengthLongerException implements Exception {
  const ParamHeaderSelfReportedLengthLongerException(
    this.rawLength,
    this.reportedLength,
  );

  final int rawLength;
  final int reportedLength;

  @override
  String toString() =>
      'param self reported length is longer than header length: param length ($rawLength) shorter than its self reported length ($reportedLength)';
}

/// Port of `ErrParamHeaderParseFailed` (paramheader.go:55), wrapping the
/// [ParamPacketTooShortException] `parseParamType` (paramheader.go:80) can
/// raise.
final class ParamHeaderParseFailedException implements Exception {
  const ParamHeaderParseFailedException(this.cause);

  final Object cause;

  @override
  String toString() => 'failed to parse param type: $cause';
}

/// Port of `paramHeaderUnrecognizedAction` (paramheader.go:14) and its
/// constants (paramheader.go:39-43): the top 2 bits of a parameter's type
/// field, RFC 9260 section-3.2.1.
final class ParamHeaderUnrecognizedAction {
  const ParamHeaderUnrecognizedAction._(this.value);

  /// The raw wire value (a Go `byte`, already masked to the top 2 bits).
  final int value;

  static const ParamHeaderUnrecognizedAction stop =
      ParamHeaderUnrecognizedAction._(0x00);
  static const ParamHeaderUnrecognizedAction stopAndReport =
      ParamHeaderUnrecognizedAction._(0x40);
  static const ParamHeaderUnrecognizedAction skip =
      ParamHeaderUnrecognizedAction._(0x80);
  static const ParamHeaderUnrecognizedAction skipAndReport =
      ParamHeaderUnrecognizedAction._(0xC0);

  factory ParamHeaderUnrecognizedAction.fromValue(int value) =>
      ParamHeaderUnrecognizedAction._(value);

  @override
  bool operator ==(Object other) =>
      other is ParamHeaderUnrecognizedAction && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Port of `paramHeaderUnrecognizedActionMask` (paramheader.go:38).
const int paramHeaderUnrecognizedActionMask = 0xC0;

/// Port of `paramHeaderLength` (paramheader.go:45).
const int paramHeaderLength = 4;

/// Port of `paramHeader` (paramheader.go:16-21).
final class ParamHeader {
  ParamHeader({
    required this.typ,
    this.unrecognizedAction = ParamHeaderUnrecognizedAction.stop,
    required this.len,
    required this.raw,
  });

  /// Port of `paramHeader.unmarshal` (paramheader.go:73-95): a factory
  /// rather than a mutating instance method, matching
  /// `ChunkHeader.unmarshal`'s adaptation (see chunkheader.dart).
  factory ParamHeader.unmarshal(Uint8List raw) {
    if (raw.length < paramHeaderLength) {
      throw const ParamHeaderTooShortException();
    }

    final paramLengthPlusHeader = ByteData.sublistView(
      raw,
      2,
      4,
    ).getUint16(0, Endian.big);
    if (paramLengthPlusHeader < paramHeaderLength) {
      throw ParamHeaderSelfReportedLengthShorterException(
        paramLengthPlusHeader,
        paramHeaderLength,
      );
    }
    if (raw.length < paramLengthPlusHeader) {
      throw ParamHeaderSelfReportedLengthLongerException(
        raw.length,
        paramLengthPlusHeader,
      );
    }

    final ParamType typ;
    try {
      typ = ParamType.parse(raw);
    } on Object catch (e) {
      throw ParamHeaderParseFailedException(e);
    }

    return ParamHeader(
      typ: typ,
      unrecognizedAction: ParamHeaderUnrecognizedAction.fromValue(
        raw[0] & paramHeaderUnrecognizedActionMask,
      ),
      len: paramLengthPlusHeader,
      raw: Uint8List.sublistView(raw, paramHeaderLength, paramLengthPlusHeader),
    );
  }

  /// Port of `paramHeader.typ` (paramheader.go:17).
  ParamType typ;

  /// Port of `paramHeader.unrecognizedAction` (paramheader.go:18).
  ParamHeaderUnrecognizedAction unrecognizedAction;

  /// Port of `paramHeader.len` (paramheader.go:19).
  int len;

  /// Port of `paramHeader.raw` (paramheader.go:20): the parameter value.
  Uint8List raw;

  /// Port of `paramHeader.marshal` (paramheader.go:61-71).
  Uint8List marshal() {
    final paramLengthPlusHeader = paramHeaderLength + raw.length;
    final out = Uint8List(paramLengthPlusHeader);
    ByteData.sublistView(out).setUint16(0, typ.value & 0xFFFF, Endian.big);
    ByteData.sublistView(
      out,
    ).setUint16(2, paramLengthPlusHeader & 0xFFFF, Endian.big);
    out.setRange(paramHeaderLength, paramLengthPlusHeader, raw);
    return out;
  }

  /// Port of `paramHeader.length` (paramheader.go:97-99).
  int length() => len;

  /// Port of `paramHeader.String` (paramheader.go:102-104).
  @override
  String toString() => '$typ ($len): $raw';
}
