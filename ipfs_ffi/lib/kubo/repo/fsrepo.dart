// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/kubo/repo/fsrepo
library;

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/kubo/config.dart' as $config;
import 'package:ipfs_ffi/kubo/repo.dart' as $repo;

/// Go: `func fsrepo.IsInitialized(path string) bool`.
bool isInitialized(String path) {
  final $r = $callSync(153, $W()..str(path));
  return $r.b();
}

/// Go: `func fsrepo.Init(repoPath string, conf *config.Config) error`.
void init(String repoPath, $config.Config conf) {
  $callSync(
      152,
      $W()
        ..str(repoPath)
        ..json(conf));
}

/// Go: `func fsrepo.Open(repoPath string) (repo.Repo, error)`.
$repo.Repo open(String repoPath) {
  final $r = $callSync(154, $W()..str(repoPath));
  return $r.hnn($repo.Repo.$h);
}
