// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: io
library;

import 'dart:typed_data';

import 'package:ipfs_ffi/src/runtime.dart';

/// Go: `io.Closer` (handle).
class Closer extends GoHandle {
  Closer.$h(super.$h);
}

/// Go: `io.Reader` (handle).
class Reader extends GoHandle {
  Reader.$h(super.$h);
}

/// Go: `func io.ReadAll(r io.Reader) ([]byte, error)`.
Uint8List readAll(Object r) {
  final $r = $callSync('io.ReadAll', [r]);
  return $bytes($r);
}
