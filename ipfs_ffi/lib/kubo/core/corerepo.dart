// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/kubo/core/corerepo
library;

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/context.dart' as $context;
import 'package:ipfs_ffi/kubo/core.dart' as $core;
import 'package:ipfs_ffi/kubo/gc.dart' as $gc;

/// Go: `func corerepo.GarbageCollect(n *core.IpfsNode, ctx context.Context) error`.
///
/// Assíncrona: roda numa goroutine do serviço.
Future<void> garbageCollect($core.IpfsNode n, $context.Context ctx) async {
  await $call(
      141,
      $W()
        ..h(n)
        ..h(ctx));
}

/// Go: `func corerepo.GarbageCollectAsync(n *core.IpfsNode, ctx context.Context) <-chan gc.Result`.
Stream<$gc.Result> garbageCollectAsync(
        $core.IpfsNode n, $context.Context ctx) =>
    $stream(
            142,
            $W()
              ..h(n)
              ..h(ctx))
        .map((r) => r.p() ? $gc.Result.$dec(r) : $nil());
