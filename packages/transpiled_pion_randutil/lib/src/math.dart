// Port of github.com/pion/randutil math.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md).
import 'dart:math';

import 'crypto.dart';

/// Random generator for non-cryptographic usage. Port of the
/// `randutil.MathRandomGenerator` interface (math.go:10).
///
/// Caution: as in the Go source, values from this generator MUST NOT be used
/// for cryptographic purposes; use [generateCryptoRandomString] or
/// [cryptoUint64] instead.
abstract interface class MathRandomGenerator {
  /// Creates a new math-random generator, seeded by [cryptoUint64]. Port of
  /// `randutil.NewMathRandomGenerator` (math.go:34).
  ///
  /// Mirrors the Go fallback: if the cryptographically secure seed is
  /// unavailable ([Random.secure] throws [UnsupportedError] on the current
  /// platform), the generator falls back to a timestamp-derived seed instead
  /// of Go's `time.Now().UnixNano()`.
  ///
  /// Go guards the underlying `*rand.Rand` with a `sync.Mutex` because it may
  /// be shared across goroutines. That primitive is deliberately not ported:
  /// Dart code within a single isolate never runs concurrently, so no
  /// analogous synchronization is needed, and Rule 17 of the project's AST
  /// audit forbids Go concurrency primitives in public APIs regardless.
  factory MathRandomGenerator() = _MathRandomGenerator;

  /// Returns a random integer within `[0:n)`. Port of `Intn` (math.go:44).
  int intn(int n);

  /// Returns a random 32-bit unsigned integer, as a non-negative [int] in
  /// `[0, 2^32)`. Port of `Uint32` (math.go:51).
  int uint32();

  /// Returns a random 64-bit unsigned integer, as the raw 64-bit bit pattern
  /// of an [int] (see [cryptoUint64] for the sign-representation note). Port
  /// of `Uint64` (math.go:58).
  int uint64();

  /// Returns a random string of length [n] built from characters of
  /// [runes]. Can be used to generate a unique ID that avoids name
  /// collisions.
  ///
  /// Caution: DO NOT use this for cryptographic usage. Port of
  /// `GenerateString` (math.go:65).
  String generateString(int n, String runes);
}

class _MathRandomGenerator implements MathRandomGenerator {
  _MathRandomGenerator() : _random = Random(_seed());

  final Random _random;

  static int _seed() {
    try {
      return cryptoUint64();
    } on UnsupportedError {
      return DateTime.now().microsecondsSinceEpoch;
    }
  }

  @override
  int intn(int n) => _random.nextInt(n);

  @override
  int uint32() => _random.nextInt(1 << 32);

  @override
  int uint64() {
    final hi = _random.nextInt(1 << 32);
    final lo = _random.nextInt(1 << 32);
    return (hi << 32) | lo;
  }

  @override
  String generateString(int n, String runes) {
    final letters = runes.runes.toList(growable: false);
    final buffer = StringBuffer();
    for (var i = 0; i < n; i++) {
      buffer.writeCharCode(letters[intn(letters.length)]);
    }
    return buffer.toString();
  }
}
