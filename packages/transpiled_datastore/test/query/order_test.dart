// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-datastore's query/order_test.go: TestOrderByKey.
import 'package:test/test.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';

import 'sample_keys.dart';

void testKeyOrder(Order o, List<String> keys, List<String> expected) {
  final entries = [for (final k in keys) Entry(key: k)];
  var res = resultsWithEntries(const Query(), entries);
  res = naiveOrder(res, [o]);
  final actual = [for (final e in res.rest()) e.key];
  expect(actual, equals(expected));
}

void main() {
  test('TestOrderByKey', () {
    testKeyOrder(const OrderByKey(), sampleKeys, const [
      '/a',
      '/ab',
      '/ab/c',
      '/ab/cd',
      '/ab/ef',
      '/ab/fg',
      '/abce',
      '/abcf',
    ]);
    testKeyOrder(const OrderByKeyDescending(), sampleKeys, const [
      '/abcf',
      '/abce',
      '/ab/fg',
      '/ab/ef',
      '/ab/cd',
      '/ab/c',
      '/ab',
      '/a',
    ]);
  });
}
