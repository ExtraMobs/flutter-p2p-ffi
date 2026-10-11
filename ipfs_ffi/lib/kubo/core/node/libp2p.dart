// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/kubo/core/node/libp2p
library;

import 'dart:ffi';

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
  $check(_d13($out));
  return RoutingOption.$h($nnH($out.value));
}

/// Go: `var libp2p.DHTClientOption libp2p.RoutingOption`.
RoutingOption get dhtClientOption {
  $check(_d14($out));
  return RoutingOption.$h($nnH($out.value));
}

/// Go: `var libp2p.DHTServerOption libp2p.RoutingOption`.
RoutingOption get dhtServerOption {
  $check(_d15($out));
  return RoutingOption.$h($nnH($out.value));
}

/// Go: `var libp2p.NilRouterOption func(_ libp2p.RoutingOptionArgs) (routing.Routing, error)`.
RoutingOption get nilRouterOption {
  $check(_d16($out));
  return RoutingOption.$h($nnH($out.value));
}

/// Go: `func libp2p.ConstructDefaultRouting(cfg *config.Config, routingOpt libp2p.RoutingOption) libp2p.RoutingOption`.
RoutingOption constructDefaultRouting(
    $config.Config cfg, RoutingOption routingOpt) {
  final $r = $callSync(
      'github.com/ipfs/kubo/core/node/libp2p.ConstructDefaultRouting',
      [cfg, routingOpt]);
  return RoutingOption.$h($nn($r) as int);
}

// Exports diretos (sem JSON) usados acima.
final _d13 = $dylib.lookupFunction<Pointer<Uint8> Function(Pointer<Int64>),
    Pointer<Uint8> Function(Pointer<Int64>)>('IpfsD13');
final _d14 = $dylib.lookupFunction<Pointer<Uint8> Function(Pointer<Int64>),
    Pointer<Uint8> Function(Pointer<Int64>)>('IpfsD14');
final _d15 = $dylib.lookupFunction<Pointer<Uint8> Function(Pointer<Int64>),
    Pointer<Uint8> Function(Pointer<Int64>)>('IpfsD15');
final _d16 = $dylib.lookupFunction<Pointer<Uint8> Function(Pointer<Int64>),
    Pointer<Uint8> Function(Pointer<Int64>)>('IpfsD16');
