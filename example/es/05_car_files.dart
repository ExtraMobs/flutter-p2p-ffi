// Lección 05 · ¿Cómo llevo bloques sin red?
//
// Pregunta: mis bloques están en un blockstore (lecciones 03-04). ¿Cómo envío
// un DAG entero a otra máquina, o lo guardo en un solo archivo, sin la red de
// IPFS?
//
// Respuesta: un archivo CAR (Content-Addressed aRchive): una cabecera con las
// raíces, y luego los bloques uno tras otro, cada uno con su CID. Un CAR es un
// blockstore en un archivo: se escribe con el blockstore de lectura y
// escritura del CAR y se lee con el de solo lectura, que encaja en la misma
// pila de la lección 03 en lugar del blockstore en memoria. Quien lo recibe no
// confía en nada: cada bloque se comprueba contra su CID (lección 02). Es lo
// que escribe `ipfs dag export`, lo que sirven los gateways con `?format=car`
// y lo que lee `ipfs dag import`.
//
// Necesita: las lecciones 03-04 (el DAG de ejemplo y la pila). Para escribir
// un CAR: las raíces al abrirlo (los CIDs por donde debe empezar quien lo
// recibe) y todos los bloques del DAG. Para extraer archivos de él: un
// blockservice y un DAGService sobre el CAR (offline, así que todo bloque
// tiene que estar en el CAR).
//
//   dart run example/es/05_car_files.dart
//
// Siguiente pregunta: "CARv1, CARv2, índice, raíces... ¿y si solo quiero una
// parte del DAG, o juntar dos CARs?" → lección 06.
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson05_');
  try {
    final ctx = go.context.background();
    final s = await Sample.build(ctx);
    say('la carpeta de ejemplo: ${s.root}');

    // 1. Qué bloques: recorre el DAG desde la raíz, el padre antes que los
    //    hijos (el orden en que escribe `ipfs dag export`). Cada Get por el
    //    CID de un enlace devuelve el bloque bajo ese CID exacto, con codec.
    Future<List<BlockFormatBlock>> dagBlocks(Cid c) async => [
          await s.store.get(ctx, c),
          for (final l in await go.ipfs.ipldFormat.getLinks(ctx, s.dag, c))
            ...await dagBlocks(l.cid!),
        ];

    // 2. Escribir: abre el CAR con sus raíces, pon los bloques, finaliza.
    //    Finalize escribe la cabecera (CARv2) y un índice (lección 06).
    //    Go:  rw, _ := blockstore.OpenReadWrite(out, []cid.Cid{root})
    //         rw.PutMany(ctx, blks); rw.Finalize()
    final out = '${tmp.path}/folder.car';
    Future<void> writeCar(String path, List<BlockFormatBlock> all) async {
      final rw = go.ipld.car.v2.blockstore.openReadWrite(path, [s.root]);
      await rw.putMany(ctx, all);
      rw.finalize();
    }

    final all = await dagBlocks(s.root);
    await writeCar(out, all);
    say('\nescribí $out: ${all.length} bloques, '
        '${File(out).lengthSync()} bytes');

    // 3. Inspeccionar: versión, raíces, cuántos bloques, están las raíces.
    //    El Reader mapea el archivo: ciérralo siempre.
    //    Go:  r, _ := car.OpenReader(out); defer r.Close(); st, _ := r.Inspect(false)
    final r = go.ipld.car.v2.openReader(out);
    try {
      final st = r.inspect(false);
      say('CARv${r.version}, raíces ${r.roots()}, ${st.blockCount} bloques '
          '(las raíces están dentro: ${st.rootsPresent})');
      say('  por codec ${st.codecCounts} (0x70 dag-pb), tamaños '
          '${st.minBlockLength}..${st.maxBlockLength} bytes');
    } finally {
      r.close();
    }

    // 4. Listar los bloques en el orden del archivo. El BlockReader comprueba
    //    el hash de cada bloque al leerlo; el final es el io.EOF de Go.
    //    Go:  br, _ := car.NewBlockReader(f)
    //         for { b, err := br.Next(); if errors.Is(err, io.EOF) { break } }
    final f = go.os.open(out);
    try {
      final br = CarV2BlockReader(f);
      say('\nlos bloques del archivo:');
      while (true) {
        try {
          final b = br.next();
          say('  ${b.cid}  ${b.rawData!.length} bytes');
        } on GolangEofException {
          break;
        }
      }
    } finally {
      f.close();
    }

    // 5. El CAR como blockstore: obtener un bloque por CID (por el índice), y
    //    extraer los archivos poniéndolo debajo de la pila de la lección 04.
    //    Go:  ro, _ := blockstore.OpenReadOnly(out); defer ro.Close()
    //         dag := merkledag.NewDAGService(blockservice.New(ro, offline.Exchange(ro)))
    //         nd, _ := dag.Get(ctx, root); f, _ := unixfile.NewUnixfsFile(ctx, dag, nd)
    //         files.WriteTo(f, dir)
    Future<void> extract(String carPath, String dir) async {
      final ro = go.ipld.car.v2.blockstore.openReadOnly(carPath);
      try {
        final dag = go.ipfs.boxo.ipld.merkledag.newDagService(go
            .ipfs.boxo.blockservice
            .new$(ro, go.ipfs.boxo.exchange.offline.exchange(ro)));
        final root = ro.roots().single;
        go.ipfs.boxo.files.writeTo(
            await go.ipfs.boxo.ipld.unixfs.file
                .newUnixfsFile(ctx, dag, await dag.get(ctx, root)),
            dir);
      } finally {
        ro.close();
      }
    }

    final ro = go.ipld.car.v2.blockstore.openReadOnly(out);
    try {
      final b = await ro.get(ctx, s.root);
      say('\nel bloque raíz, leído del CAR: ${b.rawData!.length} bytes');
    } finally {
      ro.close();
    }
    final dir = '${tmp.path}/extracted';
    await extract(out, dir);
    final back = File('$dir/data.bin').readAsBytesSync();
    say('extraje en $dir: ${Directory(dir).listSync().length} entradas; '
        'data.bin es igual: ${_same(back, s.data)}');

    say('\n== Errores comunes\n');
    final notCar = '${tmp.path}/not_a_car.car';
    File(notCar).writeAsStringSync('{"this": "is not a CAR"}');
    await mistake('abrir un archivo que no es un CAR',
        why: 'go-car comprueba la cabecera y lo rechaza',
        instead: 'maneja el error: un CAR que recibes puede venir de '
            'cualquier sitio',
        action: () => go.ipld.car.v2.openReader(notCar).close());

    // Un byte invertido cerca del final, en los datos de una hoja.
    final good = File(out).readAsBytesSync();
    final corrupted = '${tmp.path}/corrupted.car';
    File(corrupted).writeAsBytesSync(
        Uint8List.fromList(good)..[good.length - 2000] ^= 0xff);
    String inspect(String path, bool check) {
      final r = go.ipld.car.v2.openReader(path);
      try {
        return '${r.inspect(check).blockCount} bloques, sin error';
      } on GolangException catch (e) {
        return 'error: ${brief(e)}';
      } finally {
        r.close();
      }
    }

    await silentlyWrong('confiar en un CAR porque inspect(false) lo contó',
        why: 'inspect(false) solo lee la estructura, no los hashes',
        instead: 'inspect(true), el BlockReader o `ipfs dag import`, que '
            'comprueban cada bloque',
        wrong: () => inspect(corrupted, false),
        right: () => inspect(corrupted, true));

    final unfinished = '${tmp.path}/unfinished.car';
    final rw = go.ipld.car.v2.blockstore.openReadWrite(unfinished, [s.root]);
    await rw.put(ctx, await s.store.get(ctx, s.root));
    await mistake('leer un CAR cuyo escritor nunca se finalizó',
        why: 'la cabecera solo la escribe finalize()',
        instead: 'finalize() al terminar (o discard() para abandonar)',
        action: () => go.ipld.car.v2.openReader(unfinished).close());
    rw.discard();

    // Copiar "todos los bloques del blockstore" en vez de recorrer el DAG. Un
    // blockstore guarda los bloques solo por su multihash: AllKeysChan
    // devuelve cada uno como un CIDv1 raw, sin el codec con que se guardó.
    String rootsInside(String path) {
      final r = go.ipld.car.v2.openReader(path);
      try {
        final st = r.inspect(false);
        return 'raíces en el CAR: ${st.rootsPresent}, codecs ${st.codecCounts}';
      } finally {
        r.close();
      }
    }

    final byKeys = '${tmp.path}/by_keys.car';
    await silentlyWrong('escribir un CAR a partir de blockstore.allKeysChan()',
        why: 'el blockstore guarda multihashes, no CIDs: cada bloque vuelve '
            'como raw (0x55), y la raíz dag-pb no aparece',
        instead: 'recorre el DAG desde la raíz (paso 1), o usa '
            '`ipfs dag export`',
        wrong: () async {
          await writeCar(byKeys, [
            await for (final c in s.store.allKeysChan(ctx))
              await s.store.get(ctx, c),
          ]);
          return rootsInside(byKeys);
        },
        right: () => rootsInside(out));

    // Un CAR sin la 2ª hoja de data.bin.
    final dataBin = (await s.dag.get(ctx, s.root)).links().first.cid!;
    final missing = (await s.dag.get(ctx, dataBin)).links()[1].cid!;
    final partial = '${tmp.path}/partial.car';
    await writeCar(partial, [
      for (final b in all)
        if (b.cid != missing) b,
    ]);
    await mistake('extraer los archivos de un CAR parcial',
        why: 'offline, todo bloque tiene que estar en el CAR; uno no está',
        instead: 'comprueba primero qué tiene el CAR (pasos 3-4), o impórtalo '
            'en un nodo que pueda traer el resto (lección 16)',
        action: () => extract(partial, '${tmp.path}/out'));
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
