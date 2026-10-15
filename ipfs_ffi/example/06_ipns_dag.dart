// Passo 6: nomes mutáveis (IPNS), chaves e objetos IPLD (`ipfs name`,
// `ipfs key`, `ipfs dag`). Nó offline. Rode o 01_init_repo.dart antes.
//
//   dart run example/06_ipns_dag.dart [repo]
import 'dart:convert';

import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/boxo/ipld/merkledag.dart' as merkledag;
import 'package:ipfs_ffi/boxo/path.dart' as path;
import 'package:ipfs_ffi/context.dart' as context;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsService;
import 'package:ipfs_ffi/kubo/core.dart' as core;
import 'package:ipfs_ffi/kubo/core/commands/dag.dart' as dag;
import 'package:ipfs_ffi/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/kubo/repo/fsrepo.dart' as fsrepo;

Future<void> main(List<String> args) async {
  final repoPath = args.isNotEmpty ? args.first : '.ipfs-ffi';
  // O kubo roda no ipfs_host, noutro processo (dart run tool/build.dart).
  await IpfsService.start();
  loader.PluginLoader('')
    ..initialize()
    ..inject();
  final ctx = context.background();
  final n = await core.newNode(ctx, node.BuildCfg(repo: fsrepo.open(repoPath)));
  try {
    final api = coreapi.newCoreApi(n);

    // IPNS: um nome fixo (a chave do nó) apontando para um conteúdo que muda
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

    // chave extra (outro nome IPNS), assinatura e verificação
    final k = await api.key().generate(
        ctx,
        'exemplo-06-${DateTime.now().millisecondsSinceEpoch}',
        [options.key.type('ed25519')]);
    final (_, sig) = await api.key().sign(ctx, k.name, utf8.encode('olá'));
    final (_, ok) =
        await api.key().verify(ctx, k.name, sig, utf8.encode('olá'));
    print(
        'chave ${k.name} (${k.id}): assinatura ${ok ? 'válida' : 'inválida'}');
    await api.key().remove(ctx, k.name);

    // IPLD dag-pb à mão: um nó com dados e um link para um nó raw
    final folha = merkledag.RawNode(utf8.encode('folha'));
    final raiz = merkledag.nodeWithData(utf8.encode('raiz'))
      ..addNodeLink('filho', folha);
    await api.dag().addMany(ctx, [folha, raiz]);
    print('dag-pb ${raiz.cid()} → filho ${raiz.links().single.cid}');

    // IPLD DAG-CBOR a partir de JSON (ipfs dag put), lido de volta por caminho
    final post = await dag.put(
        api,
        ctx,
        utf8.encode(
            '{"titulo": "oi", "tags": ["ipfs", "dart"], "anexo": {"/": "${raiz.cid()}"}}'),
        pin: true);
    final tags = await dag.get(api, ctx, path.Path('/ipfs/$post/tags'));
    print('dag-cbor $post: tags = ${utf8.decode(tags)}');
    final viaLink = await dag.get(api, ctx, path.Path('/ipfs/$post/anexo'),
        outputCodec: 'dag-json');
    print('seguindo o link: ${utf8.decode(viaLink)}');
  } finally {
    await n.close();
  }
  await IpfsService.stop();
}
