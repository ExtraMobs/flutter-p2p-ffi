// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/query/query.dart
//
// Port of go-datastore's query/query.go. Go's result channel maps to a Dart
// Stream and its cancellation context maps to a Future completed by close().
import 'dart:async';

import 'filter.dart';
import 'order.dart';

/// Upstream channel capacity for ordinary queries.
const int normalBufSize = 1;

/// Upstream channel capacity for key-only queries.
const int keysOnlyBufSize = 128;

/// A query against a [Read] datastore, mirroring go-datastore's `Query`.
///
/// Applied in-order: [prefix] scopes to a path prefix, [filters] select a
/// subset, [orders] sort (hierarchically), then [offset]/[limit] paginate.
class Query {
  /// Creates a query.
  const Query({
    this.prefix = '',
    this.filters = const [],
    this.orders = const [],
    this.limit = 0,
    this.offset = 0,
    this.keysOnly = false,
    this.returnExpirations = false,
    this.returnsSizes = false,
  });

  /// Scopes the query to results whose keys have this prefix.
  final String prefix;

  /// Filters applied sequentially.
  final List<Filter> filters;

  /// Orderings applied hierarchically.
  final List<Order> orders;

  /// The maximum number of results (0 = no limit).
  final int limit;

  /// The number of results to skip.
  final int offset;

  /// Whether to return only keys (no values).
  final bool keysOnly;

  /// Whether to return expirations (see `TTLDatastore`).
  final bool returnExpirations;

  /// Whether to always return sizes.
  final bool returnsSizes;

  @override
  bool operator ==(Object other) =>
      other is Query &&
      prefix == other.prefix &&
      _listEquals(filters, other.filters) &&
      _listEquals(orders, other.orders) &&
      limit == other.limit &&
      offset == other.offset &&
      keysOnly == other.keysOnly &&
      returnExpirations == other.returnExpirations &&
      returnsSizes == other.returnsSizes;

  @override
  int get hashCode => Object.hash(
    prefix,
    Object.hashAll(filters),
    Object.hashAll(orders),
    limit,
    offset,
    keysOnly,
    returnExpirations,
    returnsSizes,
  );

  /// A debugging/validation representation of this query (NOT a SQL
  /// query). Equivalent to go-datastore's `Query.String`.
  @override
  String toString() {
    final s = StringBuffer('SELECT keys');
    if (!keysOnly) s.write(',vals');
    if (returnExpirations) s.write(',exps');
    s.write(' ');

    if (prefix.isNotEmpty) s.write('FROM "$prefix" ');

    if (filters.isNotEmpty) {
      s.write('FILTER [${filters[0]}');
      for (final f in filters.skip(1)) {
        s.write(', $f');
      }
      s.write('] ');
    }

    if (orders.isNotEmpty) {
      s.write('ORDER [${orders[0]}');
      for (final o in orders.skip(1)) {
        s.write(', $o');
      }
      s.write('] ');
    }

    if (offset > 0) s.write('OFFSET $offset ');
    if (limit > 0) s.write('LIMIT $limit ');

    final result = s.toString();
    return result.substring(0, result.length - 1);
  }
}

bool _listEquals(List<Object> a, List<Object> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A query result entry. Equivalent to go-datastore's `query.Entry`.
class Entry {
  /// Creates an entry.
  const Entry({required this.key, this.value, this.expiration, this.size = -1});

  /// The entry's key (a `String`, not [Key] -- avoids Go's own
  /// circular-import concern between `datastore` and `datastore/query`,
  /// carried over here for the same reason).
  final String key;

  /// The entry's value, or `null` if [Query.keysOnly] was set.
  final List<int>? value;

  /// The entry's expiration timestamp, if requested and supported.
  final DateTime? expiration;

  /// The value's size, or -1 if unknown.
  final int size;
}

/// A single query result, possibly an error. Equivalent to go-datastore's
/// `query.Result`.
class QueryResult {
  /// Creates a successful result.
  const QueryResult(this.entry) : error = null;

  /// Creates an error result.
  const QueryResult.error(Object this.error) : entry = const Entry(key: '');

  /// The result entry (meaningless if [error] is non-null).
  final Entry entry;

  /// The error, if any.
  final Object? error;
}

/// A pull-based source of query results. Equivalent to go-datastore's
/// `query.Iterator` (only the synchronous-callback shape is needed here --
/// see this file's header).
class QueryIterator {
  /// Creates an iterator from [next] (and optionally [close]).
  QueryIterator({required this.next, void Function()? close})
    : close = close ?? (() {});

  /// Returns the next result, or `(_, false)` when exhausted.
  final (QueryResult, bool) Function() next;

  /// Releases any resources held by this iterator. May be called more
  /// than once.
  final void Function() close;
}

/// A set of query results, mirroring go-datastore's `query.Results`.
abstract class Results {
  /// The query these results correspond to.
  Query query();

  /// Blocks and returns the next result, or `(_, false)` when exhausted.
  (QueryResult, bool) nextSync();

  /// Results as they become available. Equivalent to Go's `Results.Next`.
  Stream<QueryResult> get next;

  /// Completes when production ends (including after a [close] request).
  /// Equivalent to Go's `Results.Done`.
  Future<void> get done;

  /// Consumes every remaining result. Equivalent to go-datastore's
  /// `query.Results.Rest`.
  List<Entry> rest() {
    final entries = <Entry>[];
    while (true) {
      final (result, ok) = nextSync();
      if (!ok) break;
      if (result.error != null) throw result.error!;
      entries.add(result.entry);
    }
    return entries;
  }

  /// Signals early exit. Equivalent to go-datastore's `query.Results.Close`.
  void close();
}

class _IteratorResults extends Results {
  _IteratorResults(this._q, this._iterator);

  final Query _q;
  final QueryIterator _iterator;
  bool _closed = false;
  final Completer<void> _done = Completer<void>();

  @override
  late final Stream<QueryResult> next = _asStream();

  @override
  Future<void> get done => _done.future;

  Stream<QueryResult> _asStream() async* {
    while (true) {
      final (result, ok) = nextSync();
      if (!ok) return;
      yield result;
    }
  }

  @override
  Query query() => _q;

  @override
  (QueryResult, bool) nextSync() {
    final (result, ok) = _iterator.next();
    if (!ok) close();
    return (result, ok);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _iterator.close();
    if (!_done.isCompleted) _done.complete();
  }
}

/// Producer used by [resultsWithContext]. [cancelled] completes when the
/// consumer closes the results; [output] accepts results until production
/// returns.
typedef ResultsProcess =
    FutureOr<void> Function(Future<void> cancelled, Sink<QueryResult> output);

class _ContextResults extends Results {
  _ContextResults(this._q, ResultsProcess process) {
    _controller = StreamController<QueryResult>(onCancel: close);
    Future<void>(() async {
      try {
        await process(_cancelled.future, _controller.sink);
      } finally {
        await _controller.close();
        if (!_done.isCompleted) _done.complete();
      }
    });
  }

  final Query _q;
  final Completer<void> _cancelled = Completer<void>();
  final Completer<void> _done = Completer<void>();
  late final StreamController<QueryResult> _controller;
  bool _closed = false;

  @override
  Query query() => _q;

  @override
  Stream<QueryResult> get next => _controller.stream;

  @override
  Future<void> get done => _done.future;

  @override
  (QueryResult, bool) nextSync() => throw UnsupportedError(
    'resultsWithContext is asynchronous; consume Results.next instead',
  );

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

/// Starts [process] asynchronously and exposes its output as [Results.next].
/// Dart streams handle scheduling and therefore do not require Go's explicit
/// channel capacities [normalBufSize] and [keysOnlyBufSize].
Results resultsWithContext(Query q, ResultsProcess process) =>
    _ContextResults(q, process);

/// Builds [Results] from a pull-based [iterator]. Equivalent to
/// go-datastore's `query.ResultsFromIterator`.
Results resultsFromIterator(Query q, QueryIterator iterator) =>
    _IteratorResults(q, iterator);

/// Builds [Results] from a fixed list of [entries]. Equivalent to
/// go-datastore's `query.ResultsWithEntries`.
Results resultsWithEntries(Query q, List<Entry> entries) {
  var i = 0;
  return resultsFromIterator(
    q,
    QueryIterator(
      next: () {
        if (i >= entries.length) {
          return (const QueryResult(Entry(key: '')), false);
        }
        final next = entries[i];
        i++;
        return (QueryResult(next), true);
      },
    ),
  );
}

/// Re-tags existing [results] with a different [query] (used by decorator
/// datastores like `namespace`/`keytransform` that rewrite keys). Equivalent
/// to go-datastore's `query.ResultsReplaceQuery`.
Results resultsReplaceQuery(Results results, Query query) {
  if (results is! _IteratorResults) {
    throw ArgumentError('unknown results type');
  }
  return _IteratorResults(query, results._iterator);
}
