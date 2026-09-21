// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `param_heartbeat_info.go` (github.com/pion/sctp):
/// [ParamHeartbeatInfo], the mandatory Heartbeat Info parameter carried by
/// HEARTBEAT and HEARTBEAT-ACK chunks.
///
/// `paramHeartbeatInfo` is unexported in Go; see paramheader.dart's
/// file-level doc comment for the `header`-field composition pattern used
/// here.
library;

import 'dart:typed_data';

import 'param.dart';
import 'paramheader.dart';
import 'paramtype.dart';

/// Port of `paramHeartbeatInfo` (param_heartbeat_info.go:7-10).
final class ParamHeartbeatInfo implements Param {
  ParamHeartbeatInfo({Uint8List? heartbeatInformation})
    : heartbeatInformation = heartbeatInformation ?? Uint8List(0),
      header = ParamHeader(
        typ: ParamType.heartbeatInfo,
        len: 0,
        raw: Uint8List(0),
      );

  /// Composition standing in for Go's embedded `paramHeader`.
  ParamHeader header;

  /// Port of `paramHeartbeatInfo.heartbeatInformation`
  /// (param_heartbeat_info.go:9).
  Uint8List heartbeatInformation;

  /// Port of `paramHeartbeatInfo.marshal` (param_heartbeat_info.go:12-16).
  @override
  Uint8List marshal() {
    header.typ = ParamType.heartbeatInfo;
    header.raw = heartbeatInformation;
    return header.marshal();
  }

  /// Port of `paramHeartbeatInfo.unmarshal` (param_heartbeat_info.go:18-25).
  void unmarshal(Uint8List raw) {
    header = ParamHeader.unmarshal(raw);
    heartbeatInformation = header.raw;
  }

  @override
  int length() => header.length();
}
