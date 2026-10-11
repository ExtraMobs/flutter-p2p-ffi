// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/kubo/repo/fsrepo
library;

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/kubo/config.dart' as $config;
import 'package:ipfs_ffi/kubo/repo.dart' as $repo;

/// Go: `func fsrepo.IsInitialized(path string) bool`.
bool isInitialized(String path) {
  final $r =
      $callSync('github.com/ipfs/kubo/repo/fsrepo.IsInitialized', [path]);
  return $r as bool;
}

/// Go: `func fsrepo.Init(repoPath string, conf *config.Config) error`.
void init(String repoPath, $config.Config conf) {
  $callSync('github.com/ipfs/kubo/repo/fsrepo.Init', [repoPath, conf]);
}

/// Go: `func fsrepo.Open(repoPath string) (repo.Repo, error)`.
$repo.Repo open(String repoPath) {
  final $r = $callSync('github.com/ipfs/kubo/repo/fsrepo.Open', [repoPath]);
  return $repo.Repo.$h($nn($r) as int);
}
