// Lección 09 · ¿Por qué desaparecen mis bloques?
//
// Pregunta: añadí un archivo, y después ya no estaba en el nodo. ¿Por qué, y
// cómo guardo lo que importa?
//
// Respuesta: el disco de un nodo es una caché. El recolector de basura
// (`ipfs repo gc`, o automático cuando se llena el Datastore.StorageMax con el
// GC activo) borra todo bloque que nada protege. Lo que protege un bloque:
//   - un pin recursivo: la raíz y todo lo que hay debajo (lo que hace
//     `ipfs add` por defecto en la línea de comandos; la CoreAPI NO fija
//     salvo que se lo pidas);
//   - un pin directo: solo ese bloque;
//   - estar debajo de un pin recursivo: un pin "indirecto";
//   - estar en el MFS, el árbol de archivos del nodo (lección 10).
// Quitar el pin no borra; lo borra el siguiente GC.
//
// Necesita: la lección 08 (un nodo y su CoreAPI). Técnicamente, el GC
// necesita el blockstore con GC del nodo (n.blockstore) y su pinner: toma el
// bloqueo de GC (ningún add ni pin corre mientras tanto), marca todo lo que
// se alcanza desde los pins y desde el MFS, y borra el resto.
//
//   dart run example/es/09_pins_and_gc.dart
//
// Siguiente pregunta: "Fijar cada CID a mano es incómodo; ¿puedo tener
// carpetas, sin más?" → lección 10.
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson09_');
  final ctx = goContext.background();
  final n = await newNode(ctx, '${tmp.path}/repo');
  try {
    final api = goKubo.core.coreapi.newCoreApi(n);
    Future<BoxoPath> add(String text,
            [List<KuboCoreCoreifaceOptionsUnixfsAddOption> o = const []]) =>
        api.unixfs().add(ctx, goBoxo.files.newBytesFile(utf8.encode(text)), o);
    // No encontrado es el ErrNotFound de ipld, lanzado como
    // GolangNotFoundException; cualquier otro error (un store roto, un nodo
    // cerrado) sube.
    //    Go:  _, err := api.Block().Stat(ctx, p)
    //         return !ipld.IsNotFound(err)
    Future<bool> here(BoxoPath p) async {
      try {
        await api.block().stat(ctx, p);
        return true;
      } on GolangNotFoundException {
        return false;
      }
    }

    // 1. Cuatro archivos, cuatro destinos.
    //    Go:  api.Unixfs().Add(ctx, f, options.Unixfs.Pin(true, "name"))
    final pinned = await add('kept by a pin\n',
        [goKubo.core.coreiface.options.unixfs.pin(true, 'lesson-09')]);
    final loose = await add('nothing protects me\n');
    final inMfs = await add('kept by MFS\n');
    final unpinned = await add('pinned, then unpinned\n',
        [goKubo.core.coreiface.options.unixfs.pin(true, '')]);
    //    Go:  mfs.PutNode(n.FilesRoot, "/kept.txt", nd)
    goBoxo.mfs
        .putNode(n.filesRoot, '/kept.txt', await api.resolveNode(ctx, inMfs));
    //    Go:  api.Pin().Rm(ctx, p)
    await api.pin().rm(ctx, unpinned);

    // Un bloque raw (`ipfs block put --pin`): kubo lo fija como recursivo.
    final raw = await api.block().put(ctx, utf8.encode('a raw block'),
        [goKubo.core.coreiface.options.block.pin(true)]);

    Future<void> show(String when) async {
      say('\n$when:');
      for (final (name, p) in [
        ('fijado', pinned),
        ('suelto', loose),
        ('en el MFS', inMfs),
        ('desfijado', unpinned),
        ('bloque raw', raw.path!),
      ]) {
        final (how, isPinned) = await api.pin().isPinned(ctx, p);
        say('  ${name.padRight(10)} está aquí: '
            '${(await here(p)).toString().padRight(5)} '
            'pin: ${isPinned ? how : 'no'}');
      }
    }

    await show('antes del GC');

    // 2. Los pins, con nombres y tipos.
    //    Go:  api.Pin().Ls(ctx, options.Pin.Ls.Detailed(true))
    say('\npin ls:');
    await for (final p in api
        .pin()
        .ls(ctx, [goKubo.core.coreiface.options.pin.ls.detailed(true)])) {
      say('  ${p.type.padRight(9)} ${p.path} ${p.name}');
    }

    // 3. GC: todo lo que no se alcanza desde un pin o desde el MFS se va.
    //    Go:  for r := range corerepo.GarbageCollectAsync(n, ctx) { ... }
    final removed =
        await goKubo.core.corerepo.garbageCollectAsync(n, ctx).toList();
    say('\nel GC borró ${removed.length} bloque(s): '
        '${removed.map((r) => r.keyRemoved).join(', ')}');
    await show('después del GC');

    // 4. Los pins se pueden comprobar: ¿sigue aquí todo bloque debajo de
    //    ellos?
    //    Go:  for s := range api.Pin().Verify(ctx) { s.Ok() }
    final intact = await api.pin().verify(ctx).every((s) => s.ok);
    say('\npin verify: todo íntegro: $intact');

    say('\n== Errores comunes\n');
    await mistake('quitar el pin de algo que no está fijado',
        why: 'el pinner no tiene pin para él (solo está aquí por suerte, o ni '
            'está)',
        instead: 'comprueba api.pin().isPinned antes',
        action: () => api.pin().rm(ctx, loose));
    await mistake('borrar a mano un bloque fijado (`ipfs block rm`)',
        why: 'el pin lo protege: kubo se niega a borrar un bloque fijado',
        instead: 'quítale el pin antes; el siguiente GC lo borra',
        action: () => api.block().rm(ctx, raw.path!));
  } finally {
    await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
