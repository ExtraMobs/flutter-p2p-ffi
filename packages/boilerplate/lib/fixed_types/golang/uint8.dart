// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

/// Immutable byte-backed Go uint8 runtime value.
final class Uint8 implements Comparable<Uint8> {
  /// Converts modulo 2^8; defaults to zero.
  Uint8([int value = 0]) : this.fromBigInt(BigInt.from(value));

  /// Converts modulo 2^8.
  Uint8.fromBigInt(BigInt value) : _bytes = Uint8List(1) {
    _bytes[0] = value.toUnsigned(8).toInt();
  }
  final Uint8List _bytes;

  /// Exact unsigned value.
  BigInt toBigInt() => BigInt.from(_bytes[0]);

  /// Defensive copy of the byte representation.
  Uint8List toLittleEndianBytes() => Uint8List.fromList(_bytes);

  /// Adds modulo 2^8.
  Uint8 operator +(Uint8 o) => Uint8.fromBigInt(toBigInt() + o.toBigInt());

  /// Subtracts modulo 2^8.
  Uint8 operator -(Uint8 o) => Uint8.fromBigInt(toBigInt() - o.toBigInt());

  /// Negates modulo 2^8.
  Uint8 operator -() => Uint8.fromBigInt(-toBigInt());

  /// Multiplies modulo 2^8.
  Uint8 operator *(Uint8 o) => Uint8.fromBigInt(toBigInt() * o.toBigInt());

  /// Unsigned division.
  Uint8 operator ~/(Uint8 o) => Uint8.fromBigInt(toBigInt() ~/ o.toBigInt());

  /// Unsigned remainder.
  Uint8 operator %(Uint8 o) =>
      Uint8.fromBigInt(toBigInt().remainder(o.toBigInt()));

  /// Bitwise AND.
  Uint8 operator &(Uint8 o) => Uint8.fromBigInt(toBigInt() & o.toBigInt());

  /// Bitwise OR.
  Uint8 operator |(Uint8 o) => Uint8.fromBigInt(toBigInt() | o.toBigInt());

  /// Bitwise XOR.
  Uint8 operator ^(Uint8 o) => Uint8.fromBigInt(toBigInt() ^ o.toBigInt());

  /// Complements all bits.
  Uint8 operator ~() => Uint8.fromBigInt(~toBigInt());

  /// Go's `&^` operation.
  Uint8 andNot(Uint8 o) => this & ~o;

  /// Logical left shift.
  Uint8 operator <<(int n) {
    if (n < 0) throw ArgumentError.value(n, 'count');
    return n >= 8 ? Uint8() : Uint8.fromBigInt(toBigInt() << n);
  }

  /// Logical right shift.
  Uint8 operator >>(int n) {
    if (n < 0) throw ArgumentError.value(n, 'count');
    return n >= 8 ? Uint8() : Uint8.fromBigInt(toBigInt() >> n);
  }

  @override
  int compareTo(Uint8 other) => toBigInt().compareTo(other.toBigInt());

  /// Compares values.
  bool operator <(Uint8 o) => compareTo(o) < 0;

  /// Compares values.
  bool operator <=(Uint8 o) => compareTo(o) <= 0;

  /// Compares values.
  bool operator >(Uint8 o) => compareTo(o) > 0;

  /// Compares values.
  bool operator >=(Uint8 o) => compareTo(o) >= 0;
  @override
  bool operator ==(Object other) => other is Uint8 && compareTo(other) == 0;
  @override
  int get hashCode => toBigInt().hashCode;
  @override
  String toString() => toBigInt().toString();
}
