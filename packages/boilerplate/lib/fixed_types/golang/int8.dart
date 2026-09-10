// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';
import 'uint8.dart';

/// Go int8 runtime value with an immutable one-byte payload.
final class Int8 implements Comparable<Int8> {
  /// Converts retaining the low 8 bits; defaults to zero.
  Int8([int value = 0]) : this.fromBigInt(BigInt.from(value));

  /// Retains low bits and interprets them as signed.
  Int8.fromBigInt(BigInt value) : _bits = Uint8.fromBigInt(value);

  /// Converts from uint8 preserving bits.
  Int8.fromUint8(Uint8 value) : _bits = value;
  final Uint8 _bits;

  /// Exact signed value.
  BigInt toBigInt() => _bits.toBigInt().toSigned(8);

  /// Converts to uint8 preserving bits.
  Uint8 toUint8() => _bits;

  /// Defensive copy of the byte representation.
  Uint8List toLittleEndianBytes() => _bits.toLittleEndianBytes();

  /// Adds with signed overflow.
  Int8 operator +(Int8 o) => Int8.fromUint8(_bits + o._bits);

  /// Subtracts with signed overflow.
  Int8 operator -(Int8 o) => Int8.fromUint8(_bits - o._bits);

  /// Negates with signed overflow.
  Int8 operator -() => Int8.fromUint8(-_bits);

  /// Multiplies with signed overflow.
  Int8 operator *(Int8 o) => Int8.fromUint8(_bits * o._bits);

  /// Divides toward zero.
  Int8 operator ~/(Int8 o) => Int8.fromBigInt(toBigInt() ~/ o.toBigInt());

  /// Remainder has the dividend's sign.
  Int8 operator %(Int8 o) =>
      Int8.fromBigInt(toBigInt().remainder(o.toBigInt()));

  /// Bitwise AND.
  Int8 operator &(Int8 o) => Int8.fromUint8(_bits & o._bits);

  /// Bitwise OR.
  Int8 operator |(Int8 o) => Int8.fromUint8(_bits | o._bits);

  /// Bitwise XOR.
  Int8 operator ^(Int8 o) => Int8.fromUint8(_bits ^ o._bits);

  /// Complements all bits.
  Int8 operator ~() => Int8.fromUint8(~_bits);

  /// Go's `&^` operation.
  Int8 andNot(Int8 o) => this & ~o;

  /// Shifts left with fixed-width truncation.
  Int8 operator <<(int n) => Int8.fromUint8(_bits << n);

  /// Shifts right arithmetically.
  Int8 operator >>(int n) {
    if (n < 0) throw ArgumentError.value(n, 'count');
    final v = toBigInt();
    return Int8.fromBigInt(
      n >= 8 ? (v.isNegative ? -BigInt.one : BigInt.zero) : v >> n,
    );
  }

  @override
  int compareTo(Int8 other) => toBigInt().compareTo(other.toBigInt());

  /// Compares values.
  bool operator <(Int8 o) => compareTo(o) < 0;

  /// Compares values.
  bool operator <=(Int8 o) => compareTo(o) <= 0;

  /// Compares values.
  bool operator >(Int8 o) => compareTo(o) > 0;

  /// Compares values.
  bool operator >=(Int8 o) => compareTo(o) >= 0;
  @override
  bool operator ==(Object other) => other is Int8 && _bits == other._bits;
  @override
  int get hashCode => toBigInt().hashCode;
  @override
  String toString() => toBigInt().toString();
}
