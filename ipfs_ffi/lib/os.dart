// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: os
library;

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/io/fs.dart' as $fs;

/// Go: `os.File` (handle).
class File extends GoHandle {
  File.$h(super.$h);

  /// Go: `func (*os.File).Close() error`.
  void close() {
    $callSync('os.File.Close', [this]);
  }
}

/// Go: `func os.Stat(name string) (os.FileInfo, error)`.
$fs.FileInfo stat(String name) {
  final $r = $callSync('os.Stat', [name]);
  return $fs.FileInfo.$h($nn($r) as int);
}

/// Go: `func os.Create(name string) (*os.File, error)`.
File create(String name) {
  final $r = $callSync('os.Create', [name]);
  return File.$h($nn($r) as int);
}
