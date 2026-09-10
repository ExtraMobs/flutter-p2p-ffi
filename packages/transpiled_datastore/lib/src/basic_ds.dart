// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/basic_ds.dart
//
// Port of go-datastore's basic_ds.go: basic Datastore implementations.
import 'dart:developer' as developer;

import 'batch.dart';
import 'datastore.dart';
// Prefixed to avoid the free function `diskUsage` being shadowed by
// `LogDatastore`'s own instance method of the same name (an unqualified
// reference inside that method always resolves to `this.diskUsage`,
// regardless of arity) -- the same Dart naming-collision pattern already
// documented for `core_routing.getPublicKey` in transpiled_libp2p.
import 'datastore.dart' as ds show diskUsage;
import 'key.dart';
import 'query/query.dart';
import 'query/query_impl.dart';

/// Uses a plain in-memory map for storage. Not safe for concurrent
/// mutation from multiple isolates -- ordinary single-isolate Dart code
/// using this from multiple async tasks is fine, since nothing here
/// suspends mid-mutation. Equivalent to go-datastore's `MapDatastore`.
class MapDatastore implements Datastore, Batching {
  /// Creates an empty map datastore.
  MapDatastore() : _values = {};

  final Map<Key, List<int>> _values;

  @override
  Future<void> put(Key key, List<int> value) async {
    _values[key] = value;
  }

  @override
  Future<void> sync(Key prefix) async {}

  @override
  Future<List<int>> get(Key key) async {
    final value = _values[key];
    if (value == null) throw const NotFoundException();
    return value;
  }

  @override
  Future<bool> has(Key key) async => _values.containsKey(key);

  @override
  Future<int> getSize(Key key) async {
    final value = _values[key];
    if (value == null) throw const NotFoundException();
    return value.length;
  }

  @override
  Future<void> delete(Key key) async {
    _values.remove(key);
  }

  @override
  Future<Results> query(Query q) async {
    final entries = [
      for (final e in _values.entries)
        Entry(key: e.key.value, value: q.keysOnly ? null : e.value, size: e.value.length),
    ];
    final r = resultsWithEntries(q, entries);
    return naiveQueryApply(q, r);
  }

  @override
  Future<Batch> batch() async => BasicBatch(this);

  @override
  Future<void> close() async {}
}

/// A [Datastore] which has a child datastore it delegates to. Equivalent
/// to go-datastore's `Shim`.
abstract class Shim implements Datastore {
  /// This shim's children (typically a single wrapped datastore).
  List<Datastore> children();
}

/// Logs every access through a wrapped [Datastore]. Equivalent to
/// go-datastore's `LogDatastore`. Uses `dart:developer`'s `log` rather than
/// `print`, matching how the rest of this project's Dart code logs.
class LogDatastore
    implements
        Datastore,
        Batching,
        GcDatastore,
        PersistentDatastore,
        ScrubbedDatastore,
        CheckedDatastore,
        Shim {
  /// Creates a log datastore wrapping [child], logging under [name]
  /// (defaults to `'LogDatastore'` if empty).
  LogDatastore(this._child, [String name = '']) : name = name.isEmpty ? 'LogDatastore' : name;

  /// This datastore's log name.
  final String name;
  final Datastore _child;

  @override
  List<Datastore> children() => [_child];

  @override
  Future<void> put(Key key, List<int> value) async {
    developer.log('Put $key', name: name);
    await _child.put(key, value);
  }

  @override
  Future<void> sync(Key prefix) async {
    developer.log('Sync $prefix', name: name);
    await _child.sync(prefix);
  }

  @override
  Future<List<int>> get(Key key) async {
    developer.log('Get $key', name: name);
    return _child.get(key);
  }

  @override
  Future<bool> has(Key key) async {
    developer.log('Has $key', name: name);
    return _child.has(key);
  }

  @override
  Future<int> getSize(Key key) async {
    developer.log('GetSize $key', name: name);
    return _child.getSize(key);
  }

  @override
  Future<void> delete(Key key) async {
    developer.log('Delete $key', name: name);
    await _child.delete(key);
  }

  @override
  Future<int> diskUsage() async {
    developer.log('DiskUsage', name: name);
    return ds.diskUsage(_child);
  }

  @override
  Future<Results> query(Query q) async {
    developer.log('Query', name: name);
    developer.log('q.prefix: ${q.prefix}', name: name);
    developer.log('q.keysOnly: ${q.keysOnly}', name: name);
    developer.log('q.filters: ${q.filters.length}', name: name);
    developer.log('q.orders: ${q.orders.length}', name: name);
    developer.log('q.offset: ${q.offset}', name: name);
    return _child.query(q);
  }

  @override
  Future<Batch> batch() async {
    developer.log('Batch', name: name);
    final child = _child;
    if (child is Batching) {
      return _LogBatch(name, await child.batch());
    }
    throw const BatchUnsupportedException();
  }

  @override
  Future<void> close() async {
    developer.log('Close', name: name);
    await _child.close();
  }

  @override
  Future<void> check() async {
    final child = _child;
    if (child is CheckedDatastore) await child.check();
  }

  @override
  Future<void> scrub() async {
    final child = _child;
    if (child is ScrubbedDatastore) await child.scrub();
  }

  @override
  Future<void> collectGarbage() async {
    final child = _child;
    if (child is GcDatastore) await child.collectGarbage();
  }
}

/// Logs every access through a wrapped [Batch]. Equivalent to
/// go-datastore's `LogBatch`.
class _LogBatch implements Batch {
  _LogBatch(this._name, this._child);

  final String _name;
  final Batch _child;

  @override
  Future<void> put(Key key, List<int> value) async {
    developer.log('BatchPut $key', name: _name);
    await _child.put(key, value);
  }

  @override
  Future<void> delete(Key key) async {
    developer.log('BatchDelete $key', name: _name);
    await _child.delete(key);
  }

  @override
  Future<void> commit() async {
    developer.log('BatchCommit', name: _name);
    await _child.commit();
  }
}
