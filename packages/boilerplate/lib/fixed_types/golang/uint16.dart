// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

/// Immutable byte-backed Go uint16 runtime value.
final class Uint16 implements Comparable<Uint16> {
  /// Converts modulo 2^16; defaults to zero.
  Uint16([int value = 0]) : this.fromBigInt(BigInt.from(value));

  /// Converts modulo 2^16.
  Uint16.fromBigInt(BigInt value) : _bytes = Uint8List(2) {
    var v = value.toUnsigned(16);
    for (var i = 0; i < 2; i++) {
      _bytes[i] = (v & BigInt.from(255)).toInt();
      v >>= 8;
    }
  }
  final Uint8List _bytes;

  /// Exact unsigned value.
  BigInt toBigInt() => BigInt.from(_bytes[0]) | (BigInt.from(_bytes[1]) << 8);

  /// Defensive copy of the byte representation.
  Uint8List toLittleEndianBytes() => Uint8List.fromList(_bytes);

  /// Adds modulo 2^16.
  Uint16 operator +(Uint16 o) => Uint16.fromBigInt(toBigInt() + o.toBigInt());

  /// Subtracts modulo 2^16.
  Uint16 operator -(Uint16 o) => Uint16.fromBigInt(toBigInt() - o.toBigInt());

  /// Negates modulo 2^16.
  Uint16 operator -() => Uint16.fromBigInt(-toBigInt());

  /// Multiplies modulo 2^16.
  Uint16 operator *(Uint16 o) => Uint16.fromBigInt(toBigInt() * o.toBigInt());

  /// Unsigned division.
  Uint16 operator ~/(Uint16 o) => Uint16.fromBigInt(toBigInt() ~/ o.toBigInt());

  /// Unsigned remainder.
  Uint16 operator %(Uint16 o) =>
      Uint16.fromBigInt(toBigInt().remainder(o.toBigInt()));

  /// Bitwise AND.
  Uint16 operator &(Uint16 o) => Uint16.fromBigInt(toBigInt() & o.toBigInt());

  /// Bitwise OR.
  Uint16 operator |(Uint16 o) => Uint16.fromBigInt(toBigInt() | o.toBigInt());

  /// Bitwise XOR.
  Uint16 operator ^(Uint16 o) => Uint16.fromBigInt(toBigInt() ^ o.toBigInt());

  /// Complements all bits.
  Uint16 operator ~() => Uint16.fromBigInt(~toBigInt());

  /// Go's `&^` operation.
  Uint16 andNot(Uint16 o) => this & ~o;

  /// Logical left shift.
  Uint16 operator <<(int n) {
    if (n < 0) throw ArgumentError.value(n, 'count');
    return n >= 16 ? Uint16() : Uint16.fromBigInt(toBigInt() << n);
  }

  /// Logical right shift.
  Uint16 operator >>(int n) {
    if (n < 0) throw ArgumentError.value(n, 'count');
    return n >= 16 ? Uint16() : Uint16.fromBigInt(toBigInt() >> n);
  }

  @override
  int compareTo(Uint16 other) => toBigInt().compareTo(other.toBigInt());

  /// Compares values.
  bool operator <(Uint16 o) => compareTo(o) < 0;

  /// Compares values.
  bool operator <=(Uint16 o) => compareTo(o) <= 0;

  /// Compares values.
  bool operator >(Uint16 o) => compareTo(o) > 0;

  /// Compares values.
  bool operator >=(Uint16 o) => compareTo(o) >= 0;
  @override
  bool operator ==(Object other) => other is Uint16 && compareTo(other) == 0;
  @override
  int get hashCode => toBigInt().hashCode;
  @override
  String toString() => toBigInt().toString();
}
