/// CAR files: `ipfs dag export` and `ipfs dag import`, hand-written
/// (functions 34 and 35 of WIRE.md; Go in go/manual_car.go, with
/// `github.com/ipld/go-car`). They take the node, like the kubo commands, not
/// just the CoreAPI.
///
/// ```dart
/// import 'package:ipfs_ffi/car.dart' as car;
///
/// final bytes = await car.export(node, ctx, root);
/// final result = await car.import(node, ctx, bytes);
/// ```
library;

import 'dart:typed_data';

import 'package:ipfs_ffi/boxo/path.dart' as $path;
import 'package:ipfs_ffi/go/context.dart' as $context;
import 'package:ipfs_ffi/kubo/core.dart' as $core;
import 'package:ipfs_ffi/multiformats/cid.dart' as $cid;
import 'package:ipfs_ffi/src/runtime.dart';

/// `ipfs dag export`: the DAG of [path] as an in-memory CARv1. [localOnly]
/// (`--local-only`) does not touch the network and skips what is not in the
/// repo (partial CAR).
Future<Uint8List> export(
  $core.IpfsNode node,
  $context.Context ctx,
  $path.Path path, {
  bool localOnly = false,
}) async {
  final r = await $call(34, _export(node, ctx, path, localOnly, ''));
  return r.bytes() ?? Uint8List(0);
}

/// `ipfs dag export > [file]`: writes the CARv1 straight to the file (the
/// bytes do not go through Dart; use it for large DAGs).
Future<void> exportFile(
  $core.IpfsNode node,
  $context.Context ctx,
  $path.Path path,
  String file, {
  bool localOnly = false,
}) async {
  await $call(34, _export(node, ctx, path, localOnly, file));
}

$W _export($core.IpfsNode node, $context.Context ctx, $path.Path path,
        bool localOnly, String file) =>
    $W()
      ..h(node)
      ..h(ctx)
      ..str(path.value)
      ..b(localOnly)
      ..str(file);

/// Root of an imported CAR (kubo's `RootMeta`): [pinErrorMsg] is empty when
/// the pin succeeded.
final class RootMeta {
  RootMeta._(this.cid, this.pinErrorMsg);

  final $cid.Cid cid;
  final String pinErrorMsg;
}

/// Result of `ipfs dag import` (pinned roots and `--stats`).
final class ImportResult {
  ImportResult._(this.roots, this.blockCount, this.blockBytesCount);

  final List<RootMeta> roots;
  final int blockCount;
  final int blockBytesCount;
}

/// Function 35: the CARs come from [files] or, if [car] is not null, from
/// the bytes.
Future<ImportResult> _import(
    $core.IpfsNode node,
    $context.Context ctx,
    List<String> files,
    Uint8List? car,
    bool pinRoots,
    bool allowBigBlock) async {
  final r = await $call(
      35,
      $W()
        ..h(node)
        ..h(ctx)
        ..list(files, (w, f) => w.str(f))
        ..bytes(car)
        ..b(pinRoots)
        ..b(allowBigBlock));
  return ImportResult._(
      r.list(() => RootMeta._($cid.Cid(r.str()), r.str())), r.i64(), r.i64());
}

/// `ipfs dag import`: stores the blocks of the CAR (v1 or v2) [car] and, with
/// [pinRoots] (default, `--pin-roots`), pins the roots. Does not use the
/// network. [allowBigBlock] accepts blocks above 2 MiB.
Future<ImportResult> import(
  $core.IpfsNode node,
  $context.Context ctx,
  Uint8List car, {
  bool pinRoots = true,
  bool allowBigBlock = false,
}) =>
    _import(node, ctx, const [], car, pinRoots, allowBigBlock);

/// `ipfs dag import [files...]`: reads the CARs straight from the files.
Future<ImportResult> importFiles(
  $core.IpfsNode node,
  $context.Context ctx,
  List<String> files, {
  bool pinRoots = true,
  bool allowBigBlock = false,
}) =>
    _import(node, ctx, files, null, pinRoots, allowBigBlock);
