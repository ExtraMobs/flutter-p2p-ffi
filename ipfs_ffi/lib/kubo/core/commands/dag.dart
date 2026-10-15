/// `ipfs dag put/get` e `ipfs dag export/import` (arquivos CAR), escritos à
/// mão (funções 32–35 do WIRE.md); Go em go/manual_dag.go e go/manual_car.go:
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
import 'package:ipfs_ffi/kubo/core.dart' as $core;
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
  return r.p() ? $go_cid.Cid(r.str()) : $nil();
}

/// `ipfs dag get`: o nó em [path] (que pode continuar dentro dele, ex.
/// `/ipfs/<cid>/a/b`) codificado com [outputCodec].
Future<Uint8List> get(
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

/// `ipfs dag export`: o DAG de [path] como CARv1 em memória. [localOnly]
/// (`--local-only`) não toca a rede e pula o que não estiver no repo (CAR
/// parcial). Precisa do nó (como o comando do kubo), não só da CoreAPI.
Future<Uint8List> exportCar(
  $core.IpfsNode node,
  $context.Context ctx,
  $path.Path path, {
  bool localOnly = false,
}) async {
  final r = await $call(34, _export(node, ctx, path, localOnly, ''));
  return r.bytes() ?? Uint8List(0);
}

/// `ipfs dag export > [file]`: grava o CARv1 direto no arquivo (os bytes não
/// passam pelo Dart; use para DAGs grandes).
Future<void> exportCarFile(
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

/// Raiz de um CAR importado (`RootMeta` do kubo): [pinErrorMsg] vazio quando
/// o pin deu certo.
final class RootMeta {
  RootMeta._(this.cid, this.pinErrorMsg);

  final $go_cid.Cid cid;
  final String pinErrorMsg;
}

/// Resultado do `ipfs dag import` (raízes pinadas e `--stats`).
final class CarImportResult {
  CarImportResult._(this.roots, this.blockCount, this.blockBytesCount);

  final List<RootMeta> roots;
  final int blockCount;
  final int blockBytesCount;
}

/// Função 35: os CARs vêm de [files] ou, se [car] não for null, dos bytes.
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
      r.list(() => RootMeta._($go_cid.Cid(r.str()), r.str())),
      r.i64(),
      r.i64());
}

/// `ipfs dag import`: grava os blocos do CAR (v1 ou v2) [car] e, com
/// [pinRoots] (padrão, `--pin-roots`), pina as raízes. Não usa a rede.
/// [allowBigBlock] aceita blocos acima de 2 MiB.
Future<CarImportResult> importCar(
  $core.IpfsNode node,
  $context.Context ctx,
  Uint8List car, {
  bool pinRoots = true,
  bool allowBigBlock = false,
}) =>
    _import(node, ctx, const [], car, pinRoots, allowBigBlock);

/// `ipfs dag import [files...]`: lê os CARs direto dos arquivos.
Future<CarImportResult> importCarFiles(
  $core.IpfsNode node,
  $context.Context ctx,
  List<String> files, {
  bool pinRoots = true,
  bool allowBigBlock = false,
}) =>
    _import(node, ctx, files, null, pinRoots, allowBigBlock);
