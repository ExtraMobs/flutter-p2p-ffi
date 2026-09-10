// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-datastore's query/query_test.go: TestNaiveQueryApply,
// TestLimit, TestOffset, TestResultsFromIterator(+NoClose), TestStringer.
//
// Includes the channel-based tests through Dart's Stream counterpart.
import 'dart:async';

import 'package:test/test.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';

import 'sample_keys.dart';

void testResults(Results res, List<String> expected) {
  final actual = [for (final e in res.rest()) e.key];
  expect(actual, equals(expected));
}

void main() {
  test('upstream result buffer constants are preserved', () {
    expect(normalBufSize, equals(1));
    expect(keysOnlyBufSize, equals(128));
  });

  test(
    'TestResultsFromIteratorUsingChan: next streams results and done completes',
    () async {
      final results = resultsWithEntries(const Query(), const [
        Entry(key: '/a'),
        Entry(key: '/b'),
      ]);

      expect(await results.next.map((result) => result.entry.key).toList(), [
        '/a',
        '/b',
      ]);
      await results.done;
    },
  );

  test(
    'resultsWithContext publishes asynchronously and observes close cancellation',
    () async {
      final producerExited = Completer<void>();
      final results = resultsWithContext(const Query(), (
        cancelled,
        output,
      ) async {
        output.add(const QueryResult(Entry(key: '/a')));
        await cancelled;
        producerExited.complete();
      });

      final first = await results.next.first;
      expect(first.entry.key, equals('/a'));
      results.close();
      await results.done;
      await producerExited.future;
    },
  );

  test('TestNaiveQueryApply', () {
    void run(Query query, List<String> keys, List<String> expected) {
      final entries = [for (final k in keys) Entry(key: k)];
      var res = resultsWithEntries(query, entries);
      res = naiveQueryApply(query, res);
      testResults(res, expected);
    }

    run(const Query(limit: 2), sampleKeys, const ['/ab/c', '/ab/cd']);

    run(const Query(offset: 3, limit: 2), sampleKeys, const ['/ab/fg', '/a']);

    run(
      const Query(filters: [FilterKeyCompare(FilterOp.equal, '/ab')]),
      sampleKeys,
      const ['/ab'],
    );

    run(const Query(prefix: '/ab'), sampleKeys, const [
      '/ab/c',
      '/ab/cd',
      '/ab/ef',
      '/ab/fg',
    ]);

    run(const Query(orders: [OrderByKeyDescending()]), sampleKeys, const [
      '/abcf',
      '/abce',
      '/ab/fg',
      '/ab/ef',
      '/ab/cd',
      '/ab/c',
      '/ab',
      '/a',
    ]);

    run(
      const Query(limit: 2, offset: 1, prefix: '/ab', orders: [OrderByKey()]),
      sampleKeys,
      const ['/ab/cd', '/ab/ef'],
    );
  });

  test('TestLimit', () {
    void run(int limit, List<String> keys, List<String> expected) {
      final entries = [for (final k in keys) Entry(key: k)];
      final res = naiveLimit(resultsWithEntries(const Query(), entries), limit);
      testResults(res, expected);
    }

    run(0, sampleKeys, sampleKeys); // 0 = no limit.
    run(10, sampleKeys, sampleKeys); // larger than input.
    run(2, sampleKeys, const ['/ab/c', '/ab/cd']);
  });

  test('TestOffset', () {
    void run(int offset, List<String> keys, List<String> expected) {
      final entries = [for (final k in keys) Entry(key: k)];
      final res = naiveOffset(
        resultsWithEntries(const Query(), entries),
        offset,
      );
      testResults(res, expected);
    }

    run(0, sampleKeys, sampleKeys);
    run(10, sampleKeys, const []); // larger than input.
    run(2, sampleKeys, const [
      '/ab/ef',
      '/ab/fg',
      '/a',
      '/abce',
      '/abcf',
      '/ab',
    ]);
  });

  test(
    'TestResultsFromIterator: close is called exactly once via nextSync',
    () {
      var i = 0;
      var closeCalled = 0;
      final results = resultsFromIterator(
        const Query(),
        QueryIterator(
          next: () {
            if (i >= sampleKeys.length)
              return (const QueryResult(Entry(key: '')), false);
            final r = QueryResult(Entry(key: sampleKeys[i]));
            i++;
            return (r, true);
          },
          close: () => closeCalled++,
        ),
      );

      final keys = <String>[];
      while (true) {
        final (r, ok) = results.nextSync();
        if (!ok) break;
        keys.add(r.entry.key);
      }
      expect(keys, equals(sampleKeys));
      expect(closeCalled, equals(1));
    },
  );

  test('TestResultsFromIterator: close is called exactly once via rest', () {
    var i = 0;
    var closeCalled = 0;
    final results = resultsFromIterator(
      const Query(),
      QueryIterator(
        next: () {
          if (i >= sampleKeys.length)
            return (const QueryResult(Entry(key: '')), false);
          final r = QueryResult(Entry(key: sampleKeys[i]));
          i++;
          return (r, true);
        },
        close: () => closeCalled++,
      ),
    );

    final keys = [for (final e in results.rest()) e.key];
    expect(keys, equals(sampleKeys));
    expect(closeCalled, equals(1));
  });

  test('TestResultsFromIterator: no close callback does not crash', () {
    var i = 0;
    final results = resultsFromIterator(
      const Query(),
      QueryIterator(
        next: () {
          if (i >= sampleKeys.length)
            return (const QueryResult(Entry(key: '')), false);
          final r = QueryResult(Entry(key: sampleKeys[i]));
          i++;
          return (r, true);
        },
      ),
    );
    expect(results.rest().map((e) => e.key).toList(), equals(sampleKeys));
  });

  test('TestStringer', () {
    var q = const Query();
    expect(q.toString(), equals('SELECT keys,vals'));

    q = const Query(offset: 10, limit: 10);
    expect(q.toString(), equals('SELECT keys,vals OFFSET 10 LIMIT 10'));

    q = const Query(
      offset: 10,
      limit: 10,
      orders: [OrderByValue(), OrderByKey()],
    );
    expect(
      q.toString(),
      equals('SELECT keys,vals ORDER [VALUE, KEY] OFFSET 10 LIMIT 10'),
    );

    q = const Query(
      offset: 10,
      limit: 10,
      orders: [OrderByValue(), OrderByKey()],
      filters: [
        FilterKeyCompare(FilterOp.greaterThan, '/foo/bar'),
        FilterKeyCompare(FilterOp.lessThan, '/foo/bar'),
      ],
    );
    expect(
      q.toString(),
      equals(
        'SELECT keys,vals FILTER [KEY > "/foo/bar", KEY < "/foo/bar"] '
        'ORDER [VALUE, KEY] OFFSET 10 LIMIT 10',
      ),
    );

    q = const Query(
      offset: 10,
      limit: 10,
      prefix: '/foo',
      orders: [OrderByValue(), OrderByKey()],
      filters: [
        FilterKeyCompare(FilterOp.greaterThan, '/foo/bar'),
        FilterKeyCompare(FilterOp.lessThan, '/foo/bar'),
      ],
    );
    expect(
      q.toString(),
      equals(
        'SELECT keys,vals FROM "/foo" FILTER [KEY > "/foo/bar", KEY < "/foo/bar"] '
        'ORDER [VALUE, KEY] OFFSET 10 LIMIT 10',
      ),
    );

    q = const Query(
      offset: 10,
      limit: 10,
      prefix: '/foo',
      returnExpirations: true,
      orders: [OrderByValue(), OrderByKey()],
      filters: [
        FilterKeyCompare(FilterOp.greaterThan, '/foo/bar'),
        FilterKeyCompare(FilterOp.lessThan, '/foo/bar'),
      ],
    );
    expect(
      q.toString(),
      equals(
        'SELECT keys,vals,exps FROM "/foo" FILTER [KEY > "/foo/bar", KEY < "/foo/bar"] '
        'ORDER [VALUE, KEY] OFFSET 10 LIMIT 10',
      ),
    );

    q = const Query(
      offset: 10,
      limit: 10,
      prefix: '/foo',
      returnExpirations: true,
      keysOnly: true,
      orders: [OrderByValue(), OrderByKey()],
      filters: [
        FilterKeyCompare(FilterOp.greaterThan, '/foo/bar'),
        FilterKeyCompare(FilterOp.lessThan, '/foo/bar'),
      ],
    );
    expect(
      q.toString(),
      equals(
        'SELECT keys,exps FROM "/foo" FILTER [KEY > "/foo/bar", KEY < "/foo/bar"] '
        'ORDER [VALUE, KEY] OFFSET 10 LIMIT 10',
      ),
    );

    q = const Query(
      offset: 10,
      limit: 10,
      prefix: '/foo',
      keysOnly: true,
      orders: [OrderByValue(), OrderByKey()],
      filters: [
        FilterKeyCompare(FilterOp.greaterThan, '/foo/bar'),
        FilterKeyCompare(FilterOp.lessThan, '/foo/bar'),
      ],
    );
    expect(
      q.toString(),
      equals(
        'SELECT keys FROM "/foo" FILTER [KEY > "/foo/bar", KEY < "/foo/bar"] '
        'ORDER [VALUE, KEY] OFFSET 10 LIMIT 10',
      ),
    );
  });
}
