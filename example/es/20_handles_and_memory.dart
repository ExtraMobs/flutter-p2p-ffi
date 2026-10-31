// Lección 20 · ¿Cuándo tengo que liberar memoria?
//
// Pregunta: el nodo, un lector de CAR, un buffer... todo objeto Go que abro
// vive en el p2p_host (lección 01). El recolector de basura de Dart libera la
// memoria de Dart; ¿qué libera el lado de Go?
//
// Respuesta: un handle (GoHandle) es un objeto Dart pequeño que guarda un
// número; el p2p_host guarda el objeto Go de verdad en una tabla bajo ese
// número, y el recolector de basura de Go no puede liberarlo mientras esté
// ahí. La entrada se va:
//   - sola, cuando el GC de Dart recoge el handle (un Finalizer). Pero para
//     Dart un handle pesa pocos bytes, retenga lo que retenga en Go (también
//     un buffer de 64 MiB): Dart no siente presión, su GC no corre, y el
//     p2p_host crece ("basura flotante"). Vale para pocos objetos de vida
//     larga, no para bucles.
//   - ya, con release(): la entrada sale de la tabla y Go puede liberar el
//     objeto. `use(...)` libera al final de un bloque; `withGoScope(...)` /
//     GoScope liberan de una vez todo lo registrado.
// close() es otra cosa: es el Close de Go (cierra un archivo, un nodo, un
// lector); el handle sigue existiendo hasta que se libera o se recoge. Los
// valores (un CID, una ruta, bytes, una struct de datos) son copias en Dart:
// no hay nada que liberar.
//
// Necesita: la lección 01 (valores y handles). Técnicamente: el mismo
// puntero Go visto dos veces da el mismo número de handle con dos
// referencias, así que cada handle Dart se puede liberar por su cuenta.
//
//   dart run example/es/20_handles_and_memory.dart
//
// Siguiente pregunta: "Algunas funciones Go reciben una función (un handler
// de stream, un validador). ¿Cómo llama Go a mi código Dart?" → lección 21.
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

/// La memoria residente del p2p_host, en MiB.
int hostMiB() {
  final pid = P2pService.hostPid;
  if (Platform.isWindows) {
    final out =
        Process.runSync('tasklist', ['/fi', 'PID eq $pid', '/fo', 'csv', '/nh'])
            .stdout as String;
    return int.parse(out.split('","').last.replaceAll(RegExp(r'[^0-9]'), '')) ~/
        1024;
  }
  for (final line in File('/proc/$pid/status').readAsLinesSync()) {
    if (line.startsWith('VmRSS:')) {
      return int.parse(line.replaceAll(RegExp(r'[^0-9]'), '')) ~/ 1024;
    }
  }
  return -1;
}

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('lesson20_');
  final big = '${tmp.path}/8mib.bin';
  File(big).writeAsBytesSync(Uint8List(8 << 20));
  await P2pService.start();
  try {
    // 1. Un handle: un número en Dart, el objeto en Go.
    final buf = BytesBuffer(Uint8List.fromList([1, 2, 3, 4]));
    say('un bytes.Buffer: handle #${buf.$h}, liberado: ${buf.isReleased}, '
        '${buf.bytes().length} bytes en Go');
    buf.release();
    buf.release(); // un segundo release no hace nada
    say('  tras release(): liberado ${buf.isReleased}');

    // 2. El mismo puntero Go dos veces: una entrada, dos referencias.
    final f1 = go.ipfs.boxo.files.newBytesFile(Uint8List.fromList([7, 8, 9]));
    final f2 = f1.asBoxoFilesFile()!; // el mismo objeto Go, visto como File
    say('\nf1 #${f1.$h} y f2 #${f2.$h}: la misma entrada, 2 referencias');
    f1.release();
    say('  f1 liberado; f2 todavía lee ${go.io.readAll(f2)}');
    f2.release();

    // 3. Basura flotante: 20 × 8 MiB copiados a buffers de Go.
    say('\nel p2p_host al empezar: ${hostMiB()} MiB');
    for (var i = 0; i < 20; i++) {
      // use(): liberado al final del bloque, pase lo que pase dentro.
      BytesBuffer(Uint8List(0)).use((b) {
        go.os.open(big).use((f) {
          try {
            go.io.copy(b, f);
          } finally {
            f.close(); // el Close de Go: el descriptor del archivo
          }
        });
      });
    }
    say('  tras 20 copias con use(): ${hostMiB()} MiB');
    for (var i = 0; i < 20; i++) {
      final b = BytesBuffer(Uint8List(0));
      final f = go.os.open(big);
      go.io.copy(b, f);
      f.close(); // cerrado, pero ninguno de los handles liberado
    }
    say('  tras 20 copias dejadas al Finalizer: ${hostMiB()} MiB (Dart no '
        'vio motivo para recoger)');

    // 4. Muchos handles por iteración: un ámbito los libera juntos, en orden
    //    inverso, en un solo mensaje al p2p_host.
    final total = withGoScope((s) {
      final f = s.manage(go.os.open(big));
      try {
        final out = s.manage(BytesBuffer(Uint8List(0)));
        return go.io.copy(out, f);
      } finally {
        f.close();
      }
    });
    say('\nwithGoScope: copié $total bytes; los dos handles liberados al '
        'salir');
    final scope = GoScope(); // lo mismo, para una duración que eliges tú
    final kept = scope.manage(BytesBuffer(Uint8List(16)));
    scope.close();
    say('  GoScope.close(): liberado ${kept.isReleased}');

    say('\n== Errores comunes\n');
    await mistake('usar un handle después de release()',
        why: 'la entrada salió de la tabla: el número no apunta a nada',
        instead: 'todo uso antes de release(), o dentro de use((h) {...})',
        action: () => buf.bytes());
    final escaped = withGoScope((s) => s.manage(BytesBuffer(Uint8List(16))));
    await mistake('devolver un handle gestionado fuera de withGoScope',
        why: 'el ámbito lo liberó al salir',
        instead: 'devuelve un valor Dart (bytes, un CID, un recuento) desde el '
            'ámbito',
        action: () => escaped.bytes());
    if (Platform.isWindows) {
      final locked = '${tmp.path}/locked.bin';
      File(locked).writeAsBytesSync(Uint8List(64));
      final f = go.os.open(locked);
      f.release();
      await mistake('release() sin close() en un archivo abierto',
          why: 'release libera la entrada de la tabla, no el archivo: Go lo '
              'mantiene abierto hasta que su propio GC lo finaliza (y Windows '
              'entonces se niega a borrarlo)',
          instead: 'close() en un finally, luego release (o use())',
          action: () => File(locked).deleteSync());
    }
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
