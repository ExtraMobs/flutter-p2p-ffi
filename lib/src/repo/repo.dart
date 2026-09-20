import 'package:transpiled_datastore/transpiled_datastore.dart' show Batching;

import '../config/ipfs_runtime_config.dart';

/// Kubo repo.Repo contract consumed by the embedded node lifecycle.
///
/// The repository owns its datastore and configuration. Configuration returned
/// by [config] is a snapshot: mutating it does not persist changes. Repository
/// administration methods not yet used by this runtime remain unported.
abstract interface class Repo {
  /// Reads the persisted node configuration.
  Future<IpfsConfig> config();

  /// Returns the repository's batching datastore.
  Batching datastore();

  /// Flushes and releases the repository and its datastore.
  Future<void> close();
}
