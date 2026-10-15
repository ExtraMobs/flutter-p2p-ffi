/// `ipfs dag put/get`, hand-written (functions 32 and 33 of WIRE.md; Go in
/// go/manual_dag.go): store and read IPLD objects in DAG-CBOR, DAG-JSON, JSON,
/// CBOR, raw or dag-pb. In kubo this is the body of the commands
/// (core/commands/dag/put.go and get.go), not a library function. The defaults
/// are the CLI's. CAR files (`ipfs dag export/import`) are in
/// `package:ipfs_ffi/car.dart`.
///
/// ```dart
/// import 'package:ipfs_ffi/kubo.dart' as kubo;
///
/// final c = await kubo.dagPut(api, ctx, utf8.encode('{"a": 1}')); // dag-json → dag-cbor
/// final json = await kubo.dagGet(api, ctx, boxo.Path('/ipfs/$c/a'));
/// ```
library;

import 'dart:typed_data';

import 'package:ipfs_ffi/boxo/path.dart' as $path;
import 'package:ipfs_ffi/go/context.dart' as $context;
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
