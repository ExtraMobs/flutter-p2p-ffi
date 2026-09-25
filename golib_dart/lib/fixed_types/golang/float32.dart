// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'src/base.dart';
import 'src/ints.dart';

import 'float64.dart';
import 'int64.dart';
import 'src/float_format.dart';
import 'src/integer_float.dart';
import 'uint64.dart';

/// Go float32 value with four-byte IEEE 754 storage and explicit rounding.
final class Float32 extends FloatBase<Float32> {
  @override
  String get $goType => 'float32';

  @override
  Float32 $wrapDouble(double v) => Float32(v);

  @override
  int get $bits => 32;

  /// Rounds a Dart binary64 value to binary32; defaults to positive zero.
  Float32([double value = 0.0]) : _data = ByteData(4) {
    _data.setFloat32(0, value, Endian.little);
  }

  /// Go float32(float64Value), rounded to binary32 by the storage constructor.
  Float32.fromFloat64(Float64 value) : this(value.toDouble());

  /// Go float32(int64Value), without an intermediate binary64 rounding.
  Float32.fromInt64(Int64 value) : this(_ofInteger(value, 24));

  /// Go float32(uint64Value), without an intermediate binary64 rounding.
  Float32.fromUint64(Uint64 value) : this(_ofInteger(value, 24));

  final ByteData _data;

  /// Exact widening of the stored binary32 value to Dart binary64.
  double toDouble() => _data.getFloat32(0, Endian.little);

  /// Defensive copy of the private representation, not a protocol byte order.
  Uint8List toLittleEndianBytes() =>
      Uint8List.fromList(_data.buffer.asUint8List());

  /// Addition with an explicit binary32 result conversion.
  Float32 operator +(Float32 other) => Float32(toDouble() + other.toDouble());

  /// Subtraction with an explicit binary32 result conversion.
  Float32 operator -(Float32 other) => Float32(toDouble() - other.toDouble());

  /// Negation preserves signed zero.
  Float32 operator -() => Float32(-toDouble());

  /// Multiplication with an explicit binary32 result conversion.
  Float32 operator *(Float32 other) => Float32(toDouble() * other.toDouble());

  /// IEEE division; zero divisors produce infinities or NaN on this runtime.
  Float32 operator /(Float32 other) => Float32(toDouble() / other.toDouble());

  /// IEEE unordered comparison: false when either operand is NaN.
  bool operator <(Float32 other) => toDouble() < other.toDouble();

  /// IEEE unordered comparison: false when either operand is NaN.
  bool operator <=(Float32 other) => toDouble() <= other.toDouble();

  /// IEEE unordered comparison: false when either operand is NaN.
  bool operator >(Float32 other) => toDouble() > other.toDouble();

  /// IEEE unordered comparison: false when either operand is NaN.
  bool operator >=(Float32 other) => toDouble() >= other.toDouble();
  @override
  bool operator ==(Object other) =>
      other is Float32 && toDouble() == other.toDouble();
  @override
  int get hashCode => toDouble().hashCode;

  /// Go `%v`: `strconv.FormatFloat(x, 'g', -1, 32)`.
  @override
  String toString() => formatGoFloat(toDouble(), 32);
}

/// Inteiro em ±2^53 já é exato como double (o construtor arredonda uma vez);
/// fora disso, o arredondamento direto a `precision` bits.
double _ofInteger(WideIntBase value, int precision) =>
    value.$safe ? value.toInt().toDouble() : integerToFloat(value, precision);
