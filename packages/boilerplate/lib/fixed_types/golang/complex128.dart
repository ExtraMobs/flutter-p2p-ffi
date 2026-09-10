// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'complex64.dart';
import 'float64.dart';

/// Go complex128 runtime value with float64 real and imaginary parts.
final class Complex128 {
  /// Constructs a complex128 value; defaults to (0+0i).
  Complex128([Float64? real, Float64? imag])
      : real = real ?? Float64(),
        imag = imag ?? Float64();

  /// Constructs from raw double values.
  Complex128.fromDoubles([double real = 0.0, double imag = 0.0])
      : real = Float64(real),
        imag = Float64(imag);

  /// Widening conversion from complex64.
  Complex128.fromComplex64(Complex64 value)
      : real = Float64.fromFloat32(value.real),
        imag = Float64.fromFloat32(value.imag);

  /// Real component.
  final Float64 real;

  /// Imaginary component.
  final Float64 imag;

  /// Complex addition: (a+c) + (b+d)i.
  Complex128 operator +(Complex128 o) =>
      Complex128(real + o.real, imag + o.imag);

  /// Complex subtraction: (a-c) + (b-d)i.
  Complex128 operator -(Complex128 o) =>
      Complex128(real - o.real, imag - o.imag);

  /// Unary negation: (-a) + (-b)i.
  Complex128 operator -() => Complex128(-real, -imag);

  /// Complex multiplication: (ac - bd) + (ad + bc)i.
  Complex128 operator *(Complex128 o) => Complex128(
        real * o.real - imag * o.imag,
        real * o.imag + imag * o.real,
      );

  /// Complex division using Go's runtime implementation (Smith's algorithm).
  Complex128 operator /(Complex128 o) {
    final a = real.toDouble();
    final b = imag.toDouble();
    final c = o.real.toDouble();
    final d = o.imag.toDouble();

    double e, f;
    if (c.abs() >= d.abs()) {
      final ratio = d / c;
      final denom = c + ratio * d;
      e = (a + b * ratio) / denom;
      f = (b - a * ratio) / denom;
    } else {
      final ratio = c / d;
      final denom = d + ratio * c;
      e = (a * ratio + b) / denom;
      f = (b * ratio - a) / denom;
    }

    if (e.isNaN && f.isNaN) {
      if (c == 0 && d == 0 && (!a.isNaN || !b.isNaN)) {
        final infC = c.isNegative ? -double.infinity : double.infinity;
        e = infC * a;
        f = infC * b;
      }
    }

    return Complex128.fromDoubles(e, f);
  }

  @override
  bool operator ==(Object other) =>
      other is Complex128 && real == other.real && imag == other.imag;

  @override
  int get hashCode => Object.hash(real, imag);

  @override
  String toString() => '($real+$imag i)';
}
