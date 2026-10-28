// Lección 01 · ¿Cómo habla Dart con Go?
//
// Pregunta: p2p_ffi ofrece "la API de Go en Dart". ¿Dónde se ejecuta el código
// Go, y qué pasa cuando llamo a una de sus funciones?
//
// Respuesta: Go se ejecuta en otro proceso, el p2p_host (compilado por
// `dart run tool/build.dart`). P2pService.start() lo lanza y se conecta a él
// por memoria compartida. Cada función Go es una función Dart que envía un
// mensaje a ese proceso y espera la respuesta. Lo que vuelve es una de tres
// cosas:
//   - un valor (un CID, un string, bytes, una struct de datos): copiado a
//     Dart, sigue existiendo sin Go;
//   - un handle (un datastore, un nodo, un archivo abierto): el objeto se
//     queda en Go, y Dart guarda un número que apunta a él;
//   - un error: el `error` de Go se lanza como GolangException.
// Una función Go que recibe un `context.Context` puede bloquear (disco, red),
// así que en Dart devuelve un Future; las demás responden enseguida.
//
// Necesita: solo el build. Sin repositorio, sin red.
//
//   dart run example/es/01_dart_and_go.dart
//
// Siguiente pregunta: "¿Qué es ese CID que acabo de ver?" → lección 02.
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/go/block_format.dart' as blocks;
import 'package:p2p_ffi/go/boxo/blockstore.dart' as blockstore;
import 'package:p2p_ffi/go/cid.dart' as cid;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/datastore.dart' as datastore;
import 'package:p2p_ffi/go/datastore/sync.dart' as sync;
import 'package:p2p_ffi/go/multihash.dart' as multihash;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  // 1. Antes de que arranque el servicio, no hay Go al que llamar.
  await mistake('llamar a Go antes de P2pService.start()',
      why: 'el código Go vive en el proceso p2p_host, que no está corriendo',
      instead: 'await P2pService.start() una vez, al inicio del programa',
      action: () => cid.decode('bafkqaaa'));

  await P2pService.start();
  say('este proceso Dart: pid $pid; el proceso Go (p2p_host): '
      'pid ${P2pService.hostPid}');

  // 2. Una función sin context responde enseguida, y su resultado es un
  //    valor. Go:  c, err := cid.Decode("bafkqaaa")
  final c = cid.decode('bafkqaaa');
  say('\nun valor: ${c.runtimeType} "$c" (solo su texto, guardado en Dart)');
  // Un método de un valor sigue siendo Go: el texto va y la respuesta vuelve.
  say('  su versión, calculada por Go: ${c.version()}');

  // 3. Un handle: el mapa vive en Go; Dart solo guarda su número.
  //    Go:  ds := sync.MutexWrap(datastore.NewMapDatastore())
  final ds = sync.mutexWrap(datastore.MapDatastore());
  say('\nun handle: ${ds.runtimeType} #${ds.$h} (el objeto se queda en Go)');

  // 4. Una función con context devuelve un Future: se ejecuta en una
  //    goroutine del p2p_host mientras el event loop de Dart sigue.
  //    Go:  bs := blockstore.NewBlockstore(ds)
  //         err := bs.Put(ctx, blocks.NewBlock(data))
  final ctx = context.background();
  final bs = blockstore.Blockstore(ds);
  final data = utf8.encode('hello');
  final block = blocks.Block(
      cid: cid.newPrefixV1(cid.raw, multihash.sha2256).sum(data),
      rawData: data);
  await bs.put(ctx, block);
  say('\nasíncrono: guardé un bloque, está ahí: '
      '${await bs.has(ctx, block.cid!)}');

  // 5. Un error de Go es una excepción, con el mensaje de Go.
  await mistake('decodificar un CID a partir de un texto que no lo es',
      why: 'Go devolvió un error; en Dart se lanza (sin `err != nil`)',
      instead: 'captura GolangException donde se espera una entrada mala',
      action: () => cid.decode('not-a-cid'));

  // 6. Terminaste con un handle: libéralo, para que Go suelte el objeto ya
  //    (si no, solo cuando el recolector de basura de Dart llegue a él;
  //    lección 20).
  bs.release();
  ds.release();

  // 7. Detener el servicio termina el p2p_host. Los valores siguen siendo
  //    usables en Dart; los handles ya no apuntan a nada.
  await P2pService.stop();
  say('después del stop: el valor sigue siendo "$c"; '
      'el servicio está corriendo: ${P2pService.isRunning}');
  await mistake('usar Go después de P2pService.stop()',
      why: 'el proceso p2p_host terminó, con todo lo que guardaba',
      instead: 'detén el servicio solo al final, tras cerrar lo que esté '
          'abierto',
      action: () => c.version());
}
