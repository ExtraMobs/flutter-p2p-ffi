// Lección 10 · ¿Cómo trabajo con carpetas que cambian?
//
// Pregunta: todo CID es inmutable (lección 02): cambia un byte y es otro CID.
// ¿Cómo mantengo una carpeta que pueda editar, como en un disco normal?
//
// Respuesta: el MFS (Mutable File System), los comandos `ipfs files`. Es un
// árbol de nombres que guarda el nodo, cuya raíz apunta a un CID; cada cambio
// (write, mkdir, mv, rm) arma los nodos nuevos desde el cambio hasta la raíz,
// así que la raíz recibe un CID nuevo, y las versiones antiguas siguen siendo
// válidas en sus CIDs antiguos. No se copia nada: poner un CID en el MFS solo
// lo enlaza. Todo lo que está en el MFS queda protegido del GC (lección 09).
//
// Dos capas, el mismo árbol:
//   - los comandos (`Go.kubo.core.commands.filesWrite`, `filesLs`,
//     `filesRead`...): el `ipfs files` de la línea de comandos, cada uno un
//     Stream de resultados;
//   - el paquete mfs de boxo (`Go.boxo.mfs.mkdir`, `Go.boxo.mfs.lookup`,
//     `BoxoMfsFile.open`...): la capa que los comandos usan por dentro, con
//     más control (abrir un archivo, posicionarse, escribir un trozo) y más
//     deberes (cerrar lo que abres, flush).
//
// Necesita: la lección 08 (un nodo: la raíz de su MFS es n.filesRoot).
// Técnicamente, el MFS necesita un DAGService para leer y escribir sus
// nodos, y un CID raíz guardado en el repositorio entre ejecuciones.
//
//   dart run example/es/10_mfs.dart
//
// Siguiente pregunta: "El CID de la carpeta cambia con cada edición; ¿cómo
// le doy a alguien una dirección que siempre muestre la versión más nueva?"
// → lección 11.
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson10_');
  final ctx = Go.context.background();
  final n = await newNode(ctx, '${tmp.path}/repo');
  try {
    final api = Go.kubo.core.coreapi.newCoreApi(n);
    Future<String> rootCid() async =>
        (await Go.kubo.core.commands.filesStat(n, ctx, '/').single).hash;

    // 1. Los comandos: mkdir, write, ls, read, como en la línea de comandos.
    //    CLI: ipfs files mkdir -p /site; echo ... | ipfs files write --create /site/index.html
    final empty = await rootCid();
    await Go.kubo.core.commands
        .filesMkdir(n, ctx, '/site', parents: true)
        .drain<void>();
    await Go.kubo.core.commands
        .filesWrite(n, ctx, '/site/index.html',
            Go.boxo.files.newBytesFile(utf8.encode('<h1>v1</h1>\n')),
            create: true)
        .drain<void>();
    final v1 = await rootCid();
    say('la raíz del MFS: vacía $empty → tras un write $v1');
    final ls =
        await Go.kubo.core.commands.filesLs(n, ctx, '/site', long: true).single;
    for (final e in ls.entries) {
      say('  /site/${e.name}  ${e.size} bytes  ${e.hash}');
    }
    final html = await Go.kubo.core.commands
        .filesRead(n, ctx, '/site/index.html')
        .fold<List<int>>([], (all, piece) => all..addAll(piece));
    say('  leído: ${utf8.decode(html).trim()}');

    // 2. Editar el mismo nombre: la raíz recibe un CID nuevo, la antigua
    //    sigue mostrando la v1 (inmutable, como siempre).
    await Go.kubo.core.commands
        .filesWrite(n, ctx, '/site/index.html',
            Go.boxo.files.newBytesFile(utf8.encode('<h1>v2</h1>\n')),
            truncate: true)
        .drain<void>();
    final v2 = await rootCid();
    final old = await Go.kubo.core.commands
        .cat(n, ctx, ['/ipfs/$v1/site/index.html']).fold<List<int>>(
            [], (all, piece) => all..addAll(piece));
    say('\ntras editar: raíz $v2');
    say('  la raíz antigua todavía lee: ${utf8.decode(old).trim()}');

    // 3. Un CID de fuera, enlazado en el MFS sin copiar (`files cp`).
    final logo = await api
        .unixfs()
        .add(ctx, Go.boxo.files.newBytesFile(utf8.encode('a logo, say\n')));
    await Go.kubo.core.commands
        .filesCp(n, ctx, logo.value, '/site/logo.txt')
        .drain<void>();
    say('\nenlacé $logo como /site/logo.txt (ningún byte copiado)');

    // 4. El nivel bajo: el mfs de boxo, sobre el mismo árbol.
    //    Go:  f := mfs.Lookup(root, "/site/index.html").(*mfs.File)
    //         fd, _ := f.Open(ctx, mfs.Flags{Write: true, Sync: true})
    //         fd.Seek(0, io.SeekEnd); fd.Write(b); fd.Close()
    final root = n.filesRoot;
    final file = Go.boxo.mfs.lookup(root, '/site/index.html').asBoxoMfsFile()!;
    final w = await file.open(ctx, BoxoMfsFlags(write: true, sync: true));
    w.seek(0, 2); // 2 = io.SeekEnd
    w.write(utf8.encode('<p>appended by mfs</p>\n'));
    w.close(); // close es lo que escribe el cambio en el árbol
    final r = await file.open(ctx, BoxoMfsFlags(read: true));
    final now = await r.ctxReadFull(ctx, 1024);
    r.close();
    say('\nmfs, tras añadir al final:\n${utf8.decode(now)}');
    //    Go:  mfs.Mv(root, "/site/logo.txt", "/site/img/logo.txt")
    Go.boxo.mfs.mkdir(root, '/site/img', BoxoMfsMkdirOpts(mkparents: true));
    Go.boxo.mfs.mv(root, '/site/logo.txt', '/site/img/logo.txt');
    //    Go:  nd, _ := mfs.FlushPath(ctx, root, "/site")
    final site = await Go.boxo.mfs.flushPath(ctx, root, '/site');
    say('/site escrito (flush): ${site.cid()}');
    final dir = Go.boxo.mfs.lookup(root, '/site').asBoxoMfsDirectory()!;
    say('  entradas: ${(await dir.listNames(ctx)).join(', ')}');

    say('\n== Errores comunes\n');
    await mistake('escribir en una ruta cuya carpeta no existe',
        why: 'files write crea el archivo (create: true), no las carpetas de '
            'encima',
        instead: 'filesMkdir(..., parents: true) antes',
        action: () => Go.kubo.core.commands
            .filesWrite(n, ctx, '/nope/a.txt',
                Go.boxo.files.newBytesFile(utf8.encode('x')),
                create: true)
            .drain<void>());
    // (Abrir un archivo para escritura mientras otro descriptor está abierto
    // no falla: espera a que se cierre el primero, como en Go. Cierra cada
    // descriptor en un finally, o la siguiente apertura espera para siempre.)
    await mistake('borrar una carpeta que no está vacía',
        why: 'files rm rechaza carpetas salvo que le digas que borre lo que '
            'hay dentro',
        instead: 'filesRm(..., recursive: true)',
        action: () =>
            Go.kubo.core.commands.filesRm(n, ctx, ['/site']).drain<void>());
    await mistake('leer una ruta que no existe',
        why: 'las rutas del MFS son nombres en el árbol, no CIDs: una errata '
            'es un error',
        instead: 'filesStat o filesLs para comprobar; las rutas /ipfs/<cid> '
            'van a cat',
        action: () =>
            Go.kubo.core.commands.filesStat(n, ctx, '/site/index.htm').single);
  } finally {
    await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
