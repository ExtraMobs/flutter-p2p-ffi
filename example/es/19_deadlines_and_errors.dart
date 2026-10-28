// Lección 19 · ¿Cómo pongo un plazo y cancelo? ¿Qué errores pueden llegar?
//
// Pregunta: traer un CID que nadie tiene, o esperar un mensaje, puede tardar
// para siempre (lecciones 16-18). ¿Cómo dejo de esperar, y cómo distingo los
// distintos fallos?
//
// Respuesta: el `context` de Go, el primer argumento de toda llamada que
// puede esperar:
//   - context.withTimeout(padre, d) / withDeadline: Go mismo se rinde cuando
//     se acaba el tiempo, y la llamada lanza GolangDeadlineExceededException;
//   - context.withCancel(padre): llama a cancel() cuando quieras; la llamada
//     lanza GolangCanceledException;
//   - llama siempre a la función de cancelación que recibiste al terminar:
//     libera lo que Go guarda para ese context.
// Un plazo del lado de Go detiene el trabajo de Go; un `.timeout()` de Dart
// sobre el Future solo hace que Dart deje de esperar, mientras Go sigue
// trabajando.
// Los errores, del más concreto al más general (captura antes los
// concretos):
//   - GolangNotFoundException, GolangEofException, GolangCanceledException,
//     GolangDeadlineExceededException...: los errores conocidos de Go;
//   - GolangException: cualquier otro error de Go, con el mensaje de Go;
//   - P2pServiceException: el propio servicio no está (no arrancado,
//     detenido, o se cayó). También cuenta como GolangException, así que
//     captúrala antes.
// Si el p2p_host se cae (un panic de Go fuera de cualquier llamada), solo se
// va el servicio; la app recibe onStop con el motivo y el informe de Go, y
// puede reiniciar: un proceso nuevo, así que plugins, repositorio y nodo se
// abren de nuevo y los handles antiguos dejan de valer.
//
// Necesita: la lección 08 (un nodo) y la 17 (algo que espera por la red).
//
//   dart run example/es/19_deadlines_and_errors.dart
//
// Siguiente pregunta: "El nodo y todo objeto que abrí viven en Go. ¿Cuándo
// se liberan?" → lección 20.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/go/boxo/files.dart' as files;
import 'package:p2p_ffi/go/boxo/path.dart' as path;
import 'package:p2p_ffi/go/cid.dart' as cid;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/kubo/core/commands.dart' as commands;
import 'package:p2p_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:p2p_ffi/go/multicodec.dart' as multicodec;
import 'package:p2p_ffi/p2p_ffi.dart';
// ignore: implementation_imports
import 'package:p2p_ffi/src/runtime.dart' show $callSync;

import 'lesson.dart';

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('lesson19_');
  var stopped = Completer<P2pStop>();
  await P2pService.start(
      crashLog: '${tmp.path}/crash.log', // donde Go escribe un informe de caída
      onStop: (s) => stopped.complete(s));
  var bg = context.background();
  // Un nodo online solo (perfil test: sin peers de bootstrap): pedirle un CID
  // que nadie tiene espera para siempre, lo ideal para ponerle un límite.
  var n = await newNode(bg, '${tmp.path}/repo', online: true);
  final nowhere = path.Path('/ipfs/'
      '${cid.newPrefixV1(multicodec.raw, multicodec.sha2256).sum(utf8.encode('nobody has this'))}');
  try {
    var api = coreapi.newCoreApi(n);

    // 1. Un plazo: Go detiene el trabajo cuando se acaba el tiempo.
    //    Go:  ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
    //         defer cancel()
    final (withDeadline, cancelDeadline) =
        context.withTimeout(bg, const Duration(seconds: 2));
    final watch = Stopwatch()..start();
    try {
      await api.unixfs().get(withDeadline, nowhere);
    } on GolangDeadlineExceededException catch (e) {
      say('1. plazo: después de ${watch.elapsedMilliseconds} ms, '
          '${e.runtimeType}: ${e.message}');
    } finally {
      cancelDeadline();
    }

    // 2. Cancelar a mano, desde donde sea (un botón, la app cerrándose).
    //    Go:  ctx, cancel := context.WithCancel(context.Background())
    final (cancelable, cancel) = context.withCancel(bg);
    Timer(const Duration(milliseconds: 500), cancel);
    try {
      await api.unixfs().get(cancelable, nowhere);
    } on GolangCanceledException catch (e) {
      say('2. cancelado tras ~500 ms: ${e.runtimeType}: ${e.message}');
    }

    // 3. Los tipos de error, los concretos primero.
    Future<String> kindOf(Future<Object?> Function() call) async {
      try {
        await call();
        return 'sin error';
      } on P2pServiceException catch (e) {
        return 'P2pServiceException (el servicio): ${brief(e)}';
      } on GolangNotFoundException catch (e) {
        return 'GolangNotFoundException: ${brief(e)}';
      } on GolangException catch (e) {
        return 'GolangException: ${brief(e)}';
      }
    }

    say('\n3. tipos de error:');
    say('  una ruta del MFS que no existe → '
        '${await kindOf(() => commands.filesStat(n, bg, '/nope').single)}');
    say('  un bloque que no está en el blockstore → '
        '${await kindOf(() => n.blockstore.get(bg, cid.decode(nowhere.value.substring(6))))}');
    say('  un CID que no lo es → '
        '${await kindOf(() async => cid.decode('not-a-cid'))}');

    // 4. Una caída del servicio (SOLO PARA PRUEBAS: un gancho que hace panic
    //    en una goroutine de Go, como un bug dentro de kubo). Solo se cae el
    //    p2p_host; este programa sigue, avisado por onStop.
    $callSync(24);
    final s = await stopped.future;
    say('\n4. el servicio se detuvo: ${s.reason}, código de salida '
        '${s.exitCode}, activo ${s.uptime.inSeconds} s');
    say('   el informe de Go empieza por: ${s.report.split('\n').first}');
    say('   el nodo antiguo ahora: '
        '${await kindOf(() => api.unixfs().add(bg, files.newBytesFile(utf8.encode('x'))))}');

    // 5. Reiniciar: un proceso nuevo; abre todo otra vez sobre el mismo
    //    repositorio. Todo handle pertenece al servicio antiguo, el context
    //    también: crea otros nuevos.
    stopped = Completer<P2pStop>();
    await P2pService.restart();
    bg = context.background();
    n = await openNode(bg, '${tmp.path}/repo', online: true);
    api = coreapi.newCoreApi(n);
    final p =
        await api.unixfs().add(bg, files.newBytesFile(utf8.encode('back')));
    say('5. reiniciado: el servicio nuevo añadió $p');

    say('\n== Errores comunes\n');
    await mistake('un .timeout() de Dart en lugar de un plazo de Go',
        why: 'Dart deja de esperar, pero Go sigue buscando el CID: el trabajo '
            'y lo que retiene siguen en el p2p_host',
        instead: 'context.withTimeout: Go mismo se detiene y lo libera',
        action: () =>
            api.unixfs().get(bg, nowhere).timeout(const Duration(seconds: 1)));
    final (done, cancelDone) = context.withCancel(bg);
    cancelDone();
    await mistake('reutilizar un context que ya fue cancelado',
        why: 'un context cancelado sigue cancelado: toda llamada con él falla '
            'al instante, y kubo puede envolver la causa (aquí como "could '
            'not resolve name", no como GolangCanceledException)',
        instead: 'un context nuevo por operación (o por pantalla, por '
            'petición)',
        action: () => api.unixfs().get(done, nowhere));
  } finally {
    if (P2pService.isRunning) await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
