// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-datastore's query/filter_test.go: TestFilterKeyCompare,
// TestFilterKeyPrefix.
import 'package:test/test.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';

import 'sample_keys.dart';

void testKeyFilter(Filter f, List<String> keys, List<String> expected) {
  final entries = [for (final k in keys) Entry(key: k)];
  var res = resultsWithEntries(const Query(), entries);
  res = naiveFilter(res, f);
  final actual = [for (final e in res.rest()) e.key];
  expect(actual, equals(expected));
}

void main() {
  test('TestFilterKeyCompare', () {
    testKeyFilter(const FilterKeyCompare(FilterOp.equal, '/ab'), sampleKeys, const ['/ab']);
    testKeyFilter(const FilterKeyCompare(FilterOp.greaterThan, '/ab'), sampleKeys, const [
      '/ab/c',
      '/ab/cd',
      '/ab/ef',
      '/ab/fg',
      '/abce',
      '/abcf',
    ]);
    testKeyFilter(const FilterKeyCompare(FilterOp.lessThanOrEqual, '/ab'), sampleKeys, const [
      '/a',
      '/ab',
    ]);
  });

  test('TestFilterKeyPrefix', () {
    testKeyFilter(const FilterKeyPrefix('/a'), sampleKeys, const [
      '/ab/c',
      '/ab/cd',
      '/ab/ef',
      '/ab/fg',
      '/a',
      '/abce',
      '/abcf',
      '/ab',
    ]);
    testKeyFilter(const FilterKeyPrefix('/ab/'), sampleKeys, const [
      '/ab/c',
      '/ab/cd',
      '/ab/ef',
      '/ab/fg',
    ]);
  });
}
