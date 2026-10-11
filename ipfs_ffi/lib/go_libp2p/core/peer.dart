// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/libp2p/go-libp2p/core/peer
library;

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/go_multiaddr.dart' as $go_multiaddr;

/// Go: `peer.AddrInfo`.
final class AddrInfo implements GoJson {
  AddrInfo({Id? id, List<$go_multiaddr.Multiaddr>? addrs})
      : id = id,
        addrs = addrs ?? [];

  AddrInfo.$fromJson(Map<String, Object?> j)
      : id = j['ID'] == null ? null : Id(j['ID'] as String),
        addrs = [
          for (final e0 in j['Addrs'] as List)
            $go_multiaddr.Multiaddr(e0 as String)
        ];

  /// Go: `ID`.
  Id? id;

  /// Go: `Addrs`.
  List<$go_multiaddr.Multiaddr> addrs;

  @override
  Map<String, Object?> $toJson() => {'ID': $enc(id), 'Addrs': $enc(addrs)};
}

/// Go: `peer.ID` (valor).
class Id extends GoValue {
  const Id(super.value);
}

/// Go: `func peer.AddrInfoFromString(s string) (*peer.AddrInfo, error)`.
AddrInfo addrInfoFromString(String s) {
  final $r = $callSync(
      'github.com/libp2p/go-libp2p/core/peer.AddrInfoFromString', [s]);
  return AddrInfo.$fromJson($nn($r) as Map<String, Object?>);
}

/// Go: `func peer.AddrInfoToP2pAddrs(pi *peer.AddrInfo) ([]multiaddr.Multiaddr, error)`.
List<$go_multiaddr.Multiaddr> addrInfoToP2pAddrs(AddrInfo pi) {
  final $r = $callSync(
      'github.com/libp2p/go-libp2p/core/peer.AddrInfoToP2pAddrs', [pi]);
  return [for (final e0 in $r as List) $go_multiaddr.Multiaddr(e0 as String)];
}
