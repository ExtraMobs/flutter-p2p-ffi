// Lição 12 · Como uso os comandos `ipfs` que já conheço?
//
// Pergunta: conheço `ipfs add`, `ipfs cat`, `ipfs pin ls`, `ipfs dag put`...
// do terminal. Posso chamá-los do Dart, sem HTTP, e o que faço com o que eles
// devolvem?
//
// Resposta: todo comando do kubo é uma função Dart em
// `go.ipfs.kubo.core.commands`: os argumentos da linha de
// comando são os parâmetros posicionais, as flags são os nomeados (`ipfs
// files mkdir -p /a` → `filesMkdir(n, ctx, '/a', parents: true)`). Eles rodam
// dentro do próprio nó do app e devolvem um Stream: um item por linha de
// resultado do comando, ou pedaços de bytes no caso do `cat`. Um Stream se
// consome de algumas formas:
//   - `.single`: um comando com exatamente um resultado (`filesStat`, `id`);
//   - `.toList()` ou `await for`: muitos resultados (`pinLs`, `refs`);
//   - `.drain()`: rodar e ignorar a saída (`filesMkdir`);
//   - `.fold` ou um BytesBuilder: juntar os pedaços do `cat`;
//   - `.listen`: reagir a cada item quando chega, sem esperar.
// Dados IPLD que não são arquivos, como um objeto JSON, entram com o `dag
// put` (guardados como dag-cbor, com links para outros CIDs) e são lidos de
// volta por caminho.
//
// Precisa de: lição 08 (um nó: os comandos rodam nele). Tecnicamente, cada
// comando precisa do que a sua parte da CoreAPI precisa: o blockstore, o
// pinner, o MFS; comandos de rede (`swarm`, `routing`, `pubsub`) precisam de
// um nó online.
//
//   dart run example/pt_br/12_ipfs_commands.dart
//
// Próxima pergunta: "Tudo isso é local. Como o meu nó existe na rede?" →
// lição 13.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson12_');
  final ctx = go.context.background();
  final n = await newNode(ctx, '${tmp.path}/repo');
  try {
    final api = go.ipfs.kubo.core.coreapi.newCoreApi(n);

    // 1. Um resultado: `.single`.           CLI: ipfs id; ipfs repo stat
    final id = await go.ipfs.kubo.core.commands.id(n, ctx, null).single;
    say('ipfs id: ${id.id} (${id.agentVersion})');
    final repo = await go.ipfs.kubo.core.commands.repoStat(n, ctx).single;
    say('ipfs repo stat: ${repo.numObjects} objetos, ${repo.repoSize} bytes');

    // 2. Muitos resultados: `await for`.    CLI: ipfs add -r folder
    final folder = Directory('${tmp.path}/folder')..createSync();
    File('${folder.path}/a.txt').writeAsStringSync('A\n');
    File('${folder.path}/b.txt').writeAsStringSync('B\n');
    say('\nipfs add -r, um evento por arquivo:');
    await for (final e in go.ipfs.kubo.core.commands.add(
        n,
        ctx,
        [
          go.ipfs.boxo.files
              .newSerialFile(folder.path, false, go.os.stat(folder.path))
        ],
        recursive: true,
        cidVersion: 1)) {
      say('  ${e.name.padRight(12)} ${e.hash}');
    }

    // 3. Bytes em pedaços: junte-os.        CLI: ipfs cat <cid>
    final big = Uint8List(600000);
    final p = await api.unixfs().add(ctx, go.ipfs.boxo.files.newBytesFile(big));
    final joined = BytesBuilder();
    var pieces = 0;
    await for (final piece
        in go.ipfs.kubo.core.commands.cat(n, ctx, [p.value])) {
      pieces++;
      joined.add(piece);
    }
    say('\nipfs cat: ${joined.length} bytes em $pieces pedaços');

    // 4. Reagir aos itens quando chegam, sem esperar: `.listen`.
    //    CLI: ipfs pin ls --type=recursive
    final done = <String>[];
    final sub = go.ipfs.kubo.core.commands
        .pinLs(n, ctx, [], type: 'recursive')
        .listen((w) => done.addAll(w.keys.keys),
            onDone: () => say('  (pin ls terminou: ${done.length} pins)'));
    say('\nipfs pin ls começou; esta linha sai antes de ele terminar');
    await sub.asFuture<void>();

    // 5. `.drain()`: rodar e ignorar a saída.   CLI: ipfs files mkdir -p /a/b
    await go.ipfs.kubo.core.commands
        .filesMkdir(n, ctx, '/a/b', parents: true)
        .drain<void>();
    say('\nipfs files mkdir -p /a/b: feito');

    // 6. Objetos IPLD: JSON entra, dag-cbor é guardado, lido de volta por
    //    caminho, links seguidos.          CLI: ipfs dag put / ipfs dag get
    final author = await go.ipfs.kubo.core.commands.dag
        .dagPut(api, ctx, utf8.encode('{"name": "Ana", "lang": "pt"}'));
    final post = await go.ipfs.kubo.core.commands.dag.dagPut(
        api,
        ctx,
        utf8.encode('{"title": "hi", "tags": ["ipfs", "dart"], '
            '"author": {"/": "$author"}}'),
        pin: true);
    say('\nipfs dag put: post $post (dag-cbor: ${post.type() == go.multiformats.multicodec.enums.dagCbor})');
    final tags = await go.ipfs.kubo.core.commands.dag
        .dagGet(api, ctx, BoxoPath('/ipfs/$post/tags'));
    final name = await go.ipfs.kubo.core.commands.dag
        .dagGet(api, ctx, BoxoPath('/ipfs/$post/author/name'));
    say('  /tags → ${utf8.decode(tags)}');
    say('  /author/name (pelo link) → ${utf8.decode(name)}');

    say('\n== Erros comuns\n');
    await mistake('`.single` num comando que dá muitos resultados',
        why: 'o single quer exatamente um item; o ipfs add -r deu um por '
            'arquivo',
        instead: '`await for` ou `.toList()`',
        action: () => go.ipfs.kubo.core.commands
            .add(
                n,
                ctx,
                [
                  go.ipfs.boxo.files.newSerialFile(
                      folder.path, false, go.os.stat(folder.path))
                ],
                recursive: true)
            .single);
    await mistake('esperar por um erro que o Stream já lançou',
        why: 'o erro de um comando vem pelo Stream; ninguém estava ouvindo',
        instead: 'espere o Stream (ou listen com onError) dentro de um try',
        action: () => go.ipfs.kubo.core.commands
            .filesStat(n, ctx, '/no/such/path')
            .single);
    await mistake('dag put de um texto que não é JSON',
        why: 'o codec de entrada é dag-json por padrão',
        instead: 'JSON válido, ou um inputCodec que bata com o que você manda',
        action: () => go.ipfs.kubo.core.commands.dag
            .dagPut(api, ctx, utf8.encode('not json')));
  } finally {
    await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
