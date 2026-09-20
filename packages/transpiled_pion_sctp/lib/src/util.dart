// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `util.go` (github.com/pion/sctp, revision fixed in
/// doc/transpilation/UPSTREAM_LOCK.md): 4-byte chunk padding and RFC 1982
/// Serial Number Arithmetic for TSN (32-bit) and SSN (16-bit) wraparound
/// comparison.
///
/// All `sna32*`/`sna16*` symbols are unexported in Go (package-private, used
/// across many sctp `.go` files); Dart has no package-private visibility
/// narrower than "public within `lib/src`", so they stay un-underscored here
/// but are **not** re-exported from `transpiled_pion_sctp.dart`, mirroring
/// Go's package boundary at the barrel rather than at the file.
///
/// Regra 10: the subtraction inside `sna32*`/`sna16*` relies on Go's silent
/// `uint32`/`uint16` wraparound (`i2-i1` when `i1>i2`); a plain Dart `int`
/// subtraction would go negative instead of wrapping, silently breaking TSN
/// ordering near the wrap boundary. [Golang.Uint32]/[Golang.Uint16] are used
/// for that reason.
library;

import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;

const int _paddingMultiple = 4;

/// Port of `getPadding` (util.go:10-12).
int getPadding(int l) => (_paddingMultiple - (l % _paddingMultiple)) % _paddingMultiple;

/// Port of `padByte` (util.go:14-21).
Uint8List padByte(Uint8List input, int cnt) {
  final padded = Uint8List(input.length + (cnt < 0 ? 0 : cnt));
  padded.setRange(0, input.length, input);
  return padded;
}

const int _uint32Half = 0x80000000;
const int _uint16Half = 0x8000;

/// Port of `sna32LT` (util.go:24-26): RFC 1982 Serial Number Arithmetic.
bool sna32Lt(Golang.Uint32 i1, Golang.Uint32 i2) {
  final half = Golang.Uint32(_uint32Half);
  return (i1 < i2 && (i2 - i1) < half) || (i1 > i2 && (i1 - i2) > half);
}

/// Port of `sna32LTE` (util.go:28-30).
bool sna32Lte(Golang.Uint32 i1, Golang.Uint32 i2) => i1 == i2 || sna32Lt(i1, i2);

/// Port of `sna32GT` (util.go:32-34).
bool sna32Gt(Golang.Uint32 i1, Golang.Uint32 i2) {
  final half = Golang.Uint32(_uint32Half);
  return (i1 < i2 && (i2 - i1) >= half) || (i1 > i2 && (i1 - i2) <= half);
}

/// Port of `sna32GTE` (util.go:36-38).
bool sna32Gte(Golang.Uint32 i1, Golang.Uint32 i2) => i1 == i2 || sna32Gt(i1, i2);

/// Port of `sna32EQ` (util.go:40-42).
bool sna32Eq(Golang.Uint32 i1, Golang.Uint32 i2) => i1 == i2;

/// Port of `sna16LT` (util.go:44-46).
bool sna16Lt(Golang.Uint16 i1, Golang.Uint16 i2) {
  final half = Golang.Uint16(_uint16Half);
  return (i1 < i2 && (i2 - i1) < half) || (i1 > i2 && (i1 - i2) > half);
}

/// Port of `sna16LTE` (util.go:48-50).
bool sna16Lte(Golang.Uint16 i1, Golang.Uint16 i2) => i1 == i2 || sna16Lt(i1, i2);

/// Port of `sna16GT` (util.go:52-54).
bool sna16Gt(Golang.Uint16 i1, Golang.Uint16 i2) {
  final half = Golang.Uint16(_uint16Half);
  return (i1 < i2 && (i2 - i1) >= half) || (i1 > i2 && (i1 - i2) <= half);
}

/// Port of `sna16GTE` (util.go:56-58).
bool sna16Gte(Golang.Uint16 i1, Golang.Uint16 i2) => i1 == i2 || sna16Gt(i1, i2);

/// Port of `sna16EQ` (util.go:60-62).
bool sna16Eq(Golang.Uint16 i1, Golang.Uint16 i2) => i1 == i2;
