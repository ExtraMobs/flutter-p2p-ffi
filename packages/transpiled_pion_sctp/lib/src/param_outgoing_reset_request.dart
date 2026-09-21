// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `param_outgoing_reset_request.go` (github.com/pion/sctp):
/// [ParamOutgoingResetRequest], the Outgoing SSN Reset Request Parameter
/// (RFC 6525 section-4.1) used to request the reset of some or all
/// outgoing streams.
///
/// `paramOutgoingResetRequest` is unexported in Go; see paramheader.dart's
/// file-level doc comment for the `header`-field composition pattern used
/// here.
library;

import 'dart:typed_data';

import 'param.dart';
import 'paramheader.dart';
import 'paramtype.dart';

/// Port of `ErrSSNResetRequestParamTooShort`
/// (param_outgoing_reset_request.go:41-43).
final class SsnResetRequestParamTooShortException implements Exception {
  const SsnResetRequestParamTooShortException();

  @override
  String toString() => 'outgoing SSN reset request parameter too short';
}

/// Port of `paramOutgoingResetRequestStreamIdentifiersOffset`
/// (param_outgoing_reset_request.go:12).
const int paramOutgoingResetRequestStreamIdentifiersOffset = 12;

/// Port of `paramOutgoingResetRequest` (param_outgoing_reset_request.go:31-46).
final class ParamOutgoingResetRequest implements Param {
  ParamOutgoingResetRequest({
    this.reconfigRequestSequenceNumber = 0,
    this.reconfigResponseSequenceNumber = 0,
    this.senderLastTsn = 0,
    List<int>? streamIdentifiers,
  }) : streamIdentifiers = streamIdentifiers ?? <int>[],
       header = ParamHeader(
         typ: ParamType.outSsnResetReq,
         len: 0,
         raw: Uint8List(0),
       );

  /// Composition standing in for Go's embedded `paramHeader`.
  ParamHeader header;

  /// Port of `paramOutgoingResetRequest.reconfigRequestSequenceNumber`
  /// (param_outgoing_reset_request.go:34).
  int reconfigRequestSequenceNumber;

  /// Port of `paramOutgoingResetRequest.reconfigResponseSequenceNumber`
  /// (param_outgoing_reset_request.go:39).
  int reconfigResponseSequenceNumber;

  /// Port of `paramOutgoingResetRequest.senderLastTSN`
  /// (param_outgoing_reset_request.go:42).
  int senderLastTsn;

  /// Port of `paramOutgoingResetRequest.streamIdentifiers`
  /// (param_outgoing_reset_request.go:46), a Go `[]uint16`.
  List<int> streamIdentifiers;

  /// Port of `paramOutgoingResetRequest.marshal`
  /// (param_outgoing_reset_request.go:63-73).
  @override
  Uint8List marshal() {
    header.typ = ParamType.outSsnResetReq;
    final raw = Uint8List(
      paramOutgoingResetRequestStreamIdentifiersOffset +
          2 * streamIdentifiers.length,
    );
    final view = ByteData.sublistView(raw);
    view.setUint32(0, reconfigRequestSequenceNumber, Endian.big);
    view.setUint32(4, reconfigResponseSequenceNumber, Endian.big);
    view.setUint32(8, senderLastTsn, Endian.big);
    for (var i = 0; i < streamIdentifiers.length; i++) {
      view.setUint16(
        paramOutgoingResetRequestStreamIdentifiersOffset + 2 * i,
        streamIdentifiers[i] & 0xFFFF,
        Endian.big,
      );
    }
    header.raw = raw;
    return header.marshal();
  }

  /// Port of `paramOutgoingResetRequest.unmarshal`
  /// (param_outgoing_reset_request.go:75-93).
  void unmarshal(Uint8List raw) {
    header = ParamHeader.unmarshal(raw);
    if (header.raw.length < paramOutgoingResetRequestStreamIdentifiersOffset) {
      throw const SsnResetRequestParamTooShortException();
    }
    final view = ByteData.sublistView(header.raw);
    reconfigRequestSequenceNumber = view.getUint32(0, Endian.big);
    reconfigResponseSequenceNumber = view.getUint32(4, Endian.big);
    senderLastTsn = view.getUint32(8, Endian.big);

    final lim =
        (header.raw.length -
            paramOutgoingResetRequestStreamIdentifiersOffset) ~/
        2;
    streamIdentifiers = [
      for (var i = 0; i < lim; i++)
        view.getUint16(
          paramOutgoingResetRequestStreamIdentifiersOffset + 2 * i,
          Endian.big,
        ),
    ];
  }

  @override
  int length() => header.length();
}
