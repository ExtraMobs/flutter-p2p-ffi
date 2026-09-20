// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `param_requested_hmac_algorithm.go` (github.com/pion/sctp):
/// [ParamRequestedHmacAlgorithm], the Requested HMAC Algorithm Parameter
/// (RFC 4895), and [HmacAlgorithm], its algorithm identifier.
///
/// `paramRequestedHMACAlgorithm` and `hmacAlgorithm` are unexported in Go;
/// see paramheader.dart's file-level doc comment for the `header`-field
/// composition pattern used here.
library;

import 'dart:typed_data';

import 'param.dart';
import 'paramheader.dart';
import 'paramtype.dart';

/// Port of `ErrInvalidAlgorithmType` (param_requested_hmac_algorithm.go:22).
final class InvalidAlgorithmTypeException implements Exception {
  const InvalidAlgorithmTypeException(this.algorithm);

  final HmacAlgorithm algorithm;

  @override
  String toString() => 'invalid algorithm type: $algorithm';
}

/// Port of `ErrInvalidChunkLength` (param_requested_hmac_algorithm.go:25).
final class InvalidChunkLengthException implements Exception {
  const InvalidChunkLengthException();

  @override
  String toString() => 'invalid chunk length';
}

/// Port of `hmacAlgorithm` (param_requested_hmac_algorithm.go:12) and its
/// constants (param_requested_hmac_algorithm.go:14-19).
final class HmacAlgorithm {
  const HmacAlgorithm._(this.value);

  /// The raw wire value (a Go `uint16`).
  final int value;

  static const HmacAlgorithm resv1 = HmacAlgorithm._(0);
  static const HmacAlgorithm sha128 = HmacAlgorithm._(1);
  static const HmacAlgorithm resv2 = HmacAlgorithm._(2);
  static const HmacAlgorithm sha256 = HmacAlgorithm._(3);

  factory HmacAlgorithm.fromValue(int value) => HmacAlgorithm._(value);

  @override
  bool operator ==(Object other) => other is HmacAlgorithm && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// Port of `hmacAlgorithm.String` (param_requested_hmac_algorithm.go:27-39).
  @override
  String toString() {
    switch (value) {
      case 0:
        return 'HMAC Reserved (0x00)';
      case 1:
        return 'HMAC SHA-128';
      case 2:
        return 'HMAC Reserved (0x02)';
      case 3:
        return 'HMAC SHA-256';
      default:
        return 'Unknown HMAC Algorithm type: $value';
    }
  }
}

/// Port of `paramRequestedHMACAlgorithm` (param_requested_hmac_algorithm.go:41-44).
final class ParamRequestedHmacAlgorithm implements Param {
  ParamRequestedHmacAlgorithm({List<HmacAlgorithm>? availableAlgorithms})
    : availableAlgorithms = availableAlgorithms ?? <HmacAlgorithm>[],
      header = ParamHeader(typ: ParamType.reqHmacAlgo, len: 0, raw: Uint8List(0));

  /// Composition standing in for Go's embedded `paramHeader`.
  ParamHeader header;

  /// Port of `paramRequestedHMACAlgorithm.availableAlgorithms`
  /// (param_requested_hmac_algorithm.go:43).
  List<HmacAlgorithm> availableAlgorithms;

  /// Port of `paramRequestedHMACAlgorithm.marshal`
  /// (param_requested_hmac_algorithm.go:46-56).
  @override
  Uint8List marshal() {
    header.typ = ParamType.reqHmacAlgo;
    final raw = Uint8List(availableAlgorithms.length * 2);
    final view = ByteData.sublistView(raw);
    for (var i = 0; i < availableAlgorithms.length; i++) {
      view.setUint16(i * 2, availableAlgorithms[i].value & 0xFFFF, Endian.big);
    }
    header.raw = raw;
    return header.marshal();
  }

  /// Port of `paramRequestedHMACAlgorithm.unmarshal`
  /// (param_requested_hmac_algorithm.go:58-79).
  void unmarshal(Uint8List raw) {
    header = ParamHeader.unmarshal(raw);
    if (header.raw.length % 2 == 1) {
      throw const InvalidChunkLengthException();
    }

    final view = ByteData.sublistView(header.raw);
    final parsed = <HmacAlgorithm>[];
    var i = 0;
    while (i < header.raw.length) {
      final a = HmacAlgorithm.fromValue(view.getUint16(i, Endian.big));
      if (a == HmacAlgorithm.sha128 || a == HmacAlgorithm.sha256) {
        parsed.add(a);
      } else {
        throw InvalidAlgorithmTypeException(a);
      }
      i += 2;
    }
    availableAlgorithms = parsed;
  }

  @override
  int length() => header.length();
}
