// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/libp2p/go-libp2p/core/peer
library;

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/go_multiaddr.dart' as $go_multiaddr;

/// Go: `peer.AddrInfo`.
final class AddrInfo implements GoDto {
  AddrInfo({Id? id, List<$go_multiaddr.Multiaddr>? addrs})
      : id = id,
        addrs = addrs ?? [];

  AddrInfo.$dec($R r)
      : id = r.p() ? Id(r.str()) : null,
        addrs = r.list(() => r.p() ? $go_multiaddr.Multiaddr(r.str()) : $nil());

  /// Go: `ID`.
  Id? id;

  /// Go: `Addrs`.
  List<$go_multiaddr.Multiaddr> addrs;

  @override
  void $enc($W w) {
    w
      ..val(id)
      ..list(addrs, (w0, e0) => w0.val(e0));
  }
}

/// Go: `peer.ID` (valor).
class Id extends GoValue {
  const Id(super.value);
}

/// Go: `func peer.AddrInfoFromString(s string) (*peer.AddrInfo, error)`.
AddrInfo addrInfoFromString(String s) {
  final $r = $callSync(155, $W()..str(s));
  return $r.p() ? AddrInfo.$dec($r) : $nil();
}

/// Go: `func peer.AddrInfoToP2pAddrs(pi *peer.AddrInfo) ([]multiaddr.Multiaddr, error)`.
List<$go_multiaddr.Multiaddr> addrInfoToP2pAddrs(AddrInfo pi) {
  final $r = $callSync(156, $W()..dto(pi));
  return $r.list(() => $r.p() ? $go_multiaddr.Multiaddr($r.str()) : $nil());
}
