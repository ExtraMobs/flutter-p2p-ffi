// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/query/order.dart
//
// Port of go-datastore's query/order.go.
import 'query.dart';

/// Orders query results. Equivalent to go-datastore's `query.Order`.
abstract class Order {
  /// Returns -1/0/1 as [a] sorts before/the same as/after [b].
  int compare(Entry a, Entry b);
}

/// Orders results using an arbitrary [compare] function. Equivalent to
/// go-datastore's `query.OrderByFunction`.
class OrderByFunction implements Order {
  /// Creates an order from [compare].
  const OrderByFunction(this._compare);

  final int Function(Entry a, Entry b) _compare;

  @override
  int compare(Entry a, Entry b) => _compare(a, b);

  @override
  String toString() => 'FN';
}

/// Orders results by ascending value (byte-wise). Equivalent to
/// go-datastore's `query.OrderByValue`.
class OrderByValue implements Order {
  /// Creates the order.
  const OrderByValue();

  @override
  int compare(Entry a, Entry b) => compareBytes(a.value, b.value);

  @override
  String toString() => 'VALUE';
}

/// Orders results by descending value (byte-wise). Equivalent to
/// go-datastore's `query.OrderByValueDescending`.
class OrderByValueDescending implements Order {
  /// Creates the order.
  const OrderByValueDescending();

  @override
  int compare(Entry a, Entry b) => -compareBytes(a.value, b.value);

  @override
  String toString() => 'desc(VALUE)';
}

/// Orders results by ascending key. Equivalent to go-datastore's
/// `query.OrderByKey`.
class OrderByKey implements Order {
  /// Creates the order.
  const OrderByKey();

  @override
  int compare(Entry a, Entry b) => a.key.compareTo(b.key);

  @override
  String toString() => 'KEY';
}

/// Orders results by descending key. Equivalent to go-datastore's
/// `query.OrderByKeyDescending`.
class OrderByKeyDescending implements Order {
  /// Creates the order.
  const OrderByKeyDescending();

  @override
  int compare(Entry a, Entry b) => -a.key.compareTo(b.key);

  @override
  String toString() => 'desc(KEY)';
}

/// Whether [a] sorts before [b] under [orders], falling back to a stable
/// by-key comparison. Equivalent to go-datastore's `query.Less`.
bool queryLess(List<Order> orders, Entry a, Entry b) {
  for (final order in orders) {
    final c = order.compare(a, b);
    if (c < 0) return true;
    if (c > 0) return false;
  }
  return a.key.compareTo(b.key) < 0;
}

/// Compares [a] and [b] under [orders], falling back to a stable by-key
/// comparison. Equivalent to go-datastore's `query.Compare`.
int queryCompare(List<Order> orders, Entry a, Entry b) {
  for (final order in orders) {
    final n = order.compare(a, b);
    if (n != 0) return n;
  }
  return a.key.compareTo(b.key);
}

/// Sorts [entries] in place using [orders]. Equivalent to go-datastore's
/// `query.Sort`.
void querySort(List<Order> orders, List<Entry> entries) {
  entries.sort((a, b) => queryCompare(orders, a, b));
}

/// Byte-wise comparison of two optional byte lists, `null` sorting before
/// any non-null value (mirroring `bytes.Compare(nil, x)` treating `nil` as
/// the empty slice). Equivalent to Go stdlib's `bytes.Compare` at the call
/// sites in this file.
int compareBytes(List<int>? a, List<int>? b) {
  final av = a ?? const [];
  final bv = b ?? const [];
  final n = av.length < bv.length ? av.length : bv.length;
  for (var i = 0; i < n; i++) {
    if (av[i] != bv[i]) return av[i] - bv[i];
  }
  return av.length - bv.length;
}
