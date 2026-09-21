// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/p2p/host/peerstore/pstoreds/protobook.dart
//
// Port of go-libp2p's pstoreds/protobook.go: a ProtoBook that stores each
// peer's protocol set as a single entry ("protocols") in a PeerMetadata.
//
// Not ported: `protoSegments`, a 256-way lock striped by the peer ID's
// last byte. It exists purely to bound Go goroutine contention; Dart has
// no shared-memory threads to contend over (and AGENTS.md's
// RULE_NO_ARTIFICIAL_CONCURRENCY vetoes porting Go-only concurrency
// primitives into a public API anyway), so it's dropped rather than
// reimplemented as dead weight. `WithMaxProtocols`'s functional-option
// wrapper is likewise replaced by a plain named constructor parameter --
// Dart already has those; Go uses the option-function idiom because it
// doesn't.
import '../../../../core/peer/peer_id.dart';
import '../../../../core/peerstore/peerstore.dart';
import '../../../../core/protocol/protocol.dart';
import 'metadata.dart';

const String _protocolsMetadataKey = 'protocols';

/// A [ProtoBook] backed by a [DsPeerMetadata]. Equivalent to go-libp2p's
/// `pstoreds.dsProtoBook`.
class DsProtoBook implements ProtoBook {
  DsProtoBook(this._meta, {int maxProtocols = 128}) : maxProtos = maxProtocols;

  final DsPeerMetadata _meta;

  /// The maximum number of protocols stored for one peer.
  final int maxProtos;

  Set<ProtocolId> _protocolMap(PeerId p) {
    try {
      final stored = _meta.get(p, _protocolsMetadataKey);
      if (stored is List) return {for (final e in stored) e as String};
      return <ProtocolId>{};
    } on ItemNotFoundException {
      return <ProtocolId>{};
    }
  }

  /// Equivalent to go-libp2p's `dsProtoBook.SetProtocols`.
  @override
  void setProtocols(PeerId p, List<ProtocolId> protos) {
    if (protos.length > maxProtos) {
      throw StateError('too many protocols');
    }
    _meta.put(p, _protocolsMetadataKey, protos.toSet().toList());
  }

  /// Equivalent to go-libp2p's `dsProtoBook.AddProtocols`.
  @override
  void addProtocols(PeerId p, List<ProtocolId> protos) {
    final pmap = _protocolMap(p);
    if (pmap.length + protos.length > maxProtos) {
      throw StateError('too many protocols');
    }
    pmap.addAll(protos);
    _meta.put(p, _protocolsMetadataKey, pmap.toList());
  }

  /// Equivalent to go-libp2p's `dsProtoBook.GetProtocols`.
  @override
  List<ProtocolId> getProtocols(PeerId p) => _protocolMap(p).toList();

  /// Equivalent to go-libp2p's `dsProtoBook.SupportsProtocols`.
  @override
  List<ProtocolId> supportsProtocols(PeerId p, List<ProtocolId> protos) {
    final pmap = _protocolMap(p);
    return [
      for (final proto in protos)
        if (pmap.contains(proto)) proto,
    ];
  }

  /// Equivalent to go-libp2p's `dsProtoBook.FirstSupportedProtocol`.
  @override
  ProtocolId? firstSupportedProtocol(PeerId p, List<ProtocolId> protos) {
    final pmap = _protocolMap(p);
    for (final proto in protos) {
      if (pmap.contains(proto)) return proto;
    }
    return null;
  }

  /// Equivalent to go-libp2p's `dsProtoBook.RemoveProtocols`.
  @override
  void removeProtocols(PeerId p, List<ProtocolId> protos) {
    final pmap = _protocolMap(p);
    if (pmap.isEmpty) return;
    pmap.removeAll(protos);
    _meta.put(p, _protocolsMetadataKey, pmap.toList());
  }

  /// Equivalent to go-libp2p's `dsProtoBook.RemovePeer`.
  @override
  void removePeer(PeerId p) => _meta.removePeer(p);
}
