// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:base32/base32.dart';
import 'package:transpiled_block_format/transpiled_block_format.dart' as blocks;
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';

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
  Future<blocks.Block> get(Cid cid) async {
    try {
      return blocks.BasicBlock(
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
  Future<void> put(blocks.Block block) async {
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
  Future<void> putMany(Iterable<blocks.Block> values) async {
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
    final encoded = base32
        .encode(Uint8List.fromList(cid.multihash.toBytes()))
        .replaceAll('=', '')
        .toUpperCase();
    return Key('/${noPrefix ? '' : 'blocks/'}$encoded');
  }
}
