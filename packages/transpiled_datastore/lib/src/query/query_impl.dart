// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/query/query_impl.dart
//
// Port of go-datastore's query/query_impl.go: the "naive" (in-memory, not
// backend-accelerated) query-operator implementations most simple
// datastores build their `Query` method out of.
import '../path_clean.dart';
import 'filter.dart';
import 'order.dart';
import 'query.dart';

/// Applies [filter] to [results]. Equivalent to go-datastore's
/// `query.NaiveFilter`.
Results naiveFilter(Results results, Filter filter) {
  return resultsFromIterator(
    results.query(),
    QueryIterator(
      next: () {
        while (true) {
          final (result, ok) = results.nextSync();
          if (!ok) return (result, false);
          if (result.error != null || filter.filter(result.entry)) return (result, true);
        }
      },
      close: results.close,
    ),
  );
}

/// Truncates [results] to [limit] entries (0 = no limit). Equivalent to
/// go-datastore's `query.NaiveLimit`.
Results naiveLimit(Results results, int limit) {
  if (limit == 0) return results;
  var remaining = limit;
  var closed = false;
  return resultsFromIterator(
    results.query(),
    QueryIterator(
      next: () {
        if (remaining == 0) {
          if (!closed) {
            closed = true;
            results.close();
          }
          return (const QueryResult(Entry(key: '')), false);
        }
        remaining--;
        return results.nextSync();
      },
      close: () {
        if (closed) return;
        closed = true;
        results.close();
      },
    ),
  );
}

/// Skips the first [offset] entries of [results]. Equivalent to
/// go-datastore's `query.NaiveOffset`.
Results naiveOffset(Results results, int offset) {
  var remaining = offset;
  return resultsFromIterator(
    results.query(),
    QueryIterator(
      next: () {
        while (remaining > 0) {
          remaining--;
          final (res, ok) = results.nextSync();
          if (!ok || res.error != null) return (res, ok);
        }
        return results.nextSync();
      },
      close: results.close,
    ),
  );
}

/// Reorders [results] according to [orders]. WARNING: unlike every other
/// `naive*` operator here, this is not stream-friendly -- it must consume
/// every result before returning anything. Equivalent to go-datastore's
/// `query.NaiveOrder`.
Results naiveOrder(Results results, List<Order> orders) {
  if (orders.isEmpty) return results;

  final entries = <Entry>[];
  final errors = <QueryResult>[];
  while (true) {
    final (result, ok) = results.nextSync();
    if (!ok) break;
    if (result.error != null) {
      errors.add(result);
    } else {
      entries.add(result.entry);
    }
  }

  querySort(orders, entries);

  var i = 0;
  return resultsFromIterator(
    results.query(),
    QueryIterator(
      next: () {
        if (errors.isNotEmpty) return (errors.removeAt(0), true);
        if (i >= entries.length) return (const QueryResult(Entry(key: '')), false);
        final next = entries[i];
        i++;
        return (QueryResult(next), true);
      },
    ),
  );
}

/// Applies every operation in [q] (prefix, filters, orders, offset, limit)
/// to [results], in the order the Query docs specify. Equivalent to
/// go-datastore's `query.NaiveQueryApply`.
Results naiveQueryApply(Query q, Results results) {
  var qr = results;
  if (q.prefix.isNotEmpty) {
    var prefix = q.prefix;
    prefix = prefix.codeUnitAt(0) != 0x2F ? '/$prefix' : prefix;
    prefix = cleanPath(prefix);
    if (prefix != '/') {
      qr = naiveFilter(qr, FilterKeyPrefix('$prefix/'));
    }
  }
  for (final f in q.filters) {
    qr = naiveFilter(qr, f);
  }
  if (q.orders.isNotEmpty) {
    qr = naiveOrder(qr, q.orders);
  }
  if (q.offset != 0) {
    qr = naiveOffset(qr, q.offset);
  }
  if (q.limit != 0) {
    qr = naiveLimit(qr, q.limit);
  }
  return qr;
}

/// Builds entries by zipping [keys] and [values]. Equivalent to
/// go-datastore's `query.ResultEntriesFrom`.
List<Entry> resultEntriesFrom(List<String> keys, List<List<int>> values) => [
  for (var i = 0; i < keys.length; i++) Entry(key: keys[i], size: values[i].length, value: values[i]),
];
