// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

void main() {
  test('bool zero value, truth table and short-circuit effects', () {
    expect(Golang.Bool().toBool(), false);
    for (final left in [false, true]) {
      for (final right in [false, true]) {
        var calls = 0;
        Golang.Bool rhs() {
          calls++;
          return Golang.Bool(right);
        }

        final a = Golang.Bool(left);
        expect(a.and(rhs).toBool(), left && right);
        expect(calls, left ? 1 : 0);
        calls = 0;
        expect(a.or(rhs).toBool(), left || right);
        expect(calls, left ? 0 : 1);
        expect(a.not().toBool(), !left);
      }
    }
  });
  test('evaluated operand errors propagate without reevaluation', () {
    final error = StateError('rhs');
    Golang.Bool fail() => throw error;
    expect(Golang.Bool().and(fail), Golang.Bool());
    expect(Golang.Bool(true).or(fail), Golang.Bool(true));
    expect(() => Golang.Bool(true).and(fail), throwsA(same(error)));
    expect(() => Golang.Bool().or(fail), throwsA(same(error)));
  });
}
