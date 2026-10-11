// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: os
library;

import 'dart:ffi';

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/io/fs.dart' as $fs;

/// Go: `os.File` (handle).
class File extends GoHandle {
  File.$h(super.$h);

  /// Go: `func (*os.File).Close() error`.
  void close() {
    $check(_d25($h, $out));
  }
}

/// Go: `func os.Stat(name string) (os.FileInfo, error)`.
$fs.FileInfo stat(String name) {
  final $s0 = $cstr(name);
  try {
    $check(_d9($s0, $out));
  } finally {
    $free($s0);
  }
  return $fs.FileInfo.$h($nnH($out.value));
}

/// Go: `func os.Create(name string) (*os.File, error)`.
File create(String name) {
  final $s0 = $cstr(name);
  try {
    $check(_d24($s0, $out));
  } finally {
    $free($s0);
  }
  return File.$h($nnH($out.value));
}

// Exports diretos (sem JSON) usados acima.
final _d25 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Int64>),
    Pointer<Uint8> Function(int, Pointer<Int64>)>('IpfsD25');
final _d9 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int64>),
    Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int64>)>('IpfsD9');
final _d24 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int64>),
    Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int64>)>('IpfsD24');
