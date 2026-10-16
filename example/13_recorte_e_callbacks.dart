// Passo 13: recortar um CAR direto do nó e os callbacks do Go chamando o
// Dart. O exemplo 12 recorta de um CAR para outro; aqui o recorte sai dos
// blocos do próprio nó, de dois jeitos: o gateway do boxo (por caminho, com
// escopo e faixa de bytes, como o `?dag-scope=` de um gateway HTTP) e um
// seletor IPLD qualquer sobre o blockstore. No caminho, o callback sob
// demanda: funções Go que recebem uma função (o índice de um CAR, o construtor
// de seletores) recebem uma função Dart.
//
//   dart run example/13_recorte_e_callbacks.dart
//
// Como nos exemplos 10 a 12, cada passo traz o mesmo código em Go.
import 'dart:io';
import 'dart:typed_data';

import 'package:ipfs_ffi/boxo.dart' as boxo;
import 'package:ipfs_ffi/car.dart' as car;
import 'package:ipfs_ffi/go.dart' as go;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsEof, IpfsService;
import 'package:ipfs_ffi/ipld.dart' as ipld;
import 'package:ipfs_ffi/kubo.dart' as kubo;
import 'package:ipfs_ffi/multiformats.dart' as mf;

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_ex13_');
  final repoPath = '${tmp.path}/repo';

  // Serviço, plugins e repo novo: igual ao exemplo 09.
  await IpfsService.start();
  kubo.PluginLoader('')
    ..initialize()
    ..inject();
  final cfg = kubo
      .initWithIdentity(kubo.createIdentity(null, [kubo.key.type('ed25519')]));
  kubo.profiles['test']!.transform(cfg);
  kubo.init(repoPath, cfg);
  final ctx = go.background();
  final n = await kubo.newNode(ctx, kubo.BuildCfg(repo: kubo.open(repoPath)));

  try {
    // Uma pasta com dois arquivos no nó (CIDv1: as fatias viram blocos raw).
    final dir = Directory('${tmp.path}/pasta')..createSync();
    File('${dir.path}/oi.txt').writeAsStringSync('oi\n');
    File('${dir.path}/grande.bin').writeAsBytesSync(
        Uint8List.fromList(List.generate(600000, (i) => i * 7 % 251)));
    final p = await kubo.newCoreApi(n).unixfs().add(
        ctx,
        boxo.newSerialFile(dir.path, false, go.stat(dir.path)),
        [kubo.unixfs.cidVersion(1)]);
    final root = mf.Cid(p.value.substring('/ipfs/'.length));
    print('0. pasta em $root');

    // 1. O gateway do boxo sobre o nó: o CAR de um caminho. Escopo `entity`
    // = os blocos que provam o caminho e o arquivo inteiro; com faixa, só as
    // fatias dos bytes pedidos. O CAR vem num io.ReadCloser, copiado para um
    // arquivo (io.Copy). Busca na rede o que faltar, se o nó estiver online.
    //   Go:   bb, _ := gateway.NewBlocksBackend(node.Blocks)
    //         _, rc, _ := bb.GetCAR(ctx, path, gateway.CarParams{Scope: gateway.DagScopeEntity,
    //             Range: &gateway.DagByteRange{From: 0, To: &to}})
    //         f, _ := os.Create(out); io.Copy(f, rc)
    final backend = boxo.BlocksBackend(n.blocks);
    for (final (name, range) in [
      ('inteiro', null),
      ('100 bytes', boxo.DagByteRange(from: 0, to: 99)),
    ]) {
      final (_, rc) = await backend.getCar(
          ctx,
          boxo.ImmutablePath('/ipfs/$root/grande.bin'),
          boxo.CarParams(scope: boxo.dagScopeEntity, range: range));
      final out = '${tmp.path}/gateway.car';
      final f = go.create(out);
      go.copy(f, rc);
      f.close();
      rc.close();
      print('1. gateway, grande.bin $name: ${blocks(out)} blocos');
    }

    // 2. Um seletor IPLD sobre o blockstore local do nó: o bsadapter faz do
    // blockstore o storage de um LinkSystem. Com a camada UnixFS, o seletor
    // anda pelos nomes da pasta; o escolhedor de protótipo do gateway faz o
    // go-car decodificar dag-pb tipado (sem ele, a pasta não tem "oi.txt").
    //   Go:   ls := cidlink.DefaultLinkSystem()
    //         unixfsnode.AddUnixFSReificationToLinkSystem(&ls)
    //         ls.SetReadStorage(&bsadapter.Adapter{Wrapped: node.Blockstore})
    //         car.TraverseToFile(ctx, &ls, root, unixfsnode.UnixFSPathSelector("oi.txt"), out,
    //             car.WithTraversalPrototypeChooser(dagpb.AddSupportToChooser(bsfetcher.DefaultPrototypeChooser)))
    final ls = ipld.defaultLinkSystem();
    ipld.addUnixFsReificationToLinkSystem(ls);
    ls.setReadStorage(ipld.Adapter()..wrapped = n.blockstore);
    final oi = '${tmp.path}/oi.car';
    await car
        .traverseToFile(ctx, ls, root, ipld.unixFsPathSelector('oi.txt'), oi, [
      car.withTraversalPrototypeChooser(
          ipld.addSupportToChooser(boxo.defaultPrototypeChooser))
    ]);
    print(
        '2. seletor UnixFS "oi.txt": ${blocks(oi)} blocos (a pasta e o arquivo)');

    // 3. O construtor de seletores, alternativa ao JSON. O exploreFields
    // recebe uma função Go que monta os campos; no Dart, uma função Dart: o
    // Go a chama e espera a resposta (callback sob demanda, lote 1 aqui:
    // o `fields` só vale durante a chamada).
    //   Go:   ssb := builder.NewSelectorSpecBuilder(basicnode.Prototype.Any)
    //         sel := ssb.ExploreFields(func(f builder.ExploreFieldsSpecBuilder) {
    //             f.Insert("Links", ssb.ExploreAll(ssb.ExploreFields(func(g ...) {
    //                 g.Insert("Hash", ssb.Matcher()) }))) })
    final ssb = ipld.SelectorSpecBuilder(ipld.PrototypeAny());
    final links = await ssb.exploreFields((f) async {
      f.insert(
          'Links',
          ssb.exploreAll(await ssb.exploreFields((g) {
            g.insert('Hash', ssb.matcher());
          })));
    });
    final plain = ipld.defaultLinkSystem()
      ..setReadStorage(ipld.Adapter()..wrapped = n.blockstore);
    final filhos = '${tmp.path}/filhos.car';
    await car.traverseToFile(ctx, plain, root, links.node(), filhos);
    print('3. a raiz e os filhos diretos: ${blocks(filhos)} blocos');

    // 4. O índice de um CAR, percorrido com callback. O Go manda os
    // argumentos em lotes (batchSize; padrão 1024, medido) e espera o Dart:
    // false, ou uma exceção, param o Go. Enquanto o forEach roda, o índice
    // está "em uso" (isBusy, e o IpfsService.busy avisa): chamá-lo de dentro
    // do callback pode esperar uma trava que o Go segura; se esperar, o host
    // detecta e lança IpfsDeadlockException em vez de travar.
    //   Go:   idx, _ := car.GenerateIndexFromFile(path)
    //         idx.(index.IterableIndex).ForEach(func(mh multihash.Multihash, off uint64) error {...})
    final watch = IpfsService.busy
        .listen((c) => print('   (índice ${c.busy ? 'em uso' : 'livre'})'));
    final idx = car.generateIndexFromFile(oi);
    var vistos = 0;
    await idx.asIterableIndex()!.forEach((mh, offset) {
      vistos++;
      print('4. entrada: multihash de ${mh.length} bytes no byte $offset '
          '(isBusy: ${idx.isBusy})');
    });
    await Future<void>.delayed(
        Duration.zero); // o aviso de "livre" chega depois
    await watch.cancel();
    print('4. $vistos entradas');

    // 5. Os erros conhecidos do Go chegam como subclasses de
    // IpfsException: o fim de uma leitura é IpfsEof (o io.EOF do Go).
    //   Go:   for { b, err := br.Next(); if errors.Is(err, io.EOF) { break } }
    final br = car.BlockReader(File(oi).readAsBytesSync());
    var lidos = 0;
    try {
      while (true) {
        br.next();
        lidos++;
      }
    } on IpfsEof {
      print('5. BlockReader: $lidos blocos, depois IpfsEof');
    }
  } finally {
    await n.close();
    await IpfsService.stop();
    tmp.deleteSync(recursive: true);
  }
}

/// Quantos blocos o CAR em [file] tem (o Reader mapeia o arquivo: fechar).
int blocks(String file) {
  final r = car.openReader(file);
  try {
    return r.inspect(false).blockCount;
  } finally {
    r.close();
  }
}
