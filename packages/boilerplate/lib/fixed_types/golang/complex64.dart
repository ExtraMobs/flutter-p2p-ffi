// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'complex128.dart';
import 'float32.dart';
import 'float64.dart';

/// Go complex64 runtime value with float32 real and imaginary parts.
final class Complex64 {
  /// Constructs a complex64 value; defaults to (0+0i).
  Complex64([Float32? real, Float32? imag])
      : real = real ?? Float32(),
        imag = imag ?? Float32();

  /// Constructs from raw double values, rounding each to binary32.
  Complex64.fromDoubles([double real = 0.0, double imag = 0.0])
      : real = Float32(real),
        imag = Float32(imag);

  /// Narrowing conversion from Float64 real and imaginary parts.
  Complex64.fromFloat64(Float64 r, Float64 i)
      : real = Float32.fromFloat64(r),
        imag = Float32.fromFloat64(i);

  /// Narrowing conversion from Complex128.
  Complex64.fromComplex128(Complex128 value)
      : real = Float32.fromFloat64(value.real),
        imag = Float32.fromFloat64(value.imag);

  /// Real component.
  final Float32 real;

  /// Imaginary component.
  final Float32 imag;

  /// Complex addition: (a+c) + (b+d)i.
  Complex64 operator +(Complex64 o) =>
      Complex64(real + o.real, imag + o.imag);

  /// Complex subtraction: (a-c) + (b-d)i.
  Complex64 operator -(Complex64 o) =>
      Complex64(real - o.real, imag - o.imag);

  /// Unary negation: (-a) + (-b)i.
  Complex64 operator -() => Complex64(-real, -imag);

  /// Complex multiplication: (ac - bd) + (ad + bc)i.
  Complex64 operator *(Complex64 o) => Complex64(
        real * o.real - imag * o.imag,
        real * o.imag + imag * o.real,
      );

  /// Complex division using Go's runtime implementation (Smith's algorithm).
  Complex64 operator /(Complex64 o) {
    final c128 = Complex128.fromComplex64(this);
    final o128 = Complex128.fromComplex64(o);
    return Complex64.fromComplex128(c128 / o128);
  }

  @override
  bool operator ==(Object other) =>
      other is Complex64 && real == other.real && imag == other.imag;

  @override
  int get hashCode => Object.hash(real, imag);

  @override
  String toString() => '($real+$imag i)';
}
