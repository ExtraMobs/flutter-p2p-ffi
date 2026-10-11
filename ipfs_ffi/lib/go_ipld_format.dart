// Gerado por ipfs_ffi/go/gen a partir de go/gen/roots.txt; não editar.
// Go: github.com/ipfs/go-ipld-format
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ipfs_ffi/src/runtime.dart';
import 'package:ipfs_ffi/context.dart' as $context;
import 'package:ipfs_ffi/go_block_format.dart' as $go_block_format;
import 'package:ipfs_ffi/go_cid.dart' as $go_cid;

/// Go: `format.DAGService` (handle).
class DagService extends NodeGetter {
  DagService.$h(super.$h) : super.$h();
}

/// Go: `format.Link`.
final class Link implements GoJson {
  Link({String? name, int? size, $go_cid.Cid? cid})
      : name = name ?? '',
        size = size ?? 0,
        cid = cid;

  Link.$fromJson(Map<String, Object?> j)
      : name = j['Name'] as String,
        size = j['Size'] as int,
        cid = j['Cid'] == null ? null : $go_cid.Cid(j['Cid'] as String);

  /// Go: `Name`.
  String name;

  /// Go: `Size`.
  int size;

  /// Go: `Cid`.
  $go_cid.Cid? cid;

  @override
  Map<String, Object?> $toJson() =>
      {'Name': $enc(name), 'Size': $enc(size), 'Cid': $enc(cid)};
}

/// Go: `format.Node` (handle).
class Node extends $go_block_format.Block {
  Node.$h(super.$h) : super.$h();

  /// Go: `func (blocks.Block).Cid() cid.Cid`.
  $go_cid.Cid cid() {
    $check(_d23($h, $out.cast<Pointer<Uint8>>()));
    return $go_cid.Cid($take($nnP($out.cast<Pointer<Uint8>>().value)));
  }

  /// Go: `func (blocks.Block).RawData() []byte`.
  Uint8List rawData() {
    $check(_d24($h, $out.cast<Pointer<Uint8>>(), $outN));
    return $takeBytes($out.cast<Pointer<Uint8>>().value, $outN.value);
  }

  /// Go: `func (format.Node).Links() []*format.Link`.
  List<Link> links() {
    final $r = $callSync('github.com/ipfs/go-ipld-format.Node.Links', [this]);
    return [
      for (final e0 in $r as List) Link.$fromJson(e0 as Map<String, Object?>)
    ];
  }

  /// Go: `func (format.Node).Size() (uint64, error)`.
  int size() {
    $check(_d25($h, $out));
    return $out.value;
  }

  /// Go: `func (format.Node).Stat() (*format.NodeStat, error)`.
  NodeStat stat() {
    final $r = $callSync('github.com/ipfs/go-ipld-format.Node.Stat', [this]);
    return NodeStat.$fromJson($nn($r) as Map<String, Object?>);
  }
}

/// Go: `format.NodeAdder` (handle).
class NodeAdder extends GoHandle {
  NodeAdder.$h(super.$h);

  /// Go: `func (format.NodeAdder).Add(context.Context, format.Node) error`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<void> add($context.Context ctx, Node node) async {
    await $call(
        'github.com/ipfs/go-ipld-format.NodeAdder.Add', [this, ctx, node]);
  }

  /// Go: `func (format.NodeAdder).AddMany(context.Context, []format.Node) error`.
  ///
  /// Assíncrona: roda numa goroutine.
  Future<void> addMany($context.Context ctx, List<Node> nodes) async {
    await $call(
        'github.com/ipfs/go-ipld-format.NodeAdder.AddMany', [this, ctx, nodes]);
  }
}

/// Go: `format.NodeGetter` (handle).
class NodeGetter extends GoHandle {
  NodeGetter.$h(super.$h);
}

/// Go: `format.NodeOption`.
final class NodeOption implements GoJson {
  NodeOption({Node? node, String? err})
      : node = node,
        err = err;

  NodeOption.$fromJson(Map<String, Object?> j)
      : node = j['Node'] == null ? null : Node.$h(j['Node'] as int),
        err = j['Err'] == null ? null : j['Err'] as String;

  /// Go: `Node`.
  Node? node;

  /// Go: `Err`.
  String? err;

  @override
  Map<String, Object?> $toJson() => {'Node': $enc(node), 'Err': $enc(err)};
}

/// Go: `format.NodeStat`.
final class NodeStat implements GoJson {
  NodeStat(
      {String? hash,
      int? numLinks,
      int? blockSize,
      int? linksSize,
      int? dataSize,
      int? cumulativeSize})
      : hash = hash ?? '',
        numLinks = numLinks ?? 0,
        blockSize = blockSize ?? 0,
        linksSize = linksSize ?? 0,
        dataSize = dataSize ?? 0,
        cumulativeSize = cumulativeSize ?? 0;

  NodeStat.$fromJson(Map<String, Object?> j)
      : hash = j['Hash'] as String,
        numLinks = j['NumLinks'] as int,
        blockSize = j['BlockSize'] as int,
        linksSize = j['LinksSize'] as int,
        dataSize = j['DataSize'] as int,
        cumulativeSize = j['CumulativeSize'] as int;

  /// Go: `Hash`.
  String hash;

  /// Go: `NumLinks`.
  int numLinks;

  /// Go: `BlockSize`.
  int blockSize;

  /// Go: `LinksSize`.
  int linksSize;

  /// Go: `DataSize`.
  int dataSize;

  /// Go: `CumulativeSize`.
  int cumulativeSize;

  @override
  Map<String, Object?> $toJson() => {
        'Hash': $enc(hash),
        'NumLinks': $enc(numLinks),
        'BlockSize': $enc(blockSize),
        'LinksSize': $enc(linksSize),
        'DataSize': $enc(dataSize),
        'CumulativeSize': $enc(cumulativeSize)
      };
}

// Exports diretos (sem JSON) usados acima.
final _d23 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Pointer<Uint8>>),
    Pointer<Uint8> Function(int, Pointer<Pointer<Uint8>>)>('IpfsD23');
final _d24 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Pointer<Uint8>>, Pointer<Int64>),
    Pointer<Uint8> Function(
        int, Pointer<Pointer<Uint8>>, Pointer<Int64>)>('IpfsD24');
final _d25 = $dylib.lookupFunction<
    Pointer<Uint8> Function(Int64, Pointer<Int64>),
    Pointer<Uint8> Function(int, Pointer<Int64>)>('IpfsD25');
