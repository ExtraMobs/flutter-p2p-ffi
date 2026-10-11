// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/boxo/ipld/merkledag
library;

import 'dart:typed_data';

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/go_ipld_format.dart' as $go_ipld_format;

/// Go: `merkledag.ProtoNode` (handle).
class ProtoNode extends $go_ipld_format.Node {
  ProtoNode.$h(super.$h) : super.$h();

  /// Go: `func (*merkledag.ProtoNode).AddNodeLink(name string, that format.Node) error`.
  void addNodeLink(String name, $go_ipld_format.Node that) {
    $callSync('github.com/ipfs/boxo/ipld/merkledag.ProtoNode.AddNodeLink',
        [this, name, that]);
  }

  /// Go: `func (*merkledag.ProtoNode).SetData(d []byte)`.
  void setData(Uint8List d) {
    $callSync(
        'github.com/ipfs/boxo/ipld/merkledag.ProtoNode.SetData', [this, d]);
  }

  /// Go: `func (*merkledag.ProtoNode).Data() []byte`.
  Uint8List data() {
    final $r =
        $callSync('github.com/ipfs/boxo/ipld/merkledag.ProtoNode.Data', [this]);
    return $bytes($r);
  }
}

/// Go: `merkledag.RawNode` (handle).
class RawNode extends $go_ipld_format.Node {
  RawNode.$h(super.$h) : super.$h();

  /// Go: `func merkledag.NewRawNode(data []byte) *merkledag.RawNode`.
  factory RawNode(Uint8List data) {
    final $r =
        $callSync('github.com/ipfs/boxo/ipld/merkledag.NewRawNode', [data]);
    return RawNode.$h($nn($r) as int);
  }
}

/// Go: `func merkledag.NodeWithData(d []byte) *merkledag.ProtoNode`.
ProtoNode nodeWithData(Uint8List d) {
  final $r = $callSync('github.com/ipfs/boxo/ipld/merkledag.NodeWithData', [d]);
  return ProtoNode.$h($nn($r) as int);
}
