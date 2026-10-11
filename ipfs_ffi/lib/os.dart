// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: os
library;

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/io/fs.dart' as $fs;

/// Go: `func os.Stat(name string) (os.FileInfo, error)`.
$fs.FileInfo stat(String name) {
  final $r = $callSync('os.Stat', [name]);
  return $fs.FileInfo.$h($nn($r) as int);
}
