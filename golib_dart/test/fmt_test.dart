import 'package:golib_dart/fmt.dart';
import 'package:test/test.dart';

void main() {
  test('formatV de floats segue o %v do Go', () {
    // Saída de referência: fmt.Println em go1.25.
    const cases = [
      (1.0, '1'),
      (100000.0, '100000'),
      (1000000.0, '1e+06'),
      (1234567.0, '1.234567e+06'),
      (123456789.0, '1.23456789e+08'),
      (1e20, '1e+20'),
      (1e21, '1e+21'),
      (0.0001, '0.0001'),
      (0.00001, '1e-05'),
      (1.5, '1.5'),
      (3.14159, '3.14159'),
      (1e-7, '1e-07'),
      (2.5e25, '2.5e+25'),
      (-0.0, '-0'),
      (double.infinity, '+Inf'),
    ];
    for (final (v, want) in cases) {
      expect(formatV(v), want, reason: '$v');
    }
  });

  test('formatV de outros valores', () {
    expect([null, true, 's', 42].map(formatV), ['<nil>', 'true', 's', '42']);
  });
}
