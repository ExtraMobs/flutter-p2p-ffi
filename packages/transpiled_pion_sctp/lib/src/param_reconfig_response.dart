// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `param_reconfig_response.go` (github.com/pion/sctp):
/// [ParamReconfigResponse], the Re-configuration Response Parameter
/// (RFC 6525 section-4.4), and [ReconfigResult], its result code.
///
/// `paramReconfigResponse` and `reconfigResult` are unexported in Go; see
/// paramheader.dart's file-level doc comment for the `header`-field
/// composition pattern used here.
library;

import 'dart:typed_data';

import 'param.dart';
import 'paramheader.dart';
import 'paramtype.dart';

/// Port of `ErrReconfigRespParamTooShort` (param_reconfig_response.go:48-50).
final class ReconfigRespParamTooShortException implements Exception {
  const ReconfigRespParamTooShortException();

  @override
  String toString() => 'reconfig response parameter too short';
}

/// Port of `reconfigResult` (param_reconfig_response.go:37) and its
/// constants (param_reconfig_response.go:39-46).
final class ReconfigResult {
  const ReconfigResult._(this.value);

  /// The raw wire value (a Go `uint32`).
  final int value;

  static const ReconfigResult successNop = ReconfigResult._(0);
  static const ReconfigResult successPerformed = ReconfigResult._(1);
  static const ReconfigResult denied = ReconfigResult._(2);
  static const ReconfigResult errorWrongSsn = ReconfigResult._(3);
  static const ReconfigResult errorRequestAlreadyInProgress = ReconfigResult._(
    4,
  );
  static const ReconfigResult errorBadSequenceNumber = ReconfigResult._(5);
  static const ReconfigResult inProgress = ReconfigResult._(6);

  factory ReconfigResult.fromValue(int value) => ReconfigResult._(value);

  @override
  bool operator ==(Object other) =>
      other is ReconfigResult && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// Port of `reconfigResult.String` (param_reconfig_response.go:52-68).
  @override
  String toString() {
    switch (value) {
      case 0:
        return '0: Success - Nothing to do';
      case 1:
        return '1: Success - Performed';
      case 2:
        return '2: Denied';
      case 3:
        return '3: Error - Wrong SSN';
      case 4:
        return '4: Error - Request already in progress';
      case 5:
        return '5: Error - Bad Sequence Number';
      case 6:
        return '6: In progress';
      default:
        return 'Unknown reconfigResult: $value';
    }
  }
}

/// Port of `paramReconfigResponse` (param_reconfig_response.go:27-35).
final class ParamReconfigResponse implements Param {
  ParamReconfigResponse({
    this.reconfigResponseSequenceNumber = 0,
    this.result = ReconfigResult.successNop,
  }) : header = ParamHeader(
         typ: ParamType.reconfigResp,
         len: 0,
         raw: Uint8List(0),
       );

  /// Composition standing in for Go's embedded `paramHeader`.
  ParamHeader header;

  /// Port of `paramReconfigResponse.reconfigResponseSequenceNumber`
  /// (param_reconfig_response.go:31).
  int reconfigResponseSequenceNumber;

  /// Port of `paramReconfigResponse.result` (param_reconfig_response.go:33).
  ReconfigResult result;

  /// Port of `paramReconfigResponse.marshal` (param_reconfig_response.go:70-76).
  @override
  Uint8List marshal() {
    header.typ = ParamType.reconfigResp;
    final raw = Uint8List(8);
    final view = ByteData.sublistView(raw);
    view.setUint32(0, reconfigResponseSequenceNumber, Endian.big);
    view.setUint32(4, result.value, Endian.big);
    header.raw = raw;
    return header.marshal();
  }

  /// Port of `paramReconfigResponse.unmarshal`
  /// (param_reconfig_response.go:78-88).
  void unmarshal(Uint8List raw) {
    header = ParamHeader.unmarshal(raw);
    if (header.raw.length < 8) {
      throw const ReconfigRespParamTooShortException();
    }
    final view = ByteData.sublistView(header.raw);
    reconfigResponseSequenceNumber = view.getUint32(0, Endian.big);
    result = ReconfigResult.fromValue(view.getUint32(4, Endian.big));
  }

  @override
  int length() => header.length();
}
