// Lição 06 · O que mais dá para fazer com um CAR?
//
// Pergunta: a lição 05 gravou e leu um CAR. O que são CARv1 e CARv2, para que
// serve o índice, posso trocar as raízes, ficar só com parte do DAG, ou juntar
// dois CARs?
//
// Resposta:
//   - CARv1 é o formato simples: cabeçalho (raízes) + blocos. É o que o
//     `ipfs dag export` grava e o que os gateways mandam. Ler um bloco
//     significa varrer o arquivo.
//   - CARv2 embrulha um CARv1 (byte a byte) entre um cabeçalho pequeno e um
//     índice: CID → posição, para achar um bloco sem varrer. O blockstore de
//     leitura e escrita da lição 05 grava CARv2.
//   - As raízes ficam no cabeçalho; podem ser reescritas no lugar se os CIDs
//     novos ocuparem os mesmos bytes.
//   - Uma parte é um passeio pelo DAG com um seletor IPLD ("este caminho",
//     "só a raiz", "tudo") gravado como um CAR novo.
//   - Juntar é copiar os blocos de cada CAR para um novo, com as raízes de
//     todos.
//
// Precisa de: lição 05 (um CAR do exemplo). O passeio com seletor também
// precisa de um LinkSystem (o jeito do go-ipld-prime de carregar blocos por
// link) lendo do CAR, da camada UnixFS (para o seletor andar por nomes de
// arquivo) e do prototype chooser dag-pb (para os blocos dag-pb serem
// decodificados como nós UnixFS).
//
//   dart run example/pt_br/06_car_more.dart
//
// Próxima pergunta: "Fazer tudo isso à mão é muita pilha; um nó IPFS me dá a
// pilha pronta, em disco?" → lição 07.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson06_');
  String at(String name) => '${tmp.path}/$name';
  try {
    final ctx = Go.context.background();
    final s = await Sample.build(ctx);
    final v2 = at('folder.v2.car');
    await s.writeCar(ctx, v2);
    int count(String path) {
      final r = Go.car.v2.openReader(path);
      try {
        return r.inspect(true).blockCount;
      } finally {
        r.close();
      }
    }

    // 1. CARv2 → CARv1 e de volta. O v1 dentro de um v2 são os mesmos bytes.
    //    Go:  car.ExtractV1File(v2, v1); car.WrapV1File(v1, again)
    final v1 = at('folder.v1.car');
    Go.car.v2.extractV1File(v2, v1);
    final again = at('folder.again.car');
    Go.car.v2.wrapV1File(v1, again);
    say('CARv2 ${File(v2).lengthSync()} bytes → CARv1 '
        '${File(v1).lengthSync()} bytes (versão '
        '${Go.car.v2.readVersion(File(v1).readAsBytesSync())}) → CARv2 '
        '${File(again).lengthSync()} bytes');
    final r = Go.car.v2.openReader(again);
    try {
      final h = r.header;
      say('  o cabeçalho v2: os dados v1 em ${h.dataOffset}..'
          '${h.dataOffset + h.dataSize}, o índice em ${h.indexOffset}');
    } finally {
      r.close();
    }

    // 2. O índice: onde cada bloco começa. Montado a partir de um v1 (uma
    //    varredura), guardado ao lado dele, carregado de volta.
    //    Go:  idx, _ := car.GenerateIndexFromFile(v1)
    //         off, _ := index.GetFirst(idx, root)
    //         index.WriteTo(idx, f); idx2, _ := index.ReadFrom(f2)
    final idx = Go.car.v2.generateIndexFromFile(v1);
    say('\no índice do v1: o bloco raiz está no byte '
        '${Go.car.v2.index.getFirst(idx, s.root)}');
    final idxFile = '$v1.idx';
    final w = Go.os.create(idxFile);
    final n = Go.car.v2.index.writeTo(idx, w);
    w.close();
    final rd = Go.os.open(idxFile);
    final loaded = Go.car.v2.index.readFrom(rd);
    rd.close();
    say('  gravei $n bytes em ${idxFile.split('/').last}; carregado de '
        'volta: a raiz no byte ${Go.car.v2.index.getFirst(loaded, s.root)}');

    // 3. Trocar as raízes: aqui o CAR passa a começar em data.bin (um CIDv0
    //    como a pasta, então do mesmo tamanho).
    //    Go:  car.ReplaceRootsInFile(path, []cid.Cid{dataBin})
    final folder = await s.dag.get(ctx, s.root);
    final dataBin = folder.links().first.cid!;
    final copy = at('copy.car');
    File(v2).copySync(copy);
    Go.car.v2.replaceRootsInFile(copy, [dataBin]);
    final rc = Go.car.v2.openReader(copy);
    try {
      say('\nraízes trocadas: ${rc.roots()} (no CAR: '
          '${rc.inspect(false).rootsPresent})');
    } finally {
      rc.close();
    }

    // 4. Uma parte: percorra o DAG com um seletor e grave o que ele visita.
    //    Go:  ls := cidlink.DefaultLinkSystem()
    //         unixfsnode.AddUnixFSReificationToLinkSystem(&ls)
    //         src, _ := storage.OpenReadable(f); ls.SetReadStorage(src)
    //         car.TraverseToFile(ctx, &ls, root, selector, out,
    //             car.WithTraversalPrototypeChooser(
    //                 dagpb.AddSupportToChooser(bsfetcher.DefaultPrototypeChooser)))
    final dagPbChooser = Go.car.v2.withTraversalPrototypeChooser(Go.codecDagpb
        .addSupportToChooser(
            Go.boxo.fetcher.impl.blockservice.defaultPrototypeChooser));
    Future<int> select(String name, IpldPrimeDatamodelNode selector,
        [List<CarV2Option>? opts]) async {
      final f = Go.os.open(v2);
      try {
        final ls = Go.ipldPrime.linking.cid.defaultLinkSystem();
        Go.unixfsnode.addUnixFsReificationToLinkSystem(ls);
        ls.setReadStorage(Go.car.v2.storage.openReadable(f));
        final out = at('$name.car');
        await Go.car.v2.traverseToFile(
            ctx, ls, s.root, selector, out, opts ?? [dagPbChooser]);
        return count(out);
      } finally {
        f.close();
      }
    }

    say('\npartes da pasta (${count(v2)} blocos):');
    say('  só o bloco raiz:      '
        '${await select('root', Go.ipldPrime.traversal.selector.parse.commonSelectorMatchPoint)} bloco');
    say('  o caminho hello.txt:  '
        '${await select('hello', Go.unixfsnode.unixFsPathSelector('hello.txt'))}'
        ' blocos (a pasta, hello.txt)');
    say('  o caminho data.bin:   '
        '${await select('data', Go.unixfsnode.unixFsPathSelector('data.bin'))}'
        ' blocos (a pasta, data.bin, as 3 folhas)');
    say('  tudo:                 '
        '${await select('all', Go.ipldPrime.traversal.selector.parse.commonSelectorExploreAllRecursively)}'
        ' blocos');

    // 5. Juntar: um CAR novo com as raízes e os blocos dos dois.
    //    Go:  rw, _ := blockstore.OpenReadWrite(out, append(rootsA, rootsB...))
    //         para cada um: br, _ := car.NewBlockReader(f); for { b, _ := br.Next(); rw.Put(ctx, b) }
    //         rw.Finalize()
    final note = Uint8List.fromList(utf8.encode('a second CAR'));
    final noteCid =
        Go.cid.newPrefixV1(Go.multicodec.raw, Go.multihash.sha2256).sum(note);
    final second = at('second.car');
    final sw = Go.car.v2.blockstore.openReadWrite(second, [noteCid]);
    await sw.put(ctx, BlockFormatBlock(cid: noteCid, rawData: note));
    sw.finalize();
    final merged = at('merged.car');
    final rw = Go.car.v2.blockstore.openReadWrite(merged, [s.root, noteCid]);
    for (final source in [v1, second]) {
      final f = Go.os.open(source);
      try {
        final br = CarV2BlockReader(f);
        final batch = <BlockFormatBlock>[];
        while (true) {
          try {
            batch.add(br.next());
          } on GolangEofException {
            break;
          }
        }
        await rw.putMany(ctx, batch);
      } finally {
        f.close();
      }
    }
    rw.finalize();
    final rm = Go.car.v2.openReader(merged);
    try {
      say('\njuntos: ${rm.inspect(true).blockCount} blocos, raízes '
          '${rm.roots()}');
    } finally {
      rm.close();
    }

    say('\n== Erros comuns\n');
    await mistake('extrair o v1 de um CAR que já é v1',
        why: 'não há embrulho v2 para tirar',
        instead: 'confira Go.car.v2.readVersion antes',
        action: () => Go.car.v2.extractV1File(v1, at('x.car')));
    await mistake('embrulhar um CAR que já é v2 (e depois lê-lo)',
        why: 'o wrapV1File toma o cabeçalho v2 como dados v1: grava sem '
            'reclamar e o arquivo só falha ao ser lido',
        instead: 'confira Go.car.v2.readVersion antes; embrulhe só v1',
        action: () {
      final twice = at('twice.car');
      Go.car.v2.wrapV1File(v2, twice);
      count(twice);
    });
    await mistake('trocar a raiz por um CID de outro tamanho',
        why: 'o cabeçalho é reescrito no lugar: as raízes novas têm de ocupar '
            'os mesmos bytes (aqui um CIDv1 no lugar de um CIDv0)',
        instead: 'um CID da mesma versão e codec, ou copie os blocos para um '
            'CAR novo (passo 5) com as raízes novas',
        action: () => Go.car.v2.replaceRootsInFile(
            copy, [Go.cid.newCidV1(Go.multicodec.dagPb, dataBin.hash())]));
    await silentlyWrong('selecionar por caminho sem o chooser dag-pb',
        why: 'o go-car decodifica dag-pb como dados genéricos, a camada UnixFS '
            'não acha "data.bin" neles, e o passeio para na raiz',
        instead:
            'passe Go.car.v2.withTraversalPrototypeChooser(...) como no passo 4',
        wrong: () async =>
            '${await select('nochooser', Go.unixfsnode.unixFsPathSelector('data.bin'), [])} blocos',
        right: () async =>
            '${await select('chooser', Go.unixfsnode.unixFsPathSelector('data.bin'))} blocos');
    await mistake('juntar dentro de um dos CARs de origem',
        why: 'o openReadWrite num arquivo existente o retoma, e só um CARv2 '
            'gravado por ele mesmo pode ser retomado; um v1 é recusado',
        instead: 'grave num arquivo novo, depois substitua a origem se '
            'precisar',
        action: () => Go.car.v2.blockstore
            .openReadWrite(v1, [s.root, noteCid]).discard());
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
