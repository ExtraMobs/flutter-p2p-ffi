part of '../../transpiled_go_cidranger.dart';

// Port of github.com/libp2p/go-cidranger/net/ip.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md). Go's own `net` subpackage (imported
// upstream as `rnet`) for byte-level IP/CIDR manipulation, kept distinct
// from the outer `cidranger` package's `Network`/`Ranger` API surface.
//
// Go stdlib's `net.IP` is stood in for by `package:boilerplate/net/golang.dart`'s
// `Ip` (see transpiled_go_cidranger.dart's header for why).

/// The version of an IP address. Equivalent to go-cidranger/net's
/// `IPVersion` (a bare string type upstream with two exported constants;
/// ported as a closed Dart `enum` since Go never observes a third value).
enum IpVersion {
  /// 32-bit addresses, one `Uint32` word.
  ipv4,

  /// 128-bit addresses, four `Uint32` words.
  ipv6,
}

/// The number of 32-bit words an IPv4 [NetworkNumber] holds. Equivalent to
/// go-cidranger/net's `IPv4Uint32Count`.
const int ipv4Uint32Count = 1;

/// The number of 32-bit words an IPv6 [NetworkNumber] holds. Equivalent to
/// go-cidranger/net's `IPv6Uint32Count`.
const int ipv6Uint32Count = 4;

/// Bits per word. Equivalent to go-cidranger/net's `BitsPerUint32`.
const int bitsPerUint32 = 32;

/// Bytes per word. Equivalent to go-cidranger/net's `BytePerUint32`.
const int bytePerUint32 = 4;

/// Thrown by [NetworkNumber.bit] when the requested position is out of
/// range. Equivalent to go-cidranger/net's `ErrInvalidBitPosition`.
class InvalidBitPositionException implements Exception {
  /// Creates the exception.
  const InvalidBitPositionException();
  @override
  String toString() => 'bit position not valid';
}

/// Thrown when two [NetworkNumber]/[Network] values of different IP
/// versions are compared. Equivalent to go-cidranger/net's
/// `ErrVersionMismatch`.
class VersionMismatchException implements Exception {
  /// Creates the exception.
  const VersionMismatchException();
  @override
  String toString() => 'Network input version mismatch';
}

/// Thrown by [NetworkNumber.leastCommonBitPosition] and
/// [Network.leastCommonBitPosition] when two values diverge at their very
/// first bit. Equivalent to go-cidranger/net's `ErrNoGreatestCommonBit`.
class NoGreatestCommonBitException implements Exception {
  /// Creates the exception.
  const NoGreatestCommonBitException();
  @override
  String toString() => 'No greatest common bit';
}

/// An IP address represented as 32-bit words (1 word for IPv4, 4 for
/// IPv6), matching go-cidranger/net's `NetworkNumber` wire layout exactly
/// (each word is a Go `uint32`, so overflow on [next]/[previous] wraps
/// modulo 2^32 via [Golang.Uint32] rather than growing, per
/// AGENTS.md's "tipos primitivos Go compartilhados").
class NetworkNumber {
  /// Wraps already-validated 32-bit words (each `0 <= w <= 0xFFFFFFFF`),
  /// one word for IPv4 or four for IPv6. Prefer [NetworkNumber.fromIp] when
  /// starting from an [Ip].
  const NetworkNumber(this._words);

  final List<int> _words;

  /// Builds the [NetworkNumber] equivalent to [ip], or `null` if [ip] is
  /// `null` or neither IPv4- nor IPv6-capable (Go: neither `ip.To4()` nor
  /// `ip.To16()` succeeds -- reachable here since [Ip] can hold a byte
  /// slice of any length, exactly like Go's `net.IP`). Equivalent to
  /// go-cidranger/net's `NewNetworkNumber`.
  static NetworkNumber? fromIp(Ip? ip) {
    if (ip == null) return null;
    var coercedIp = ip.to4();
    var parts = ipv4Uint32Count;
    if (coercedIp == null) {
      coercedIp = ip.to16();
      parts = ipv6Uint32Count;
    }
    if (coercedIp == null) return null;
    final raw = coercedIp.asBytes();
    final words = <int>[];
    for (var i = 0; i < parts; i++) {
      final idx = i * bytePerUint32;
      var w = 0;
      for (var j = 0; j < bytePerUint32; j++) {
        w = (w << 8) | raw[idx + j];
      }
      words.add(w);
    }
    return NetworkNumber(words);
  }

  /// The number of 32-bit words (1 for IPv4, 4 for IPv6).
  int get length => _words.length;

  /// The word at [index].
  int operator [](int index) => _words[index];

  /// This value if it's an IPv4 address (exactly [ipv4Uint32Count] words),
  /// `null` otherwise. Equivalent to go-cidranger/net's
  /// `NetworkNumber.ToV4`.
  NetworkNumber? toV4() => length == ipv4Uint32Count ? this : null;

  /// This value if it's an IPv6 address (exactly [ipv6Uint32Count] words),
  /// `null` otherwise. Equivalent to go-cidranger/net's
  /// `NetworkNumber.ToV6`.
  NetworkNumber? toV6() => length == ipv6Uint32Count ? this : null;

  /// The equivalent [Ip]. Equivalent to go-cidranger/net's
  /// `NetworkNumber.ToIP`, whose IPv4 branch calls stdlib `net.IPv4`,
  /// widening the 4-byte result to the IPv4-mapped 16-byte form --
  /// reproduced here via [Ip.to16].
  Ip toIp() {
    final bytes = Uint8List(length * bytePerUint32);
    for (var i = 0; i < length; i++) {
      final w = _words[i];
      final base = i * bytePerUint32;
      bytes[base] = (w >> 24) & 0xff;
      bytes[base + 1] = (w >> 16) & 0xff;
      bytes[base + 2] = (w >> 8) & 0xff;
      bytes[base + 3] = w & 0xff;
    }
    if (bytes.length == bytePerUint32) return Ip.fromBytes(bytes).to16()!;
    return Ip.fromBytes(bytes);
  }

  /// Value equality. Equivalent to go-cidranger/net's
  /// `NetworkNumber.Equal`.
  @override
  bool operator ==(Object other) {
    if (other is! NetworkNumber) return false;
    if (length != other.length) return false;
    for (var i = 0; i < length; i++) {
      if (_words[i] != other._words[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_words);

  /// The next logical network number (increments as a big-endian integer,
  /// wrapping modulo 2^(32*[length])). Equivalent to go-cidranger/net's
  /// `NetworkNumber.Next`.
  NetworkNumber next() {
    final words = List<int>.of(_words);
    for (var i = words.length - 1; i >= 0; i--) {
      final w = Golang.Uint32(words[i]) + Golang.Uint32(1);
      words[i] = w.toBigInt().toInt();
      if (words[i] > 0) break;
    }
    return NetworkNumber(words);
  }

  /// The previous logical network number (decrements as a big-endian
  /// integer, wrapping modulo 2^(32*[length])). Equivalent to
  /// go-cidranger/net's `NetworkNumber.Previous`.
  NetworkNumber previous() {
    final words = List<int>.of(_words);
    for (var i = words.length - 1; i >= 0; i--) {
      final w = Golang.Uint32(words[i]) - Golang.Uint32(1);
      words[i] = w.toBigInt().toInt();
      if (words[i] < 0xFFFFFFFF) break;
    }
    return NetworkNumber(words);
  }

  /// The bit value (0 or 1) at [position] (0 == least significant bit of
  /// the last word). Throws [InvalidBitPositionException] if [position] is
  /// out of range. Equivalent to go-cidranger/net's `NetworkNumber.Bit`.
  int bit(int position) {
    if (position < 0 || position > length * bitsPerUint32 - 1) {
      throw const InvalidBitPositionException();
    }
    final idx = length - 1 - position ~/ bitsPerUint32;
    final rShift = position & (bitsPerUint32 - 1);
    return (_words[idx] >> rShift) & 1;
  }

  /// The smallest position of the preceding common bits shared with
  /// [other]; throws [NoGreatestCommonBitException] if they diverge from
  /// the very first bit, or [VersionMismatchException] if they're
  /// different lengths. Equivalent to go-cidranger/net's
  /// `NetworkNumber.LeastCommonBitPosition`.
  int leastCommonBitPosition(NetworkNumber other) {
    if (length != other.length) throw const VersionMismatchException();
    for (var i = 0; i < length; i++) {
      var mask = 1 << 31;
      var pos = 31;
      while (mask > 0) {
        if ((_words[i] & mask) != (other._words[i] & mask)) {
          if (i == 0 && pos == 31) throw const NoGreatestCommonBitException();
          return (pos + 1) + bitsPerUint32 * (length - i - 1);
        }
        pos--;
        mask >>= 1;
      }
    }
    return 0;
  }
}
