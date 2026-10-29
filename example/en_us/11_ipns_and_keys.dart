// Lesson 11 · How do I give a fixed name to something that changes?
//
// Question: my site's CID changes on every edit (lesson 10). How do I give
// people one address that always leads to the latest version?
//
// Answer: IPNS. An IPNS name is a public key (its hash, like a peer ID:
// `/ipns/k51...`); a record signed with the private key says "this name
// points to /ipfs/<cid>, version N". Publishing a new record moves the name;
// whoever resolves it checks the signature, so only the key holder can move
// it. Each node has one key of its own (its identity, lesson 07), named
// "self", and can make more in its keystore: one per name it wants to keep.
// Keys also sign and verify any bytes.
//
// Needs: lesson 08 (a node). Technically: a key in the keystore (to sign)
// and somewhere to put the signed record: the node's own repo when
// offline (what this lesson does), the DHT or a delegated router online
// (lessons 15-17), where other peers can find it.
//
//   dart run example/en_us/11_ipns_and_keys.dart
//
// Next question: "I know these from the `ipfs` command line; can I just
// call the commands?" → lesson 12.
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson11_');
  final ctx = Go.context.background();
  final n = await newNode(ctx, '${tmp.path}/repo');
  try {
    final api = Go.kubo.core.coreapi.newCoreApi(n);

    // 1. The node's own key, "self": its IPNS name is its peer ID.
    //    Go:  k, _ := api.Key().Self(ctx)
    final self = await api.key().self(ctx);
    final selfName = Go.boxo.ipns.nameFromPeer(self.id!);
    say('key "${self.name}": peer ${self.id}');
    say('  its IPNS name: ${selfName.asPath()}');

    // 2. Publish v1, resolve; publish v2, resolve: the name stays, the
    //    target moves.
    //    Go:  name, _ := api.Name().Publish(ctx, p, options.Name.AllowOffline(true))
    //         target, _ := api.Name().Resolve(ctx, "/ipns/"+name.String(), options.Name.Cache(false))
    for (final version in ['v1', 'v2']) {
      final p = await api.unixfs().add(
          ctx,
          Go.boxo.files.newBytesFile(utf8.encode('my site, $version\n')),
          [Go.kubo.core.coreiface.options.unixfs.pin(true, 'site-$version')]);
      final name = await api.name().publish(
          ctx, p, [Go.kubo.core.coreiface.options.name.allowOffline(true)]);
      final target = await api.name().resolve(ctx, '/ipns/$name',
          [Go.kubo.core.coreiface.options.name.cache(false)]);
      say('\npublished $version: /ipns/$name → $target');
    }

    // 3. Another key for another name (one name per thing you publish).
    //    Go:  k, _ := api.Key().Generate(ctx, "blog", options.Key.Type("ed25519"))
    //         api.Name().Publish(ctx, p, options.Name.Key("blog"), ...)
    final blog = await api.key().generate(
        ctx, 'blog', [Go.kubo.core.coreiface.options.key.type('ed25519')]);
    final post = await api
        .unixfs()
        .add(ctx, Go.boxo.files.newBytesFile(utf8.encode('first post\n')));
    final blogName = await api.name().publish(ctx, post, [
      Go.kubo.core.coreiface.options.name.key('blog'),
      Go.kubo.core.coreiface.options.name.allowOffline(true)
    ]);
    say('\nkey "blog" (${blog.id}): /ipns/$blogName → $post');
    say('  keys in the keystore: '
        '${(await api.key().list(ctx)).map((k) => k.name).join(', ')}');

    // 4. Keys sign and verify any bytes.
    //    Go:  k, sig, _ := api.Key().Sign(ctx, "blog", data)
    //         _, ok, _ := api.Key().Verify(ctx, "blog", sig, data)
    final data = utf8.encode('I wrote this');
    final (_, signature) = await api.key().sign(ctx, 'blog', data);
    final (_, ok) = await api.key().verify(ctx, 'blog', signature, data);
    final (_, forged) = await api
        .key()
        .verify(ctx, 'blog', signature, utf8.encode('I did not write this'));
    say('\nsigned ${data.length} bytes with "blog": '
        '${signature.length}-byte signature; valid: $ok; on other bytes: '
        '$forged');

    // 5. Rename and remove. Removing a key loses its name for good: nobody
    //    can publish under it again.
    final (renamed, _) = await api.key().rename(ctx, 'blog', 'old-blog');
    await api.key().remove(ctx, renamed.name);
    say('\nrenamed "blog" to "${renamed.name}", then removed it');

    say('\n== Common mistakes\n');
    await mistake('publishing offline without allowOffline(true)',
        why: 'by default publish wants to reach the network, so the record '
            'can be found; this node is offline',
        instead:
            'Go.kubo.core.coreiface.options.name.allowOffline(true) for a local record, or an '
            'online node (lesson 17)',
        action: () async => api.name().publish(
            ctx, post, [Go.kubo.core.coreiface.options.name.key('self')]));
    await mistake('publishing with a key that does not exist',
        why: 'there is no private key to sign the record with',
        instead: 'api.key().generate first; api.key().list shows what exists',
        action: () => api.name().publish(ctx, post, [
              Go.kubo.core.coreiface.options.name.key('no-such-key'),
              Go.kubo.core.coreiface.options.name.allowOffline(true)
            ]));
    await mistake('generating a key named "self"',
        why: '"self" is the node\'s own identity key, always present',
        instead: 'any other name',
        action: () => api.key().generate(ctx, 'self'));
  } finally {
    await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
