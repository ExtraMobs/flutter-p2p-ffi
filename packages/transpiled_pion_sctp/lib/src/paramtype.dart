// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `paramtype.go` (github.com/pion/sctp): [ParamType], the SCTP
/// INIT/INIT-ACK parameter type field.
///
/// `paramType` and its constants are unexported in Go; [ParamType] is public
/// within `lib/src` (see util.dart's file-level doc comment) but not
/// exported from `transpiled_pion_sctp.dart`, mirroring [ChunkType]'s
/// convention (`ChunkType.<name>` static members instead of Go's
/// disambiguation prefix).
library;

import 'dart:typed_data';

/// Port of `ErrParamPacketTooShort` (paramtype.go:47).
final class ParamPacketTooShortException implements Exception {
  const ParamPacketTooShortException();

  @override
  String toString() => 'packet to short';
}

/// Port of `paramType` (paramtype.go:13) and its constants
/// (paramtype.go:16-41).
final class ParamType {
  const ParamType._(this.value);

  /// The raw wire value (a Go `uint16`).
  final int value;

  static const ParamType heartbeatInfo = ParamType._(1);
  static const ParamType ipv4Addr = ParamType._(5);
  static const ParamType ipv6Addr = ParamType._(6);
  static const ParamType stateCookie = ParamType._(7);
  static const ParamType unrecognizedParam = ParamType._(8);
  static const ParamType cookiePreservative = ParamType._(9);
  static const ParamType hostNameAddr = ParamType._(11);
  static const ParamType supportedAddrTypes = ParamType._(12);
  static const ParamType outSsnResetReq = ParamType._(13);
  static const ParamType incSsnResetReq = ParamType._(14);
  static const ParamType ssnTsnResetReq = ParamType._(15);
  static const ParamType reconfigResp = ParamType._(16);
  static const ParamType addOutStreamsReq = ParamType._(17);
  static const ParamType addIncStreamsReq = ParamType._(18);
  static const ParamType ecnCapable = ParamType._(32768);
  static const ParamType zeroChecksumAcceptable = ParamType._(32769);
  static const ParamType random = ParamType._(32770);
  static const ParamType chunkList = ParamType._(32771);
  static const ParamType reqHmacAlgo = ParamType._(32772);
  static const ParamType padding = ParamType._(32773);
  static const ParamType supportedExt = ParamType._(32776);
  static const ParamType forwardTsnSupp = ParamType._(49152);
  static const ParamType addIpAddr = ParamType._(49153);
  static const ParamType delIpAddr = ParamType._(49154);
  static const ParamType errClauseInd = ParamType._(49155);
  static const ParamType setPriAddr = ParamType._(49156);
  static const ParamType successInd = ParamType._(49157);
  static const ParamType adaptLayerInd = ParamType._(49158);

  /// Constructs from the raw wire value, mirroring Go's `paramType(...)`
  /// conversion (an unchecked, always-succeeding numeric cast in Go).
  factory ParamType.fromValue(int value) => ParamType._(value);

  @override
  bool operator ==(Object other) => other is ParamType && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// Port of `parseParamType` (paramtype.go:49-55).
  static ParamType parse(Uint8List raw) {
    if (raw.length < 2) {
      throw const ParamPacketTooShortException();
    }
    return ParamType._(ByteData.sublistView(raw, 0, 2).getUint16(0, Endian.big));
  }

  /// Port of `paramType.String` (paramtype.go:57-94).
  @override
  String toString() {
    switch (value) {
      case 1:
        return 'Heartbeat Info';
      case 5:
        return 'IPv4 IP';
      case 6:
        return 'IPv6 IP';
      case 7:
        return 'State Cookie';
      case 8:
        return 'Unrecognized Parameters';
      case 9:
        return 'Cookie Preservative';
      case 11:
        return 'Host Name IP';
      case 12:
        return 'Supported IP Types';
      case 13:
        return 'Outgoing SSN Reset Request Parameter';
      case 14:
        return 'Incoming SSN Reset Request Parameter';
      case 15:
        return 'SSN/TSN Reset Request Parameter';
      case 16:
        return 'Re-configuration Response Parameter';
      case 17:
        return 'Add Outgoing Streams Request Parameter';
      case 18:
        return 'Add Incoming Streams Request Parameter';
      case 32768:
        return 'ECN Capable';
      case 32769:
        return 'Zero Checksum Acceptable';
      case 32770:
        return 'Random';
      case 32771:
        return 'Chunk List';
      case 32772:
        return 'Requested HMAC Algorithm Parameter';
      case 32773:
        return 'Padding';
      case 32776:
        return 'Supported Extensions';
      case 49152:
        return 'Forward TSN supported';
      case 49153:
        return 'Add IP IP';
      case 49154:
        return 'Delete IP IP';
      case 49155:
        return 'Error Cause Indication';
      case 49156:
        return 'Set Primary IP';
      case 49157:
        return 'Success Indication';
      case 49158:
        return 'Adaptation Layer Indication';
      default:
        return 'Unknown ParamType: $value';
    }
  }
}
