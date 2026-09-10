// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-datastore's test/basic_tests.go: the shared conformance suite
// every Datastore implementation is checked against upstream. This isn't
// production code -- it's a reusable *test* helper, exactly like Go's own
// `dstest` package, applied here to MapDatastore/LogDatastore/
// NullDatastore in map_datastore_test.dart/log_datastore_test.dart/
// null_datastore_test.dart.
import 'dart:math';

import 'package:test/test.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';

/// How many elements the datastore suite tests are run with. Equivalent to
/// go-datastore's `dstest.ElemCount` (Go halves this under its race
/// detector; Dart has no equivalent concept, so this always uses the full
/// value).
const int elemCount = 100;

List<int> _randValue() {
  final random = Random.secure();
  return List.generate(64, (_) => random.nextInt(256));
}

/// Equivalent to go-datastore's `dstest.SubtestBasicPutGet`.
Future<void> subtestBasicPutGet(Datastore ds) async {
  final k = Key('foo');
  final val = 'Hello Datastore!'.codeUnits;

  await ds.put(k, val);

  expect(await ds.has(k), isTrue, reason: 'should have key foo, has returned false');
  expect(await ds.getSize(k), equals(val.length));

  final out = await ds.get(k);
  expect(out, equals(val));

  expect(await ds.has(k), isTrue, reason: 'should have key foo, has returned false');
  expect(await ds.getSize(k), equals(val.length));

  await ds.delete(k);

  expect(await ds.has(k), isFalse, reason: 'should not have key foo, has returned true');
  await expectLater(
    () => ds.getSize(k),
    throwsA(isA<NotFoundException>()),
    reason: 'expected error getting size after delete',
  );
}

/// Equivalent to go-datastore's `dstest.SubtestNotFounds`.
Future<void> subtestNotFounds(Datastore ds) async {
  final badk = Key('notreal');

  await expectLater(() => ds.get(badk), throwsA(isA<NotFoundException>()));

  expect(await ds.has(badk), isFalse, reason: "has returned true for key we don't have");
  await expectLater(() => ds.getSize(badk), throwsA(isA<NotFoundException>()));

  // Must not throw even though the key doesn't exist.
  await ds.delete(badk);
}

/// Equivalent to go-datastore's `dstest.SubtestBasicSync`.
Future<void> subtestBasicSync(Datastore ds) async {
  await ds.sync(Key('prefix'));
  await ds.put(Key('/prefix'), 'foo'.codeUnits);
  await ds.sync(Key('/prefix'));
  await ds.put(Key('/prefix/sub'), 'bar'.codeUnits);
  await ds.sync(Key('/prefix'));
  await ds.sync(Key('/prefix/sub'));
  await ds.sync(Key(''));
}

class _TestFilter implements Filter {
  const _TestFilter();
  @override
  bool filter(Entry e) => e.key.length % 2 == 0;
}

/// Builds the standard 4*[count]-entry fixture used by every query subtest
/// below, and puts it into [ds]. Equivalent to go-datastore's
/// `test/basic_tests.go`'s `subtestQuery` (the fixture-building half).
Future<List<Entry>> _seedQueryFixture(Datastore ds, int count) async {
  final input = <Entry>[];
  for (var i = 0; i < count; i++) {
    final key = Key('${i}key$i').value;
    final value = _randValue();
    input.add(Entry(key: key, size: value.length, value: value));
  }
  for (var i = 0; i < count; i++) {
    final key = Key('/prefix/${i}key$i').value;
    final value = _randValue();
    input.add(Entry(key: key, size: value.length, value: value));
  }
  for (var i = 0; i < count; i++) {
    final key = Key('/prefix/sub/${i}key$i').value;
    final value = _randValue();
    input.add(Entry(key: key, size: value.length, value: value));
  }
  for (var i = 0; i < count; i++) {
    final key = Key('/capital/${i}KEY$i').value;
    final value = _randValue();
    input.add(Entry(key: key, size: value.length, value: value));
  }

  for (final e in input) {
    await ds.put(Key.raw(e.key), e.value!);
  }
  for (final e in input) {
    final val = await ds.get(Key.raw(e.key));
    expect(val, equals(e.value), reason: 'input value didnt match the one returned from Get');
  }
  return input;
}

/// Equivalent to go-datastore's `test/basic_tests.go`'s `subtestQuery`.
Future<void> subtestQuery(Datastore ds, Query q, int count) async {
  final input = await _seedQueryFixture(ds, count);

  final resp = await ds.query(q);
  expect(resp.query(), equals(q));

  final actual = resp.rest();

  final expected = naiveQueryApply(q, resultsWithEntries(q, input)).rest();
  expect(actual, hasLength(expected.length));

  final actualSorted = List.of(actual);
  final expectedSorted = List.of(expected);
  if (q.orders.isEmpty) {
    querySort(const [OrderByKey()], actualSorted);
    querySort(const [OrderByKey()], expectedSorted);
  }
  for (var i = 0; i < actualSorted.length; i++) {
    expect(actualSorted[i].key, equals(expectedSorted[i].key));
    if (!q.keysOnly) {
      expect(actualSorted[i].value, equals(expectedSorted[i].value));
    }
    if (q.returnsSizes) {
      expect(actualSorted[i].size, greaterThan(0));
    }
  }

  // Equivalent behavior check via queryIter.
  final viaIter = await queryIter(ds, q).toList();
  expect(viaIter, hasLength(expected.length));
  final viaIterSorted = List.of(viaIter);
  if (q.orders.isEmpty) {
    querySort(const [OrderByKey()], viaIterSorted);
  }
  for (var i = 0; i < viaIterSorted.length; i++) {
    expect(viaIterSorted[i].key, equals(expectedSorted[i].key));
  }

  for (final e in input) {
    await ds.delete(Key.raw(e.key));
  }
}

/// Equivalent to go-datastore's `dstest.SubtestManyKeysAndQuery`.
Future<void> subtestManyKeysAndQuery(Datastore ds) => subtestQuery(ds, const Query(keysOnly: true), elemCount);

/// Equivalent to go-datastore's `dstest.SubtestReturnSizes`.
Future<void> subtestReturnSizes(Datastore ds) => subtestQuery(ds, const Query(returnsSizes: true), 100);

/// Equivalent to go-datastore's `dstest.SubtestOrder`.
Future<void> subtestOrder(Datastore ds) async {
  for (final orders in [
    [const OrderByKey()],
    [const OrderByKeyDescending()],
    [const OrderByValue(), const OrderByKey()],
    [OrderByFunction((a, b) => compareBytes(a.value, b.value))],
  ]) {
    await subtestQuery(ds, Query(orders: orders), elemCount);
  }
}

/// Equivalent to go-datastore's `dstest.SubtestLimit`.
Future<void> subtestLimit(Datastore ds) async {
  Future<void> run(int offset, int limit) => subtestQuery(
    ds,
    Query(orders: const [OrderByKey()], offset: offset, limit: limit, keysOnly: true),
    elemCount,
  );

  await run(0, elemCount ~/ 10);
  await run(0, 0);
  await run(elemCount ~/ 10, 0);
  await run(elemCount ~/ 10, elemCount ~/ 10);
  await run(elemCount ~/ 10, elemCount ~/ 5);
  await run(elemCount ~/ 2, elemCount ~/ 5);
  await run(elemCount - 1, elemCount ~/ 5);
  await run(elemCount * 2, elemCount ~/ 5);
  await run(elemCount * 2, 0);
  await run(elemCount - 1, 0);
  await run(elemCount - 5, 0);
}

/// Equivalent to go-datastore's `dstest.SubtestFilter`.
Future<void> subtestFilter(Datastore ds) async {
  for (final filters in [
    [const FilterKeyCompare(FilterOp.equal, '/0key0')],
    [const FilterKeyCompare(FilterOp.lessThan, '/2')],
    [const FilterKeyPrefix('/0key0')],
    [FilterValueCompare(FilterOp.lessThan, _randValue())],
    const [_TestFilter()],
  ]) {
    await subtestQuery(ds, Query(filters: filters), 100);
  }
}

/// Equivalent to go-datastore's `dstest.SubtestPrefix`.
Future<void> subtestPrefix(Datastore ds) async {
  for (final prefix in [
    '',
    '/',
    '/./',
    '/.././/',
    '/prefix/../',
    '/prefix',
    '/prefix/',
    '/prefix/sub/',
    '/0/',
    '/bad/',
  ]) {
    await subtestQuery(ds, Query(prefix: prefix), elemCount);
  }
}

/// Equivalent to go-datastore's `dstest.SubtestCombinations` (Go's
/// `perms`-based exhaustive product, ported directly as nested loops).
Future<void> subtestCombinations(Datastore ds) async {
  const offsets = [0, elemCount ~/ 10, elemCount - 5, elemCount];
  const limits = [0, 1, elemCount ~/ 10, elemCount];
  final filters = [
    [const FilterKeyCompare(FilterOp.equal, '/0key0')],
    [const FilterKeyCompare(FilterOp.lessThan, '/2')],
  ];
  const prefixes = ['', '/prefix', '/0'];
  final orders = [
    [const OrderByKey()],
    [const OrderByKeyDescending()],
    [const OrderByValue(), const OrderByKey()],
    [OrderByFunction((a, b) => compareBytes(a.value, b.value))],
  ];
  const lengths = [0, 1, elemCount];

  for (final offset in offsets) {
    for (final limit in limits) {
      for (final filter in filters) {
        for (final order in orders) {
          for (final prefix in prefixes) {
            for (final length in lengths) {
              await subtestQuery(
                ds,
                Query(offset: offset, limit: limit, filters: filter, orders: order, prefix: prefix),
                length,
              );
            }
          }
        }
      }
    }
  }
}

/// All basic (non-batching) subtests, in Go's `dstest.BasicSubtests` order.
final List<Future<void> Function(Datastore)> basicSubtests = [
  subtestBasicPutGet,
  subtestNotFounds,
  subtestPrefix,
  subtestOrder,
  subtestLimit,
  subtestFilter,
  subtestManyKeysAndQuery,
  subtestReturnSizes,
  subtestBasicSync,
  // subtestCombinations is deliberately excluded from the default suite:
  // its exhaustive product (4*4*2*4*3*3 = 1152 sub-queries) is the "only
  // run when not under the race detector" case in Go; it's exercised
  // explicitly and separately (see map_datastore_test.dart) rather than on
  // every SubtestAll call, to keep the default suite fast.
];

/// Runs every [basicSubtests] entry against [ds], clearing it between each.
/// Equivalent to go-datastore's `dstest.SubtestAll` (batching subtests are
/// ported separately -- see test_util.dart -- since Dart has no
/// `ds is Batching` auto-dispatch story as clean as Go's type switch here).
Future<void> subtestAll(Datastore ds) async {
  for (final subtest in basicSubtests) {
    await subtest(ds);
    await _clearDs(ds);
  }
}

Future<void> _clearDs(Datastore ds) async {
  final results = await ds.query(const Query(keysOnly: true));
  for (final r in results.rest()) {
    await ds.delete(Key.raw(r.key));
  }
}
