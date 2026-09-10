// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Parity checks for go-ipld-prime's codec/api.go public values.
import 'package:test/test.dart';
import 'package:transpiled_ipld_prime/codec.dart';

void main() {
  test('ErrBudgetExhausted.Error', () {
    expect(
      const BudgetExhaustedException().toString(),
      'decoder resource budget exhausted (message too long or too complex)',
    );
  });

  test('MapSortMode values match Go iota order', () {
    expect(MapSortMode.none.index, 0);
    expect(MapSortMode.lexical.index, 1);
    expect(MapSortMode.rfc7049.index, 2);
  });
}
