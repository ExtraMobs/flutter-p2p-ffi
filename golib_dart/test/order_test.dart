import 'package:golib_dart/builtin.dart' as go;
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

void main() {
  test('minOf/maxOf devolvem o operando pela ordem do tipo', () {
    final xs = [Golang.Int(3), Golang.Int(-2), Golang.Int(7)];
    expect(go.minOf(xs, (a, b) => a < b), Golang.Int(-2));
    expect(go.maxOf(xs, (a, b) => a < b), Golang.Int(7));
    final ss = [Golang.String.fromDart('b'), Golang.String.fromDart('a')];
    expect(go.minOf(ss, (a, b) => a < b), Golang.String.fromDart('a'));
  });

  test('minFloat/maxFloat: NaN contamina, -0 < +0', () {
    double d(Golang.Float64 v) => v.toDouble();
    final nan = [Golang.Float64(1), Golang.Float64(double.nan), Golang.Float64(-5)];
    expect(go.minFloat(nan, d).toDouble().isNaN, isTrue);
    expect(go.maxFloat(nan, d).toDouble().isNaN, isTrue);
    final zeros = [Golang.Float64(0.0), Golang.Float64(-0.0)];
    expect(go.minFloat(zeros, d).toDouble().isNegative, isTrue);
    expect(go.maxFloat(zeros.reversed.toList(), d).toDouble().isNegative, isFalse);
  });

  test('GoMap.clear e Slice.clear', () {
    final m = go.GoMap<int, int>.of({1: 2}, const go.Elem<int>(8, _zero));
    m.clear();
    expect(m.length, 0);
    go.GoMap<int, int>.nil(const go.Elem<int>(8, _zero)).clear();
    final s = go.Slice<int>.of([1, 2, 3], const go.Elem<int>(8, _zero)).slice(1);
    s.clear();
    expect(s.items.toList(), [0, 0]);
  });
}

int _zero() => 0;
