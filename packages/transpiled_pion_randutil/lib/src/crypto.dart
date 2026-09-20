// Port of github.com/pion/randutil crypto.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md).
import 'dart:math';
import 'dart:typed_data';

/// Generates a cryptographically secure random string built from characters
/// of [runes], with length [n]. Port of `randutil.GenerateCryptoRandomString`
/// (crypto.go:10).
///
/// The Go signature returns `(string, error)`: the error is only observable
/// when the OS entropy source used by `crypto/rand.Reader` fails to read.
/// Dart's analogous failure mode is [Random.secure] throwing
/// [UnsupportedError] when the platform provides no cryptographically secure
/// random source; that exception is left to propagate uncaught, matching the
/// Go function's behavior of propagating the underlying reader error without
/// wrapping it in a custom type.
String generateCryptoRandomString(int n, String runes) {
  final letters = runes.runes.toList(growable: false);
  final random = Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < n; i++) {
    buffer.writeCharCode(letters[random.nextInt(letters.length)]);
  }
  return buffer.toString();
}

/// Returns a cryptographically secure random 64-bit value. Port of
/// `randutil.CryptoUint64` (crypto.go:24), which reads 8 bytes from
/// `crypto/rand.Reader` and decodes them as a little-endian `uint64`.
///
/// The returned Dart [int] carries the same 64 bits as the Go `uint64`.
/// Dart's native `int` is a signed 64-bit two's-complement value, so a
/// result with the top bit set prints as a negative number; that is a
/// representation detail only, not a change in the bit pattern.
int cryptoUint64() {
  final random = Random.secure();
  final bytes = Uint8List(8);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes.buffer.asByteData().getInt64(0, Endian.little);
}
