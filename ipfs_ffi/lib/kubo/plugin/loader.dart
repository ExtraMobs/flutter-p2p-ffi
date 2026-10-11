// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/kubo/plugin/loader
library;

import 'package:ipfs_ffi/src/runtime.dart';

/// Go: `loader.PluginLoader` (handle).
class PluginLoader extends GoHandle {
  PluginLoader.$h(super.$h);

  /// Go: `func loader.NewPluginLoader(repo string) (*loader.PluginLoader, error)`.
  factory PluginLoader(String repo) {
    final $r =
        $callSync('github.com/ipfs/kubo/plugin/loader.NewPluginLoader', [repo]);
    return PluginLoader.$h($nn($r) as int);
  }

  /// Go: `func (*loader.PluginLoader).Initialize() error`.
  void initialize() {
    $callSync(
        'github.com/ipfs/kubo/plugin/loader.PluginLoader.Initialize', [this]);
  }

  /// Go: `func (*loader.PluginLoader).Inject() error`.
  void inject() {
    $callSync('github.com/ipfs/kubo/plugin/loader.PluginLoader.Inject', [this]);
  }
}
