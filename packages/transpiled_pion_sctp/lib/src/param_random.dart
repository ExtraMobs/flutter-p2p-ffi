// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `param_random.go` (github.com/pion/sctp): [ParamRandom], the
/// Random parameter (RFC 4805) used by SCTP-AUTH's shared key derivation.
///
/// `paramRandom` is unexported in Go; see paramheader.dart's file-level doc
/// comment for the `header`-field composition pattern used here.
library;

import 'dart:typed_data';

import 'param.dart';
import 'paramheader.dart';
import 'paramtype.dart';

/// Port of `paramRandom` (param_random.go:7-10).
final class ParamRandom implements Param {
  ParamRandom({Uint8List? randomData})
    : randomData = randomData ?? Uint8List(0),
      header = ParamHeader(typ: ParamType.random, len: 0, raw: Uint8List(0));

  /// Composition standing in for Go's embedded `paramHeader`.
  ParamHeader header;

  /// Port of `paramRandom.randomData` (param_random.go:9).
  Uint8List randomData;

  /// Port of `paramRandom.marshal` (param_random.go:12-16).
  @override
  Uint8List marshal() {
    header.typ = ParamType.random;
    header.raw = randomData;
    return header.marshal();
  }

  /// Port of `paramRandom.unmarshal` (param_random.go:18-25).
  void unmarshal(Uint8List raw) {
    header = ParamHeader.unmarshal(raw);
    randomData = header.raw;
  }

  @override
  int length() => header.length();
}
