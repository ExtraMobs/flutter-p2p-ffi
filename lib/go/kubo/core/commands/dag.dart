/// `ipfs dag put/get/export/import`, hand-written (functions 32–35 of
/// WIRE.md; Go in go/manual_dag.go and go/manual_car.go): store and read IPLD
/// objects in DAG-CBOR, DAG-JSON, JSON, CBOR, raw or dag-pb, and move whole
/// DAGs as CAR files. In kubo this is the body of the commands
/// (core/commands/dag), not a library function; the defaults are the CLI's.
/// Export and import take the node, like the kubo commands, not just the
/// CoreAPI.
///
/// The result types of the generated `ipfs dag` commands (`dag stat`, `dag
/// resolve`) are in the same Go package, so they live here too, generated in
/// the `dag.g.dart` part.
///
/// ```dart
/// import 'package:p2p_ffi/p2p_ffi.dart';
///
/// final dag = Go.kubo.core.commands.dag;
/// final c = await dag.dagPut(api, ctx, utf8.encode('{"a": 1}')); // dag-json → dag-cbor
/// final json = await dag.dagGet(api, ctx, BoxoPath('/ipfs/$c/a'));
/// final car = await dag.dagExport(node, ctx, BoxoPath('/ipfs/$c'));
/// final result = await dag.dagImport(node, ctx, car);
/// ```
library;

import 'dart:typed_data';

import 'package:p2p_ffi/go/boxo/path.dart' as $path;
import 'package:p2p_ffi/go/context.dart' as $context;
import 'package:p2p_ffi/go/kubo/core.dart' as $core;
import 'package:p2p_ffi/go/kubo/core/coreiface.dart' as $coreiface;
import 'package:p2p_ffi/go/cid.dart' as $cid;
import 'package:p2p_ffi/src/go.dart' show GoKuboCoreCommandsDag;
import 'package:p2p_ffi/src/runtime.dart';

part 'dag.g.dart';

$W _export($core.KuboCoreIpfsNode node, $context.Context ctx,
        $path.BoxoPath path, bool localOnly, String file) =>
    $W()
      ..h(node)
      ..h(ctx)
      ..str(path.value)
      ..b(localOnly)
      ..str(file);

/// Root of an imported CAR (kubo's `KuboCoreCommandsDagRootMeta`): [pinErrorMsg] is empty when
/// the pin succeeded.
final class KuboCoreCommandsDagRootMeta {
  KuboCoreCommandsDagRootMeta._(this.cid, this.pinErrorMsg);

  final $cid.Cid cid;
  final String pinErrorMsg;
}

/// Result of `ipfs dag import` (pinned roots and `--stats`).
final class KuboCoreCommandsDagCarImportResult {
  KuboCoreCommandsDagCarImportResult._(
      this.roots, this.blockCount, this.blockBytesCount);

  final List<KuboCoreCommandsDagRootMeta> roots;
  final int blockCount;
  final int blockBytesCount;
}

/// Function 35: the CARs come from [files] or, if [car] is not null, from
/// the bytes.
Future<KuboCoreCommandsDagCarImportResult> _import(
    $core.KuboCoreIpfsNode node,
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
  return KuboCoreCommandsDagCarImportResult._(
      r.list(() => KuboCoreCommandsDagRootMeta._($cid.Cid(r.str()), r.str())),
      r.i64(),
      r.i64());
}

/// Go: the hand port of `ipfs dag put/get/export/import`
/// (`Go.kubo.core.commands.dag`).
extension GoKuboCoreCommandsDagApi on GoKuboCoreCommandsDag {
  /// `ipfs dag put`: decodes [data] with [inputCodec], stores it with
  /// [storeCodec] (CIDv1, hash [hash]) and returns the CID. [pin] pins
  /// recursively; [allowBigBlock] allows blocks above 2 MiB
  /// (`--allow-big-block`).
  ///
  /// The CLI uses `Import.HashFunction` from the config as the default hash;
  /// here the default is that config's default value (`sha2-256`).
  Future<$cid.Cid> dagPut(
    $coreiface.KuboCoreCoreifaceCoreApi api,
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
    $coreiface.KuboCoreCoreifaceCoreApi api,
    $context.Context ctx,
    $path.BoxoPath path, {
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
    $core.KuboCoreIpfsNode node,
    $context.Context ctx,
    $path.BoxoPath path, {
    bool localOnly = false,
  }) async {
    final r = await $call(34, _export(node, ctx, path, localOnly, ''));
    return r.bytes() ?? Uint8List(0);
  }

  /// `ipfs dag export > [file]`: writes the CARv1 straight to the file (the
  /// bytes do not go through Dart; use it for large DAGs).
  Future<void> dagExportFile(
    $core.KuboCoreIpfsNode node,
    $context.Context ctx,
    $path.BoxoPath path,
    String file, {
    bool localOnly = false,
  }) async {
    await $call(34, _export(node, ctx, path, localOnly, file));
  }

  /// `ipfs dag import`: stores the blocks of the CAR (v1 or v2) [car] and, with
  /// [pinRoots] (default, `--pin-roots`), pins the roots. Does not use the
  /// network. [allowBigBlock] accepts blocks above 2 MiB.
  Future<KuboCoreCommandsDagCarImportResult> dagImport(
    $core.KuboCoreIpfsNode node,
    $context.Context ctx,
    Uint8List car, {
    bool pinRoots = true,
    bool allowBigBlock = false,
  }) =>
      _import(node, ctx, const [], car, pinRoots, allowBigBlock);

  /// `ipfs dag import [files...]`: reads the CARs straight from the files.
  Future<KuboCoreCommandsDagCarImportResult> dagImportFiles(
    $core.KuboCoreIpfsNode node,
    $context.Context ctx,
    List<String> files, {
    bool pinRoots = true,
    bool allowBigBlock = false,
  }) =>
      _import(node, ctx, files, null, pinRoots, allowBigBlock);
}
