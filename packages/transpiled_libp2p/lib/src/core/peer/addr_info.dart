// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/core/peer/addr_info.dart
//
// Port of go-libp2p's core/peer/addrinfo.go and addrinfo_serde.go: a small
// struct pairing a peer ID with a set of addresses, plus the multiaddr
// splitting helpers used to build one from a `/.../p2p/Qm...` address.
import 'dart:convert';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import 'peer_id.dart';

/// A peer paired with a set of addresses (and later, keys?). Equivalent to
/// go-libp2p core/peer's `AddrInfo`.
class AddrInfo {
  /// Builds an [AddrInfo] from [id] and [addrs] (empty by default).
  const AddrInfo({required this.id, this.addrs = const []});

  /// Restores an [AddrInfo] from [toJson]'s output, matching go-libp2p's
  /// `AddrInfo.UnmarshalJSON`.
  factory AddrInfo.fromJson(Map<String, Object?> json) {
    final addrs = (json['Addrs'] as List? ?? const [])
        .map((a) => Multiaddr.parse(a as String))
        .toList();
    return AddrInfo(id: PeerId.decode(json['ID'] as String), addrs: addrs);
  }

  /// Parses [toJson]'s JSON-encoded string form.
  factory AddrInfo.fromJsonString(String s) =>
      AddrInfo.fromJson(jsonDecode(s) as Map<String, Object?>);

  /// The peer this info describes.
  final PeerId id;

  /// The peer's known addresses (not including a trailing `/p2p/...`
  /// component -- see [addrInfoToP2pAddrs] to add one back).
  final List<Multiaddr> addrs;

  @override
  String toString() => '{$id: $addrs}';

  /// A loggable representation, matching go-libp2p's `AddrInfo.Loggable`.
  Map<String, Object?> loggable() => {
    'peerID': id.toString(),
    'addrs': addrs.map((a) => a.toString()).toList(),
  };

  /// JSON-encodable form, matching go-libp2p's `AddrInfo.MarshalJSON`
  /// (field names `ID`/`Addrs`, addresses as their string form).
  Map<String, Object?> toJson() => {
    'ID': id.toBase58(),
    'Addrs': addrs.map((a) => a.toAddrString()).toList(),
  };

  /// Encodes this [AddrInfo] as a JSON string.
  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is AddrInfo && id == other.id && _addrsEqual(addrs, other.addrs);

  @override
  int get hashCode => Object.hash(id, Object.hashAll(addrs));
}

bool _addrsEqual(List<Multiaddr> a, List<Multiaddr> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Splits a p2p [Multiaddr] into a transport multiaddr and a peer ID.
///
/// * The returned transport is `null` if [m] only contains a `/p2p/...`
///   part.
/// * The returned [PeerId] is `null` if [m] doesn't contain a `/p2p/...`
///   part.
///
/// Equivalent to go-libp2p's `SplitAddr`.
(Multiaddr? transport, PeerId? id) splitAddr(Multiaddr? m) {
  if (m == null) return (null, null);

  final (prefix, last) = m.splitLast();
  if (last == null || last.protocol.code != Protocols.p2p) {
    return (m, null);
  }
  // Already validated by the multiaddr library's p2p transcoder.
  return (prefix, PeerId(value: last.valueBytes));
}

/// Extracts the peer ID from a p2p [Multiaddr]'s trailing `/p2p/...`
/// component. Throws [InvalidPeerIdSourceException] if there isn't one.
/// Equivalent to go-libp2p's `IDFromP2PAddr`.
PeerId idFromP2pAddr(Multiaddr? m) {
  if (m == null || m.components.isEmpty) {
    throw const InvalidPeerIdSourceException();
  }
  final last = m.components.last;
  if (last.protocol.code != Protocols.p2p) {
    throw const InvalidPeerIdSourceException();
  }
  return PeerId(value: last.valueBytes);
}

/// Builds an [AddrInfo] from the string representation of a p2p multiaddr.
/// Equivalent to go-libp2p's `AddrInfoFromString`.
AddrInfo addrInfoFromString(String s) =>
    addrInfoFromP2pAddr(Multiaddr.parse(s));

/// Converts a p2p [Multiaddr] to an [AddrInfo]. Throws
/// [InvalidPeerIdSourceException] if [m] has no `/p2p/...` component.
/// Equivalent to go-libp2p's `AddrInfoFromP2pAddr`.
AddrInfo addrInfoFromP2pAddr(Multiaddr m) {
  final (transport, id) = splitAddr(m);
  if (id == null) throw const InvalidPeerIdSourceException();
  return AddrInfo(id: id, addrs: transport == null ? const [] : [transport]);
}

/// Converts an [AddrInfo] to one `/.../p2p/Qm...` multiaddr per address (or
/// a single bare `/p2p/Qm...` if [info] has no addresses). Equivalent to
/// go-libp2p's `AddrInfoToP2pAddrs`.
List<Multiaddr> addrInfoToP2pAddrs(AddrInfo info) {
  final p2pComponent = Component(Protocols.byName('p2p')!, info.id.toBase58());
  if (info.addrs.isEmpty) {
    return [Multiaddr([p2pComponent])];
  }
  return [
    for (final addr in info.addrs) addr.encapsulate(Multiaddr([p2pComponent])),
  ];
}

/// Groups a set of `/.../p2p/Qm...` multiaddrs by peer ID into one
/// [AddrInfo] per peer, preserving the order addresses were first seen for
/// each peer. Throws [InvalidPeerIdSourceException] if any address has no
/// `/p2p/...` component. Equivalent to go-libp2p's `AddrInfosFromP2pAddrs`.
List<AddrInfo> addrInfosFromP2pAddrs(List<Multiaddr> maddrs) {
  final byId = <PeerId, List<Multiaddr>>{};
  for (final maddr in maddrs) {
    final (transport, id) = splitAddr(maddr);
    if (id == null) throw const InvalidPeerIdSourceException();
    final addrs = byId.putIfAbsent(id, () => []);
    if (transport != null) addrs.add(transport);
  }
  return [for (final entry in byId.entries) AddrInfo(id: entry.key, addrs: entry.value)];
}

/// Extracts the peer IDs from [infos], in order. Equivalent to go-libp2p's
/// `AddrInfosToIDs`.
List<PeerId> addrInfosToIds(List<AddrInfo> infos) => [
  for (final info in infos) info.id,
];
