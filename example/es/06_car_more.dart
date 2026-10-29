// Lección 06 · ¿Qué más puedo hacer con un CAR?
//
// Pregunta: la lección 05 escribió y leyó un CAR. ¿Qué son CARv1 y CARv2,
// para qué sirve el índice, puedo cambiar las raíces, quedarme solo con parte
// del DAG, o juntar dos CARs?
//
// Respuesta:
//   - CARv1 es el formato simple: cabecera (raíces) + bloques. Es lo que
//     escribe `ipfs dag export` y lo que envían los gateways. Leer un bloque
//     significa recorrer el archivo.
//   - CARv2 envuelve un CARv1 (byte a byte) entre una cabecera pequeña y un
//     índice: CID → posición, para encontrar un bloque sin recorrer. El
//     blockstore de lectura y escritura de la lección 05 escribe CARv2.
//   - Las raíces están en la cabecera; se pueden reescribir en su sitio si
//     los CIDs nuevos ocupan los mismos bytes.
//   - Una parte es un recorrido del DAG con un selector IPLD ("esta ruta",
//     "solo la raíz", "todo") escrito como un CAR nuevo.
//   - Juntar es copiar los bloques de cada CAR a uno nuevo, con las raíces
//     de todos.
//
// Necesita: la lección 05 (un CAR del ejemplo). El recorrido con selector
// también necesita un LinkSystem (la forma de go-ipld-prime de cargar bloques
// por enlace) que lea del CAR, la capa UnixFS (para que el selector avance por
// nombres de archivo) y el prototype chooser dag-pb (para que los bloques
// dag-pb se decodifiquen como nodos UnixFS).
//
//   dart run example/es/06_car_more.dart
//
// Siguiente pregunta: "Hacer todo esto a mano es mucha pila; ¿un nodo IPFS me
// da la pila lista, en disco?" → lección 07.
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
    final ctx = goContext.background();
    final s = await Sample.build(ctx);
    final v2 = at('folder.v2.car');
    await s.writeCar(ctx, v2);
    int count(String path) {
      final r = goCar.v2.openReader(path);
      try {
        return r.inspect(true).blockCount;
      } finally {
        r.close();
      }
    }

    // 1. CARv2 → CARv1 y vuelta. El v1 dentro de un v2 son los mismos bytes.
    //    Go:  car.ExtractV1File(v2, v1); car.WrapV1File(v1, again)
    final v1 = at('folder.v1.car');
    goCar.v2.extractV1File(v2, v1);
    final again = at('folder.again.car');
    goCar.v2.wrapV1File(v1, again);
    say('CARv2 ${File(v2).lengthSync()} bytes → CARv1 '
        '${File(v1).lengthSync()} bytes (versión '
        '${goCar.v2.readVersion(File(v1).readAsBytesSync())}) → CARv2 '
        '${File(again).lengthSync()} bytes');
    final r = goCar.v2.openReader(again);
    try {
      final h = r.header;
      say('  la cabecera v2: los datos v1 en ${h.dataOffset}..'
          '${h.dataOffset + h.dataSize}, el índice en ${h.indexOffset}');
    } finally {
      r.close();
    }

    // 2. El índice: dónde empieza cada bloque. Se arma a partir de un v1 (un
    //    recorrido), se guarda a su lado y se vuelve a cargar.
    //    Go:  idx, _ := car.GenerateIndexFromFile(v1)
    //         off, _ := index.GetFirst(idx, root)
    //         index.WriteTo(idx, f); idx2, _ := index.ReadFrom(f2)
    final idx = goCar.v2.generateIndexFromFile(v1);
    say('\nel índice del v1: el bloque raíz está en el byte '
        '${goCar.v2.index.getFirst(idx, s.root)}');
    final idxFile = '$v1.idx';
    final w = goOs.create(idxFile);
    final n = goCar.v2.index.writeTo(idx, w);
    w.close();
    final rd = goOs.open(idxFile);
    final loaded = goCar.v2.index.readFrom(rd);
    rd.close();
    say('  guardé $n bytes en ${idxFile.split('/').last}; cargado de nuevo: '
        'la raíz en el byte ${goCar.v2.index.getFirst(loaded, s.root)}');

    // 3. Cambiar las raíces: aquí el CAR pasa a empezar en data.bin (un CIDv0
    //    como la carpeta, así que del mismo tamaño).
    //    Go:  car.ReplaceRootsInFile(path, []cid.Cid{dataBin})
    final folder = await s.dag.get(ctx, s.root);
    final dataBin = folder.links().first.cid!;
    final copy = at('copy.car');
    File(v2).copySync(copy);
    goCar.v2.replaceRootsInFile(copy, [dataBin]);
    final rc = goCar.v2.openReader(copy);
    try {
      say('\nraíces cambiadas: ${rc.roots()} (en el CAR: '
          '${rc.inspect(false).rootsPresent})');
    } finally {
      rc.close();
    }

    // 4. Una parte: recorre el DAG con un selector y escribe lo que visita.
    //    Go:  ls := cidlink.DefaultLinkSystem()
    //         unixfsnode.AddUnixFSReificationToLinkSystem(&ls)
    //         src, _ := storage.OpenReadable(f); ls.SetReadStorage(src)
    //         car.TraverseToFile(ctx, &ls, root, selector, out,
    //             car.WithTraversalPrototypeChooser(
    //                 dagpb.AddSupportToChooser(bsfetcher.DefaultPrototypeChooser)))
    final dagPbChooser = goCar.v2.withTraversalPrototypeChooser(
        goCodecDagpb.addSupportToChooser(
            goBoxo.fetcher.impl.blockservice.defaultPrototypeChooser));
    Future<int> select(String name, IpldPrimeDatamodelNode selector,
        [List<CarV2Option>? opts]) async {
      final f = goOs.open(v2);
      try {
        final ls = goIpldPrime.linking.cid.defaultLinkSystem();
        goUnixfsnode.addUnixFsReificationToLinkSystem(ls);
        ls.setReadStorage(goCar.v2.storage.openReadable(f));
        final out = at('$name.car');
        await goCar.v2.traverseToFile(
            ctx, ls, s.root, selector, out, opts ?? [dagPbChooser]);
        return count(out);
      } finally {
        f.close();
      }
    }

    say('\npartes de la carpeta (${count(v2)} bloques):');
    say('  solo el bloque raíz:  '
        '${await select('root', goIpldPrime.traversal.selector.parse.commonSelectorMatchPoint)} bloque');
    say('  la ruta hello.txt:    '
        '${await select('hello', goUnixfsnode.unixFsPathSelector('hello.txt'))}'
        ' bloques (la carpeta, hello.txt)');
    say('  la ruta data.bin:     '
        '${await select('data', goUnixfsnode.unixFsPathSelector('data.bin'))}'
        ' bloques (la carpeta, data.bin, sus 3 hojas)');
    say('  todo:                 '
        '${await select('all', goIpldPrime.traversal.selector.parse.commonSelectorExploreAllRecursively)}'
        ' bloques');

    // 5. Juntar: un CAR nuevo con las raíces y los bloques de los dos.
    //    Go:  rw, _ := blockstore.OpenReadWrite(out, append(rootsA, rootsB...))
    //         para cada uno: br, _ := car.NewBlockReader(f); for { b, _ := br.Next(); rw.Put(ctx, b) }
    //         rw.Finalize()
    final note = Uint8List.fromList(utf8.encode('a second CAR'));
    final noteCid =
        goCid.newPrefixV1(goMulticodec.raw, goMultihash.sha2256).sum(note);
    final second = at('second.car');
    final sw = goCar.v2.blockstore.openReadWrite(second, [noteCid]);
    await sw.put(ctx, BlockFormatBlock(cid: noteCid, rawData: note));
    sw.finalize();
    final merged = at('merged.car');
    final rw = goCar.v2.blockstore.openReadWrite(merged, [s.root, noteCid]);
    for (final source in [v1, second]) {
      final f = goOs.open(source);
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
    final rm = goCar.v2.openReader(merged);
    try {
      say('\njuntos: ${rm.inspect(true).blockCount} bloques, raíces '
          '${rm.roots()}');
    } finally {
      rm.close();
    }

    say('\n== Errores comunes\n');
    await mistake('extraer el v1 de un CAR que ya es v1',
        why: 'no hay envoltorio v2 que quitar',
        instead: 'comprueba goCar.v2.readVersion antes',
        action: () => goCar.v2.extractV1File(v1, at('x.car')));
    await mistake('envolver un CAR que ya es v2 (y luego leerlo)',
        why: 'wrapV1File toma la cabecera v2 como datos v1: escribe sin '
            'quejarse y el archivo solo falla al leerlo',
        instead: 'comprueba goCar.v2.readVersion antes; envuelve solo v1',
        action: () {
      final twice = at('twice.car');
      goCar.v2.wrapV1File(v2, twice);
      count(twice);
    });
    await mistake('cambiar la raíz por un CID de otro tamaño',
        why: 'la cabecera se reescribe en su sitio: las raíces nuevas tienen '
            'que ocupar los mismos bytes (aquí un CIDv1 en lugar de un CIDv0)',
        instead: 'un CID de la misma versión y codec, o copia los bloques a '
            'un CAR nuevo (paso 5) con las raíces nuevas',
        action: () => goCar.v2.replaceRootsInFile(
            copy, [goCid.newCidV1(goMulticodec.dagPb, dataBin.hash())]));
    await silentlyWrong('seleccionar por ruta sin el chooser dag-pb',
        why: 'go-car decodifica dag-pb como datos genéricos, la capa UnixFS no '
            'encuentra "data.bin" en ellos, y el recorrido se detiene en la '
            'raíz',
        instead: 'pasa goCar.v2.withTraversalPrototypeChooser(...) como en el '
            'paso 4',
        wrong: () async =>
            '${await select('nochooser', goUnixfsnode.unixFsPathSelector('data.bin'), [])} bloques',
        right: () async =>
            '${await select('chooser', goUnixfsnode.unixFsPathSelector('data.bin'))} bloques');
    await mistake('juntar dentro de uno de los CARs de origen',
        why: 'openReadWrite sobre un archivo existente lo retoma, y solo se '
            'puede retomar un CARv2 escrito por él mismo; un v1 se rechaza',
        instead: 'escribe en un archivo nuevo y luego reemplaza el origen si '
            'hace falta',
        action: () =>
            goCar.v2.blockstore.openReadWrite(v1, [s.root, noteCid]).discard());
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
