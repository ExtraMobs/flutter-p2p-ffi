// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';
import 'uint16.dart';

/// Go int16 runtime value with an immutable two-byte payload.
final class Int16 implements Comparable<Int16> {
  /// Converts retaining the low 16 bits; defaults to zero.
  Int16([int value = 0]) : this.fromBigInt(BigInt.from(value));

  /// Retains low bits and interprets them as signed.
  Int16.fromBigInt(BigInt value) : _bits = Uint16.fromBigInt(value);

  /// Converts from uint16 preserving bits.
  Int16.fromUint16(Uint16 value) : _bits = value;
  final Uint16 _bits;

  /// Exact signed value.
  BigInt toBigInt() => _bits.toBigInt().toSigned(16);

  /// Converts to uint16 preserving bits.
  Uint16 toUint16() => _bits;

  /// Defensive copy of the byte representation.
  Uint8List toLittleEndianBytes() => _bits.toLittleEndianBytes();

  /// Adds with signed overflow.
  Int16 operator +(Int16 o) => Int16.fromUint16(_bits + o._bits);

  /// Subtracts with signed overflow.
  Int16 operator -(Int16 o) => Int16.fromUint16(_bits - o._bits);

  /// Negates with signed overflow.
  Int16 operator -() => Int16.fromUint16(-_bits);

  /// Multiplies with signed overflow.
  Int16 operator *(Int16 o) => Int16.fromUint16(_bits * o._bits);

  /// Divides toward zero.
  Int16 operator ~/(Int16 o) => Int16.fromBigInt(toBigInt() ~/ o.toBigInt());

  /// Remainder has the dividend's sign.
  Int16 operator %(Int16 o) =>
      Int16.fromBigInt(toBigInt().remainder(o.toBigInt()));

  /// Bitwise AND.
  Int16 operator &(Int16 o) => Int16.fromUint16(_bits & o._bits);

  /// Bitwise OR.
  Int16 operator |(Int16 o) => Int16.fromUint16(_bits | o._bits);

  /// Bitwise XOR.
  Int16 operator ^(Int16 o) => Int16.fromUint16(_bits ^ o._bits);

  /// Complements all bits.
  Int16 operator ~() => Int16.fromUint16(~_bits);

  /// Go's `&^` operation.
  Int16 andNot(Int16 o) => this & ~o;

  /// Shifts left with fixed-width truncation.
  Int16 operator <<(int n) => Int16.fromUint16(_bits << n);

  /// Shifts right arithmetically.
  Int16 operator >>(int n) {
    if (n < 0) throw ArgumentError.value(n, 'count');
    final v = toBigInt();
    return Int16.fromBigInt(
      n >= 16 ? (v.isNegative ? -BigInt.one : BigInt.zero) : v >> n,
    );
  }

  @override
  int compareTo(Int16 other) => toBigInt().compareTo(other.toBigInt());

  /// Compares values.
  bool operator <(Int16 o) => compareTo(o) < 0;

  /// Compares values.
  bool operator <=(Int16 o) => compareTo(o) <= 0;

  /// Compares values.
  bool operator >(Int16 o) => compareTo(o) > 0;

  /// Compares values.
  bool operator >=(Int16 o) => compareTo(o) >= 0;
  @override
  bool operator ==(Object other) => other is Int16 && _bits == other._bits;
  @override
  int get hashCode => toBigInt().hashCode;
  @override
  String toString() => toBigInt().toString();
}
