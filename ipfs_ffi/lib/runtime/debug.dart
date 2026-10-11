// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: runtime/debug
library;

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/os.dart' as $os;

/// Go: `debug.CrashOptions`.
final class CrashOptions implements GoJson {
  CrashOptions();
  CrashOptions.$fromJson(Map<String, Object?> j);

  @override
  Map<String, Object?> $toJson() => {};
}

/// Go: `func debug.SetCrashOutput(f *os.File, opts debug.CrashOptions) error`.
void setCrashOutput($os.File f, CrashOptions opts) {
  $callSync('runtime/debug.SetCrashOutput', [f, opts]);
}
