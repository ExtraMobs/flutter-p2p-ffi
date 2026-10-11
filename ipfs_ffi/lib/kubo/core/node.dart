// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/kubo/core/node
library;

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/kubo/core/node/libp2p.dart' as $libp2p;
import 'package:ipfs_ffi/kubo/repo.dart' as $repo;

/// Go: `node.BuildCfg`.
final class BuildCfg implements GoJson {
  BuildCfg(
      {bool? online,
      Map<String, bool>? extraOpts,
      bool? permanent,
      bool? disableEncryptedConnections,
      $libp2p.RoutingOption? routing,
      $libp2p.HostOption? host,
      $repo.Repo? repo,
      int? shutdownTimeout})
      : online = online ?? false,
        extraOpts = extraOpts ?? {},
        permanent = permanent ?? false,
        disableEncryptedConnections = disableEncryptedConnections ?? false,
        routing = routing,
        host = host,
        repo = repo,
        shutdownTimeout = shutdownTimeout ?? 0;

  BuildCfg.$fromJson(Map<String, Object?> j)
      : online = j['Online'] as bool,
        extraOpts = {
          for (final e0 in (j['ExtraOpts'] as Map<String, Object?>).entries)
            e0.key: e0.value as bool
        },
        permanent = j['Permanent'] as bool,
        disableEncryptedConnections = j['DisableEncryptedConnections'] as bool,
        routing = j['Routing'] == null
            ? null
            : $libp2p.RoutingOption.$h(j['Routing'] as int),
        host =
            j['Host'] == null ? null : $libp2p.HostOption.$h(j['Host'] as int),
        repo = j['Repo'] == null ? null : $repo.Repo.$h(j['Repo'] as int),
        shutdownTimeout = j['ShutdownTimeout'] as int;

  /// Go: `Online`.
  bool online;

  /// Go: `ExtraOpts`.
  Map<String, bool> extraOpts;

  /// Go: `Permanent`.
  bool permanent;

  /// Go: `DisableEncryptedConnections`.
  bool disableEncryptedConnections;

  /// Go: `Routing`.
  $libp2p.RoutingOption? routing;

  /// Go: `Host`.
  $libp2p.HostOption? host;

  /// Go: `Repo`.
  $repo.Repo? repo;

  /// Go: `ShutdownTimeout`.
  int shutdownTimeout;

  @override
  Map<String, Object?> $toJson() => {
        'Online': $enc(online),
        'ExtraOpts': $enc(extraOpts),
        'Permanent': $enc(permanent),
        'DisableEncryptedConnections': $enc(disableEncryptedConnections),
        'Routing': $enc(routing),
        'Host': $enc(host),
        'Repo': $enc(repo),
        'ShutdownTimeout': $enc(shutdownTimeout)
      };
}
