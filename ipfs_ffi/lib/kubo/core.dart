// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/kubo/core
library;

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/context.dart' as $context;
import 'package:ipfs_ffi/kubo/core/node.dart' as $node;

/// Go: `core.IpfsNode` (handle).
class IpfsNode extends GoHandle {
  IpfsNode.$h(super.$h);

  /// Go: `func (*core.IpfsNode).Close() error`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<void> close() async {
    await $call('github.com/ipfs/kubo/core.IpfsNode.Close', [this]);
  }
}

/// Go: `func core.NewNode(ctx context.Context, cfg *core.BuildCfg) (*core.IpfsNode, error)`.
///
/// Assíncrona: roda numa goroutine.
Future<IpfsNode> newNode($context.Context ctx, $node.BuildCfg cfg) async {
  final $r = await $call('github.com/ipfs/kubo/core.NewNode', [ctx, cfg]);
  return IpfsNode.$h($nn($r) as int);
}
