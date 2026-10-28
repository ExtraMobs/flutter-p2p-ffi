// Lección 11 · ¿Cómo doy un nombre fijo a algo que cambia?
//
// Pregunta: el CID de mi sitio cambia con cada edición (lección 10). ¿Cómo le
// doy a la gente una dirección que siempre lleve a la versión más nueva?
//
// Respuesta: IPNS. Un nombre IPNS es una clave pública (su hash, como un peer
// ID: `/ipns/k51...`); un registro firmado con la clave privada dice "este
// nombre apunta a /ipfs/<cid>, versión N". Publicar un registro nuevo mueve
// el nombre; quien lo resuelve comprueba la firma, así que solo quien tiene
// la clave puede moverlo. Cada nodo tiene una clave propia (su identidad,
// lección 07), llamada "self", y puede crear más en su keystore: una por
// nombre que quiera mantener. Las claves también firman y verifican
// cualquier byte.
//
// Necesita: la lección 08 (un nodo). Técnicamente: una clave en el keystore
// (para firmar) y un sitio donde poner el registro firmado: el propio
// repositorio del nodo cuando está offline (lo que hace esta lección), el
// DHT o un enrutador delegado online (lecciones 15-17), donde otros peers
// pueden encontrarlo.
//
//   dart run example/es/11_ipns_and_keys.dart
//
// Siguiente pregunta: "Esto lo conozco de la línea de comandos `ipfs`;
// ¿puedo llamar a los comandos sin más?" → lección 12.
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/go/boxo/files.dart' as files;
import 'package:p2p_ffi/go/boxo/ipns.dart' as ipns;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:p2p_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson11_');
  final ctx = context.background();
  final n = await newNode(ctx, '${tmp.path}/repo');
  try {
    final api = coreapi.newCoreApi(n);

    // 1. La clave del propio nodo, "self": su nombre IPNS es su peer ID.
    //    Go:  k, _ := api.Key().Self(ctx)
    final self = await api.key().self(ctx);
    final selfName = ipns.nameFromPeer(self.id!);
    say('clave "${self.name}": peer ${self.id}');
    say('  su nombre IPNS: ${selfName.asPath()}');

    // 2. Publica la v1, resuelve; publica la v2, resuelve: el nombre se
    //    queda, el destino se mueve.
    //    Go:  name, _ := api.Name().Publish(ctx, p, options.Name.AllowOffline(true))
    //         target, _ := api.Name().Resolve(ctx, "/ipns/"+name.String(), options.Name.Cache(false))
    for (final version in ['v1', 'v2']) {
      final p = await api.unixfs().add(
          ctx,
          files.newBytesFile(utf8.encode('my site, $version\n')),
          [options.unixfs.pin(true, 'site-$version')]);
      final name =
          await api.name().publish(ctx, p, [options.name.allowOffline(true)]);
      final target = await api
          .name()
          .resolve(ctx, '/ipns/$name', [options.name.cache(false)]);
      say('\npubliqué la $version: /ipns/$name → $target');
    }

    // 3. Otra clave para otro nombre (un nombre por cosa que publicas).
    //    Go:  k, _ := api.Key().Generate(ctx, "blog", options.Key.Type("ed25519"))
    //         api.Name().Publish(ctx, p, options.Name.Key("blog"), ...)
    final blog =
        await api.key().generate(ctx, 'blog', [options.key.type('ed25519')]);
    final post = await api
        .unixfs()
        .add(ctx, files.newBytesFile(utf8.encode('first post\n')));
    final blogName = await api.name().publish(
        ctx, post, [options.name.key('blog'), options.name.allowOffline(true)]);
    say('\nclave "blog" (${blog.id}): /ipns/$blogName → $post');
    say('  claves en el keystore: '
        '${(await api.key().list(ctx)).map((k) => k.name).join(', ')}');

    // 4. Las claves firman y verifican cualquier byte.
    //    Go:  k, sig, _ := api.Key().Sign(ctx, "blog", data)
    //         _, ok, _ := api.Key().Verify(ctx, "blog", sig, data)
    final data = utf8.encode('I wrote this');
    final (_, signature) = await api.key().sign(ctx, 'blog', data);
    final (_, ok) = await api.key().verify(ctx, 'blog', signature, data);
    final (_, forged) = await api
        .key()
        .verify(ctx, 'blog', signature, utf8.encode('I did not write this'));
    say('\nfirmé ${data.length} bytes con "blog": firma de '
        '${signature.length} bytes; válida: $ok; sobre otros bytes: $forged');

    // 5. Renombrar y borrar. Borrar una clave pierde su nombre para siempre:
    //    nadie puede volver a publicar con él.
    final (renamed, _) = await api.key().rename(ctx, 'blog', 'old-blog');
    await api.key().remove(ctx, renamed.name);
    say('\nrenombré "blog" a "${renamed.name}" y luego la borré');

    say('\n== Errores comunes\n');
    await mistake('publicar offline sin allowOffline(true)',
        why: 'por defecto publish quiere llegar a la red, para que el '
            'registro se pueda encontrar; este nodo está offline',
        instead: 'options.name.allowOffline(true) para un registro local, o '
            'un nodo online (lección 17)',
        action: () async =>
            api.name().publish(ctx, post, [options.name.key('self')]));
    await mistake('publicar con una clave que no existe',
        why: 'no hay clave privada con la que firmar el registro',
        instead: 'api.key().generate antes; api.key().list muestra lo que hay',
        action: () => api.name().publish(ctx, post, [
              options.name.key('no-such-key'),
              options.name.allowOffline(true)
            ]));
    await mistake('generar una clave llamada "self"',
        why: '"self" es la clave de identidad del propio nodo, siempre '
            'presente',
        instead: 'cualquier otro nombre',
        action: () => api.key().generate(ctx, 'self'));
  } finally {
    await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
