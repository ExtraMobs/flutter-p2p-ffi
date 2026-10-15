/// `ipfs dag put/get/export/import`, hand-written (functions 32–35 of
/// WIRE.md; Go in go/manual_dag.go and go/manual_car.go): store and read IPLD
/// objects in DAG-CBOR, DAG-JSON, JSON, CBOR, raw or dag-pb, and move whole
/// DAGs as CAR files. In kubo this is the body of the commands
/// (core/commands/dag), not a library function; the defaults are the CLI's.
/// Export and import take the node, like the kubo commands, not just the
/// CoreAPI.
///
/// ```dart
/// import 'package:ipfs_ffi/kubo.dart' as kubo;
///
/// final c = await kubo.dagPut(api, ctx, utf8.encode('{"a": 1}')); // dag-json → dag-cbor
/// final json = await kubo.dagGet(api, ctx, boxo.Path('/ipfs/$c/a'));
/// final car = await kubo.dagExport(node, ctx, boxo.Path('/ipfs/$c'));
/// final result = await kubo.dagImport(node, ctx, car);
/// ```
library;

import 'dart:typed_data';

import 'package:ipfs_ffi/boxo/path.dart' as $path;
import 'package:ipfs_ffi/go/context.dart' as $context;
import 'package:ipfs_ffi/kubo/core.dart' as $core;
import 'package:ipfs_ffi/kubo/core/coreiface.dart' as $coreiface;
import 'package:ipfs_ffi/multiformats/cid.dart' as $cid;
import 'package:ipfs_ffi/src/runtime.dart';

/// `ipfs dag put`: decodes [data] with [inputCodec], stores it with
/// [storeCodec] (CIDv1, hash [hash]) and returns the CID. [pin] pins
/// recursively; [allowBigBlock] allows blocks above 2 MiB
/// (`--allow-big-block`).
///
/// The CLI uses `Import.HashFunction` from the config as the default hash;
/// here the default is that config's default value (`sha2-256`).
Future<$cid.Cid> dagPut(
  $coreiface.CoreApi api,
  $context.Context ctx,
  Uint8List data, {
  String inputCodec = 'dag-json',
  String storeCodec = 'dag-cbor',
  String hash = 'sha2-256',
  bool pin = false,
  bool allowBigBlock = false,
}) async {
  final r = await $call(
      32,
      $W()
        ..h(api)
        ..h(ctx)
        ..bytes(data)
        ..str(inputCodec)
        ..str(storeCodec)
        ..str(hash)
        ..b(pin)
        ..b(allowBigBlock));
  return r.p() ? $cid.Cid(r.str()) : $nil();
}

/// `ipfs dag get`: the node at [path] (which may continue inside it, e.g.
/// `/ipfs/<cid>/a/b`) encoded with [outputCodec].
Future<Uint8List> dagGet(
  $coreiface.CoreApi api,
  $context.Context ctx,
  $path.Path path, {
  String outputCodec = 'dag-json',
}) async {
  final r = await $call(
      33,
      $W()
        ..h(api)
        ..h(ctx)
        ..str(path.value)
        ..str(outputCodec));
  return r.bytes() ?? Uint8List(0);
}

/// `ipfs dag export`: the DAG of [path] as an in-memory CARv1. [localOnly]
/// (`--local-only`) does not touch the network and skips what is not in the
/// repo (partial CAR).
Future<Uint8List> dagExport(
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
Future<void> dagExportFile(
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
final class CarImportResult {
  CarImportResult._(this.roots, this.blockCount, this.blockBytesCount);

  final List<RootMeta> roots;
  final int blockCount;
  final int blockBytesCount;
}

/// Function 35: the CARs come from [files] or, if [car] is not null, from
/// the bytes.
Future<CarImportResult> _import(
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
  return CarImportResult._(
      r.list(() => RootMeta._($cid.Cid(r.str()), r.str())), r.i64(), r.i64());
}

/// `ipfs dag import`: stores the blocks of the CAR (v1 or v2) [car] and, with
/// [pinRoots] (default, `--pin-roots`), pins the roots. Does not use the
/// network. [allowBigBlock] accepts blocks above 2 MiB.
Future<CarImportResult> dagImport(
  $core.IpfsNode node,
  $context.Context ctx,
  Uint8List car, {
  bool pinRoots = true,
  bool allowBigBlock = false,
}) =>
    _import(node, ctx, const [], car, pinRoots, allowBigBlock);

/// `ipfs dag import [files...]`: reads the CARs straight from the files.
Future<CarImportResult> dagImportFiles(
  $core.IpfsNode node,
  $context.Context ctx,
  List<String> files, {
  bool pinRoots = true,
  bool allowBigBlock = false,
}) =>
    _import(node, ctx, files, null, pinRoots, allowBigBlock);
