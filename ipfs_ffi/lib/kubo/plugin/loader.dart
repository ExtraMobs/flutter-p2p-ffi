// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/kubo/plugin/loader
library;

import 'dart:ffi';

import 'package:ipfs_ffi/src/runtime.dart';

/// Go: `loader.PluginLoader` (handle).
class PluginLoader extends GoHandle {
  PluginLoader.$h(super.$h);

  /// Go: `func loader.NewPluginLoader(repo string) (*loader.PluginLoader, error)`.
  factory PluginLoader(String repo) {
    final $s0 = $cstr(repo);
    try {
      $check(_d0($s0, $out));
    } finally {
      $free($s0);
    }
    return PluginLoader.$h($nnH($out.value));
  }

  /// Go: `func (*loader.PluginLoader).Initialize() error`.
  void initialize() {
    $check(_d1($h, $out));
  }

  /// Go: `func (*loader.PluginLoader).Inject() error`.
  void inject() {
    $check(_d2($h, $out));
  }
}

// Exports diretos (sem JSON) usados acima.
final _d0 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int64>),
    Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int64>)>('IpfsD0');
final _d1 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Int64>),
    Pointer<Uint8> Function(int, Pointer<Int64>)>('IpfsD1');
final _d2 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Int64>),
    Pointer<Uint8> Function(int, Pointer<Int64>)>('IpfsD2');
