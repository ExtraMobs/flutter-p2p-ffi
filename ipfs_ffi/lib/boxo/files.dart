// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/boxo/files
library;

import 'dart:typed_data';

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/io.dart' as $io;
import 'package:ipfs_ffi/io/fs.dart' as $fs;

/// Go: `files.File` (handle).
class File extends Node {
  File.$h(super.$h) : super.$h();
}

/// Go: `files.Node` (handle).
class Node extends $io.Closer {
  Node.$h(super.$h) : super.$h();
}

/// Go: `func files.NewBytesFile(b []byte) files.File`.
File newBytesFile(Uint8List b) {
  final $r = $callSync('github.com/ipfs/boxo/files.NewBytesFile', [b]);
  return File.$h($nn($r) as int);
}

/// Go: `func files.NewSerialFile(path string, includeHidden bool, stat os.FileInfo) (files.Node, error)`.
Node newSerialFile(String path, bool includeHidden, $fs.FileInfo stat) {
  final $r = $callSync(
      'github.com/ipfs/boxo/files.NewSerialFile', [path, includeHidden, stat]);
  return Node.$h($nn($r) as int);
}

/// Go: `func files.ToFile(n files.Node) files.File`.
File toFile(Node n) {
  final $r = $callSync('github.com/ipfs/boxo/files.ToFile', [n]);
  return File.$h($nn($r) as int);
}

/// Go: `func files.WriteTo(nd files.Node, fpath string) error`.
void writeTo(Node nd, String fpath) {
  $callSync('github.com/ipfs/boxo/files.WriteTo', [nd, fpath]);
}
