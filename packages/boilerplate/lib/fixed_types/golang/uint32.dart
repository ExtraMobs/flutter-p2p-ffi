// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

/// Immutable byte-backed Go uint32 runtime value.
final class Uint32 implements Comparable<Uint32> {
  /// Converts a runtime value modulo 2^32; defaults to zero.
  Uint32([int value = 0]) : this.fromBigInt(BigInt.from(value));

  /// Converts a value modulo 2^32.
  Uint32.fromBigInt(BigInt value) : _bytes = Uint8List(4) {
    var bits = value.toUnsigned(32);
    for (var i = 0; i < 4; i++) {
      _bytes[i] = (bits & BigInt.from(255)).toInt();
      bits >>= 8;
    }
  }

  final Uint8List _bytes;

  /// Exact unsigned value.
  BigInt toBigInt() {
    var value = BigInt.zero;
    for (var i = 3; i >= 0; i--) {
      value = (value << 8) | BigInt.from(_bytes[i]);
    }
    return value;
  }

  /// Defensive copy of the internal little-endian bytes.
  Uint8List toLittleEndianBytes() => Uint8List.fromList(_bytes);

  /// Adds modulo 2^32.
  Uint32 operator +(Uint32 other) =>
      Uint32.fromBigInt(toBigInt() + other.toBigInt());

  /// Subtracts modulo 2^32.
  Uint32 operator -(Uint32 other) =>
      Uint32.fromBigInt(toBigInt() - other.toBigInt());

  /// Negates modulo 2^32.
  Uint32 operator -() => Uint32.fromBigInt(-toBigInt());

  /// Multiplies modulo 2^32.
  Uint32 operator *(Uint32 other) =>
      Uint32.fromBigInt(toBigInt() * other.toBigInt());

  /// Divides using unsigned integer division.
  Uint32 operator ~/(Uint32 other) =>
      Uint32.fromBigInt(toBigInt() ~/ other.toBigInt());

  /// Computes the unsigned remainder.
  Uint32 operator %(Uint32 other) =>
      Uint32.fromBigInt(toBigInt().remainder(other.toBigInt()));

  /// Computes bitwise AND.
  Uint32 operator &(Uint32 other) =>
      Uint32.fromBigInt(toBigInt() & other.toBigInt());

  /// Computes bitwise OR.
  Uint32 operator |(Uint32 other) =>
      Uint32.fromBigInt(toBigInt() | other.toBigInt());

  /// Computes bitwise XOR.
  Uint32 operator ^(Uint32 other) =>
      Uint32.fromBigInt(toBigInt() ^ other.toBigInt());

  /// Complements all 32 bits.
  Uint32 operator ~() => Uint32.fromBigInt(~toBigInt());

  /// Go's `&^` operation.
  Uint32 andNot(Uint32 other) => this & ~other;

  /// Shifts left, discarding bits above bit 31.
  Uint32 operator <<(int count) {
    if (count < 0) throw ArgumentError.value(count, 'count');
    return count >= 32 ? Uint32() : Uint32.fromBigInt(toBigInt() << count);
  }

  /// Shifts right logically.
  Uint32 operator >>(int count) {
    if (count < 0) throw ArgumentError.value(count, 'count');
    return count >= 32 ? Uint32() : Uint32.fromBigInt(toBigInt() >> count);
  }

  @override
  int compareTo(Uint32 other) => toBigInt().compareTo(other.toBigInt());

  /// Compares unsigned values.
  bool operator <(Uint32 other) => compareTo(other) < 0;

  /// Compares unsigned values.
  bool operator <=(Uint32 other) => compareTo(other) <= 0;

  /// Compares unsigned values.
  bool operator >(Uint32 other) => compareTo(other) > 0;

  /// Compares unsigned values.
  bool operator >=(Uint32 other) => compareTo(other) >= 0;
  @override
  bool operator ==(Object other) => other is Uint32 && compareTo(other) == 0;
  @override
  int get hashCode => toBigInt().hashCode;
  @override
  String toString() => toBigInt().toString();
}
