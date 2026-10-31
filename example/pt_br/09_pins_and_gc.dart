// Lição 09 · Por que os meus blocos somem?
//
// Pergunta: adicionei um arquivo, e depois ele tinha sumido do nó. Por quê, e
// como guardo o que importa?
//
// Resposta: o disco de um nó é um cache. O coletor de lixo (`ipfs repo gc`,
// ou automático quando o Datastore.StorageMax enche com o GC ligado) apaga
// todo bloco que nada protege. O que protege um bloco:
//   - um pin recursivo: a raiz e tudo abaixo dela (o que o `ipfs add` faz por
//     padrão na linha de comando; a CoreAPI NÃO fixa a menos que você peça);
//   - um pin direto: só aquele bloco;
//   - estar abaixo de um pin recursivo: um pin "indireto";
//   - estar no MFS, a árvore de arquivos do nó (lição 10).
// Tirar o pin não apaga; o próximo GC é que apaga.
//
// Precisa de: lição 08 (um nó e a CoreAPI dele). Tecnicamente, o GC precisa
// do blockstore com GC do nó (n.blockstore) e do pinner dele: ele pega a
// trava de GC (nenhum add ou pin roda enquanto isso), marca tudo o que se
// alcança a partir dos pins e do MFS, e apaga o resto.
//
//   dart run example/pt_br/09_pins_and_gc.dart
//
// Próxima pergunta: "Fixar cada CID à mão é desajeitado; posso ter pastas,
// simplesmente?" → lição 10.
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson09_');
  final ctx = go.context.background();
  final n = await newNode(ctx, '${tmp.path}/repo');
  try {
    final api = go.ipfs.kubo.core.coreapi.newCoreApi(n);
    Future<BoxoPath> add(String text,
            [List<KuboCoreCoreifaceOptionsUnixfsAddOption> o = const []]) =>
        api
            .unixfs()
            .add(ctx, go.ipfs.boxo.files.newBytesFile(utf8.encode(text)), o);
    // Não encontrado é o ErrNotFound do ipld, lançado como
    // GolangNotFoundException; qualquer outro erro (um store quebrado, um nó
    // fechado) sobe.
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

    // 1. Quatro arquivos, quatro destinos.
    //    Go:  api.Unixfs().Add(ctx, f, options.Unixfs.Pin(true, "name"))
    final pinned = await add('kept by a pin\n',
        [go.ipfs.kubo.core.coreiface.options.unixfs.pin(true, 'lesson-09')]);
    final loose = await add('nothing protects me\n');
    final inMfs = await add('kept by MFS\n');
    final unpinned = await add('pinned, then unpinned\n',
        [go.ipfs.kubo.core.coreiface.options.unixfs.pin(true, '')]);
    //    Go:  mfs.PutNode(n.FilesRoot, "/kept.txt", nd)
    go.ipfs.boxo.mfs
        .putNode(n.filesRoot, '/kept.txt', await api.resolveNode(ctx, inMfs));
    //    Go:  api.Pin().Rm(ctx, p)
    await api.pin().rm(ctx, unpinned);

    // Um bloco raw (`ipfs block put --pin`): o kubo o fixa como recursivo.
    final raw = await api.block().put(ctx, utf8.encode('a raw block'),
        [go.ipfs.kubo.core.coreiface.options.block.pin(true)]);

    Future<void> show(String when) async {
      say('\n$when:');
      for (final (name, p) in [
        ('fixado', pinned),
        ('solto', loose),
        ('no MFS', inMfs),
        ('desfixado', unpinned),
        ('bloco raw', raw.path!),
      ]) {
        final (how, isPinned) = await api.pin().isPinned(ctx, p);
        say('  ${name.padRight(10)} está aqui: '
            '${(await here(p)).toString().padRight(5)} '
            'pin: ${isPinned ? how : 'não'}');
      }
    }

    await show('antes do GC');

    // 2. Os pins, com nomes e tipos.
    //    Go:  api.Pin().Ls(ctx, options.Pin.Ls.Detailed(true))
    say('\npin ls:');
    await for (final p in api
        .pin()
        .ls(ctx, [go.ipfs.kubo.core.coreiface.options.pin.ls.detailed(true)])) {
      say('  ${p.type.padRight(9)} ${p.path} ${p.name}');
    }

    // 3. GC: tudo o que não se alcança a partir de um pin ou do MFS vai
    //    embora.
    //    Go:  for r := range corerepo.GarbageCollectAsync(n, ctx) { ... }
    final removed =
        await go.ipfs.kubo.core.corerepo.garbageCollectAsync(n, ctx).toList();
    say('\no GC removeu ${removed.length} bloco(s): '
        '${removed.map((r) => r.keyRemoved).join(', ')}');
    await show('depois do GC');

    // 4. Os pins podem ser conferidos: todo bloco abaixo deles ainda está
    //    aqui?
    //    Go:  for s := range api.Pin().Verify(ctx) { s.Ok() }
    final intact = await api.pin().verify(ctx).every((s) => s.ok);
    say('\npin verify: tudo íntegro: $intact');

    say('\n== Erros comuns\n');
    await mistake('tirar o pin de algo que não está fixado',
        why: 'o pinner não tem pin para ele (só está aqui por sorte, ou nem '
            'está)',
        instead: 'confira api.pin().isPinned antes',
        action: () => api.pin().rm(ctx, loose));
    await mistake('apagar à mão um bloco fixado (`ipfs block rm`)',
        why: 'o pin o protege: o kubo se recusa a apagar um bloco fixado',
        instead: 'tire o pin antes; o próximo GC o apaga',
        action: () => api.block().rm(ctx, raw.path!));
  } finally {
    await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
