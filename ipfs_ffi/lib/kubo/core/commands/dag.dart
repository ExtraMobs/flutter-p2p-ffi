/// `ipfs dag put` e `ipfs dag get` (escrito à mão; Go em go/manual_dag.go):
/// gravar e ler objetos IPLD em DAG-CBOR, DAG-JSON, JSON, CBOR, raw ou dag-pb.
/// No kubo isso é o corpo dos comandos (core/commands/dag/put.go e get.go),
/// não uma função de biblioteca. Os padrões são os do CLI.
///
/// ```dart
/// import 'package:ipfs_ffi/kubo/core/commands/dag.dart' as dag;
///
/// final c = await dag.put(api, ctx, utf8.encode('{"a": 1}')); // dag-json → dag-cbor
/// final json = await dag.get(api, ctx, path.Path('/ipfs/$c/a'));
/// ```
library;

import 'dart:typed_data';

import 'package:ipfs_ffi/boxo/path.dart' as $path;
import 'package:ipfs_ffi/context.dart' as $context;
import 'package:ipfs_ffi/go_cid.dart' as $go_cid;
import 'package:ipfs_ffi/kubo/core/coreiface.dart' as $coreiface;
import 'package:ipfs_ffi/src/runtime.dart';

/// `ipfs dag put`: decodifica [data] com [inputCodec], grava com [storeCodec]
/// (CIDv1, hash [hash]) e devolve o CID. [pin] pina recursivamente;
/// [allowBigBlock] libera blocos acima de 2 MiB (`--allow-big-block`).
///
/// O CLI usa `Import.HashFunction` da config como hash padrão; aqui o padrão é
/// o valor padrão dessa config (`sha2-256`).
Future<$go_cid.Cid> put(
  $coreiface.CoreApi api,
  $context.Context ctx,
  Uint8List data, {
  String inputCodec = 'dag-json',
  String storeCodec = 'dag-cbor',
  String hash = 'sha2-256',
  bool pin = false,
  bool allowBigBlock = false,
}) async {
  final r = await $call('kubo/core/commands/dag.put',
      [api, ctx, data, inputCodec, storeCodec, hash, pin, allowBigBlock]);
  return $go_cid.Cid($nn(r) as String);
}

/// `ipfs dag get`: o nó em [path] (que pode continuar dentro dele, ex.
/// `/ipfs/<cid>/a/b`) codificado com [outputCodec].
Future<Uint8List> get(
  $coreiface.CoreApi api,
  $context.Context ctx,
  $path.Path path, {
  String outputCodec = 'dag-json',
}) async {
  final r =
      await $call('kubo/core/commands/dag.get', [api, ctx, path, outputCodec]);
  return $bytes(r);
}
