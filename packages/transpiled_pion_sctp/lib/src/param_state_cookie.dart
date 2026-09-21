// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `param_state_cookie.go` (github.com/pion/sctp):
/// [ParamStateCookie], the State Cookie parameter carried by INIT-ACK and
/// COOKIE-ECHO, and [ParamStateCookie.random], which fills a fresh one with 32
/// cryptographically random bytes.
///
/// `paramStateCookie` and `newRandomStateCookie` are unexported in Go; see
/// paramheader.dart's file-level doc comment for the `header`-field
/// composition pattern used here.
///
/// Go's `newRandomStateCookie` uses the stdlib `crypto/rand.Read`, not
/// `github.com/pion/randutil` (a different, non-cryptographic-by-default
/// package this module also depends on for other purposes) -- so this port
/// uses Dart's own CSPRNG, `dart:math`'s `Random.secure()`, rather than
/// `transpiled_pion_randutil`, to stay faithful to which RNG upstream
/// actually calls here.
library;

import 'dart:math';
import 'dart:typed_data';

import 'param.dart';
import 'paramheader.dart';
import 'paramtype.dart';

/// Port of `paramStateCookie` (param_state_cookie.go:11-14).
final class ParamStateCookie implements Param {
  ParamStateCookie({Uint8List? cookie})
    : cookie = cookie ?? Uint8List(0),
      header = ParamHeader(
        typ: ParamType.stateCookie,
        len: 0,
        raw: Uint8List(0),
      );

  /// Port of newRandomStateCookie: 32 bytes from the operating system CSPRNG.
  factory ParamStateCookie.random() {
    final random = Random.secure();
    final cookie = Uint8List(32);
    for (var i = 0; i < cookie.length; i++) {
      cookie[i] = random.nextInt(256);
    }
    return ParamStateCookie(cookie: cookie);
  }

  /// Composition standing in for Go's embedded `paramHeader`.
  ParamHeader header;

  /// Port of `paramStateCookie.cookie` (param_state_cookie.go:13).
  Uint8List cookie;

  /// Port of `paramStateCookie.marshal` (param_state_cookie.go:23-27).
  @override
  Uint8List marshal() {
    header.typ = ParamType.stateCookie;
    header.raw = cookie;
    return header.marshal();
  }

  /// Port of `paramStateCookie.unmarshal` (param_state_cookie.go:29-36).
  void unmarshal(Uint8List raw) {
    header = ParamHeader.unmarshal(raw);
    cookie = header.raw;
  }

  @override
  int length() => header.length();

  /// Port of `paramStateCookie.String` (param_state_cookie.go:39-41).
  @override
  String toString() => '$header: $cookie';
}
