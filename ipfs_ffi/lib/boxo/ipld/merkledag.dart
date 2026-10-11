// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/boxo/ipld/merkledag
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/go_ipld_format.dart' as $go_ipld_format;

/// Go: `merkledag.ProtoNode` (handle).
class ProtoNode extends $go_ipld_format.Node {
  ProtoNode.$h(super.$h) : super.$h();

  /// Go: `func (*merkledag.ProtoNode).AddNodeLink(name string, that format.Node) error`.
  void addNodeLink(String name, $go_ipld_format.Node that) {
    final $s0 = $cstr(name);
    try {
      $check(_d28($h, $s0, that.$h, $out));
    } finally {
      $free($s0);
    }
  }

  /// Go: `func (*merkledag.ProtoNode).SetData(d []byte)`.
  void setData(Uint8List d) {
    final $b0 = $cbytes(d);
    try {
      $check(_d29($h, $b0, d.length, $out));
    } finally {
      $free($b0);
    }
  }

  /// Go: `func (*merkledag.ProtoNode).Data() []byte`.
  Uint8List data() {
    $check(_d30($h, $out.cast<Pointer<Uint8>>(), $outN));
    return $takeBytes($out.cast<Pointer<Uint8>>().value, $outN.value);
  }
}

/// Go: `merkledag.RawNode` (handle).
class RawNode extends $go_ipld_format.Node {
  RawNode.$h(super.$h) : super.$h();

  /// Go: `func merkledag.NewRawNode(data []byte) *merkledag.RawNode`.
  factory RawNode(Uint8List data) {
    final $b0 = $cbytes(data);
    try {
      $check(_d26($b0, data.length, $out));
    } finally {
      $free($b0);
    }
    return RawNode.$h($nnH($out.value));
  }
}

/// Go: `func merkledag.NodeWithData(d []byte) *merkledag.ProtoNode`.
ProtoNode nodeWithData(Uint8List d) {
  final $b0 = $cbytes(d);
  try {
    $check(_d27($b0, d.length, $out));
  } finally {
    $free($b0);
  }
  return ProtoNode.$h($nnH($out.value));
}

// Exports diretos (sem JSON) usados acima.
final _d28 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Uint8>, Int64, Pointer<Int64>),
    Pointer<Uint8> Function(
        int, Pointer<Uint8>, int, Pointer<Int64>)>('IpfsD28');
final _d29 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Uint8>, Int64, Pointer<Int64>),
    Pointer<Uint8> Function(
        int, Pointer<Uint8>, int, Pointer<Int64>)>('IpfsD29');
final _d30 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Pointer<Uint8>>, Pointer<Int64>),
    Pointer<Uint8> Function(
        int, Pointer<Pointer<Uint8>>, Pointer<Int64>)>('IpfsD30');
final _d26 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Pointer<Uint8>, Int64, Pointer<Int64>),
    Pointer<Uint8> Function(Pointer<Uint8>, int, Pointer<Int64>)>('IpfsD26');
final _d27 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Pointer<Uint8>, Int64, Pointer<Int64>),
    Pointer<Uint8> Function(Pointer<Uint8>, int, Pointer<Int64>)>('IpfsD27');
