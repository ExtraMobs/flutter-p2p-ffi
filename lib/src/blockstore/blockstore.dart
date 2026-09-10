import 'dart:typed_data';

import 'package:transpiled_block_format/transpiled_block_format.dart' as blocks;
import 'package:transpiled_boxo/transpiled_boxo.dart' as boxo;
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';

export 'package:transpiled_boxo/transpiled_boxo.dart'
    show BlockstoreNotFoundException;

/// Returned when bytes do not match their content identifier.
final class BlockstoreHashMismatchException implements Exception {
  /// Creates a hash-mismatch error.
  const BlockstoreHashMismatchException(this.cid);

  /// Expected Cid.
  final Cid cid;

  @override
  String toString() => 'blockstore: data did not match $cid';
}

/// Embedded-node integration: Boxo storage with mandatory Cid validation.
final class Blockstore {
  /// Creates an in-memory blockstore unless [datastore] is supplied.
  Blockstore({Batching? datastore}) : _datastore = datastore ?? MapDatastore() {
    _store = boxo.Blockstore(_datastore);
  }

  final Batching _datastore;
  late final boxo.Blockstore _store;

  /// Reports whether [cid] is stored.
  Future<bool> has(Cid cid) => _store.has(cid);

  /// Returns the encoded block size without loading its bytes.
  Future<int> getSize(Cid cid) => _store.getSize(cid);

  /// Returns the block named by [cid], validating its bytes before returning.
  Future<blocks.Block> get(Cid cid) async {
    final value = await _store.get(cid);
    final data = Uint8List.fromList(value.rawData());
    _validate(cid, data);
    return blocks.BasicBlock(data, cid);
  }

  /// Stores [block] after validating its Cid.
  Future<void> put(blocks.Block block) async {
    final cid = block.cid();
    final data = Uint8List.fromList(block.rawData());
    _validate(cid, data);
    await _store.put(blocks.BasicBlock(data, cid));
  }

  /// Stores all [values], validating every Cid before any write.
  Future<void> putMany(Iterable<blocks.Block> values) async {
    final pending = <blocks.Block>[];
    for (final block in values) {
      final cid = block.cid();
      final data = Uint8List.fromList(block.rawData());
      _validate(cid, data);
      pending.add(blocks.BasicBlock(data, cid));
    }
    await _store.putMany(pending);
  }

  /// Releases the underlying datastore.
  Future<void> close() => _datastore.close();

  static void _validate(Cid cid, Uint8List data) {
    if (cid.prefix.sum(data) != cid) {
      throw BlockstoreHashMismatchException(cid);
    }
  }
}
