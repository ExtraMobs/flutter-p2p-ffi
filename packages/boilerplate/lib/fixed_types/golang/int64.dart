// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'uint64.dart';

/// Go int64 runtime value with an immutable eight-byte two's-complement payload.
final class Int64 implements Comparable<Int64> {
  /// Converts a runtime integer; defaults to zero.
  Int64([int value = 0]) : this.fromBigInt(BigInt.from(value));

  /// Retains the low 64 bits, then interprets them as signed.
  Int64.fromBigInt(BigInt value) : _bits = Uint64.fromBigInt(value);

  /// Go int64(uint64Value), preserving the bit pattern.
  Int64.fromUint64(Uint64 value) : _bits = value;

  final Uint64 _bits;

  /// Returns the exact signed mathematical value.
  BigInt toBigInt() => _bits.toBigInt().toSigned(64);

  /// Explicit Dart boundary, not a Go integer conversion.
  /// Throws when the runtime's int cannot represent this value exactly.
  int toIntExact() {
    final value = toBigInt();
    final result = value.toInt();
    if (BigInt.from(result) != value) {
      throw UnsupportedError('Dart int cannot represent this Int64 exactly');
    }
    return result;
  }

  /// Go uint64(int64Value), preserving the bit pattern.
  Uint64 toUint64() => _bits;

  /// Returns a defensive copy; internal byte order is not a wire format.
  Uint8List toLittleEndianBytes() => _bits.toLittleEndianBytes();

  /// Signed addition with Go two's-complement overflow.
  Int64 operator +(Int64 other) => Int64.fromUint64(_bits + other._bits);

  /// Signed subtraction with Go two's-complement overflow.
  Int64 operator -(Int64 other) => Int64.fromUint64(_bits - other._bits);

  /// Signed negation, including MinInt64 wrapping to itself.
  Int64 operator -() => Int64.fromUint64(-_bits);

  /// Signed multiplication with Go two's-complement overflow.
  Int64 operator *(Int64 other) => Int64.fromUint64(_bits * other._bits);

  /// Go integer division truncates toward zero; MinInt64 / -1 wraps.
  Int64 operator ~/(Int64 other) =>
      Int64.fromBigInt(toBigInt() ~/ other.toBigInt());

  /// Go remainder has the dividend's sign, unlike Dart's Euclidean modulo.
  Int64 operator %(Int64 other) =>
      Int64.fromBigInt(toBigInt().remainder(other.toBigInt()));

  /// Bitwise AND.
  Int64 operator &(Int64 other) => Int64.fromUint64(_bits & other._bits);

  /// Bitwise OR.
  Int64 operator |(Int64 other) => Int64.fromUint64(_bits | other._bits);

  /// Bitwise XOR.
  Int64 operator ^(Int64 other) => Int64.fromUint64(_bits ^ other._bits);

  /// Go unary ^ is Dart unary ~.
  Int64 operator ~() => Int64.fromUint64(~_bits);

  /// Go &^ clears bits set in the right operand.
  Int64 andNot(Int64 other) => this & ~other;

  /// Left shift truncates to 64 bits.
  Int64 operator <<(int count) => Int64.fromUint64(_bits << count);

  /// Arithmetic right shift preserves the sign, including counts >= 64.
  Int64 operator >>(int count) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'negative shift amount');
    }
    final value = toBigInt();
    return Int64.fromBigInt(
      count >= 64
          ? (value.isNegative ? -BigInt.one : BigInt.zero)
          : value >> count,
    );
  }

  @override
  int compareTo(Int64 other) => toBigInt().compareTo(other.toBigInt());

  /// Signed comparison.
  bool operator <(Int64 other) => compareTo(other) < 0;

  /// Signed comparison.
  bool operator <=(Int64 other) => compareTo(other) <= 0;

  /// Signed comparison.
  bool operator >(Int64 other) => compareTo(other) > 0;

  /// Signed comparison.
  bool operator >=(Int64 other) => compareTo(other) >= 0;
  @override
  bool operator ==(Object other) => other is Int64 && _bits == other._bits;
  @override
  int get hashCode => toBigInt().hashCode;
  @override
  String toString() => toBigInt().toString();
}
