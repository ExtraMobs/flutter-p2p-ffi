import '../../config/ipfs_runtime_config.dart';
import '../../repo/repo.dart';

/// Configuration accepted by the Kubo core node constructor.
///
/// This is the supported Dart subset of Kubo's `core/node.BuildCfg`:
/// [online] selects whether the node is built with networking enabled,
/// [config] supplies the application configuration used by the existing
/// runtime, and [shutdownTimeout] caps graceful shutdown when positive.
/// [repo] supplies persistent configuration and storage when provided.
/// Kubo's `Host` and `Routing` hooks remain unported.
class BuildCfg {
  /// Creates a build configuration.
  ///
  /// A zero-value Kubo `BuildCfg` is offline. When [config] is omitted, the
  /// same default is used here.
  BuildCfg({
    this.repo,
    IpfsConfig? config,
    this.online = false,
    Map<String, bool>? extraOpts,
    this.shutdownTimeout = Duration.zero,
  }) : _config = config ?? IpfsConfig(offline: !online),
       extraOpts = extraOpts ?? <String, bool>{};

  final IpfsConfig _config;

  /// Repository used by the node; its configuration takes precedence over
  /// [config], matching Kubo BuildCfg.Repo. The node closes it on shutdown.
  final Repo? repo;

  /// Whether the constructed node has networking enabled.
  final bool online;

  /// Kubo's optional construction switches (`pubsub` and `ipnsps`).
  ///
  /// The map is mutable, matching Go's `BuildCfg.ExtraOpts` map field.
  final Map<String, bool> extraOpts;

  /// Caps graceful shutdown, matching Kubo's `ShutdownTimeout`.
  ///
  /// A zero value disables the cap and waits indefinitely. Values below zero
  /// are treated the same way, as Kubo only applies a timeout when positive.
  final Duration shutdownTimeout;

  /// The application configuration used to construct the node.
  IpfsConfig get config {
    if (_config.offline == !online) return _config;
    return _config.copyWith(offline: !online);
  }
}
