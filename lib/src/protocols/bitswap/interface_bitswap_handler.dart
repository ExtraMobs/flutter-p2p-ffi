import 'package:transpiled_block_format/transpiled_block_format.dart'
    as block_format;
import 'package:transpiled_ipfs/src/core/cid.dart';

/// Reusable Boxo `bitswap.BlockGetter` surface.
abstract interface class BlockGetter {
  /// Retrieves one block over Bitswap.
  Future<block_format.Block> getBlock(Cid cid);
}
