// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/kubo/repo/fsrepo
library;

import 'dart:ffi';

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/kubo/config.dart' as $config;
import 'package:ipfs_ffi/kubo/repo.dart' as $repo;

/// Go: `func fsrepo.IsInitialized(path string) bool`.
bool isInitialized(String path) {
  final $s0 = $cstr(path);
  try {
    $check(_d3($s0, $out));
  } finally {
    $free($s0);
  }
  return $out.value != 0;
}

/// Go: `func fsrepo.Init(repoPath string, conf *config.Config) error`.
void init(String repoPath, $config.Config conf) {
  $callSync('github.com/ipfs/kubo/repo/fsrepo.Init', [repoPath, conf]);
}

/// Go: `func fsrepo.Open(repoPath string) (repo.Repo, error)`.
$repo.Repo open(String repoPath) {
  final $s0 = $cstr(repoPath);
  try {
    $check(_d4($s0, $out));
  } finally {
    $free($s0);
  }
  return $repo.Repo.$h($nnH($out.value));
}

// Exports diretos (sem JSON) usados acima.
final _d3 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int64>),
    Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int64>)>('IpfsD3');
final _d4 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int64>),
    Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int64>)>('IpfsD4');
