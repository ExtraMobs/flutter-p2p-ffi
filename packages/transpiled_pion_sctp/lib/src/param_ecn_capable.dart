// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `param_ecn_capable.go` (github.com/pion/sctp): [ParamEcnCapable],
/// the ECN Capable parameter (RFC 2960), which carries no value beyond its
/// header.
///
/// `paramECNCapable` is unexported in Go; see paramheader.dart's file-level
/// doc comment for the `header`-field composition pattern used here.
library;

import 'dart:typed_data';

import 'param.dart';
import 'paramheader.dart';
import 'paramtype.dart';

/// Port of `paramECNCapable` (param_ecn_capable.go:7-9).
final class ParamEcnCapable implements Param {
  ParamEcnCapable()
    : header = ParamHeader(
        typ: ParamType.ecnCapable,
        len: 0,
        raw: Uint8List(0),
      );

  /// Composition standing in for Go's embedded `paramHeader`.
  ParamHeader header;

  /// Port of `paramECNCapable.marshal` (param_ecn_capable.go:11-15).
  @override
  Uint8List marshal() {
    header.typ = ParamType.ecnCapable;
    header.raw = Uint8List(0);
    return header.marshal();
  }

  /// Port of `paramECNCapable.unmarshal` (param_ecn_capable.go:17-23).
  void unmarshal(Uint8List raw) {
    header = ParamHeader.unmarshal(raw);
  }

  @override
  int length() => header.length();
}
