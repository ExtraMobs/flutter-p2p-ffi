// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/p2p/host/peerstore/pstoreds/metadata.dart
//
// Port of go-libp2p's pstoreds/metadata.go: a PeerMetadata backed by a
// Datastore, one entry per (peer, key). Go serializes values with `gob`,
// which relies on Go reflection/type-registration this port has no
// equivalent for; values here are serialized with `dart:convert`'s
// jsonEncode/jsonDecode instead (stdlib, same "arbitrary small values"
// use case metadata is actually used for -- protocol version strings,
// protocol-ID sets, agent versions). A value that isn't JSON-encodable
// throws from [DsPeerMetadata.put], same as an unregistered gob type
// would fail Go's encoder.
//
// See pstoreds.dart's doc comment for why this, like the other books
// here, loads eagerly and mutates a synchronous in-memory cache rather
// than Go's direct per-call `ds.Get`/`ds.Put`.
import 'dart:convert';
import 'dart:typed_data';

import 'package:transpiled_base32/transpiled_base32.dart' as base32;
import 'package:transpiled_datastore/transpiled_datastore.dart';

import '../../../../core/peer/peer_id.dart';
import '../../../../core/peerstore/peerstore.dart';

final Key _pmBase = Key('/peers/metadata');

Key _metadataKey(PeerId p, String key) =>
    _pmBase.childString(base32.rawStdEncoding.encodeToString(p.value)).childString(key);

/// A [PeerMetadata] backed by a persistent [Datastore]. Equivalent to
/// go-libp2p's `pstoreds.dsPeerMetadata`.
class DsPeerMetadata implements PeerMetadata {
  DsPeerMetadata._(this._store);

  final Datastore _store;
  final Map<String, Map<String, Object?>> _metadata = {};

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
  /// [Datastore].
  Future<void> flush() async {
    await _writeQueue;
    final failure = _writeFailure;
    if (failure != null) {
      Error.throwWithStackTrace(failure, _writeFailureStack!);
    }
  }

  /// Loads every metadata entry persisted under [_pmBase] from [store].
  /// Equivalent to go-libp2p's `pstoreds.NewPeerMetadata`, plus the eager
  /// load this port needs (see this file's doc comment).
  static Future<DsPeerMetadata> open(Datastore store) async {
    final pm = DsPeerMetadata._(store);
    final results = await store.query(Query(prefix: _pmBase.value));
    for (final entry in results.rest()) {
      var value = entry.value;
      if (value == null) continue;
      final key = Key(entry.key);
      final metaKey = key.name;
      final peerSegment = key.parent.name;
      late final PeerId peerId;
      try {
        peerId = PeerId.fromBytes(base32.rawStdEncoding.decodeString(peerSegment));
      } catch (_) {
        // Repair records written by the earlier Dart Base58 implementation.
        final PeerId legacyPeer;
        try {
          legacyPeer = PeerId.decode(peerSegment);
        } catch (_) {
          continue;
        }
        peerId = legacyPeer;
        final canonical = _metadataKey(peerId, metaKey);
        if (await store.has(canonical)) {
          value = await store.get(canonical);
        } else {
          await store.put(canonical, value);
        }
        await store.delete(key);
      }
      try {
        final decoded = json.decode(utf8.decode(value));
        pm._metadata.putIfAbsent(peerId.toBase58(), () => {})[metaKey] = decoded;
      } catch (_) {
        // Skip malformed/foreign entries under this prefix.
      }
    }
    return pm;
  }

  /// Equivalent to go-libp2p's `dsPeerMetadata.Get`.
  @override
  Object? get(PeerId p, String key) {
    final m = _metadata[p.toBase58()];
    if (m == null || !m.containsKey(key)) {
      throw const ItemNotFoundException();
    }
    return m[key];
  }

  /// Equivalent to go-libp2p's `dsPeerMetadata.Put`.
  @override
  void put(PeerId p, String key, Object? val) {
    final encoded = Uint8List.fromList(utf8.encode(json.encode(val)));
    final m = _metadata.putIfAbsent(p.toBase58(), () => {});
    m[key] = val;
    _enqueue(() => _store.put(_metadataKey(p, key), encoded));
  }

  /// Equivalent to go-libp2p's `dsPeerMetadata.RemovePeer`.
  @override
  void removePeer(PeerId p) {
    final pKey = p.toBase58();
    final m = _metadata.remove(pKey);
    if (m == null || m.isEmpty) return;
    final keys = m.keys.toList();
    _enqueue(() async {
      for (final key in keys) {
        await _store.delete(_metadataKey(p, key));
      }
    });
  }
}
