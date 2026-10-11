// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/kubo/gc
library;

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/go_cid.dart' as $go_cid;

/// Go: `gc.Result`.
final class Result implements GoJson {
  Result({$go_cid.Cid? keyRemoved, String? error})
      : keyRemoved = keyRemoved,
        error = error;

  Result.$fromJson(Map<String, Object?> j)
      : keyRemoved = j['KeyRemoved'] == null
            ? null
            : $go_cid.Cid(j['KeyRemoved'] as String),
        error = j['Error'] == null ? null : j['Error'] as String;

  /// Go: `KeyRemoved`.
  $go_cid.Cid? keyRemoved;

  /// Go: `Error`.
  String? error;

  @override
  Map<String, Object?> $toJson() =>
      {'KeyRemoved': $enc(keyRemoved), 'Error': $enc(error)};
}
