// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'src/base.dart';
import 'src/ints.dart';

import 'float32.dart';
import 'int64.dart';
import 'src/float_format.dart';
import 'src/float_integer.dart';
import 'src/integer_float.dart';
import 'uint64.dart';

/// Go float64 value with eight-byte IEEE 754 storage and explicit rounding.
final class Float64 extends FloatBase<Float64> {
  @override
  String get $goType => 'float64';

  @override
  Float64 $wrapDouble(double v) => Float64(v);

  /// Stores a Dart binary64 value; defaults to positive zero.
  Float64([double value = 0.0]) : _data = ByteData(8) {
    _data.setFloat64(0, value, Endian.little);
  }

  /// Go float64(float32Value): exact widening for finite binary32 values.
  Float64.fromFloat32(Float32 value) : this(value.toDouble());

  /// Go float64(int64Value), rounding the exact signed integer once.
  Float64.fromInt64(Int64 value) : this(_ofInteger(value, 53));

  /// Go float64(uint64Value), rounding the exact unsigned integer once.
  Float64.fromUint64(Uint64 value) : this(_ofInteger(value, 53));

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

  /// Go `%v`: `strconv.FormatFloat(x, 'g', -1, 64)`.
  @override
  String toString() => formatGoFloat(toDouble(), 64);

  /// Go T(x) para um inteiro de `width` bits (gc/amd64); passe o resultado
  /// ao `fromBigInt` do destino, que mantém os bits baixos.
  BigInt toInteger(int width, {required bool signed}) =>
      floatToInteger(toDouble(), width, signed: signed);
}

/// Inteiro em ±2^53 já é exato como double (o construtor arredonda uma vez);
/// fora disso, o arredondamento direto a `precision` bits.
double _ofInteger(WideIntBase value, int precision) => value.$safe
    ? value.toInt().toDouble()
    : integerToFloat(value.toBigInt(), precision);
