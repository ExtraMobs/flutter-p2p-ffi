// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:transpiled_block_format/transpiled_block_format.dart'
    as block_format;
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart' as multihash;

import 'datastore/dshelp/key.dart' as dshelp;

/// Namespace used by Boxo blockstores unless NoPrefix is selected.
final blockPrefix = Key('/blocks');
final _log = Logger('blockstore');

final class _BlockstoreIterationException implements Exception {
  const _BlockstoreIterationException(this._cause);
  final Object _cause;
  @override
  String toString() => 'blockstore.AllKeysChan iteration error: $_cause';
}

/// Thrown when a block is absent from the datastore.
final class BlockstoreNotFoundException implements Exception {
  /// Creates a not-found error for [cid].
  const BlockstoreNotFoundException(this.cid);

  /// The requested Cid.
  final Cid cid;

  @override
  String toString() => 'blockstore: block not found: $cid';
}

/// A thin Boxo blockstore over a batching datastore.
final class Blockstore {
  /// Creates a blockstore backed by [datastore].
  Blockstore(
    this._datastore, {
    this.writeThrough = false,
    this.noPrefix = false,
  });

  final Batching _datastore;

  /// Whether [put] skips its existing-block check.
  final bool writeThrough;

  /// Whether datastore keys omit the `/blocks` namespace.
  final bool noPrefix;

  /// Reports whether [cid] is stored.
  Future<bool> has(Cid cid) => _datastore.has(_key(cid));

  /// Returns the stored block named by [cid].
  Future<block_format.Block> get(Cid cid) async {
    try {
      return block_format.BasicBlock(
        Uint8List.fromList(await _datastore.get(_key(cid))),
        cid,
      );
    } on NotFoundException {
      throw BlockstoreNotFoundException(cid);
    }
  }

  /// Returns the stored block size without loading its bytes.
  Future<int> getSize(Cid cid) async {
    try {
      return await _datastore.getSize(_key(cid));
    } on NotFoundException {
      throw BlockstoreNotFoundException(cid);
    }
  }

  /// Stores [block], skipping the write when it is already present unless
  /// [writeThrough] is enabled.
  Future<void> put(block_format.Block block) async {
    final key = _key(block.cid());
    if (!writeThrough) {
      try {
        if (await _datastore.has(key)) return;
      } catch (_) {
        // Boxo proceeds with Put when the Has optimization fails.
      }
    }
    await _datastore.put(key, block.rawData());
  }

  /// Stores [values] using one datastore batch, including when it is empty.
  Future<void> putMany(Iterable<block_format.Block> values) async {
    final blocksList = values.toList();
    if (blocksList.length == 1) return put(blocksList.single);

    final batch = await _datastore.batch();
    for (final block in blocksList) {
      final key = _key(block.cid());
      if (!writeThrough) {
        try {
          if (await _datastore.has(key)) continue;
        } catch (_) {
          // Boxo proceeds with the batch write when Has fails.
        }
      }
      await batch.put(key, block.rawData());
    }
    await batch.commit();
  }

  Key _key(Cid cid) {
    final key = dshelp.multihashToDsKey(cid.multihash.toBytes());
    return noPrefix ? key : blockPrefix.child(key);
  }

  /// Opens key enumeration. Query-creation failures propagate through the
  /// Future; iteration failures are logged and end the stream, as in Go.
  Future<Stream<Cid>> allKeysChan() async {
    final stream = await allKeysChanWithErr();
    return stream.handleError(
      (Object _) {},
      test: (error) => error is _BlockstoreIterationException,
    );
  }

  /// Enumerates keys with errors delivered through the returned stream.
  /// This maps Go's post-drain error callback to Dart stream error events.
  Future<Stream<Cid>> allKeysChanWithErr() async {
    final results = await _datastore.query(
      Query(prefix: noPrefix ? '' : blockPrefix.value, keysOnly: true),
    );
    return _allKeys(results);
  }

  Stream<Cid> _allKeys(Results results) async* {
    try {
      await for (final result in results.next) {
        if (result.error case final cause?) {
          final error = _BlockstoreIterationException(cause);
          _log.severe(error);
          throw error;
        }
        final encodedKey = noPrefix
            ? result.entry.key
            : result.entry.key.substring(blockPrefix.value.length);
        final Uint8List bytes;
        try {
          bytes = dshelp.binaryFromDsKey(Key.raw(encodedKey));
        } catch (error) {
          _log.warning('error parsing key from binary: $error');
          continue;
        }
        yield Cid.v1('raw', multihash.decode(bytes));
      }
    } finally {
      results.close();
    }
  }
}
