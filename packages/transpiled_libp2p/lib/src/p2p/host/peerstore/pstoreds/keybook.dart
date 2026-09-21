// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/p2p/host/peerstore/pstoreds/keybook.dart
//
// Port of go-libp2p's pstoreds/keybook.go: a KeyBook backed by a
// Datastore. Every persisted key is loaded into memory by [DsKeyBook.open]
// (see pstoreds.dart's doc comment for why this port needs to be
// eager/synchronous rather than Go's lazy per-call `ds.Get`/`ds.Put`);
// reads are then synchronous against that cache, and writes are queued
// and replayed against the store in order (see [DsKeyBook.flush]).
import 'dart:typed_data';

import 'package:transpiled_base32/transpiled_base32.dart' as base32;
import 'package:transpiled_datastore/transpiled_datastore.dart';

import '../../../../core/crypto/key_codec.dart';
import '../../../../core/crypto/key_types.dart' hide Key;
import '../../../../core/peer/peer_id.dart';
import '../../../../core/peerstore/peerstore.dart';

final Key _kbBase = Key('/peers/keys');

/// Loads or persists one peer's key under `[_kbBase]/<peer base32>/[suffix]`.
Key _peerToKey(PeerId p, String suffix) => _kbBase
    .childString(base32.rawStdEncoding.encodeToString(p.value))
    .childString(suffix);

/// A KeyBook backed by a persistent [Datastore]. Equivalent to
/// go-libp2p's `pstoreds.dsKeyBook`.
class DsKeyBook implements KeyBook {
  DsKeyBook._(this._store);

  final Datastore _store;
  final Map<String, PubKey> _pubKeys = {};
  final Map<String, PrivKey> _privKeys = {};

  Future<void> _writeQueue = Future<void>.value();
  Object? _writeFailure;
  StackTrace? _writeFailureStack;

  void _enqueue(Future<void> Function() op) {
    _writeQueue = _writeQueue.then((_) async {
      try {
        await op();
      } catch (error, stack) {
        // Continue draining, but never report a failed mutation as durable.
        if (_writeFailure == null) {
          _writeFailure = error;
          _writeFailureStack = stack;
        }
      }
    });
  }

  /// Waits for every queued persistence write to reach the underlying
  /// [Datastore]. Call before assuming a mutation is durable (e.g. from
  /// [Pstoreds.close]).
  Future<void> flush() async {
    await _writeQueue;
    final failure = _writeFailure;
    if (failure != null) {
      Error.throwWithStackTrace(failure, _writeFailureStack!);
    }
  }

  /// Loads every key persisted under [_kbBase] from [store]. Equivalent to
  /// go-libp2p's `pstoreds.NewKeyBook`, plus the eager load this port
  /// needs (see this file's doc comment).
  static Future<DsKeyBook> open(Datastore store) async {
    final kb = DsKeyBook._(store);
    final results = await store.query(Query(prefix: _kbBase.value));
    for (final entry in results.rest()) {
      var value = entry.value;
      if (value == null) continue;
      final key = Key(entry.key);
      final suffix = key.name;
      final peerSegment = key.parent.name;
      late final PeerId peerId;
      try {
        peerId = PeerId.fromBytes(
          base32.rawStdEncoding.decodeString(peerSegment),
        );
      } catch (_) {
        // Repair records written by the earlier Dart Base58 implementation.
        final PeerId legacyPeer;
        try {
          legacyPeer = PeerId.decode(peerSegment);
        } catch (_) {
          continue;
        }
        peerId = legacyPeer;
        final canonical = _peerToKey(peerId, suffix);
        if (await store.has(canonical)) {
          value = await store.get(canonical);
        } else {
          await store.put(canonical, value);
        }
        await store.delete(key);
      }
      try {
        final bytes = Uint8List.fromList(value);
        if (suffix == 'pub') {
          kb._pubKeys[peerId.toBase58()] = unmarshalPublicKey(bytes);
        } else if (suffix == 'priv') {
          kb._privKeys[peerId.toBase58()] = await unmarshalPrivateKey(bytes);
        }
      } catch (_) {
        // Skip malformed/foreign entries under this prefix.
      }
    }
    return kb;
  }

  /// Equivalent to go-libp2p's `dsKeyBook.PubKey`.
  @override
  PubKey? pubKey(PeerId p) {
    final pKey = p.toBase58();
    final cached = _pubKeys[pKey];
    if (cached != null) return cached;
    try {
      final extracted = p.extractPublicKey();
      _pubKeys[pKey] = extracted;
      _enqueue(
        () => _store.put(_peerToKey(p, 'pub'), marshalPublicKey(extracted)),
      );
      return extracted;
    } catch (_) {
      return null;
    }
  }

  /// Equivalent to go-libp2p's `dsKeyBook.AddPubKey`.
  @override
  void addPubKey(PeerId p, PubKey pk) {
    if (!p.matchesPublicKey(pk)) {
      throw ArgumentError('ID does not match PublicKey');
    }
    _pubKeys[p.toBase58()] = pk;
    _enqueue(() => _store.put(_peerToKey(p, 'pub'), marshalPublicKey(pk)));
  }

  /// Equivalent to go-libp2p's `dsKeyBook.PrivKey`.
  @override
  PrivKey? privKey(PeerId p) => _privKeys[p.toBase58()];

  /// Equivalent to go-libp2p's `dsKeyBook.AddPrivKey`.
  @override
  void addPrivKey(PeerId p, PrivKey sk) {
    if (!p.matchesPrivateKey(sk)) {
      throw ArgumentError('ID does not match PrivateKey');
    }
    _privKeys[p.toBase58()] = sk;
    _enqueue(
      () async => _store.put(_peerToKey(p, 'priv'), marshalPrivateKey(sk)),
    );
  }

  /// Equivalent to go-libp2p's `dsKeyBook.PeersWithKeys`.
  @override
  List<PeerId> peersWithKeys() {
    final set = <String>{..._pubKeys.keys, ..._privKeys.keys};
    return [for (final s in set) PeerId.decode(s)];
  }

  /// Equivalent to go-libp2p's `dsKeyBook.RemovePeer`.
  @override
  void removePeer(PeerId p) {
    _pubKeys.remove(p.toBase58());
    _privKeys.remove(p.toBase58());
    _enqueue(() async {
      await _store.delete(_peerToKey(p, 'priv'));
      await _store.delete(_peerToKey(p, 'pub'));
    });
  }
}
