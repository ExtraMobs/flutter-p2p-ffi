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
    $check(_d32($h, $out));
  }
}

/// Go: `func os.Stat(name string) (os.FileInfo, error)`.
$fs.FileInfo stat(String name) {
  final $s0 = $cstr(name);
  try {
    $check(_d10($s0, $out));
  } finally {
    $free($s0);
  }
  return $fs.FileInfo.$h($nnH($out.value));
}

/// Go: `func os.Create(name string) (*os.File, error)`.
File create(String name) {
  final $s0 = $cstr(name);
  try {
    $check(_d31($s0, $out));
  } finally {
    $free($s0);
  }
  return File.$h($nnH($out.value));
}

// Exports diretos (sem JSON) usados acima.
final _d32 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Int64>),
    Pointer<Uint8> Function(int, Pointer<Int64>)>('IpfsD32');
final _d10 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int64>),
    Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int64>)>('IpfsD10');
final _d31 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int64>),
    Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int64>)>('IpfsD31');
