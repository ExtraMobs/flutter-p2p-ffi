// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'float32.dart';
import 'int64.dart';
import 'src/integer_float.dart';
import 'uint64.dart';

/// Go float64 value with eight-byte IEEE 754 storage and explicit rounding.
final class Float64 {
  /// Stores a Dart binary64 value; defaults to positive zero.
  Float64([double value = 0.0]) : _data = ByteData(8) {
    _data.setFloat64(0, value, Endian.little);
  }

  /// Go float64(float32Value): exact widening for finite binary32 values.
  Float64.fromFloat32(Float32 value) : this(value.toDouble());

  /// Go float64(int64Value), rounding the exact signed integer once.
  Float64.fromInt64(Int64 value) : this(integerToFloat(value.toBigInt(), 53));

  /// Go float64(uint64Value), rounding the exact unsigned integer once.
  Float64.fromUint64(Uint64 value) : this(integerToFloat(value.toBigInt(), 53));

  final ByteData _data;

  /// Returns the stored binary64 value.
  double toDouble() => _data.getFloat64(0, Endian.little);

  /// Defensive copy of the private representation, not a protocol byte order.
  Uint8List toLittleEndianBytes() =>
      Uint8List.fromList(_data.buffer.asUint8List());

  /// Addition with an explicit binary64 result conversion.
  Float64 operator +(Float64 other) => Float64(toDouble() + other.toDouble());

  /// Subtraction with an explicit binary64 result conversion.
  Float64 operator -(Float64 other) => Float64(toDouble() - other.toDouble());

  /// Negation preserves signed zero.
  Float64 operator -() => Float64(-toDouble());

  /// Multiplication with an explicit binary64 result conversion.
  Float64 operator *(Float64 other) => Float64(toDouble() * other.toDouble());

  /// IEEE division; zero divisors produce infinities or NaN on this runtime.
  Float64 operator /(Float64 other) => Float64(toDouble() / other.toDouble());

  /// IEEE unordered comparison: false when either operand is NaN.
  bool operator <(Float64 other) => toDouble() < other.toDouble();

  /// IEEE unordered comparison: false when either operand is NaN.
  bool operator <=(Float64 other) => toDouble() <= other.toDouble();

  /// IEEE unordered comparison: false when either operand is NaN.
  bool operator >(Float64 other) => toDouble() > other.toDouble();

  /// IEEE unordered comparison: false when either operand is NaN.
  bool operator >=(Float64 other) => toDouble() >= other.toDouble();
  @override
  bool operator ==(Object other) =>
      other is Float64 && toDouble() == other.toDouble();
  @override
  int get hashCode => toDouble().hashCode;
}
