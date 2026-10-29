// Lección 12 · ¿Cómo uso los comandos `ipfs` que ya conozco?
//
// Pregunta: conozco `ipfs add`, `ipfs cat`, `ipfs pin ls`, `ipfs dag put`...
// de la terminal. ¿Puedo llamarlos desde Dart, sin HTTP, y qué hago con lo
// que devuelven?
//
// Respuesta: cada comando de kubo es una función Dart en
// `Go.kubo.core.commands`: los argumentos de la línea de
// comandos son sus parámetros posicionales, las flags los nombrados (`ipfs
// files mkdir -p /a` → `filesMkdir(n, ctx, '/a', parents: true)`). Se
// ejecutan dentro del propio nodo de la app y devuelven un Stream: un
// elemento por línea de resultado del comando, o trozos de bytes en el caso
// de `cat`. Un Stream se consume de varias formas:
//   - `.single`: un comando con exactamente un resultado (`filesStat`, `id`);
//   - `.toList()` o `await for`: muchos resultados (`pinLs`, `refs`);
//   - `.drain()`: ejecutarlo e ignorar la salida (`filesMkdir`);
//   - `.fold` o un BytesBuilder: juntar los trozos de `cat`;
//   - `.listen`: reaccionar a cada elemento cuando llega, sin esperar.
// Los datos IPLD que no son archivos, como un objeto JSON, entran con `dag
// put` (guardados como dag-cbor, con enlaces a otros CIDs) y se leen de
// vuelta por ruta.
//
// Necesita: la lección 08 (un nodo: los comandos se ejecutan en él).
// Técnicamente, cada comando necesita lo que necesita su parte de la
// CoreAPI: el blockstore, el pinner, el MFS; los comandos de red (`swarm`,
// `routing`, `pubsub`) necesitan un nodo online.
//
//   dart run example/es/12_ipfs_commands.dart
//
// Siguiente pregunta: "Todo esto es local. ¿Cómo existe mi nodo en la red?"
// → lección 13.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson12_');
  final ctx = Go.context.background();
  final n = await newNode(ctx, '${tmp.path}/repo');
  try {
    final api = Go.kubo.core.coreapi.newCoreApi(n);

    // 1. Un resultado: `.single`.           CLI: ipfs id; ipfs repo stat
    final id = await Go.kubo.core.commands.id(n, ctx, null).single;
    say('ipfs id: ${id.id} (${id.agentVersion})');
    final repo = await Go.kubo.core.commands.repoStat(n, ctx).single;
    say('ipfs repo stat: ${repo.numObjects} objetos, ${repo.repoSize} bytes');

    // 2. Muchos resultados: `await for`.    CLI: ipfs add -r folder
    final folder = Directory('${tmp.path}/folder')..createSync();
    File('${folder.path}/a.txt').writeAsStringSync('A\n');
    File('${folder.path}/b.txt').writeAsStringSync('B\n');
    say('\nipfs add -r, un evento por archivo:');
    await for (final e in Go.kubo.core.commands.add(
        n,
        ctx,
        [
          Go.boxo.files
              .newSerialFile(folder.path, false, Go.os.stat(folder.path))
        ],
        recursive: true,
        cidVersion: 1)) {
      say('  ${e.name.padRight(12)} ${e.hash}');
    }

    // 3. Bytes en trozos: júntalos.         CLI: ipfs cat <cid>
    final big = Uint8List(600000);
    final p = await api.unixfs().add(ctx, Go.boxo.files.newBytesFile(big));
    final joined = BytesBuilder();
    var pieces = 0;
    await for (final piece in Go.kubo.core.commands.cat(n, ctx, [p.value])) {
      pieces++;
      joined.add(piece);
    }
    say('\nipfs cat: ${joined.length} bytes en $pieces trozos');

    // 4. Reaccionar a los elementos cuando llegan, sin esperar: `.listen`.
    //    CLI: ipfs pin ls --type=recursive
    final done = <String>[];
    final sub = Go.kubo.core.commands
        .pinLs(n, ctx, [], type: 'recursive')
        .listen((w) => done.addAll(w.keys.keys),
            onDone: () => say('  (pin ls terminó: ${done.length} pins)'));
    say('\nipfs pin ls empezó; esta línea sale antes de que termine');
    await sub.asFuture<void>();

    // 5. `.drain()`: ejecutar e ignorar la salida.   CLI: ipfs files mkdir -p /a/b
    await Go.kubo.core.commands
        .filesMkdir(n, ctx, '/a/b', parents: true)
        .drain<void>();
    say('\nipfs files mkdir -p /a/b: hecho');

    // 6. Objetos IPLD: entra JSON, se guarda dag-cbor, se lee de vuelta por
    //    ruta, siguiendo enlaces.          CLI: ipfs dag put / ipfs dag get
    final author = await Go.kubo.core.commands.dag
        .dagPut(api, ctx, utf8.encode('{"name": "Ana", "lang": "pt"}'));
    final post = await Go.kubo.core.commands.dag.dagPut(
        api,
        ctx,
        utf8.encode('{"title": "hi", "tags": ["ipfs", "dart"], '
            '"author": {"/": "$author"}}'),
        pin: true);
    say('\nipfs dag put: post $post (dag-cbor: ${post.type() == Go.multicodec.dagCbor})');
    final tags = await Go.kubo.core.commands.dag
        .dagGet(api, ctx, BoxoPath('/ipfs/$post/tags'));
    final name = await Go.kubo.core.commands.dag
        .dagGet(api, ctx, BoxoPath('/ipfs/$post/author/name'));
    say('  /tags → ${utf8.decode(tags)}');
    say('  /author/name (por el enlace) → ${utf8.decode(name)}');

    say('\n== Errores comunes\n');
    await mistake('`.single` en un comando que da muchos resultados',
        why: 'single quiere exactamente un elemento; ipfs add -r dio uno por '
            'archivo',
        instead: '`await for` o `.toList()`',
        action: () => Go.kubo.core.commands
            .add(
                n,
                ctx,
                [
                  Go.boxo.files.newSerialFile(
                      folder.path, false, Go.os.stat(folder.path))
                ],
                recursive: true)
            .single);
    await mistake('esperar un error que el Stream ya lanzó',
        why: 'el error de un comando llega por el Stream; nadie lo escuchaba',
        instead: 'espera el Stream (o listen con onError) dentro de un try',
        action: () =>
            Go.kubo.core.commands.filesStat(n, ctx, '/no/such/path').single);
    await mistake('dag put de un texto que no es JSON',
        why: 'el codec de entrada es dag-json por defecto',
        instead: 'JSON válido, o un inputCodec que coincida con lo que envías',
        action: () => Go.kubo.core.commands.dag
            .dagPut(api, ctx, utf8.encode('not json')));
  } finally {
    await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
