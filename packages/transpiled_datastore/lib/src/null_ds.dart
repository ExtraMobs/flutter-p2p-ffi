// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/null_ds.dart
//
// Port of go-datastore's null_ds.go: a Datastore that stores nothing, but
// conforms to the full API. Useful for tests.
import 'batch.dart';
import 'datastore.dart';
import 'key.dart';
import 'query/query.dart';

/// Stores nothing, but conforms to the full [Datastore] API. Equivalent to
/// go-datastore's `NullDatastore`.
class NullDatastore
    implements
        Datastore,
        Batching,
        ScrubbedDatastore,
        CheckedDatastore,
        PersistentDatastore,
        GcDatastore,
        TxnDatastore {
  /// Creates a null datastore.
  NullDatastore();

  @override
  Future<void> put(Key key, List<int> value) async {}

  @override
  Future<void> sync(Key prefix) async {}

  @override
  Future<List<int>> get(Key key) async => throw const NotFoundException();

  @override
  Future<bool> has(Key key) async => false;

  @override
  Future<int> getSize(Key key) async => throw const NotFoundException();

  @override
  Future<void> delete(Key key) async {}

  @override
  Future<void> scrub() async {}

  @override
  Future<void> check() async {}

  @override
  Future<Results> query(Query q) async => resultsWithEntries(q, const []);

  @override
  Future<Batch> batch() async => BasicBatch(this);

  @override
  Future<void> collectGarbage() async {}

  @override
  Future<int> diskUsage() async => 0;

  @override
  Future<void> close() async {}

  @override
  Future<Txn> newTransaction({required bool readOnly}) async => _NullTxn();
}

class _NullTxn implements Txn {
  @override
  Future<List<int>> get(Key key) async => const [];

  @override
  Future<bool> has(Key key) async => false;

  @override
  Future<int> getSize(Key key) async => 0;

  @override
  Future<Results> query(Query q) async => resultsWithEntries(q, const []);

  @override
  Future<void> put(Key key, List<int> value) async {}

  @override
  Future<void> delete(Key key) async {}

  @override
  Future<void> commit() async {}

  @override
  Future<void> discard() async {}
}
