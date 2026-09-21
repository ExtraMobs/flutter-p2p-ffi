// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/p2p/host/peerstore/pstoreds/peerstore.dart
//
// Port of go-libp2p's pstoreds/peerstore.go: `Pstoreds`, a [Peerstore]
// backed by a persistent [Datastore] -- addresses, keys, protocols and
// metadata all survive a process restart, as long as the same [Datastore]
// is reopened. Go's `pstoreds` struct embeds its four books
// (`*dsKeyBook`, `*dsAddrBook`, `*dsProtoBook`, `*dsPeerMetadata`) and
// `peerstore.Metrics` to get their methods for free; Dart has no struct
// embedding, so [Pstoreds] holds each book and delegates to it instead.
//
// The central adaptation this whole package makes, relative to the Go
// original: go-libp2p's `core/peerstore` interfaces are synchronous
// because Go's `ds.Datastore` is itself a synchronous/blocking interface
// (`Get`/`Put` do disk I/O directly, no goroutines). This transpilation's
// [Datastore] (transpiled_datastore) is Future-based instead. A
// synchronous [Peerstore] can't be built as a lazy, bounded read-through
// cache over a Future-based store the way Go's ARC-cached `dsAddrBook`
// is -- so instead, [Pstoreds.open] (and each book's own `open`) loads
// every persisted record into memory once, up front, and every
// [Peerstore] method thereafter is synchronous against that in-memory
// state. Mutations still persist: each book queues its datastore writes
// and replays them in order, and [close] awaits every queue before
// returning -- so "close the peerstore, then re-`open` the same
// [Datastore]" is a faithful restart for testing purposes.
//
// `Metrics` isn't a separate file here because it isn't one in the
// existing Dart port either: `pstoremem`'s `MemoryPeerstore` implements
// `recordLatency`/`latencyEwma`/`removePeer` inline rather than importing
// a shared `p2p/host/peerstore/metrics.go` port (which doesn't exist in
// this codebase yet, and is outside this package's scope). [Pstoreds]
// does the same, with the same EWMA smoothing factor (0.1).
import 'package:transpiled_datastore/transpiled_datastore.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../../core/crypto/key_types.dart' hide Key;
import '../../../../core/peer/addr_info.dart';
import '../../../../core/peer/peer_id.dart';
import '../../../../core/peerstore/peerstore.dart';
import '../../../../core/protocol/protocol.dart';
import '../../../../core/record/envelope.dart';
import 'addr_book.dart';
import 'keybook.dart';
import 'metadata.dart';
import 'options.dart';
import 'protobook.dart';

export 'addr_book.dart' show AddrsRecord, DsAddrBook, TtlWriteMode, cleanAddrs;
export 'keybook.dart' show DsKeyBook;
export 'metadata.dart' show DsPeerMetadata;
export 'options.dart' show Clock, Options, RealClock, defaultOpts;
export 'pb/pstore_message.dart'
    show AddrBookRecord, AddrBookRecord_AddrEntry, CertifiedRecord;
export 'protobook.dart' show DsProtoBook;

const double _latencyEwmaSmoothing = 0.1;

/// A [Peerstore] and [CertifiedAddrBook] backed by a persistent
/// [Datastore]. Equivalent to go-libp2p's `pstoreds.pstoreds`.
class Pstoreds implements Peerstore, CertifiedAddrBook {
  Pstoreds._(
    this._keyBook,
    this._addrBook,
    this._protoBook,
    this._peerMetadata,
  );

  final DsKeyBook _keyBook;
  final DsAddrBook _addrBook;
  final DsProtoBook _protoBook;
  final DsPeerMetadata _peerMetadata;

  final Map<String, Duration> _latencies = {};

  /// Opens a peerstore backed by [store], loading every previously
  /// persisted peer. Equivalent to go-libp2p's `pstoreds.NewPeerstore`,
  /// plus the eager load this port needs (see this file's doc comment).
  ///
  /// It's the caller's responsibility to call [removePeer] to ensure that
  /// memory consumption of the peerstore doesn't grow unboundedly.
  static Future<Pstoreds> open(Batching store, {Options? opts}) async {
    final options = opts ?? defaultOpts();
    final addrBook = await DsAddrBook.open(store, options);
    final keyBook = await DsKeyBook.open(store);
    final peerMetadata = await DsPeerMetadata.open(store);
    final protoBook = DsProtoBook(
      peerMetadata,
      maxProtocols: options.maxProtocols,
    );
    return Pstoreds._(keyBook, addrBook, protoBook, peerMetadata);
  }

  // --- AddrBook (delegates to _addrBook) ---

  @override
  void addAddr(PeerId p, Multiaddr addr, Duration ttl) =>
      _addrBook.addAddr(p, addr, ttl);

  @override
  void addAddrs(PeerId p, List<Multiaddr> addrs, Duration ttl) =>
      _addrBook.addAddrs(p, addrs, ttl);

  @override
  void setAddr(PeerId p, Multiaddr addr, Duration ttl) =>
      _addrBook.setAddr(p, addr, ttl);

  @override
  void setAddrs(PeerId p, List<Multiaddr> addrs, Duration ttl) =>
      _addrBook.setAddrs(p, addrs, ttl);

  @override
  void updateAddrs(PeerId p, Duration oldTtl, Duration newTtl) =>
      _addrBook.updateAddrs(p, oldTtl, newTtl);

  @override
  List<Multiaddr> addrs(PeerId p) => _addrBook.addrs(p);

  @override
  Stream<Multiaddr> addrStream(PeerId p) => _addrBook.addrStream(p);

  @override
  void clearAddrs(PeerId p) => _addrBook.clearAddrs(p);

  @override
  List<PeerId> peersWithAddrs() => _addrBook.peersWithAddrs();

  // --- CertifiedAddrBook (delegates to _addrBook) ---

  @override
  bool consumePeerRecord(Envelope s, Duration ttl) =>
      _addrBook.consumePeerRecord(s, ttl);

  @override
  Envelope? getPeerRecord(PeerId p) => _addrBook.getPeerRecord(p);

  // --- KeyBook (delegates to _keyBook) ---

  @override
  PubKey? pubKey(PeerId p) => _keyBook.pubKey(p);

  @override
  void addPubKey(PeerId p, PubKey pk) => _keyBook.addPubKey(p, pk);

  @override
  PrivKey? privKey(PeerId p) => _keyBook.privKey(p);

  @override
  void addPrivKey(PeerId p, PrivKey sk) => _keyBook.addPrivKey(p, sk);

  @override
  List<PeerId> peersWithKeys() => _keyBook.peersWithKeys();

  // --- ProtoBook (delegates to _protoBook) ---

  @override
  List<ProtocolId> getProtocols(PeerId p) => _protoBook.getProtocols(p);

  @override
  void addProtocols(PeerId p, List<ProtocolId> protos) =>
      _protoBook.addProtocols(p, protos);

  @override
  void setProtocols(PeerId p, List<ProtocolId> protos) =>
      _protoBook.setProtocols(p, protos);

  @override
  void removeProtocols(PeerId p, List<ProtocolId> protos) =>
      _protoBook.removeProtocols(p, protos);

  @override
  List<ProtocolId> supportsProtocols(PeerId p, List<ProtocolId> protos) =>
      _protoBook.supportsProtocols(p, protos);

  @override
  ProtocolId? firstSupportedProtocol(PeerId p, List<ProtocolId> protos) =>
      _protoBook.firstSupportedProtocol(p, protos);

  // --- PeerMetadata (delegates to _peerMetadata) ---

  @override
  Object? get(PeerId p, String key) => _peerMetadata.get(p, key);

  @override
  void put(PeerId p, String key, Object? val) => _peerMetadata.put(p, key, val);

  // --- Metrics (inline; see this file's doc comment) ---

  /// Equivalent to go-libp2p's `metrics.RecordLatency`.
  @override
  void recordLatency(PeerId p, Duration d) {
    final pKey = p.toBase58();
    final existing = _latencies[pKey];
    if (existing == null) {
      _latencies[pKey] = d;
      return;
    }
    final newMicros =
        ((1.0 - _latencyEwmaSmoothing) * existing.inMicroseconds) +
        (_latencyEwmaSmoothing * d.inMicroseconds);
    _latencies[pKey] = Duration(microseconds: newMicros.round());
  }

  /// Equivalent to go-libp2p's `metrics.LatencyEWMA`.
  @override
  Duration latencyEwma(PeerId p) => _latencies[p.toBase58()] ?? Duration.zero;

  // --- Peerstore ---

  /// Equivalent to go-libp2p's `pstoreds.RemovePeer`: removes [p] from
  /// the KeyBook, ProtoBook, PeerMetadata and Metrics. Does NOT remove it
  /// from the AddrBook.
  @override
  void removePeer(PeerId p) {
    _keyBook.removePeer(p);
    _protoBook.removePeer(p);
    _peerMetadata.removePeer(p);
    _latencies.remove(p.toBase58());
  }

  /// Equivalent to go-libp2p's `pstoreds.PeerInfo`.
  @override
  AddrInfo peerInfo(PeerId p) => AddrInfo(id: p, addrs: _addrBook.addrs(p));

  /// Equivalent to go-libp2p's `pstoreds.Peers`.
  @override
  List<PeerId> peers() {
    final set = <String>{};
    for (final p in peersWithKeys()) {
      set.add(p.toBase58());
    }
    for (final p in peersWithAddrs()) {
      set.add(p.toBase58());
    }
    return [for (final s in set) PeerId.decode(s)];
  }

  /// Equivalent to go-libp2p's `pstoreds.Close`: waits for every queued
  /// persistence write across all four books to reach the underlying
  /// [Datastore].
  @override
  Future<void> close() =>
      Future.wait([_keyBook.flush(), _addrBook.flush(), _peerMetadata.flush()]);
}
