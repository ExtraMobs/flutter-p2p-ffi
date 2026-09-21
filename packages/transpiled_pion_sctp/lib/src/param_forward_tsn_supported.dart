// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `param_forward_tsn_supported.go` (github.com/pion/sctp):
/// [ParamForwardTsnSupported], the Forward TSN Supported parameter
/// (RFC 3758), which carries no value beyond its header.
///
/// `paramForwardTSNSupported` is unexported in Go; see paramheader.dart's
/// file-level doc comment for the `header`-field composition pattern used
/// here.
library;

import 'dart:typed_data';

import 'param.dart';
import 'paramheader.dart';
import 'paramtype.dart';

/// Port of `paramForwardTSNSupported` (param_forward_tsn_supported.go:14-16).
final class ParamForwardTsnSupported implements Param {
  ParamForwardTsnSupported()
    : header = ParamHeader(
        typ: ParamType.forwardTsnSupp,
        len: 0,
        raw: Uint8List(0),
      );

  /// Composition standing in for Go's embedded `paramHeader`.
  ParamHeader header;

  /// Port of `paramForwardTSNSupported.marshal`
  /// (param_forward_tsn_supported.go:18-22).
  @override
  Uint8List marshal() {
    header.typ = ParamType.forwardTsnSupp;
    header.raw = Uint8List(0);
    return header.marshal();
  }

  /// Port of `paramForwardTSNSupported.unmarshal`
  /// (param_forward_tsn_supported.go:24-30).
  void unmarshal(Uint8List raw) {
    header = ParamHeader.unmarshal(raw);
  }

  @override
  int length() => header.length();
}
