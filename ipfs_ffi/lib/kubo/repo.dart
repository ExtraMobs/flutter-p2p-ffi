// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/kubo/repo
library;

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/io.dart' as $io;
import 'package:ipfs_ffi/kubo/config.dart' as $config;

/// Go: `repo.Repo` (handle).
class Repo extends $io.Closer {
  Repo.$h(super.$h) : super.$h();

  /// Go: `func (repo.Repo).Config() (*config.Config, error)`.
  $config.Config config() {
    final $r = $callSync('github.com/ipfs/kubo/repo.Repo.Config', [this]);
    return $config.Config($nn($r) as Map<String, Object?>);
  }
}
