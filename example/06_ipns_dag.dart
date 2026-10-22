// Step 6: mutable names (IPNS), keys and IPLD objects (`ipfs name`,
// `ipfs key`, `ipfs dag`). Offline node. Run 01_init_repo.dart first.
//
//   dart run example/06_ipns_dag.dart [repo]
import 'dart:convert';

import 'package:p2p_ffi/go/boxo/files.dart' as files;
import 'package:p2p_ffi/go/boxo/ipld/merkledag.dart' as merkledag;
import 'package:p2p_ffi/go/boxo/path.dart' as path;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/kubo/core.dart' as core;
import 'package:p2p_ffi/go/kubo/core/commands/dag.dart' as dag;
import 'package:p2p_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:p2p_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:p2p_ffi/go/kubo/core/node.dart' as node;
import 'package:p2p_ffi/go/kubo/plugin/loader.dart' as loader;
import 'package:p2p_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:p2p_ffi/p2p_ffi.dart' show P2pService;

Future<void> main(List<String> args) async {
  final repoPath = args.isNotEmpty ? args.first : '.ipfs-ffi';
  // Kubo runs in the p2p_host, in another process (dart run tool/build.dart).
  await P2pService.start();
  loader.PluginLoader('')
    ..initialize()
    ..inject();
  final ctx = context.background();
  final n = await core.newNode(ctx, node.BuildCfg(repo: fsrepo.open(repoPath)));
  try {
    final api = coreapi.newCoreApi(n);

    // IPNS: a fixed name (the node's key) pointing to content that changes
    for (final version in ['v1', 'v2']) {
      final p = await api.unixfs().add(
          ctx,
          files.newBytesFile(utf8.encode('site $version\n')),
          [options.unixfs.pin(true, 'site-$version')]);
      final name =
          await api.name().publish(ctx, p, [options.name.allowOffline(true)]);
      final now = await api
          .name()
          .resolve(ctx, '/ipns/$name', [options.name.cache(false)]);
      print('/ipns/$name → $now ($version)');
    }

    // an extra key (another IPNS name), signing and verifying
    final k = await api.key().generate(
        ctx,
        'example-06-${DateTime.now().millisecondsSinceEpoch}',
        [options.key.type('ed25519')]);
    final (_, sig) = await api.key().sign(ctx, k.name, utf8.encode('hello'));
    final (_, ok) =
        await api.key().verify(ctx, k.name, sig, utf8.encode('hello'));
    print('key ${k.name} (${k.id}): signature ${ok ? 'valid' : 'invalid'}');
    await api.key().remove(ctx, k.name);

    // IPLD dag-pb by hand: a node with data and a link to a raw node
    final leaf = merkledag.RawNode(utf8.encode('leaf'));
    final root = merkledag.nodeWithData(utf8.encode('root'))
      ..addNodeLink('child', leaf);
    await api.dag().addMany(ctx, [leaf, root]);
    print('dag-pb ${root.cid()} → child ${root.links().single.cid}');

    // IPLD DAG-CBOR from JSON (ipfs dag put), read back by path
    final post = await dag.dagPut(
        api,
        ctx,
        utf8.encode(
            '{"title": "hi", "tags": ["ipfs", "dart"], "attachment": {"/": "${root.cid()}"}}'),
        pin: true);
    final tags = await dag.dagGet(api, ctx, path.Path('/ipfs/$post/tags'));
    print('dag-cbor $post: tags = ${utf8.decode(tags)}');
    final viaLink = await dag.dagGet(
        api, ctx, path.Path('/ipfs/$post/attachment'),
        outputCodec: 'dag-json');
    print('following the link: ${utf8.decode(viaLink)}');
  } finally {
    await n.close();
  }
  await P2pService.stop();
}
