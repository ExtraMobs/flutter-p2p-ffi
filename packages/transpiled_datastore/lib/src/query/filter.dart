// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/query/filter.dart
//
// Port of go-datastore's query/filter.go.
import 'order.dart' show compareBytes;
import 'query.dart';

/// Tests query result entries. Equivalent to go-datastore's `query.Filter`.
abstract class Filter {
  /// Returns whether [e] passes this filter.
  bool filter(Entry e);
}

/// A comparison operator. Equivalent to go-datastore's `query.Op`.
enum FilterOp {
  /// `==`
  equal('=='),

  /// `!=`
  notEqual('!='),

  /// `>`
  greaterThan('>'),

  /// `>=`
  greaterThanOrEqual('>='),

  /// `<`
  lessThan('<'),

  /// `<=`
  lessThanOrEqual('<=');

  const FilterOp(this.symbol);

  /// The operator's textual form.
  final String symbol;
}

/// Filters by comparing an entry's value against [value]. Equivalent to
/// go-datastore's `query.FilterValueCompare`.
class FilterValueCompare implements Filter {
  /// Creates the filter.
  const FilterValueCompare(this.op, this.value);

  /// The comparison operator.
  final FilterOp op;

  /// The value to compare against.
  final List<int> value;

  @override
  bool filter(Entry e) {
    final cmp = compareBytes(e.value, value);
    return switch (op) {
      FilterOp.equal => cmp == 0,
      FilterOp.notEqual => cmp != 0,
      FilterOp.lessThan => cmp < 0,
      FilterOp.lessThanOrEqual => cmp <= 0,
      FilterOp.greaterThan => cmp > 0,
      FilterOp.greaterThanOrEqual => cmp >= 0,
    };
  }

  @override
  String toString() => 'VALUE ${op.symbol} "${String.fromCharCodes(value)}"';
}

/// Filters by comparing an entry's key against [key]. Equivalent to
/// go-datastore's `query.FilterKeyCompare`.
class FilterKeyCompare implements Filter {
  /// Creates the filter.
  const FilterKeyCompare(this.op, this.key);

  /// The comparison operator.
  final FilterOp op;

  /// The key to compare against.
  final String key;

  @override
  bool filter(Entry e) {
    return switch (op) {
      FilterOp.equal => e.key == key,
      FilterOp.notEqual => e.key != key,
      FilterOp.greaterThan => e.key.compareTo(key) > 0,
      FilterOp.greaterThanOrEqual => e.key.compareTo(key) >= 0,
      FilterOp.lessThan => e.key.compareTo(key) < 0,
      FilterOp.lessThanOrEqual => e.key.compareTo(key) <= 0,
    };
  }

  @override
  String toString() => 'KEY ${op.symbol} "$key"';
}

/// Filters entries whose key starts with [prefix]. Equivalent to
/// go-datastore's `query.FilterKeyPrefix`.
class FilterKeyPrefix implements Filter {
  /// Creates the filter.
  const FilterKeyPrefix(this.prefix);

  /// The required key prefix.
  final String prefix;

  @override
  bool filter(Entry e) => e.key.startsWith(prefix);

  @override
  String toString() => 'PREFIX("$prefix")';
}
