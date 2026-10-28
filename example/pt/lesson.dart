// Compartilhado pelas lições (o roteiro está em example/pt/README.md): o DAG
// de exemplo das lições 03-06, os auxiliares que executam um erro comum de
// propósito e mostram o que acontece de verdade, e say(), que escreve a saída
// da lição.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:p2p_ffi/go/block_format.dart' as blocks;
import 'package:p2p_ffi/go/boxo/blockservice.dart' as blockservice;
import 'package:p2p_ffi/go/boxo/blockstore.dart' as blockstore;
import 'package:p2p_ffi/go/boxo/chunker.dart' as chunker;
import 'package:p2p_ffi/go/boxo/exchange/offline.dart' as offline;
import 'package:p2p_ffi/go/boxo/ipld/merkledag.dart' as merkledag;
import 'package:p2p_ffi/go/boxo/ipld/unixfs/importer.dart' as importer;
import 'package:p2p_ffi/go/boxo/ipld/unixfs/io.dart' as unixfs_io;
import 'package:p2p_ffi/go/bytes.dart' as bytes;
import 'package:p2p_ffi/go/car/v2/blockstore.dart' as car_blockstore;
import 'package:p2p_ffi/go/cid.dart' as cid;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/datastore.dart' as datastore;
import 'package:p2p_ffi/go/datastore/sync.dart' as sync;
import 'package:p2p_ffi/go/ipld_format.dart' as ipld_format;
import 'package:p2p_ffi/p2p_ffi.dart';

/// O exemplo das lições 03 e 04, montado em memória com a mesma pilha
/// (datastore → blockstore → exchange offline → blockservice → DAGService):
/// uma pasta com `data.bin` (600 000 bytes, 3 folhas de 256 KiB) e
/// `hello.txt`.
final class Sample {
  Sample._(this.store, this.dag, this.root, this.data);

  /// Onde os blocos estão.
  final blockstore.Blockstore store;

  /// O DAGService sobre [store].
  final ipld_format.DagService dag;

  /// O CID da pasta.
  final cid.Cid root;

  /// Os bytes de `data.bin`.
  final Uint8List data;

  static Future<Sample> build(context.Context ctx) async {
    final bs = blockstore.Blockstore(sync.mutexWrap(datastore.MapDatastore()));
    final dag =
        merkledag.newDagService(blockservice.new$(bs, offline.exchange(bs)));
    ipld_format.Node file(List<int> data) => importer.buildDagFromReader(
        dag,
        chunker.newSizeSplitter(
            bytes.Buffer(Uint8List.fromList(data)), 256 * 1024));
    final rnd = Random(42);
    final data =
        Uint8List.fromList(List.generate(600000, (_) => rnd.nextInt(256)));
    final dir = unixfs_io.Directory(dag);
    await dir.addChild(ctx, 'data.bin', file(data));
    await dir.addChild(ctx, 'hello.txt', file(utf8.encode('hello\n')));
    final folder = dir.getNode();
    await dag.add(ctx, folder);
    return Sample._(bs, dag, folder.cid(), data);
  }

  /// Os blocos do DAG abaixo de [c], o pai antes dos filhos (lição 05).
  Future<List<blocks.Block>> blocksOf(context.Context ctx, cid.Cid c) async => [
        await store.get(ctx, c),
        for (final l in await ipld_format.getLinks(ctx, dag, c))
          ...await blocksOf(ctx, l.cid!),
      ];

  /// Grava o exemplo inteiro como um CARv2 em [path] (lição 05).
  Future<void> writeCar(context.Context ctx, String path) async {
    final rw = car_blockstore.openReadWrite(path, [root]);
    await rw.putMany(ctx, await blocksOf(ctx, root));
    rw.finalize();
  }
}

/// Um erro comum: executa [action], que tem de falhar, e mostra o que foi
/// feito, o erro, o porquê e o que fazer no lugar. Se não falhar, a lição
/// para: o comportamento que ela ensina mudou.
Future<void> mistake(String done,
    {required String why,
    required String instead,
    required FutureOr<void> Function() action}) async {
  try {
    await action();
  } on Object catch (e) {
    say('✗ $done\n'
        '    erro:       ${e.runtimeType}: ${brief(e)}\n'
        '    por quê:    $why\n'
        '    no lugar:   $instead\n');
    return;
  }
  throw StateError('esperava um erro e não houve nenhum: "$done" '
      '(o comportamento que esta lição ensina mudou)');
}

/// Um erro silencioso: nada falha, mas o resultado está errado. Mostra o
/// resultado errado ao lado do certo; se os dois forem iguais, a lição para.
Future<void> silentlyWrong(String done,
    {required String why,
    required String instead,
    required FutureOr<Object?> Function() wrong,
    required FutureOr<Object?> Function() right}) async {
  final w = '${await wrong()}', r = '${await right()}';
  if (w == r) {
    throw StateError('"$done" deu o mesmo que o jeito certo ($w): '
        'o comportamento que esta lição ensina mudou');
  }
  say('✗ $done (sem erro nenhum)\n'
      '    resultado:  $w\n'
      '    o certo:    $r\n'
      '    por quê:    $why\n'
      '    no lugar:   $instead\n');
}

/// A primeira linha da mensagem de [e], encurtada.
String brief(Object e) {
  final m = (e is GolangException ? e.message : '$e').split('\n').first;
  return m.length > 160 ? '${m.substring(0, 157)}...' : m;
}

/// Bytes em hexadecimal (`1220ab...`), para mostrar hashes e CIDs.
String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Escreve uma linha da lição: no log do `dart:developer`, com o nome do
/// arquivo da lição (filtrável no DevTools e no console de depuração da IDE),
/// e no terminal, onde o `dart run` não mostra esse log.
void say(Object? message) {
  dev.log('$message', name: Platform.script.pathSegments.last);
  print(message);
}
