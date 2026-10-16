// Passo 12: arquivos CAR pelo baixo nível, o go-car do Go
// (github.com/ipld/go-car/v2) chamado direto do Dart, no namespace `car`.
// O exemplo 07 usa o `ipfs dag export/import` (o nó lê e grava o CAR inteiro);
// aqui o arquivo é aberto e mexido sem nó: ler a versão e as raízes, contar
// os blocos, percorrer bloco a bloco, converter CARv1 ↔ CARv2, montar e
// guardar o índice, criar um CAR bloco a bloco e recortar um DAG com um
// seletor IPLD.
//
//   dart run example/12_car_baixo_nivel.dart
//
// Como nos exemplos 10 e 11, cada passo traz o mesmo código em Go: as funções
// são as do go-car (pkg.go.dev/github.com/ipld/go-car/v2), geradas, na mesma
// ordem de argumentos.
import 'dart:io';
import 'dart:typed_data';

import 'package:ipfs_ffi/boxo.dart' as boxo;
import 'package:ipfs_ffi/car.dart' as car;
import 'package:ipfs_ffi/go.dart' as go;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsException, IpfsService;
import 'package:ipfs_ffi/ipld.dart' as ipld;
import 'package:ipfs_ffi/kubo.dart' as kubo;
import 'package:ipfs_ffi/multiformats.dart' as mf;

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_ex12_');
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

  try {
    // O nó só entra para fazer um CAR de exemplo: uma pasta com dois
    // arquivos, exportada pelo `ipfs dag export` (exemplo 07). Daqui para
    // baixo, nada usa o nó.
    final n = await kubo.newNode(ctx, kubo.BuildCfg(repo: kubo.open(repoPath)));
    final dir = Directory('${tmp.path}/pasta')..createSync();
    File('${dir.path}/oi.txt').writeAsStringSync('oi, CAR\n');
    File('${dir.path}/grande.bin').writeAsBytesSync(
        Uint8List.fromList(List.generate(400000, (i) => i * 7 % 251)));
    final p = await kubo.newCoreApi(n).unixfs().add(
        ctx,
        boxo.newSerialFile(dir.path, false, go.stat(dir.path)),
        [kubo.unixfs.cidVersion(1)]);
    final root = mf.Cid(p.value.substring('/ipfs/'.length));
    final v1 = '${tmp.path}/pasta.car';
    await kubo.dagExportFile(n, ctx, p, v1);
    await n.close();
    print('0. ${File(v1).lengthSync()} bytes em $v1, raiz $root');

    // 1. Abrir e inspecionar. O Inspect lê o arquivo inteiro (e, com true,
    // confere o hash de cada bloco). Os contadores são mapas de código
    // multicodec (0x70 dag-pb, 0x55 raw, 0x12 sha2-256) para quantidade.
    //   Go:   r, _ := car.OpenReader(path)
    //         st, _ := r.Inspect(true)
    final r = car.openReader(v1);
    final st = r.inspect(true);
    print('1. CARv${r.version}, raízes ${r.roots()}, ${st.blockCount} blocos, '
        'codecs ${st.codecCounts}, maior bloco ${st.maxBlockLength} bytes');
    r.close();

    // 2. Bloco a bloco, como o `ipfs dag import` lê: o BlockReader aceita
    // os bytes ou um arquivo aberto (os.Open). O fim é o io.EOF do Go, que
    // chega como IpfsException('EOF').
    //   Go:   f, _ := os.Open(path)
    //         br, _ := car.NewBlockReader(f)
    //         for { b, err := br.Next(); if err == io.EOF { break } ... }
    final f = go.open(v1);
    final br = car.BlockReader(f);
    var i = 0;
    while (true) {
      try {
        final b = br.next();
        print('2. bloco ${i++}: ${b.cid} (${b.rawData!.length} bytes)');
      } on IpfsException catch (e) {
        if (e.message != 'EOF') rethrow;
        break;
      }
    }
    f.close();

    // 3. CARv1 → CARv2: o v2 põe um cabeçalho na frente e o índice no fim
    // (achar um bloco sem ler o arquivo todo). O Header é uma struct do Go;
    // os métodos dele vêm junto (hasIndex).
    //   Go:   car.WrapV1File(v1, v2)
    //         r2, _ := car.OpenReader(v2); r2.Header.HasIndex()
    final v2 = '${tmp.path}/pasta.v2.car';
    car.wrapV1File(v1, v2);
    final r2 = car.openReader(v2);
    final h = r2.header;
    print('3. CARv${r2.version}: dados em ${h.dataOffset}..'
        '${h.dataOffset + h.dataSize}, índice em ${h.indexOffset} '
        '(hasIndex: ${h.hasIndex()})');
    r2.close();

    // 4. O índice à parte: gerar de um CARv1, consultar o deslocamento de
    // um bloco e guardar os bytes num bytes.Buffer do Go (qualquer
    // io.Writer serve: um os.File grava direto no disco).
    //   Go:   idx, _ := car.GenerateIndexFromFile(v1)
    //         off, _ := index.GetFirst(idx, root)
    //         var buf bytes.Buffer; index.WriteTo(idx, &buf)
    final idx = car.generateIndexFromFile(v1);
    final buf = go.Buffer(Uint8List(0));
    car.writeTo(idx, buf);
    print(
        '4. índice ${idx.codec() == mf.carMultihashIndexSorted ? 'multihash-sorted' : idx.codec()}: '
        'raiz no byte ${car.getFirst(idx, root)}, ${buf.bytes().length} bytes serializado');

    // 5. Um CAR novo, bloco a bloco, sem nó. O CID sai do prefixo (versão
    // 1, codec raw, sha2-256) aplicado aos bytes; o Block do Go é montado no
    // Dart (cid + dados). Finalize grava o índice e fecha.
    //   Go:   pre := cid.NewPrefixV1(cid.Raw, multihash.SHA2_256)
    //         c, _ := pre.Sum(data)
    //         rw, _ := blockstore.OpenReadWrite(path, []cid.Cid{c})
    //         rw.Put(ctx, blocks.NewBlockWithCid(data, c)); rw.Finalize()
    final pre = mf.newPrefixV1(0x55, 0x12);
    final novo = '${tmp.path}/novo.car';
    final datas = [
      for (final s in ['um', 'dois', 'três']) Uint8List.fromList(s.codeUnits)
    ];
    final cids = [for (final d in datas) pre.sum(d)];
    final rw = car.openReadWrite(novo, [cids.first]);
    for (var k = 0; k < datas.length; k++) {
      await rw.put(ctx, ipld.Block(cid: cids[k], rawData: datas[k]));
    }
    rw.finalize();
    // e lido de volta pelo blockstore só de leitura (usa o índice)
    final ro = car.openReadOnly(novo);
    final keys = await ro.allKeysChan(ctx).toList();
    print('5. $novo: ${keys.length} blocos, '
        '"${String.fromCharCodes((await ro.get(ctx, cids[1])).rawData!)}" pelo CID');
    ro.close();

    // 6. Recortar com um seletor IPLD: o LinkSystem lê do CAR aberto e só
    // o que o seletor alcança vai para o arquivo novo. MatchPoint = só a
    // raiz; ExploreAllRecursively = o DAG inteiro; ou um seletor em JSON.
    //   Go:   ls := cidlink.DefaultLinkSystem()
    //         src, _ := storage.OpenReadable(f); ls.SetReadStorage(src)
    //         car.TraverseToFile(ctx, &ls, root, selectorparse.CommonSelector_MatchPoint, out)
    final ls = ipld.defaultLinkSystem();
    final src = go.open(v1);
    ls.setReadStorage(car.openReadable(src));
    final soRaiz = '${tmp.path}/raiz.car';
    await car.traverseToFile(
        ctx, ls, root, ipld.commonSelectorMatchPoint, soRaiz);
    final inteiro = '${tmp.path}/inteiro.car';
    await car.traverseToFile(
        ctx, ls, root, ipld.commonSelectorExploreAllRecursively, inteiro);
    src.close();
    final a = car.openReader(soRaiz), b = car.openReader(inteiro);
    print('6. só a raiz: ${a.inspect(false).blockCount} bloco; '
        'o DAG inteiro: ${b.inspect(false).blockCount} blocos');
    a.close();
    b.close();
  } finally {
    await IpfsService.stop();
    tmp.deleteSync(recursive: true);
  }
}
