// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/kubo/core/node/libp2p
library;

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/kubo/config.dart' as $config;

/// Go: `libp2p.HostOption` (handle).
class HostOption extends GoHandle {
  HostOption.$h(super.$h);
}

/// Go: `libp2p.RoutingOption` (handle).
class RoutingOption extends GoHandle {
  RoutingOption.$h(super.$h);
}

/// Go: `var libp2p.DHTOption libp2p.RoutingOption`.
RoutingOption get dhtOption {
  final $r = $callSync('github.com/ipfs/kubo/core/node/libp2p.DHTOption', []);
  return RoutingOption.$h($nn($r) as int);
}

/// Go: `var libp2p.DHTClientOption libp2p.RoutingOption`.
RoutingOption get dhtClientOption {
  final $r =
      $callSync('github.com/ipfs/kubo/core/node/libp2p.DHTClientOption', []);
  return RoutingOption.$h($nn($r) as int);
}

/// Go: `var libp2p.DHTServerOption libp2p.RoutingOption`.
RoutingOption get dhtServerOption {
  final $r =
      $callSync('github.com/ipfs/kubo/core/node/libp2p.DHTServerOption', []);
  return RoutingOption.$h($nn($r) as int);
}

/// Go: `var libp2p.NilRouterOption func(_ libp2p.RoutingOptionArgs) (routing.Routing, error)`.
RoutingOption get nilRouterOption {
  final $r =
      $callSync('github.com/ipfs/kubo/core/node/libp2p.NilRouterOption', []);
  return RoutingOption.$h($nn($r) as int);
}

/// Go: `func libp2p.ConstructDefaultRouting(cfg *config.Config, routingOpt libp2p.RoutingOption) libp2p.RoutingOption`.
RoutingOption constructDefaultRouting(
    $config.Config cfg, RoutingOption routingOpt) {
  final $r = $callSync(
      'github.com/ipfs/kubo/core/node/libp2p.ConstructDefaultRouting',
      [cfg, routingOpt]);
  return RoutingOption.$h($nn($r) as int);
}
