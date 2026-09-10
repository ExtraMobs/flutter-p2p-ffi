// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'uint32.dart';

/// Go int32 runtime value with an immutable four-byte two's-complement payload.
final class Int32 implements Comparable<Int32> {
  /// Converts a runtime integer; defaults to zero.
  Int32([int value = 0]) : this.fromBigInt(BigInt.from(value));

  /// Retains the low 32 bits, then interprets them as signed.
  Int32.fromBigInt(BigInt value) : _bits = Uint32.fromBigInt(value);

  /// Converts from uint32 while preserving the bit pattern.
  Int32.fromUint32(Uint32 value) : _bits = value;

  final Uint32 _bits;

  /// Exact signed mathematical value.
  BigInt toBigInt() => _bits.toBigInt().toSigned(32);

  /// Converts to uint32 while preserving the bit pattern.
  Uint32 toUint32() => _bits;

  /// Defensive copy of the internal little-endian bytes.
  Uint8List toLittleEndianBytes() => _bits.toLittleEndianBytes();

  /// Adds with signed two's-complement overflow.
  Int32 operator +(Int32 other) => Int32.fromUint32(_bits + other._bits);

  /// Subtracts with signed two's-complement overflow.
  Int32 operator -(Int32 other) => Int32.fromUint32(_bits - other._bits);

  /// Negates with signed two's-complement overflow.
  Int32 operator -() => Int32.fromUint32(-_bits);

  /// Multiplies with signed two's-complement overflow.
  Int32 operator *(Int32 other) => Int32.fromUint32(_bits * other._bits);

  /// Divides toward zero.
  Int32 operator ~/(Int32 other) =>
      Int32.fromBigInt(toBigInt() ~/ other.toBigInt());

  /// Computes the remainder with the dividend's sign.
  Int32 operator %(Int32 other) =>
      Int32.fromBigInt(toBigInt().remainder(other.toBigInt()));

  /// Computes bitwise AND.
  Int32 operator &(Int32 other) => Int32.fromUint32(_bits & other._bits);

  /// Computes bitwise OR.
  Int32 operator |(Int32 other) => Int32.fromUint32(_bits | other._bits);

  /// Computes bitwise XOR.
  Int32 operator ^(Int32 other) => Int32.fromUint32(_bits ^ other._bits);

  /// Complements all 32 bits.
  Int32 operator ~() => Int32.fromUint32(~_bits);

  /// Go's `&^` operation.
  Int32 andNot(Int32 other) => this & ~other;

  /// Shifts left with 32-bit truncation.
  Int32 operator <<(int count) => Int32.fromUint32(_bits << count);

  /// Shifts right arithmetically.
  Int32 operator >>(int count) {
    if (count < 0) throw ArgumentError.value(count, 'count');
    final value = toBigInt();
    return Int32.fromBigInt(
      count >= 32
          ? (value.isNegative ? -BigInt.one : BigInt.zero)
          : value >> count,
    );
  }

  @override
  int compareTo(Int32 other) => toBigInt().compareTo(other.toBigInt());

  /// Compares signed values.
  bool operator <(Int32 other) => compareTo(other) < 0;

  /// Compares signed values.
  bool operator <=(Int32 other) => compareTo(other) <= 0;

  /// Compares signed values.
  bool operator >(Int32 other) => compareTo(other) > 0;

  /// Compares signed values.
  bool operator >=(Int32 other) => compareTo(other) >= 0;
  @override
  bool operator ==(Object other) => other is Int32 && _bits == other._bits;
  @override
  int get hashCode => toBigInt().hashCode;
  @override
  String toString() => toBigInt().toString();
}
