// Lección 21 · ¿Cómo llama Go a mi código Dart?
//
// Pregunta: algunas funciones Go reciben una función: un handler de stream
// (lección 14), un validador de pubsub (lección 18), un callback por entrada
// de un índice. Go se ejecuta en otro proceso; ¿cómo llama a una función
// Dart, y cuáles son las reglas?
//
// Respuesta: una función Dart pasada donde Go espera una función se vuelve un
// callback: cuando Go la llama, el p2p_host envía los argumentos a Dart, Dart
// ejecuta la función en su event loop, y la respuesta (o la excepción)
// vuelve a Go. Cuatro formas:
//   - llamada durante la llamada, muchas veces (el ForEach de un índice): Go
//     envía las llamadas en lotes para ahorrar idas y vueltas (`batchSize`);
//     lanzar una excepción desde la función detiene a Go, y la llamada falla
//     con tu error;
//   - guardada por Go después de que la llamada vuelve (un handler de
//     stream, un Notifiee, un validador): Go la llama cada vez que ocurre el
//     evento, hasta que la quitas (removeStreamHandler, stopNotify...);
//   - una interfaz Go implementada en Dart (network.Notifiee,
//     mdns.Notifee): una función Dart por método Go, las que omites no hacen
//     nada;
//   - una función que recibe un objeto Go válido solo durante la llamada (un
//     constructor de selectores): úsalo dentro, nunca lo guardes.
// Si, dentro de un callback, tu código Dart vuelve a llamar a un objeto Go
// que la función Go en espera mantiene bloqueado, el p2p_host lo nota y
// lanza GolangDeadlockException en tu función en lugar de quedarse colgado.
//
// Necesita: las lecciones 06 (un índice, un selector), 14 (un handler de
// stream).
//
//   dart run example/es/21_callbacks.dart
//
// Este es el final del curso; las preguntas que responde están en
// README.md.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

/// Se lanza desde un callback para detener el bucle de Go antes de tiempo.
class Enough implements Exception {}

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson21_');
  try {
    final ctx = go.context.background();

    // 1. Llamada muchas veces durante la llamada: cada entrada de un índice
    //    de CAR.
    //    Go:  idx.(index.IterableIndex).ForEach(func(mh multihash.Multihash, off uint64) error {...})
    final s = await Sample.build(ctx);
    final carFile = '${tmp.path}/sample.car';
    await s.writeCar(ctx, carFile);
    final idx = go.ipld.car.v2
        .generateIndexFromFile(carFile)
        .asCarV2IndexIterableIndex()!;
    final offsets = <int>[];
    await idx.forEach((multihash, offset) => offsets.add(offset));
    say('forEach llamó a la función Dart ${offsets.length} veces; posiciones '
        '${offsets..sort()}');
    //    Parar antes de tiempo: lanza una excepción; Go se detiene y la
    //    llamada falla con tu error.
    var seen = 0;
    try {
      await idx.forEach((_, __) {
        if (++seen == 2) throw Enough();
      }, batchSize: 1);
    } on Enough {
      say('  se detuvo tras $seen entradas, por una excepción en el callback');
    }

    // 2. Guardada por Go: un handler de stream, llamado por cada stream que
    //    llega, hasta que se quita.
    //    Go:  b.SetStreamHandler(proto, func(s network.Stream) {...})
    Future<Libp2pCoreHost> newHost() => go.libp2p.libp2p.new$([
          go.libp2p.libp2p.options.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
        ]);
    final a = await newHost(), b = await newHost();
    var served = 0;
    b.setStreamHandler('/lesson/echo/1.0.0', (st) async {
      served++;
      final got = await readerStream(st).expand((c) => c).toList();
      await st.write(Uint8List.fromList(got.reversed.toList()));
      await st.close();
    });
    await a.connect(ctx, go.libp2p.libp2p.core.host.infoFromHost(b));
    Future<String> echo(String text) async {
      final st = await a.newStream(ctx, b.id(), ['/lesson/echo/1.0.0']);
      await st.write(Uint8List.fromList(utf8.encode(text)));
      await st.closeWrite();
      return utf8.decode(await readerStream(st).expand((c) => c).toList());
    }

    say('\neco "abc" → "${await echo('abc')}", "dart" → '
        '"${await echo('dart')}" (el handler se ejecutó $served veces)');
    b.removeStreamHandler('/lesson/echo/1.0.0');

    // 3. Una interfaz Go implementada en Dart: solo los métodos que
    //    necesitas.
    //    Go:  a.Network().Notify(&network.NotifyBundle{DisconnectedF: ...})
    final gone = Libp2pCoreNetworkNotifiee(
        disconnected: (_, c) =>
            say('  [Notifiee] perdí a ${c.remotePeer().shortString()}'));
    a.network().notify(gone);
    final c = await newHost();
    await a.connect(ctx, go.libp2p.libp2p.core.host.infoFromHost(c));
    say('\ncerrando c, con un Notifiee en a:');
    await c.close();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    a.network().stopNotify(gone);

    // 4. Un objeto Go válido solo durante la llamada: un constructor de
    //    selectores entrega un constructor de campos a la función, que lo
    //    rellena ahí mismo.
    //    Go:  ssb.ExploreFields(func(efsb builder.ExploreFieldsSpecBuilder) {
    //             efsb.Insert("Links", ssb.Matcher()) })
    final ssb = IpldPrimeTraversalSelectorBuilderSelectorSpecBuilder(
        IpldPrimeNodeBasicnodePrototypeAny());
    final spec =
        await ssb.exploreFields((f) => f.insert('Links', ssb.matcher()));
    say('\nexploreFields: armé una especificación de selector dentro del '
        'callback: ${spec.runtimeType}');

    say('\n== Errores comunes\n');
    await mistake('un lote grande en un callback que recibe un objeto Go',
        why: 'con lote, Go sigue antes de que Dart ejecute la función: el '
            'constructor de campos ya terminó cuando Dart inserta en él',
        instead: 'deja el valor por defecto (1) cuando el callback recibe un '
            'objeto Go; lotes solo para valores simples (posiciones, bytes)',
        action: () => ssb.exploreFields((f) => f.insert('Links', ssb.matcher()),
            batchSize: 1024));
    await mistake('abrir un stream a un handler que se quitó',
        why: 'removeStreamHandler le quitó a Go la función Dart: b ya no '
            'habla el protocolo',
        instead: 'mantén el handler mientras atiendes; quítalo al terminar',
        action: () => echo('again'));
    await a.close();
    await b.close();
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
