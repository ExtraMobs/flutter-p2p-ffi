// ignore_for_file: library_prefixes
import 'package:golib_dart/builtin.dart' as go;
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/fmt.dart' as fmt;
import 'package:test/test.dart';

Golang.String _s(String s) => Golang.String.fromDart(s);

go.Slice<Object?> _args(List<Object?> a) =>
    go.Slice<Object?>.of(a, const go.Elem<Object?>(16, go.zeroNull, pointers: true));

void main() {
  test('Errorf: %w guarda o erro para Unwrap; sem %w é errorString', () {
    final base = fmt.errorf(_s('base'), _args([]));
    expect(base, isA<go.ErrorString>());
    final w = fmt.errorf(_s('ctx: %w'), _args([base]));
    expect(w, isA<go.WrapError>());
    expect((w as go.WrapError).unwrap(), same(base));
    expect(w.error(), _s('ctx: base'));
    final many = fmt.errorf(_s('%w + %w'), _args([base, w]));
    expect((many as go.WrapErrors).errs, [base, w]);
  });
}
