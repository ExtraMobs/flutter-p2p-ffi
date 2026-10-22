// O go-car (github.com/ipld/go-car/v2, namespace `car`, 0.16.0): arquivos CAR
// sem nó. O nó só monta o CAR de entrada (uma pasta pelo Unixfs, CIDv1 com
// folhas raw, exportada pelo dagExportFile); o resto é o go-car direto:
// leitura, conversões v1/v2, índice, blockstore e a travessia seletiva.
// Exige `dart run tool/build.dart`.
import 'dart:io' show Directory, File;
import 'dart:typed_data';

import 'package:ipfs_ffi/go/boxo/gateway.dart' as gateway;
import 'package:ipfs_ffi/go/boxo/path.dart' as path;
import 'package:ipfs_ffi/go/boxo/fetcher/impl/blockservice.dart'
    as blockservice;
import 'package:ipfs_ffi/go/boxo/files.dart' as files;
import 'package:ipfs_ffi/go/car/v2.dart' as car;
import 'package:ipfs_ffi/go/car/v2/index.dart' as index;
import 'package:ipfs_ffi/go/car/v2/blockstore.dart' as blockstore;
import 'package:ipfs_ffi/go/car/v2/storage.dart' as storage;
import 'package:ipfs_ffi/go/bytes.dart' as go_bytes;
import 'package:ipfs_ffi/go/context.dart' as context;
import 'package:ipfs_ffi/go/os.dart' as os;
import 'package:ipfs_ffi/go/io.dart' as io;
import 'package:ipfs_ffi/go/ipld_prime/storage/bsadapter.dart' as bsadapter;
import 'package:ipfs_ffi/go/block_format.dart' as block_format;
import 'package:ipfs_ffi/go/ipld_prime/linking.dart' as linking;
import 'package:ipfs_ffi/go/ipld_prime/node/basicnode.dart' as basicnode;
import 'package:ipfs_ffi/go/ipld_prime/traversal/selector/builder.dart'
    as builder;
import 'package:ipfs_ffi/go/codec_dagpb.dart' as codec_dagpb;
import 'package:ipfs_ffi/go/unixfsnode.dart' as unixfsnode;
import 'package:ipfs_ffi/go/ipld_prime/traversal/selector/parse.dart' as parse;
import 'package:ipfs_ffi/go/ipld_prime/linking/cid.dart' as cid;
import 'package:ipfs_ffi/go/ipld_prime/traversal/selector.dart' as selector;
import 'package:ipfs_ffi/go/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/go/kubo/core/coreiface.dart' as coreiface;
import 'package:ipfs_ffi/go/kubo/core.dart' as core;
import 'package:ipfs_ffi/go/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/go/kubo/config.dart' as config;
import 'package:ipfs_ffi/go/kubo/core/commands/dag.dart' as dag;
import 'package:ipfs_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:ipfs_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/go/cid.dart' as go_cid;
import 'package:ipfs_ffi/go/multicodec.dart' as multicodec;
import 'package:ipfs_ffi/ipfs_ffi.dart';
import 'package:test/test.dart';

const dagPb = 0x70, raw = 0x55, sha256 = 0x12;

void main() {
  late Directory tmp;
  late String v1; // o CARv1 do dagExportFile
  late go_cid.Cid root;
  late int blocks; // quantos blocos o CAR tem
  late context.Context ctx;
  late core.IpfsNode n; // aberto até o fim: o recorte pelo nó
  late coreiface.CoreApi api;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('ipfs_ffi_car_');
    await IpfsService.start();
    ctx = context.background();
    loader.PluginLoader('')
      ..initialize()
      ..inject();
    final cfg = config.initWithIdentity(
        config.createIdentity(null, [options.key.type('ed25519')]));
    config.profiles['test']!.transform(cfg);
    fsrepo.init('${tmp.path}/repo', cfg);
    n = await core.newNode(
        ctx, node.BuildCfg(repo: fsrepo.open('${tmp.path}/repo')));
    api = coreapi.newCoreApi(n);

    final dir = Directory('${tmp.path}/pasta')..createSync();
    File('${dir.path}/a.txt').writeAsStringSync('A' * 1000);
    File('${dir.path}/b.txt').writeAsStringSync('B' * 600000);
    final p = await api.unixfs().add(
        ctx,
        files.newSerialFile(dir.path, false, os.stat(dir.path)),
        [options.unixfs.cidVersion(1), options.unixfs.chunker('size-262144')]);
    root = go_cid.Cid(p.value.substring('/ipfs/'.length));
    v1 = '${tmp.path}/base.car';
    await dag.dagExportFile(n, ctx, p, v1);
    final r = car.openReader(v1);
    blocks = r.inspect(false).blockCount;
    r.close();
  });

  tearDownAll(() async {
    await n.close();
    await IpfsService.stop();
    tmp.deleteSync(recursive: true);
  });

  test('leitura: versão, raízes e estatísticas (Reader.inspect)', () {
    final r = car.openReader(v1);
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
    expect(car.readVersion(File(v1).readAsBytesSync()), 1);
  });

  test('BlockReader: bloco a bloco, por bytes e por arquivo', () {
    final bytes = File(v1).readAsBytesSync();
    final br = car.BlockReader(bytes);
    expect(br.version, 1);
    expect(br.roots, [root]);
    final seen = <go_cid.Cid>[];
    while (true) {
      try {
        final b = br.next();
        seen.add(b.cid!);
        expect(b.rawData, isNotEmpty);
      } on IpfsEof {
        break; // o io.EOF do Go: acabou
      }
    }
    expect(seen, hasLength(blocks));
    expect(seen.first, root); // o export começa pela raiz

    final f = os.open(v1);
    final br2 = car.BlockReader(f);
    final (c, data, size) = br2.nextReader();
    expect(c, root);
    expect(io.readAll(data), hasLength(size));
    final meta = br2.skipNext();
    expect(meta.cid, seen[1]);
    expect(meta.size, greaterThan(0));
    f.close();
  });

  test('conversões: wrap/extract, raízes trocadas, cabeçalho v2', () {
    final v2 = '${tmp.path}/v2.car';
    car.wrapV1File(v1, v2);
    final r = car.openReader(v2);
    expect(r.version, 2);
    final h = r.header;
    expect(h.hasIndex(), isTrue); // o wrap gera o índice
    expect(h.dataOffset, car.pragmaSize + car.headerSize);
    expect(h.characteristics!.isFullyIndexed(), isFalse);
    expect(h.withDataSize(7).dataSize, 7); // método de DTO: cópia nova
    expect(h.dataSize, isNot(7));
    expect(io.readAll(r.dataReader()), File(v1).readAsBytesSync());
    r.close();

    final back = '${tmp.path}/back.car';
    car.extractV1File(v2, back);
    expect(File(back).readAsBytesSync(), File(v1).readAsBytesSync());

    // wrap de bytes (io.ReadSeeker) para um bytes.Buffer (io.Writer)
    final buf = go_bytes.Buffer(Uint8List(0));
    car.wrapV1(File(v1).readAsBytesSync(), buf);
    expect(car.readVersion(buf.bytes()), 2);

    // troca a raiz por uma folha (o mesmo tamanho de CID)
    final leaf = car.BlockReader(File(v1).readAsBytesSync())
      ..next()
      ..next();
    final other = leaf.next().cid!;
    car.replaceRootsInFile(v2, [other]);
    expect(car.openReader(v2).roots(), [other]);
  });

  test('índice: gera, consulta, serializa e anexa', () {
    final idx = car.generateIndexFromFile(v1);
    expect(idx.codec(), multicodec.carMultihashIndexSorted);
    final at = index.getFirst(idx, root);
    expect(at, greaterThan(0));

    // serializado num bytes.Buffer e lido de volta
    final buf = go_bytes.Buffer(Uint8List(0));
    final n = index.writeTo(idx, buf);
    final bytes = buf.bytes();
    expect(bytes, hasLength(n));
    expect(index.readCodec(bytes), multicodec.carMultihashIndexSorted);
    expect(index.getFirst(index.readFrom(bytes), root), at);

    // outro codec, carregado de registros
    final sorted = index.new$(multicodec.carIndexSorted);
    sorted.load([index.Record$(cid: root, offset: 42)]);
    expect(index.getFirst(sorted, root), 42);
  });

  test('blockstore: ReadWrite bloco a bloco e ReadOnly', () async {
    final prefix = go_cid.newPrefixV1(raw, sha256);
    final datas = [
      for (var i = 0; i < 3; i++) Uint8List.fromList([i, i, i])
    ];
    final cids = [for (final d in datas) prefix.sum(d)];
    final file = '${tmp.path}/novo.car';

    final rw = blockstore.openReadWrite(file, [cids.first]);
    await rw.put(ctx, block_format.Block(cid: cids[0], rawData: datas[0]));
    await rw.putMany(ctx, [
      for (var i = 1; i < 3; i++)
        block_format.Block(cid: cids[i], rawData: datas[i])
    ]);
    expect(await rw.has(ctx, cids[2]), isTrue);
    expect((await rw.get(ctx, cids[1])).rawData, datas[1]);
    rw.finalize();

    final ro = blockstore.openReadOnly(file);
    expect(ro.roots(), [cids.first]);
    expect(await ro.getSize(ctx, cids[0]), 3);
    expect((await ro.get(ctx, cids[2])).rawData, datas[2]);
    expect(await ro.has(ctx, prefix.sum(Uint8List(1))), isFalse);
    expect((await ro.allKeysChan(ctx).toList()).toSet(), cids.toSet());
    ro.close();
    expect(car.openReader(file).inspect(true).blockCount, 3);
  });

  test('travessia seletiva: CAR → seletor → CAR', () async {
    final ls = cid.defaultLinkSystem();
    final src = os.open(v1);
    final readable = storage.openReadable(src);
    expect(readable.roots(), [root]);
    ls.setReadStorage(readable);

    final only = '${tmp.path}/raiz.car';
    await car.traverseToFile(
        ctx, ls, root, parse.commonSelectorMatchPoint, only);
    expect(car.openReader(only).inspect(true).blockCount, 1);

    final all = '${tmp.path}/tudo.car';
    await car.traverseToFile(
        ctx, ls, root, parse.commonSelectorExploreAllRecursively, all);
    expect(car.openReader(all).inspect(true).blockCount, blocks);

    // CARv1 para um io.Writer, com seletor em JSON
    final buf = go_bytes.Buffer(Uint8List(0));
    final size = await car.traverseV1(
        ctx, ls, root, parse.parseJsonSelector('{".":{}}'), buf);
    expect(buf.bytes(), hasLength(size));
    expect(car.BlockReader(buf.bytes()).roots, [root]);
    src.close();
  });

  test('sentinelas do Go viram subclasses de IpfsException', () async {
    final missing =
        go_cid.newPrefixV1(raw, sha256).sum(Uint8List.fromList([9]));
    final ro = blockstore.openReadOnly(v1);
    await expectLater(ro.get(ctx, missing), throwsA(isA<IpfsNotFound>()));
    ro.close();

    // o unixfs.add olha o contexto antes de começar
    final (c, cancel) = context.withCancel(context.background());
    cancel();
    await expectLater(api.unixfs().add(c, files.newBytesFile(Uint8List(1))),
        throwsA(isA<IpfsCanceled>()));
    final (d, cancel2) =
        context.withTimeout(context.background(), Duration.zero);
    await expectLater(api.unixfs().add(d, files.newBytesFile(Uint8List(1))),
        throwsA(isA<IpfsDeadlineExceeded>()));
    cancel2();
  });

  group('recorte pelo nó', () {
    /// Os CIDs dos blocos de um CAR em bytes.
    List<go_cid.Cid> cids(Uint8List bytes) {
      final br = car.BlockReader(bytes);
      final out = <go_cid.Cid>[];
      while (true) {
        try {
          out.add(br.next().cid!);
        } on IpfsEof {
          return out;
        }
      }
    }

    /// O CAR do caminho [p] pelo gateway do boxo sobre o nó.
    Future<(gateway.ContentPathMetadata, Uint8List)> getCar(
        String p, gateway.CarParams params) async {
      final backend = gateway.BlocksBackend(n.blocks);
      final (meta, rc) =
          await backend.getCar(ctx, path.ImmutablePath(p), params);
      final bytes = io.readAll(rc);
      rc.close();
      return (meta, bytes);
    }

    /// Quantos blocos o CAR em [file] tem.
    int count(String file) {
      final r = car.openReader(file); // mapeia o arquivo: fechar (Windows)
      try {
        return r.inspect(true).blockCount;
      } finally {
        r.close();
      }
    }

    test('gateway.getCar: escopos e faixa de bytes', () async {
      final (_, all) = await getCar(
          '/ipfs/$root', gateway.CarParams(scope: gateway.dagScopeAll));
      expect(cids(all), hasLength(blocks));
      final (_, one) = await getCar(
          '/ipfs/$root', gateway.CarParams(scope: gateway.dagScopeBlock));
      expect(cids(one), [root]);
      // a pasta (para provar o caminho) e o b.txt inteiro: raiz e 2 fatias
      final (meta, entity) = await getCar('/ipfs/$root/b.txt',
          gateway.CarParams(scope: gateway.dagScopeEntity));
      expect(meta.pathSegmentRoots, [root]);
      expect(cids(entity), hasLength(4));
      expect(cids(entity).first, root);
      // só os primeiros 100 bytes: a primeira fatia
      final (_, range) = await getCar(
          '/ipfs/$root/b.txt',
          gateway.CarParams(
              scope: gateway.dagScopeEntity,
              range: gateway.DagByteRange(from: 0, to: 99)));
      expect(cids(range), hasLength(3));
    });

    /// LinkSystem sobre o blockstore local do nó (bsadapter).
    linking.LinkSystem nodeLinks({bool unixfs = false}) {
      final ls = cid.defaultLinkSystem();
      if (unixfs) unixfsnode.addUnixFsReificationToLinkSystem(ls);
      ls.setReadStorage(bsadapter.Adapter()..wrapped = n.blockstore);
      return ls;
    }

    test('seletor qualquer sobre o blockstore local (bsadapter)', () async {
      final out = '${tmp.path}/bs.car';
      await car.traverseToFile(ctx, nodeLinks(), root,
          parse.commonSelectorExploreAllRecursively, out);
      expect(count(out), blocks);
    });

    test('seletor UnixFS pelo nome do arquivo', () async {
      // a reificação UnixFS só pega nós dag-pb tipados: o escolhedor do
      // gateway (sem ele, o go-car decodifica genérico e o caminho não anda)
      final chooser = [
        car.withTraversalPrototypeChooser(codec_dagpb
            .addSupportToChooser(blockservice.defaultPrototypeChooser))
      ];
      for (final (name, want) in [('b.txt', 4), ('a.txt', 2)]) {
        final out = '${tmp.path}/$name.car';
        await car.traverseToFile(ctx, nodeLinks(unixfs: true), root,
            unixfsnode.unixFsPathSelector(name), out, chooser);
        expect(count(out), want, reason: name);
      }
    });

    test('construtor de seletores, com exploreFields (callback)', () async {
      final ssb = builder.SelectorSpecBuilder(basicnode.PrototypeAny());
      final everything = ssb.exploreRecursive(selector.recursionLimitNone(),
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
        await car.traverseToFile(ctx, nodeLinks(), root, spec.node(), out);
        expect(count(out), want);
      }
    });
  });

  test('release determinístico no host (use e withGoScope)', () {
    final bytes = File(v1).readAsBytesSync();
    late car.BlockReader br;
    final cids = car.BlockReader(bytes).use((reader) {
      br = reader;
      final out = <go_cid.Cid>[];
      while (true) {
        try {
          out.add(reader.next().cid!);
        } on IpfsEof {
          break;
        }
      }
      return out;
    });
    expect(cids, hasLength(blocks));
    expect(br.isReleased, isTrue);
    expect(() => br.next(), throwsA(isA<IpfsException>()));

    late car.Reader r;
    final inspected = withGoScope((scope) {
      r = scope.manage(car.openReader(v1));
      final st = r.inspect(false);
      r.close();
      return st.blockCount;
    });
    expect(inspected, blocks);
    expect(r.isReleased, isTrue);
    expect(() => r.version, throwsA(isA<IpfsException>()));
  });
}
