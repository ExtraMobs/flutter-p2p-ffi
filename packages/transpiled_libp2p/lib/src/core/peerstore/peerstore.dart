// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../crypto/key_types.dart';
import '../peer/addr_info.dart';
import '../peer/peer_id.dart';
import '../protocol/protocol.dart';
import '../record/envelope.dart';

/// Thrown when an item is not found in the peerstore.
class ItemNotFoundException implements Exception {
  const ItemNotFoundException([this.message = 'item not found']);
  final String message;

  @override
  String toString() => message;
}

/// Address expiration time.
const Duration addressTtl = Duration(hours: 1);

/// Short-lived address expiration time.
const Duration tempAddrTtl = Duration(minutes: 2);

/// Expiration time after a recent connection.
const Duration recentlyConnectedAddrTtl = Duration(minutes: 15);

/// Expiration time for externally observed addresses.
const Duration ownObservedAddrTtl = Duration(minutes: 30);

/// Permanent TTLs are distinct, as in go-libp2p (`math.MaxInt64 - iota`).
const Duration permanentAddrTtl = Duration(microseconds: 9223372036854775);
const Duration connectedAddrTtl = Duration(microseconds: 9223372036854774);

/// Returns true if [ttl] indicates a connection-held address.
bool ttlIsConnected(Duration ttl) => ttl >= connectedAddrTtl;

/// AddrBook holds the multiaddrs of peers.
abstract interface class AddrBook {
  void addAddr(PeerId p, Multiaddr addr, Duration ttl);
  void addAddrs(PeerId p, List<Multiaddr> addrs, Duration ttl);
  void setAddr(PeerId p, Multiaddr addr, Duration ttl);
  void setAddrs(PeerId p, List<Multiaddr> addrs, Duration ttl);
  void updateAddrs(PeerId p, Duration oldTtl, Duration newTtl);
  List<Multiaddr> addrs(PeerId p);
  Stream<Multiaddr> addrStream(PeerId p);
  void clearAddrs(PeerId p);
  List<PeerId> peersWithAddrs();
}

/// CertifiedAddrBook manages signed peer records and certified addresses.
abstract interface class CertifiedAddrBook {
  bool consumePeerRecord(Envelope s, Duration ttl);
  Envelope? getPeerRecord(PeerId p);
}

/// Helper to upcast an [AddrBook] to a [CertifiedAddrBook].
CertifiedAddrBook? getCertifiedAddrBook(AddrBook ab) {
  if (ab is CertifiedAddrBook) {
    return ab as CertifiedAddrBook;
  }
  return null;
}

/// KeyBook tracks the keys of Peers.
abstract interface class KeyBook {
  PubKey? pubKey(PeerId p);
  void addPubKey(PeerId p, PubKey pk);
  PrivKey? privKey(PeerId p);
  void addPrivKey(PeerId p, PrivKey sk);
  List<PeerId> peersWithKeys();
  void removePeer(PeerId p);
}

/// Metrics tracks metrics across a set of peers.
abstract interface class Metrics {
  void recordLatency(PeerId p, Duration d);
  Duration latencyEwma(PeerId p);
  void removePeer(PeerId p);
}

/// ProtoBook tracks the protocols supported by peers.
abstract interface class ProtoBook {
  List<ProtocolId> getProtocols(PeerId p);
  void addProtocols(PeerId p, List<ProtocolId> protos);
  void setProtocols(PeerId p, List<ProtocolId> protos);
  void removeProtocols(PeerId p, List<ProtocolId> protos);
  List<ProtocolId> supportsProtocols(PeerId p, List<ProtocolId> protos);
  ProtocolId? firstSupportedProtocol(PeerId p, List<ProtocolId> protos);
  void removePeer(PeerId p);
}

/// PeerMetadata stores arbitrary key-value pairs for peers.
abstract interface class PeerMetadata {
  Object? get(PeerId p, String key);
  void put(PeerId p, String key, Object? val);
  void removePeer(PeerId p);
}

/// Peerstore provides a store of peer-related information.
abstract interface class Peerstore implements AddrBook, KeyBook, PeerMetadata, Metrics, ProtoBook {
  AddrInfo peerInfo(PeerId p);
  List<PeerId> peers();
  @override
  void removePeer(PeerId p);
  Future<void> close();
}

/// Returns an [AddrInfo] for each specified peer ID, in-order.
List<AddrInfo> addrInfos(Peerstore ps, List<PeerId> peers) {
  return [for (final p in peers) ps.peerInfo(p)];
}
