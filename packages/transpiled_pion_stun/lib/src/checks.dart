/// Port of `checks.go` (pion/stun v3.1.1), the `!debug` build (default).
///
/// Upstream ships two mutually-exclusive implementations selected by the Go
/// `debug` build tag: `checks.go` (`!debug`, returns plain sentinel errors,
/// used by every ordinary build) and `checks_debug.go` (`debug`, returns
/// struct-typed `*AttrLengthErr` carrying `Attr`/`Got`/`Expected` for
/// diagnostics). Dart has no build-tag equivalent and this project ships one
/// build, so only the default (`!debug`) behavior is ported; the `debug`
/// variant's extra diagnostic fields (`AttrLengthErr`, `AttrOverflowErr` in
/// `attributes_debug.go`, `CRCMismatch` in `fingerprint_debug.go`,
/// `IntegrityErr` in `integrity_debug.go`) are gated out entirely upstream
/// too under normal `go build` and are not part of this port's surface.
library;

import 'attributes.dart';
import 'errors.dart';
import 'fingerprint.dart';
import 'integrity.dart';

/// Port of `CheckSize` (checks.go:15-21). Throws
/// [AttributeSizeInvalidException] if `got` != `expected`.
void checkSize(AttrType attr, int got, int expected) {
  if (got == expected) return;
  throw const AttributeSizeInvalidException();
}

/// Port of `checkHMAC` (checks.go:24-30).
///
/// Upstream compares via `internal/hmac.Equal`, itself a thin wrapper over
/// `crypto/subtle.ConstantTimeCompare` -- a fixed timing comparison, not an
/// HMAC computation. `package:crypto`'s `ListEquality` is not constant time,
/// so this is a straightforward manual constant-time byte compare (same
/// technique `crypto/subtle.ConstantTimeCompare` uses: XOR every byte pair,
/// OR the results, compare once at the end) rather than a new dependency for
/// four lines.
void checkHmac(List<int> got, List<int> expected) {
  if (got.length != expected.length) {
    throw const IntegrityMismatchException();
  }
  var diff = 0;
  for (var i = 0; i < got.length; i++) {
    diff |= got[i] ^ expected[i];
  }
  if (diff == 0) return;
  throw const IntegrityMismatchException();
}

/// Port of `checkFingerprint` (checks.go:32-38).
void checkFingerprint(int got, int expected) {
  if (got == expected) return;
  throw const FingerprintMismatchException();
}

/// Port of `IsAttrSizeInvalid` (checks.go:41-43).
bool isAttrSizeInvalid(Object err) => err is AttributeSizeInvalidException;

/// Port of `CheckOverflow` (checks.go:46-52). Throws
/// [AttributeSizeOverflowException] if `got` > `maxVal`.
void checkOverflow(AttrType attr, int got, int maxVal) {
  if (got <= maxVal) return;
  throw const AttributeSizeOverflowException();
}

/// Port of `IsAttrSizeOverflow` (checks.go:55-57).
bool isAttrSizeOverflow(Object err) => err is AttributeSizeOverflowException;
