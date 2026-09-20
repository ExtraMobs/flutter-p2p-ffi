// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `param_zero_checksum.go` (github.com/pion/sctp):
/// [ParamZeroChecksumAcceptable], the Zero Checksum Acceptable parameter
/// (draft-ietf-tsvwg-sctp-zero-checksum-00), used to inform the peer that
/// the sender is willing to accept a zero SCTP checksum if some other error
/// detection method (identified by `edmid`) is used instead.
///
/// `paramZeroChecksumAcceptable` is unexported in Go; see paramheader.dart's
/// file-level doc comment for the `header`-field composition pattern used
/// here.
library;

import 'dart:typed_data';

import 'param.dart';
import 'paramheader.dart';
import 'paramtype.dart';

/// Port of `ErrZeroChecksumParamTooShort` (param_zero_checksum.go:25-27).
final class ZeroChecksumParamTooShortException implements Exception {
  const ZeroChecksumParamTooShortException();

  @override
  String toString() => 'zero checksum parameter too short';
}

/// Port of `dtlsErrorDetectionMethod` (param_zero_checksum.go:29-31): the
/// only currently-assigned Error Detection Method Identifier (EDMID) value
/// for [ParamZeroChecksumAcceptable.edmid].
const int dtlsErrorDetectionMethod = 1;

/// Port of `paramZeroChecksumAcceptable` (param_zero_checksum.go:17-23).
final class ParamZeroChecksumAcceptable implements Param {
  ParamZeroChecksumAcceptable({this.edmid = 0})
    : header = ParamHeader(typ: ParamType.zeroChecksumAcceptable, len: 0, raw: Uint8List(0));

  /// Composition standing in for Go's embedded `paramHeader`.
  ParamHeader header;

  /// Port of `paramZeroChecksumAcceptable.edmid` (param_zero_checksum.go:22).
  int edmid;

  /// Port of `paramZeroChecksumAcceptable.marshal` (param_zero_checksum.go:33-39).
  @override
  Uint8List marshal() {
    header.typ = ParamType.zeroChecksumAcceptable;
    final raw = Uint8List(4);
    ByteData.sublistView(raw).setUint32(0, edmid, Endian.big);
    header.raw = raw;
    return header.marshal();
  }

  /// Port of `paramZeroChecksumAcceptable.unmarshal` (param_zero_checksum.go:41-51).
  void unmarshal(Uint8List raw) {
    header = ParamHeader.unmarshal(raw);
    if (header.raw.length < 4) {
      throw const ZeroChecksumParamTooShortException();
    }
    edmid = ByteData.sublistView(header.raw).getUint32(0, Endian.big);
  }

  @override
  int length() => header.length();
}
