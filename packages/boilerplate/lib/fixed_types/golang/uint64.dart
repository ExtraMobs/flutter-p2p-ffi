// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

/// Immutable byte-backed Go uint64 runtime value.
/// Conversion truncates modulo 2^64, as Go integer conversion does.
final class Uint64 implements Comparable<Uint64> {
  /// Converts a runtime value modulo 2^64; default construction is zero.
  Uint64([int value = 0]) : this.fromBigInt(BigInt.from(value));

  /// Converts a runtime value modulo 2^64; default construction is zero.
  Uint64.fromBigInt(BigInt value) : _bytes = Uint8List(8) {
    var bits = value.toUnsigned(64);
    for (var i = 0; i < 8; i++) {
      _bytes[i] = (bits & BigInt.from(255)).toInt();
      bits >>= 8;
    }
  }

  final Uint8List _bytes;

  /// Exact mathematical value, without native int precision loss.
  BigInt toBigInt() {
    var value = BigInt.zero;
    for (var i = 7; i >= 0; i--) {
      value = (value << 8) | BigInt.from(_bytes[i]);
    }
    return value;
  }

  /// Defensive copy of internal little-endian bytes, not a protocol encoding.
  Uint8List toLittleEndianBytes() => Uint8List.fromList(_bytes);

  /// Fixed-width Go operation; unsigned results wrap modulo 2^64.
  Uint64 operator +(Uint64 other) =>
      Uint64.fromBigInt(toBigInt() + other.toBigInt());

  /// Fixed-width Go operation; unsigned results wrap modulo 2^64.
  Uint64 operator -(Uint64 other) =>
      Uint64.fromBigInt(toBigInt() - other.toBigInt());

  /// Fixed-width Go operation; unsigned results wrap modulo 2^64.
  Uint64 operator -() => Uint64.fromBigInt(-toBigInt());

  /// Fixed-width Go operation; unsigned results wrap modulo 2^64.
  Uint64 operator *(Uint64 other) =>
      Uint64.fromBigInt(toBigInt() * other.toBigInt());

  /// Fixed-width Go operation; unsigned results wrap modulo 2^64.
  Uint64 operator ~/(Uint64 other) =>
      Uint64.fromBigInt(toBigInt() ~/ other.toBigInt());

  /// Fixed-width Go operation; unsigned results wrap modulo 2^64.
  Uint64 operator %(Uint64 other) =>
      Uint64.fromBigInt(toBigInt().remainder(other.toBigInt()));

  /// Fixed-width Go operation; unsigned results wrap modulo 2^64.
  Uint64 operator &(Uint64 other) =>
      Uint64.fromBigInt(toBigInt() & other.toBigInt());

  /// Fixed-width Go operation; unsigned results wrap modulo 2^64.
  Uint64 operator |(Uint64 other) =>
      Uint64.fromBigInt(toBigInt() | other.toBigInt());

  /// Fixed-width Go operation; unsigned results wrap modulo 2^64.
  Uint64 operator ^(Uint64 other) =>
      Uint64.fromBigInt(toBigInt() ^ other.toBigInt());

  /// Fixed-width Go operation; unsigned results wrap modulo 2^64.
  Uint64 operator ~() => Uint64.fromBigInt(~toBigInt());

  /// Go &^ clears bits set in the right operand.
  Uint64 andNot(Uint64 other) => this & ~other;

  /// Fixed-width Go operation; unsigned results wrap modulo 2^64.
  Uint64 operator <<(int count) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'negative shift amount');
    }
    return count >= 64 ? Uint64() : Uint64.fromBigInt(toBigInt() << count);
  }

  /// Fixed-width Go operation; unsigned results wrap modulo 2^64.
  Uint64 operator >>(int count) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'negative shift amount');
    }
    return count >= 64 ? Uint64() : Uint64.fromBigInt(toBigInt() >> count);
  }

  @override
  int compareTo(Uint64 other) => toBigInt().compareTo(other.toBigInt());

  /// Compares unsigned numerical values.
  bool operator <(Uint64 other) => compareTo(other) < 0;

  /// Compares unsigned numerical values.
  bool operator <=(Uint64 other) => compareTo(other) <= 0;

  /// Compares unsigned numerical values.
  bool operator >(Uint64 other) => compareTo(other) > 0;

  /// Compares unsigned numerical values.
  bool operator >=(Uint64 other) => compareTo(other) >= 0;
  @override
  bool operator ==(Object other) => other is Uint64 && compareTo(other) == 0;
  @override
  int get hashCode => toBigInt().hashCode;
  @override
  String toString() => toBigInt().toString();
}
