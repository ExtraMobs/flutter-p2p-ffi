// Lição 11 · Como dou um nome fixo a algo que muda?
//
// Pergunta: o CID do meu site muda a cada edição (lição 10). Como dou às
// pessoas um endereço que sempre leva à versão mais nova?
//
// Resposta: IPNS. Um nome IPNS é uma chave pública (o hash dela, como um peer
// ID: `/ipns/k51...`); um registro assinado com a chave privada diz "este
// nome aponta para /ipfs/<cid>, versão N". Publicar um registro novo move o
// nome; quem o resolve confere a assinatura, então só quem tem a chave pode
// movê-lo. Cada nó tem uma chave própria (a sua identidade, lição 07),
// chamada "self", e pode criar mais no keystore: uma por nome que queira
// manter. As chaves também assinam e verificam quaisquer bytes.
//
// Precisa de: lição 08 (um nó). Tecnicamente: uma chave no keystore (para
// assinar) e um lugar para pôr o registro assinado: o próprio repositório do
// nó quando offline (o que esta lição faz), o DHT ou um roteador delegado
// online (lições 15-17), onde outros peers podem achá-lo.
//
//   dart run example/pt_br/11_ipns_and_keys.dart
//
// Próxima pergunta: "Conheço isso da linha de comando `ipfs`; posso só
// chamar os comandos?" → lição 12.
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson11_');
  final ctx = go.context.background();
  final n = await newNode(ctx, '${tmp.path}/repo');
  try {
    final api = go.ipfs.kubo.core.coreapi.newCoreApi(n);

    // 1. A chave do próprio nó, "self": o nome IPNS dela é o peer ID.
    //    Go:  k, _ := api.Key().Self(ctx)
    final self = await api.key().self(ctx);
    final selfName = go.ipfs.boxo.ipns.nameFromPeer(self.id!);
    say('chave "${self.name}": peer ${self.id}');
    say('  o nome IPNS dela: ${selfName.asPath()}');

    // 2. Publica a v1, resolve; publica a v2, resolve: o nome fica, o alvo
    //    muda.
    //    Go:  name, _ := api.Name().Publish(ctx, p, options.Name.AllowOffline(true))
    //         target, _ := api.Name().Resolve(ctx, "/ipns/"+name.String(), options.Name.Cache(false))
    for (final version in ['v1', 'v2']) {
      final p = await api.unixfs().add(ctx,
          go.ipfs.boxo.files.newBytesFile(utf8.encode('my site, $version\n')), [
        go.ipfs.kubo.core.coreiface.options.unixfs.pin(true, 'site-$version')
      ]);
      final name = await api.name().publish(ctx, p,
          [go.ipfs.kubo.core.coreiface.options.name.allowOffline(true)]);
      final target = await api.name().resolve(ctx, '/ipns/$name',
          [go.ipfs.kubo.core.coreiface.options.name.cache(false)]);
      say('\npubliquei a $version: /ipns/$name → $target');
    }

    // 3. Outra chave para outro nome (um nome por coisa que você publica).
    //    Go:  k, _ := api.Key().Generate(ctx, "blog", options.Key.Type("ed25519"))
    //         api.Name().Publish(ctx, p, options.Name.Key("blog"), ...)
    final blog = await api.key().generate(
        ctx, 'blog', [go.ipfs.kubo.core.coreiface.options.key.type('ed25519')]);
    final post = await api
        .unixfs()
        .add(ctx, go.ipfs.boxo.files.newBytesFile(utf8.encode('first post\n')));
    final blogName = await api.name().publish(ctx, post, [
      go.ipfs.kubo.core.coreiface.options.name.key('blog'),
      go.ipfs.kubo.core.coreiface.options.name.allowOffline(true)
    ]);
    say('\nchave "blog" (${blog.id}): /ipns/$blogName → $post');
    say('  chaves no keystore: '
        '${(await api.key().list(ctx)).map((k) => k.name).join(', ')}');

    // 4. As chaves assinam e verificam quaisquer bytes.
    //    Go:  k, sig, _ := api.Key().Sign(ctx, "blog", data)
    //         _, ok, _ := api.Key().Verify(ctx, "blog", sig, data)
    final data = utf8.encode('I wrote this');
    final (_, signature) = await api.key().sign(ctx, 'blog', data);
    final (_, ok) = await api.key().verify(ctx, 'blog', signature, data);
    final (_, forged) = await api
        .key()
        .verify(ctx, 'blog', signature, utf8.encode('I did not write this'));
    say('\nassinei ${data.length} bytes com "blog": assinatura de '
        '${signature.length} bytes; válida: $ok; em outros bytes: $forged');

    // 5. Renomear e remover. Remover uma chave perde o nome para sempre:
    //    ninguém mais consegue publicar sob ele.
    final (renamed, _) = await api.key().rename(ctx, 'blog', 'old-blog');
    await api.key().remove(ctx, renamed.name);
    say('\nrenomeei "blog" para "${renamed.name}" e depois a removi');

    say('\n== Erros comuns\n');
    await mistake('publicar offline sem allowOffline(true)',
        why: 'por padrão o publish quer alcançar a rede, para o registro ser '
            'encontrado; este nó está offline',
        instead:
            'go.ipfs.kubo.core.coreiface.options.name.allowOffline(true) para um registro local, ou '
            'um nó online (lição 17)',
        action: () async => api.name().publish(
            ctx, post, [go.ipfs.kubo.core.coreiface.options.name.key('self')]));
    await mistake('publicar com uma chave que não existe',
        why: 'não há chave privada para assinar o registro',
        instead: 'api.key().generate antes; api.key().list mostra o que existe',
        action: () => api.name().publish(ctx, post, [
              go.ipfs.kubo.core.coreiface.options.name.key('no-such-key'),
              go.ipfs.kubo.core.coreiface.options.name.allowOffline(true)
            ]));
    await mistake('gerar uma chave chamada "self"',
        why: '"self" é a chave de identidade do próprio nó, sempre presente',
        instead: 'qualquer outro nome',
        action: () => api.key().generate(ctx, 'self'));
  } finally {
    await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
