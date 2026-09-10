// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

/// Returned when block data does not match its supplied Cid.
final class WrongHashException implements Exception {
  /// Creates the hash mismatch error.
  const WrongHashException();

  @override
  String toString() => 'data did not match given hash';
}

/// Common block interface.
abstract interface class Block {
  /// Raw block contents.
  Uint8List rawData();

  /// Content identifier for the block.
  Cid cid();

  /// Human-readable block representation.
  @override
  String toString();

  /// Structured logging fields.
  Map<String, Object?> loggable();
}

/// A block containing opaque bytes and a Cid.
final class BasicBlock implements Block {
  /// Creates a block from [data] and its [cid].
  BasicBlock(this._data, this._cid);

  /// Creates a block using the default CIDv0 SHA-256 format. Equivalent to
  /// Go's `NewBlock`.
  factory BasicBlock.fromData(Uint8List data) {
    final digest = MultihashUtils.sum('sha2-256', data).digest;
    return BasicBlock(data, Cid.v0(Uint8List.fromList(digest)));
  }

  /// Creates a block using a Cid prefix. Equivalent to Go's
  /// `NewBlockWithPrefix`.
  factory BasicBlock.withPrefix(Uint8List data, Prefix prefix) =>
      BasicBlock(data, prefix.sum(data));

  /// Creates a block from a precomputed Cid. Equivalent to Go's
  /// `NewBlockWithCid`.
  factory BasicBlock.withCid(Uint8List data, Cid cid) =>
      BasicBlock(data, cid);

  final Uint8List _data;
  final Cid _cid;

  @override
  Uint8List rawData() => _data;

  @override
  Cid cid() => _cid;

  /// Multihash bytes contained in the Cid.
  Uint8List multihash() => Uint8List.fromList(_cid.multihash.toBytes());

  @override
  String toString() => '[Block ${_cid.toString()}]';

  @override
  Map<String, Object?> loggable() => {'block': _cid.toString()};
}
