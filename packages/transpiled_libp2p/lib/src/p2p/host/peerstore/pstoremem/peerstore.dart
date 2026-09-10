// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../../core/crypto/key_types.dart';
import '../../../../core/peer/addr_info.dart';
import '../../../../core/peer/peer_id.dart';
import '../../../../core/peerstore/peerstore.dart';
import '../../../../core/protocol/protocol.dart';
import '../../../../core/record/envelope.dart';

class _ExpiringAddr {
  _ExpiringAddr({
    required this.addr,
    required this.ttl,
    required this.expiry,
  });

  final Multiaddr addr;
  Duration ttl;
  DateTime expiry;

  bool isExpired(DateTime now) {
    if (ttl >= connectedAddrTtl) return false;
    return now.isAfter(expiry);
  }
}

/// In-memory implementation of [Peerstore] and [CertifiedAddrBook].
class MemoryPeerstore implements Peerstore, CertifiedAddrBook {
  MemoryPeerstore({this.maxProtocols = 128, this.latencyEwmaSmoothing = 0.1});

  final int maxProtocols;
  final double latencyEwmaSmoothing;

  final Map<String, Map<String, _ExpiringAddr>> _addrBook = {};
  final Map<String, Envelope> _peerRecords = {};
  final Map<String, List<StreamController<Multiaddr>>> _addrStreams = {};

  final Map<String, PubKey> _pubKeys = {};
  final Map<String, PrivKey> _privKeys = {};

  final Map<String, Map<String, Object?>> _metadata = {};
  final Map<String, Set<ProtocolId>> _protocols = {};
  final Map<String, Duration> _latencies = {};

  bool _closed = false;

  void _checkClosed() {
    if (_closed) throw StateError('Peerstore is closed');
  }

  // --- AddrBook ---

  @override
  void addAddr(PeerId p, Multiaddr addr, Duration ttl) {
    addAddrs(p, [addr], ttl);
  }

  @override
  void addAddrs(PeerId p, List<Multiaddr> addrs, Duration ttl) {
    _checkClosed();
    if (ttl <= Duration.zero || addrs.isEmpty) return;
    final pKey = p.toBase58();
    final peerAddrs = _addrBook.putIfAbsent(pKey, () => <String, _ExpiringAddr>{});
    final now = DateTime.now();

    for (final addr in addrs) {
      final aKey = addr.toAddrString();
      final existing = peerAddrs[aKey];
      if (existing == null) {
        peerAddrs[aKey] = _ExpiringAddr(addr: addr, ttl: ttl, expiry: now.add(ttl));
        final streams = _addrStreams[pKey];
        if (streams != null) {
          for (final s in streams) {
            if (!s.isClosed) s.add(addr);
          }
        }
      } else {
        if (ttl > existing.ttl) {
          existing.ttl = ttl;
          existing.expiry = now.add(ttl);
        }
      }
    }
  }

  @override
  void setAddr(PeerId p, Multiaddr addr, Duration ttl) {
    setAddrs(p, [addr], ttl);
  }

  @override
  void setAddrs(PeerId p, List<Multiaddr> addrs, Duration ttl) {
    _checkClosed();
    final pKey = p.toBase58();
    if (ttl <= Duration.zero) {
      clearAddrs(p);
      return;
    }
    final peerAddrs = _addrBook.putIfAbsent(pKey, () => <String, _ExpiringAddr>{});
    final now = DateTime.now();

    for (final addr in addrs) {
      final aKey = addr.toAddrString();
      final existing = peerAddrs[aKey];
      if (existing == null) {
        peerAddrs[aKey] = _ExpiringAddr(addr: addr, ttl: ttl, expiry: now.add(ttl));
        final streams = _addrStreams[pKey];
        if (streams != null) {
          for (final s in streams) {
            if (!s.isClosed) s.add(addr);
          }
        }
      } else {
        existing.ttl = ttl;
        existing.expiry = now.add(ttl);
      }
    }
  }

  @override
  void updateAddrs(PeerId p, Duration oldTtl, Duration newTtl) {
    _checkClosed();
    final pKey = p.toBase58();
    final peerAddrs = _addrBook[pKey];
    if (peerAddrs == null) return;
    final now = DateTime.now();

    for (final entry in peerAddrs.values.toList()) {
      if (entry.ttl == oldTtl) {
        entry.ttl = newTtl;
        entry.expiry = now.add(newTtl);
      }
    }
  }

  @override
  List<Multiaddr> addrs(PeerId p) {
    _checkClosed();
    final pKey = p.toBase58();
    final peerAddrs = _addrBook[pKey];
    if (peerAddrs == null) return const [];

    final now = DateTime.now();
    final result = <Multiaddr>[];
    final expired = <String>[];

    for (final MapEntry(:key, :value) in peerAddrs.entries) {
      if (value.isExpired(now)) {
        expired.add(key);
      } else {
        result.add(value.addr);
      }
    }

    for (final k in expired) {
      peerAddrs.remove(k);
    }
    if (peerAddrs.isEmpty) {
      _addrBook.remove(pKey);
    }

    return result;
  }

  @override
  Stream<Multiaddr> addrStream(PeerId p) async* {
    _checkClosed();
    final pKey = p.toBase58();
    final existing = addrs(p);
    for (final a in existing) {
      yield a;
    }
    final controller = StreamController<Multiaddr>();
    final list = _addrStreams.putIfAbsent(pKey, () => []);
    list.add(controller);
    try {
      yield* controller.stream;
    } finally {
      list.remove(controller);
      await controller.close();
    }
  }

  @override
  void clearAddrs(PeerId p) {
    _checkClosed();
    final pKey = p.toBase58();
    _addrBook.remove(pKey);
    _peerRecords.remove(pKey);
  }

  @override
  List<PeerId> peersWithAddrs() {
    _checkClosed();
    final ids = <PeerId>[];
    for (final pKey in _addrBook.keys.toList()) {
      final p = PeerId.decode(pKey);
      if (addrs(p).isNotEmpty) {
        ids.add(p);
      }
    }
    return ids;
  }

  // --- CertifiedAddrBook ---

  @override
  bool consumePeerRecord(Envelope s, Duration ttl) {
    _checkClosed();
    final p = PeerId.fromPubKey(s.publicKey);
    final pKey = p.toBase58();
    final existing = _peerRecords[pKey];
    if (existing != null && s.rawPayload.length < existing.rawPayload.length) {
      // Seq comparison heuristic if both are peer records
      return false;
    }
    _peerRecords[pKey] = s;
    return true;
  }

  @override
  Envelope? getPeerRecord(PeerId p) {
    _checkClosed();
    return _peerRecords[p.toBase58()];
  }

  // --- KeyBook ---

  @override
  PubKey? pubKey(PeerId p) {
    _checkClosed();
    final pKey = p.toBase58();
    final pk = _pubKeys[pKey];
    if (pk != null) return pk;
    try {
      final extracted = p.extractPublicKey();
      _pubKeys[pKey] = extracted;
      return extracted;
    } catch (_) {
      return null;
    }
  }

  @override
  void addPubKey(PeerId p, PubKey pk) {
    _checkClosed();
    if (!p.matchesPublicKey(pk)) {
      throw ArgumentError('ID does not match PublicKey');
    }
    _pubKeys[p.toBase58()] = pk;
  }

  @override
  PrivKey? privKey(PeerId p) {
    _checkClosed();
    return _privKeys[p.toBase58()];
  }

  @override
  void addPrivKey(PeerId p, PrivKey sk) {
    _checkClosed();
    if (!p.matchesPrivateKey(sk)) {
      throw ArgumentError('ID does not match PrivateKey');
    }
    _privKeys[p.toBase58()] = sk;
  }

  @override
  List<PeerId> peersWithKeys() {
    _checkClosed();
    final set = <String>{..._pubKeys.keys, ..._privKeys.keys};
    return [for (final s in set) PeerId.decode(s)];
  }

  // --- Metrics ---

  @override
  void recordLatency(PeerId p, Duration d) {
    _checkClosed();
    final pKey = p.toBase58();
    final existing = _latencies[pKey];
    if (existing == null) {
      _latencies[pKey] = d;
    } else {
      final s = (latencyEwmaSmoothing > 1 || latencyEwmaSmoothing < 0) ? 0.1 : latencyEwmaSmoothing;
      final newMicros = ((1.0 - s) * existing.inMicroseconds) + (s * d.inMicroseconds);
      _latencies[pKey] = Duration(microseconds: newMicros.round());
    }
  }

  @override
  Duration latencyEwma(PeerId p) {
    _checkClosed();
    return _latencies[p.toBase58()] ?? Duration.zero;
  }

  // --- ProtoBook ---

  @override
  List<ProtocolId> getProtocols(PeerId p) {
    _checkClosed();
    final set = _protocols[p.toBase58()];
    return set == null ? const [] : set.toList();
  }

  @override
  void addProtocols(PeerId p, List<ProtocolId> protos) {
    _checkClosed();
    final set = _protocols.putIfAbsent(p.toBase58(), () => <ProtocolId>{});
    if (set.length + protos.length > maxProtocols) {
      throw StateError('too many protocols');
    }
    set.addAll(protos);
  }

  @override
  void setProtocols(PeerId p, List<ProtocolId> protos) {
    _checkClosed();
    if (protos.length > maxProtocols) {
      throw StateError('too many protocols');
    }
    final set = _protocols.putIfAbsent(p.toBase58(), () => <ProtocolId>{});
    set.clear();
    set.addAll(protos);
  }

  @override
  void removeProtocols(PeerId p, List<ProtocolId> protos) {
    _checkClosed();
    final set = _protocols[p.toBase58()];
    if (set != null) {
      set.removeAll(protos);
    }
  }

  @override
  List<ProtocolId> supportsProtocols(PeerId p, List<ProtocolId> protos) {
    _checkClosed();
    final set = _protocols[p.toBase58()];
    if (set == null) return const [];
    return [for (final pr in protos) if (set.contains(pr)) pr];
  }

  @override
  ProtocolId? firstSupportedProtocol(PeerId p, List<ProtocolId> protos) {
    _checkClosed();
    final set = _protocols[p.toBase58()];
    if (set == null) return null;
    for (final pr in protos) {
      if (set.contains(pr)) return pr;
    }
    return null;
  }

  // --- PeerMetadata ---

  @override
  Object? get(PeerId p, String key) {
    _checkClosed();
    final m = _metadata[p.toBase58()];
    if (m == null || !m.containsKey(key)) {
      throw const ItemNotFoundException();
    }
    return m[key];
  }

  @override
  void put(PeerId p, String key, Object? val) {
    _checkClosed();
    final m = _metadata.putIfAbsent(p.toBase58(), () => <String, Object?>{});
    m[key] = val;
  }

  // --- Peerstore ---

  @override
  AddrInfo peerInfo(PeerId p) {
    _checkClosed();
    return AddrInfo(id: p, addrs: addrs(p));
  }

  @override
  List<PeerId> peers() {
    _checkClosed();
    final set = <String>{
      ..._addrBook.keys,
      ..._pubKeys.keys,
      ..._privKeys.keys,
      ..._protocols.keys,
      ..._metadata.keys,
    };
    return [for (final s in set) PeerId.decode(s)];
  }

  @override
  void removePeer(PeerId p) {
    _checkClosed();
    final pKey = p.toBase58();
    _pubKeys.remove(pKey);
    _privKeys.remove(pKey);
    _metadata.remove(pKey);
    _protocols.remove(pKey);
    _latencies.remove(pKey);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final list in _addrStreams.values) {
      for (final stream in list) {
        await stream.close();
      }
    }
    _addrStreams.clear();
    _addrBook.clear();
    _peerRecords.clear();
    _pubKeys.clear();
    _privKeys.clear();
    _metadata.clear();
    _protocols.clear();
    _latencies.clear();
  }
}
