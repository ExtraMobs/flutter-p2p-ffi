// Port of github.com/pion/transport/v4/utils/xor (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md): xor_generic.go, xor_old.go.
//
// Upstream ships two build-tagged implementations that both compute the same
// result: xor_generic.go (Go >= 1.20) delegates to `crypto/subtle.XORBytes`;
// xor_old.go (Go < 1.20) hand-rolls a word-aligned loop
// (`fastXORBytes`/`safeXORBytes`, xor_old.go:37-77) purely as a performance
// optimization over unsafe word-sized reads. Neither build tag changes the
// observable contract documented on `XorBytes` (xor_old.go:28-31): XOR the
// first `min(len(a), len(b))` bytes of `a` and `b` into `dst` and return that
// count. `fastXORBytes`/`safeXORBytes`/`isAligned`/`wordSize` are
// Go-unsafe-pointer performance internals with no Dart analogue and are not
// part of the exported contract, so only the observable behavior is ported
// as a single straightforward byte loop.
import 'dart:typed_data';

/// XORs the first `min(a.length, b.length)` bytes of [a] and [b] into [dst],
/// which must have at least that many bytes of space. Returns the number of
/// bytes XOR'd. Port of `XorBytes` (xor_old.go:28-45, xor_generic.go:17-20).
int xorBytes(Uint8List dst, Uint8List a, Uint8List b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    dst[i] = a[i] ^ b[i];
  }
  return n;
}
