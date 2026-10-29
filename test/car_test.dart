// O go-car (github.com/ipld/go-car/v2, namespace `car`, 0.16.0): arquivos CAR
// sem nó. O nó só monta o CAR de entrada (uma pasta pelo Unixfs, CIDv1 com
// folhas raw, exportada pelo dagExportFile); o resto é o go-car direto:
// leitura, conversões v1/v2, índice, blockstore e a travessia seletiva.
// Exige `dart run tool/build.dart`.
import 'dart:io' show Directory, File;
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';
import 'package:test/test.dart';

const dagPb = 0x70, raw = 0x55, sha256 = 0x12;

void main() {
  late Directory tmp;
  late String v1; // o CARv1 do dagExportFile
  late Cid root;
  late int blocks; // quantos blocos o CAR tem
  late Context ctx;
  late KuboCoreIpfsNode n; // aberto até o fim: o recorte pelo nó
  late KuboCoreCoreifaceCoreApi api;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('p2p_ffi_car_');
    await P2pService.start();
    ctx = go.context.background();
    KuboPluginLoader('')
      ..initialize()
      ..inject();
    final cfg = go.ipfs.kubo.config.initWithIdentity(go.ipfs.kubo.config
        .createIdentity(
            null, [go.ipfs.kubo.core.coreiface.options.key.type('ed25519')]));
    go.ipfs.kubo.config.profiles['test']!.transform(cfg);
    go.ipfs.kubo.repo.fsrepo.init('${tmp.path}/repo', cfg);
    n = await go.ipfs.kubo.core.newNode(
        ctx,
        KuboCoreNodeBuildCfg(
            repo: go.ipfs.kubo.repo.fsrepo.open('${tmp.path}/repo')));
    api = go.ipfs.kubo.core.coreapi.newCoreApi(n);

    final dir = Directory('${tmp.path}/pasta')..createSync();
    File('${dir.path}/a.txt').writeAsStringSync('A' * 1000);
    File('${dir.path}/b.txt').writeAsStringSync('B' * 600000);
    final p = await api.unixfs().add(
        ctx,
        go.ipfs.boxo.files.newSerialFile(dir.path, false, go.os.stat(dir.path)),
        [
          go.ipfs.kubo.core.coreiface.options.unixfs.cidVersion(1),
          go.ipfs.kubo.core.coreiface.options.unixfs.chunker('size-262144')
        ]);
    root = Cid(p.value.substring('/ipfs/'.length));
    v1 = '${tmp.path}/base.car';
    await go.ipfs.kubo.core.commands.dag.dagExportFile(n, ctx, p, v1);
    final r = go.ipld.car.v2.openReader(v1);
    blocks = r.inspect(false).blockCount;
    r.close();
  });

  tearDownAll(() async {
    await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  });

  test('leitura: versão, raízes e estatísticas (Reader.inspect)', () {
    final r = go.ipld.car.v2.openReader(v1);
    expect(r.version, 1);
    expect(r.roots(), [root]);
    final st = r.inspect(true); // confere o hash de cada bloco
    r.close();
    expect(st.blockCount, blocks);
    // pasta + a.txt + b.txt (raiz + 3 fatias, mas as duas primeiras são
    // iguais: o mesmo CID, um bloco só)
    expect(blocks, 5);
    expect(st.rootsPresent, isTrue);
    expect(st.codecCounts, {dagPb: 2, raw: 3}); // mapa de chave multicodec
    expect(st.mhTypeCounts, {sha256: 5});
    expect(go.ipld.car.v2.readVersion(File(v1).readAsBytesSync()), 1);
  });

  test('BlockReader: bloco a bloco, por bytes e por arquivo', () {
    final bytes = File(v1).readAsBytesSync();
    final br = CarV2BlockReader(bytes);
    expect(br.version, 1);
    expect(br.roots, [root]);
    final seen = <Cid>[];
    while (true) {
      try {
        final b = br.next();
        seen.add(b.cid!);
        expect(b.rawData, isNotEmpty);
      } on GolangEofException {
        break; // o io.EOF do Go: acabou
      }
    }
    expect(seen, hasLength(blocks));
    expect(seen.first, root); // o export começa pela raiz

    final f = go.os.open(v1);
    final br2 = CarV2BlockReader(f);
    final (c, data, size) = br2.nextReader();
    expect(c, root);
    expect(go.io.readAll(data), hasLength(size));
    final meta = br2.skipNext();
    expect(meta.cid, seen[1]);
    expect(meta.size, greaterThan(0));
    f.close();
  });

  test('conversões: wrap/extract, raízes trocadas, cabeçalho v2', () {
    final v2 = '${tmp.path}/v2.car';
    go.ipld.car.v2.wrapV1File(v1, v2);
    final r = go.ipld.car.v2.openReader(v2);
    expect(r.version, 2);
    final h = r.header;
    expect(h.hasIndex(), isTrue); // o wrap gera o índice
    expect(h.dataOffset, go.ipld.car.v2.pragmaSize + go.ipld.car.v2.headerSize);
    expect(h.characteristics!.isFullyIndexed(), isFalse);
    expect(h.withDataSize(7).dataSize, 7); // método de DTO: cópia nova
    expect(h.dataSize, isNot(7));
    expect(go.io.readAll(r.dataReader()), File(v1).readAsBytesSync());
    r.close();

    final back = '${tmp.path}/back.car';
    go.ipld.car.v2.extractV1File(v2, back);
    expect(File(back).readAsBytesSync(), File(v1).readAsBytesSync());

    // wrap de bytes (io.ReadSeeker) para um bytes.Buffer (io.Writer)
    final buf = BytesBuffer(Uint8List(0));
    go.ipld.car.v2.wrapV1(File(v1).readAsBytesSync(), buf);
    expect(go.ipld.car.v2.readVersion(buf.bytes()), 2);

    // troca a raiz por uma folha (o mesmo tamanho de CID)
    final leaf = CarV2BlockReader(File(v1).readAsBytesSync())
      ..next()
      ..next();
    final other = leaf.next().cid!;
    go.ipld.car.v2.replaceRootsInFile(v2, [other]);
    expect(go.ipld.car.v2.openReader(v2).roots(), [other]);
  });

  test('índice: gera, consulta, serializa e anexa', () {
    final idx = go.ipld.car.v2.generateIndexFromFile(v1);
    expect(idx.codec(), go.multiformats.multicodec.carMultihashIndexSorted);
    final at = go.ipld.car.v2.index.getFirst(idx, root);
    expect(at, greaterThan(0));

    // serializado num bytes.Buffer e lido de volta
    final buf = BytesBuffer(Uint8List(0));
    final n = go.ipld.car.v2.index.writeTo(idx, buf);
    final bytes = buf.bytes();
    expect(bytes, hasLength(n));
    expect(go.ipld.car.v2.index.readCodec(bytes),
        go.multiformats.multicodec.carMultihashIndexSorted);
    expect(
        go.ipld.car.v2.index
            .getFirst(go.ipld.car.v2.index.readFrom(bytes), root),
        at);

    // outro codec, carregado de registros
    final sorted =
        go.ipld.car.v2.index.new$(go.multiformats.multicodec.carIndexSorted);
    sorted.load([CarV2IndexRecord(cid: root, offset: 42)]);
    expect(go.ipld.car.v2.index.getFirst(sorted, root), 42);
  });

  test('blockstore: ReadWrite bloco a bloco e ReadOnly', () async {
    final prefix = go.ipfs.cid.newPrefixV1(raw, sha256);
    final datas = [
      for (var i = 0; i < 3; i++) Uint8List.fromList([i, i, i])
    ];
    final cids = [for (final d in datas) prefix.sum(d)];
    final file = '${tmp.path}/novo.car';

    final rw = go.ipld.car.v2.blockstore.openReadWrite(file, [cids.first]);
    await rw.put(ctx, BlockFormatBlock(cid: cids[0], rawData: datas[0]));
    await rw.putMany(ctx, [
      for (var i = 1; i < 3; i++)
        BlockFormatBlock(cid: cids[i], rawData: datas[i])
    ]);
    expect(await rw.has(ctx, cids[2]), isTrue);
    expect((await rw.get(ctx, cids[1])).rawData, datas[1]);
    rw.finalize();

    final ro = go.ipld.car.v2.blockstore.openReadOnly(file);
    expect(ro.roots(), [cids.first]);
    expect(await ro.getSize(ctx, cids[0]), 3);
    expect((await ro.get(ctx, cids[2])).rawData, datas[2]);
    expect(await ro.has(ctx, prefix.sum(Uint8List(1))), isFalse);
    expect((await ro.allKeysChan(ctx).toList()).toSet(), cids.toSet());
    ro.close();
    expect(go.ipld.car.v2.openReader(file).inspect(true).blockCount, 3);
  });

  test('travessia seletiva: CAR → seletor → CAR', () async {
    final ls = go.ipld.ipldPrime.linking.cid.defaultLinkSystem();
    final src = go.os.open(v1);
    final readable = go.ipld.car.v2.storage.openReadable(src);
    expect(readable.roots(), [root]);
    ls.setReadStorage(readable);

    final only = '${tmp.path}/raiz.car';
    await go.ipld.car.v2.traverseToFile(
        ctx,
        ls,
        root,
        go.ipld.ipldPrime.traversal.selector.parse.commonSelectorMatchPoint,
        only);
    expect(go.ipld.car.v2.openReader(only).inspect(true).blockCount, 1);

    final all = '${tmp.path}/tudo.car';
    await go.ipld.car.v2.traverseToFile(
        ctx,
        ls,
        root,
        go.ipld.ipldPrime.traversal.selector.parse
            .commonSelectorExploreAllRecursively,
        all);
    expect(go.ipld.car.v2.openReader(all).inspect(true).blockCount, blocks);

    // CARv1 para um io.Writer, com seletor em JSON
    final buf = BytesBuffer(Uint8List(0));
    final size = await go.ipld.car.v2.traverseV1(
        ctx,
        ls,
        root,
        go.ipld.ipldPrime.traversal.selector.parse
            .parseJsonSelector('{".":{}}'),
        buf);
    expect(buf.bytes(), hasLength(size));
    expect(CarV2BlockReader(buf.bytes()).roots, [root]);
    src.close();
  });

  test('sentinelas do Go viram subclasses de GolangException', () async {
    final missing =
        go.ipfs.cid.newPrefixV1(raw, sha256).sum(Uint8List.fromList([9]));
    final ro = go.ipld.car.v2.blockstore.openReadOnly(v1);
    await expectLater(
        ro.get(ctx, missing), throwsA(isA<GolangNotFoundException>()));
    ro.close();

    // o unixfs.add olha o contexto antes de começar
    final (c, cancel) = go.context.withCancel(go.context.background());
    cancel();
    await expectLater(
        api.unixfs().add(c, go.ipfs.boxo.files.newBytesFile(Uint8List(1))),
        throwsA(isA<GolangCanceledException>()));
    final (d, cancel2) =
        go.context.withTimeout(go.context.background(), Duration.zero);
    await expectLater(
        api.unixfs().add(d, go.ipfs.boxo.files.newBytesFile(Uint8List(1))),
        throwsA(isA<GolangDeadlineExceededException>()));
    cancel2();
  });

  group('recorte pelo nó', () {
    /// Os CIDs dos blocos de um CAR em bytes.
    List<Cid> cids(Uint8List bytes) {
      final br = CarV2BlockReader(bytes);
      final out = <Cid>[];
      while (true) {
        try {
          out.add(br.next().cid!);
        } on GolangEofException {
          return out;
        }
      }
    }

    /// O CAR do caminho [p] pelo gateway do boxo sobre o nó.
    Future<(BoxoGatewayContentPathMetadata, Uint8List)> getCar(
        String p, BoxoGatewayCarParams params) async {
      final backend = BoxoGatewayBlocksBackend(n.blocks);
      final (meta, rc) =
          await backend.getCar(ctx, BoxoPathImmutablePath(p), params);
      final bytes = go.io.readAll(rc);
      rc.close();
      return (meta, bytes);
    }

    /// Quantos blocos o CAR em [file] tem.
    int count(String file) {
      final r =
          go.ipld.car.v2.openReader(file); // mapeia o arquivo: fechar (Windows)
      try {
        return r.inspect(true).blockCount;
      } finally {
        r.close();
      }
    }

    test('gateway.getCar: escopos e faixa de bytes', () async {
      final (_, all) = await getCar('/ipfs/$root',
          BoxoGatewayCarParams(scope: go.ipfs.boxo.gateway.dagScopeAll));
      expect(cids(all), hasLength(blocks));
      final (_, one) = await getCar('/ipfs/$root',
          BoxoGatewayCarParams(scope: go.ipfs.boxo.gateway.dagScopeBlock));
      expect(cids(one), [root]);
      // a pasta (para provar o caminho) e o b.txt inteiro: raiz e 2 fatias
      final (meta, entity) = await getCar('/ipfs/$root/b.txt',
          BoxoGatewayCarParams(scope: go.ipfs.boxo.gateway.dagScopeEntity));
      expect(meta.pathSegmentRoots, [root]);
      expect(cids(entity), hasLength(4));
      expect(cids(entity).first, root);
      // só os primeiros 100 bytes: a primeira fatia
      final (_, range) = await getCar(
          '/ipfs/$root/b.txt',
          BoxoGatewayCarParams(
              scope: go.ipfs.boxo.gateway.dagScopeEntity,
              range: BoxoGatewayDagByteRange(from: 0, to: 99)));
      expect(cids(range), hasLength(3));
    });

    /// LinkSystem sobre o blockstore local do nó (bsadapter).
    IpldPrimeLinkingLinkSystem nodeLinks({bool unixfs = false}) {
      final ls = go.ipld.ipldPrime.linking.cid.defaultLinkSystem();
      if (unixfs) go.ipfs.unixfsnode.addUnixFsReificationToLinkSystem(ls);
      ls.setReadStorage(
          IpldPrimeStorageBsadapterAdapter()..wrapped = n.blockstore);
      return ls;
    }

    test('seletor qualquer sobre o blockstore local (bsadapter)', () async {
      final out = '${tmp.path}/bs.car';
      await go.ipld.car.v2.traverseToFile(
          ctx,
          nodeLinks(),
          root,
          go.ipld.ipldPrime.traversal.selector.parse
              .commonSelectorExploreAllRecursively,
          out);
      expect(count(out), blocks);
    });

    test('seletor UnixFS pelo nome do arquivo', () async {
      // a reificação UnixFS só pega nós dag-pb tipados: o escolhedor do
      // gateway (sem ele, o go-car decodifica genérico e o caminho não anda)
      final chooser = [
        go.ipld.car.v2.withTraversalPrototypeChooser(go.ipld.codecDagpb
            .addSupportToChooser(
                go.ipfs.boxo.fetcher.impl.blockservice.defaultPrototypeChooser))
      ];
      for (final (name, want) in [('b.txt', 4), ('a.txt', 2)]) {
        final out = '${tmp.path}/$name.car';
        await go.ipld.car.v2.traverseToFile(ctx, nodeLinks(unixfs: true), root,
            go.ipfs.unixfsnode.unixFsPathSelector(name), out, chooser);
        expect(count(out), want, reason: name);
      }
    });

    test('construtor de seletores, com exploreFields (callback)', () async {
      final ssb = IpldPrimeTraversalSelectorBuilderSelectorSpecBuilder(
          IpldPrimeNodeBasicnodePrototypeAny());
      final everything = ssb.exploreRecursive(
          go.ipld.ipldPrime.traversal.selector.recursionLimitNone(),
          ssb.exploreAll(ssb.exploreRecursiveEdge()));
      // os links da raiz: Links/*/Hash (dag-pb no modelo de dados)
      final links = await ssb.exploreFields((f) async {
        f.insert(
            'Links',
            ssb.exploreAll(await ssb.exploreFields((g) {
              g.insert('Hash', ssb.matcher());
            })));
      });
      for (final (spec, want) in [(everything, blocks), (links, 3)]) {
        final out = '${tmp.path}/sel.car';
        await go.ipld.car.v2
            .traverseToFile(ctx, nodeLinks(), root, spec.node(), out);
        expect(count(out), want);
      }
    });
  });

  test('release determinístico no host (use e withGoScope)', () {
    final bytes = File(v1).readAsBytesSync();
    late CarV2BlockReader br;
    final cids = CarV2BlockReader(bytes).use((reader) {
      br = reader;
      final out = <Cid>[];
      while (true) {
        try {
          out.add(reader.next().cid!);
        } on GolangEofException {
          break;
        }
      }
      return out;
    });
    expect(cids, hasLength(blocks));
    expect(br.isReleased, isTrue);
    expect(() => br.next(), throwsA(isA<GolangException>()));

    late CarV2Reader r;
    final inspected = withGoScope((scope) {
      r = scope.manage(go.ipld.car.v2.openReader(v1));
      final st = r.inspect(false);
      r.close();
      return st.blockCount;
    });
    expect(inspected, blocks);
    expect(r.isReleased, isTrue);
    expect(() => r.version, throwsA(isA<GolangException>()));
  });
}
