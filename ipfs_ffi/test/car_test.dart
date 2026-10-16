// O go-car (github.com/ipld/go-car/v2, namespace `car`, 0.16.0): arquivos CAR
// sem nó. O nó só monta o CAR de entrada (uma pasta pelo Unixfs, CIDv1 com
// folhas raw, exportada pelo dagExportFile); o resto é o go-car direto:
// leitura, conversões v1/v2, índice, blockstore e a travessia seletiva.
// Exige `dart run tool/build.dart`.
import 'dart:io' show Directory, File;
import 'dart:typed_data';

import 'package:ipfs_ffi/boxo.dart' as boxo;
import 'package:ipfs_ffi/car.dart' as car;
import 'package:ipfs_ffi/go.dart' as go;
import 'package:ipfs_ffi/ipfs_ffi.dart';
import 'package:ipfs_ffi/ipld.dart' as ipld;
import 'package:ipfs_ffi/kubo.dart' as kubo;
import 'package:ipfs_ffi/multiformats.dart' as mf;
import 'package:test/test.dart';

const dagPb = 0x70, raw = 0x55, sha256 = 0x12;

void main() {
  late Directory tmp;
  late String v1; // o CARv1 do dagExportFile
  late mf.Cid root;
  late int blocks; // quantos blocos o CAR tem
  late go.Context ctx;
  late kubo.IpfsNode n; // aberto até o fim: o recorte pelo nó
  late kubo.CoreApi api;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('ipfs_ffi_car_');
    await IpfsService.start();
    ctx = go.background();
    kubo.PluginLoader('')
      ..initialize()
      ..inject();
    final cfg = kubo.initWithIdentity(
        kubo.createIdentity(null, [kubo.key.type('ed25519')]));
    kubo.profiles['test']!.transform(cfg);
    kubo.init('${tmp.path}/repo', cfg);
    n = await kubo.newNode(
        ctx, kubo.BuildCfg(repo: kubo.open('${tmp.path}/repo')));
    api = kubo.newCoreApi(n);

    final dir = Directory('${tmp.path}/pasta')..createSync();
    File('${dir.path}/a.txt').writeAsStringSync('A' * 1000);
    File('${dir.path}/b.txt').writeAsStringSync('B' * 600000);
    final p = await api.unixfs().add(
        ctx,
        boxo.newSerialFile(dir.path, false, go.stat(dir.path)),
        [kubo.unixfs.cidVersion(1), kubo.unixfs.chunker('size-262144')]);
    root = mf.Cid(p.value.substring('/ipfs/'.length));
    v1 = '${tmp.path}/base.car';
    await kubo.dagExportFile(n, ctx, p, v1);
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
    blocks = st.blockCount;
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
    final seen = <mf.Cid>[];
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

    final f = go.open(v1);
    final br2 = car.BlockReader(f);
    final (c, data, size) = br2.nextReader();
    expect(c, root);
    expect(go.readAll(data), hasLength(size));
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
    expect(go.readAll(r.dataReader()), File(v1).readAsBytesSync());
    r.close();

    final back = '${tmp.path}/back.car';
    car.extractV1File(v2, back);
    expect(File(back).readAsBytesSync(), File(v1).readAsBytesSync());

    // wrap de bytes (io.ReadSeeker) para um bytes.Buffer (io.Writer)
    final buf = go.Buffer(Uint8List(0));
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
    expect(idx.codec(), mf.carMultihashIndexSorted);
    final at = car.getFirst(idx, root);
    expect(at, greaterThan(0));

    // serializado num bytes.Buffer e lido de volta
    final buf = go.Buffer(Uint8List(0));
    final n = car.writeTo(idx, buf);
    final bytes = buf.bytes();
    expect(bytes, hasLength(n));
    expect(car.readCodec(bytes), mf.carMultihashIndexSorted);
    expect(car.getFirst(car.readFrom(bytes), root), at);

    // outro codec, carregado de registros
    final sorted = car.new$(mf.carIndexSorted);
    sorted.load([car.Record$(cid: root, offset: 42)]);
    expect(car.getFirst(sorted, root), 42);
  });

  test('blockstore: ReadWrite bloco a bloco e ReadOnly', () async {
    final prefix = mf.newPrefixV1(raw, sha256);
    final datas = [
      for (var i = 0; i < 3; i++) Uint8List.fromList([i, i, i])
    ];
    final cids = [for (final d in datas) prefix.sum(d)];
    final file = '${tmp.path}/novo.car';

    final rw = car.openReadWrite(file, [cids.first]);
    await rw.put(ctx, ipld.Block(cid: cids[0], rawData: datas[0]));
    await rw.putMany(ctx, [
      for (var i = 1; i < 3; i++) ipld.Block(cid: cids[i], rawData: datas[i])
    ]);
    expect(await rw.has(ctx, cids[2]), isTrue);
    expect((await rw.get(ctx, cids[1])).rawData, datas[1]);
    rw.finalize();

    final ro = car.openReadOnly(file);
    expect(ro.roots(), [cids.first]);
    expect(await ro.getSize(ctx, cids[0]), 3);
    expect((await ro.get(ctx, cids[2])).rawData, datas[2]);
    expect(await ro.has(ctx, prefix.sum(Uint8List(1))), isFalse);
    expect((await ro.allKeysChan(ctx).toList()).toSet(), cids.toSet());
    ro.close();
    expect(car.openReader(file).inspect(true).blockCount, 3);
  });

  test('travessia seletiva: CAR → seletor → CAR', () async {
    final ls = ipld.defaultLinkSystem();
    final src = go.open(v1);
    final readable = car.openReadable(src);
    expect(readable.roots(), [root]);
    ls.setReadStorage(readable);

    final only = '${tmp.path}/raiz.car';
    await car.traverseToFile(
        ctx, ls, root, ipld.commonSelectorMatchPoint, only);
    expect(car.openReader(only).inspect(true).blockCount, 1);

    final all = '${tmp.path}/tudo.car';
    await car.traverseToFile(
        ctx, ls, root, ipld.commonSelectorExploreAllRecursively, all);
    expect(car.openReader(all).inspect(true).blockCount, blocks);

    // CARv1 para um io.Writer, com seletor em JSON
    final buf = go.Buffer(Uint8List(0));
    final size = await car.traverseV1(
        ctx, ls, root, ipld.parseJsonSelector('{".":{}}'), buf);
    expect(buf.bytes(), hasLength(size));
    expect(car.BlockReader(buf.bytes()).roots, [root]);
    src.close();
  });

  test('sentinelas do Go viram subclasses de IpfsException', () async {
    final missing = mf.newPrefixV1(raw, sha256).sum(Uint8List.fromList([9]));
    final ro = car.openReadOnly(v1);
    await expectLater(ro.get(ctx, missing), throwsA(isA<IpfsNotFound>()));
    ro.close();

    // o unixfs.add olha o contexto antes de começar
    final (c, cancel) = go.withCancel(go.background());
    cancel();
    await expectLater(api.unixfs().add(c, boxo.newBytesFile(Uint8List(1))),
        throwsA(isA<IpfsCanceled>()));
    final (d, cancel2) = go.withTimeout(go.background(), Duration.zero);
    await expectLater(api.unixfs().add(d, boxo.newBytesFile(Uint8List(1))),
        throwsA(isA<IpfsDeadlineExceeded>()));
    cancel2();
  });
}
