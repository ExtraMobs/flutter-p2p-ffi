// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/datastore.dart
//
// Port of go-datastore's datastore.go: the core `Datastore` interface
// family. Go's `context.Context` cancellation isn't ported as a parameter
// -- callers needing cancellation use Dart's own `Future` cancellation
// idioms (there is no per-call context object anywhere else in this
// transpilation either, e.g. transpiled_libp2p's routing interfaces).
import 'key.dart';
import 'query/query.dart';

/// Thrown by [Read.get]/[Read.getSize] when a key has no mapped value.
/// Equivalent to go-datastore's `ErrNotFound`.
class NotFoundException implements Exception {
  /// Creates the exception.
  const NotFoundException();
  @override
  String toString() => 'datastore: key not found';
}

/// Thrown by [Batching.batch] when a datastore doesn't actually support
/// batching. Equivalent to go-datastore's `ErrBatchUnsupported`.
class BatchUnsupportedException implements Exception {
  /// Creates the exception.
  const BatchUnsupportedException();
  @override
  String toString() => 'this datastore does not support batching';
}

/// The read-side of the [Datastore] interface. Equivalent to go-datastore's
/// `Read`.
abstract class Read {
  /// Retrieves the value named by [key]. Throws [NotFoundException] if
  /// [key] has no mapped value.
  Future<List<int>> get(Key key);

  /// Whether [key] is mapped to a value.
  Future<bool> has(Key key);

  /// The size of the value named by [key]. Throws [NotFoundException] if
  /// [key] has no mapped value.
  Future<int> getSize(Key key);

  /// Runs [q] against this datastore.
  Future<Results> query(Query q);
}

/// The write-side of the [Datastore] interface. Equivalent to go-datastore's
/// `Write`.
abstract class Write {
  /// Stores [value] named by [key].
  Future<void> put(Key key, List<int> value);

  /// Removes the value for [key]. Not an error if [key] isn't mapped.
  Future<void> delete(Key key);
}

/// Storage for any key-value pair. Equivalent to go-datastore's `Datastore`.
abstract class Datastore implements Read, Write {
  /// Guarantees that [put]/[delete] calls under [prefix] which returned
  /// before this call are observed afterward, even across a crash. May be
  /// a no-op if [put]/[delete] already satisfy this.
  Future<void> sync(Key prefix);

  /// Releases any resources held by this datastore.
  Future<void> close();
}

/// A deferred, grouped set of updates. Equivalent to go-datastore's `Batch`.
///
/// Batches do NOT have transactional semantics. Updates aren't flushed
/// until [commit] is called; a batch must not be reused after [commit].
abstract class Batch implements Write {
  /// Applies this batch's writes to the datastore.
  Future<void> commit();
}

/// A [Datastore] supporting deferred, grouped updates. Equivalent to
/// go-datastore's `Batching`.
abstract class Batching implements Datastore {
  /// Starts a new [Batch] against this datastore.
  Future<Batch> batch();
}

/// A [Datastore] that can check its own on-disk data integrity. Equivalent
/// to go-datastore's `CheckedDatastore`.
abstract class CheckedDatastore implements Datastore {
  /// Checks data integrity.
  Future<void> check();
}

/// A [Datastore] that can scrub/error-correct itself. Equivalent to
/// go-datastore's `ScrubbedDatastore`.
abstract class ScrubbedDatastore implements Datastore {
  /// Scrubs the datastore.
  Future<void> scrub();
}

/// A [Datastore] that doesn't free disk space merely by removing data, and
/// so needs an explicit collection pass. Equivalent to go-datastore's
/// `GCDatastore`.
abstract class GcDatastore implements Datastore {
  /// Reclaims disk space.
  Future<void> collectGarbage();
}

/// A [Datastore] that can report its disk usage. Equivalent to
/// go-datastore's `PersistentDatastore`.
abstract class PersistentDatastore implements Datastore {
  /// The space used by this datastore, in bytes.
  Future<int> diskUsage();
}

/// [d]'s [PersistentDatastore.diskUsage] if it implements that interface,
/// `0` otherwise. Equivalent to go-datastore's `DiskUsage`.
Future<int> diskUsage(Datastore d) async {
  if (d is PersistentDatastore) return d.diskUsage();
  return 0;
}

/// A [Datastore] supporting expiring entries. Equivalent to go-datastore's
/// `TTLDatastore`.
abstract class TtlDatastore implements Datastore {
  /// Stores [value] named by [key], expiring after [ttl].
  Future<void> putWithTtl(Key key, List<int> value, Duration ttl);

  /// Changes [key]'s expiration to [ttl] from now.
  Future<void> setTtl(Key key, Duration ttl);

  /// [key]'s current expiration time.
  Future<DateTime> getExpiration(Key key);
}

/// A batch of reads/writes performed atomically as a group. Equivalent to
/// go-datastore's `Txn`.
abstract class Txn implements Read, Write {
  /// Commits this transaction. An error indicates nothing was committed.
  Future<void> commit();

  /// Discards this transaction's recorded changes. A no-op once [commit]
  /// has succeeded, so it's safe to call unconditionally on cleanup.
  Future<void> discard();
}

/// A [Datastore] supporting [Txn]s. Equivalent to go-datastore's
/// `TxnDatastore`.
abstract class TxnDatastore implements Datastore {
  /// Starts a new transaction. [readOnly] may let the datastore optimize
  /// for read-only access.
  Future<Txn> newTransaction({required bool readOnly});
}

/// A default [Read.has] implementation in terms of [Read.get]. Equivalent
/// to go-datastore's `GetBackedHas`.
Future<bool> getBackedHas(Read ds, Key key) async {
  try {
    await ds.get(key);
    return true;
  } on NotFoundException {
    return false;
  }
}

/// A default [Read.getSize] implementation in terms of [Read.get].
/// Equivalent to go-datastore's `GetBackedSize`.
Future<int> getBackedSize(Read ds, Key key) async {
  final value = await ds.get(key);
  return value.length;
}

/// Streams every entry matching [q] against [ds], stopping (and rethrowing)
/// at the first error. Equivalent to go-datastore's `QueryIter` (a Go
/// range-over-func iterator there; a `Stream` is the closest native Dart
/// equivalent).
Stream<Entry> queryIter(Read ds, Query q) async* {
  final results = await ds.query(q);
  try {
    while (true) {
      final (result, ok) = results.nextSync();
      if (!ok) return;
      if (result.error != null) throw result.error!;
      yield result.entry;
    }
  } finally {
    results.close();
  }
}
