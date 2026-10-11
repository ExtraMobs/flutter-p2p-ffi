// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/boxo/files
library;

import 'dart:ffi';
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
  final $s0 = $cstr(path);
  try {
    $check(_d6($s0, includeHidden ? 1 : 0, stat.$h, $out));
  } finally {
    $free($s0);
  }
  return Node.$h($nnH($out.value));
}

/// Go: `func files.ToFile(n files.Node) files.File`.
File toFile(Node n) {
  $check(_d7(n.$h, $out));
  return File.$h($nnH($out.value));
}

/// Go: `func files.WriteTo(nd files.Node, fpath string) error`.
void writeTo(Node nd, String fpath) {
  final $s1 = $cstr(fpath);
  try {
    $check(_d8(nd.$h, $s1, $out));
  } finally {
    $free($s1);
  }
}

// Exports diretos (sem JSON) usados acima.
final _d6 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Pointer<Uint8>, Int64, Int64, Pointer<Int64>),
    Pointer<Uint8> Function(
        Pointer<Uint8>, int, int, Pointer<Int64>)>('IpfsD6');
final _d7 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Int64>),
    Pointer<Uint8> Function(int, Pointer<Int64>)>('IpfsD7');
final _d8 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Uint8>, Pointer<Int64>),
    Pointer<Uint8> Function(int, Pointer<Uint8>, Pointer<Int64>)>('IpfsD8');
