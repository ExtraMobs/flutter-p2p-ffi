// Lição 10 · Como trabalho com pastas que mudam?
//
// Pergunta: todo CID é imutável (lição 02): mude um byte e é outro CID. Como
// mantenho uma pasta que posso editar, como num disco normal?
//
// Resposta: o MFS (Mutable File System), os comandos `ipfs files`. É uma
// árvore de nomes guardada pelo nó cuja raiz aponta para um CID; cada mudança
// (write, mkdir, mv, rm) monta os nós novos da mudança até a raiz, então a
// raiz ganha um CID novo, e as versões antigas continuam válidas nos CIDs
// antigos. Nada é copiado: pôr um CID no MFS só o liga. Tudo o que está no
// MFS fica protegido do GC (lição 09).
//
// Duas camadas, a mesma árvore:
//   - os comandos (`goKubo.core.commands.filesWrite`, `filesLs`,
//     `filesRead`...): o `ipfs files` da linha de comando, cada um um Stream
//     de resultados;
//   - o pacote mfs do boxo (`goBoxo.mfs.mkdir`, `goBoxo.mfs.lookup`,
//     `BoxoMfsFile.open`...): a camada que os comandos usam por dentro, com
//     mais controle (abrir um arquivo, posicionar, escrever um pedaço) e mais
//     deveres (fechar o que abriu, flush).
//
// Precisa de: lição 08 (um nó: a raiz do MFS dele é n.filesRoot).
// Tecnicamente, o MFS precisa de um DAGService para ler e gravar os seus nós,
// e de um CID raiz guardado no repositório entre execuções.
//
//   dart run example/pt_br/10_mfs.dart
//
// Próxima pergunta: "O CID da pasta muda a cada edição; como dou a alguém um
// endereço que sempre mostra a versão mais nova?" → lição 11.
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson10_');
  final ctx = goContext.background();
  final n = await newNode(ctx, '${tmp.path}/repo');
  try {
    final api = goKubo.core.coreapi.newCoreApi(n);
    Future<String> rootCid() async =>
        (await goKubo.core.commands.filesStat(n, ctx, '/').single).hash;

    // 1. Os comandos: mkdir, write, ls, read, como na linha de comando.
    //    CLI: ipfs files mkdir -p /site; echo ... | ipfs files write --create /site/index.html
    final empty = await rootCid();
    await goKubo.core.commands
        .filesMkdir(n, ctx, '/site', parents: true)
        .drain<void>();
    await goKubo.core.commands
        .filesWrite(n, ctx, '/site/index.html',
            goBoxo.files.newBytesFile(utf8.encode('<h1>v1</h1>\n')),
            create: true)
        .drain<void>();
    final v1 = await rootCid();
    say('a raiz do MFS: vazia $empty → depois de um write $v1');
    final ls =
        await goKubo.core.commands.filesLs(n, ctx, '/site', long: true).single;
    for (final e in ls.entries) {
      say('  /site/${e.name}  ${e.size} bytes  ${e.hash}');
    }
    final html = await goKubo.core.commands
        .filesRead(n, ctx, '/site/index.html')
        .fold<List<int>>([], (all, piece) => all..addAll(piece));
    say('  lido: ${utf8.decode(html).trim()}');

    // 2. Editar o mesmo nome: a raiz ganha um CID novo, a antiga ainda
    //    mostra a v1 (imutável, como sempre).
    await goKubo.core.commands
        .filesWrite(n, ctx, '/site/index.html',
            goBoxo.files.newBytesFile(utf8.encode('<h1>v2</h1>\n')),
            truncate: true)
        .drain<void>();
    final v2 = await rootCid();
    final old = await goKubo.core.commands
        .cat(n, ctx, ['/ipfs/$v1/site/index.html']).fold<List<int>>(
            [], (all, piece) => all..addAll(piece));
    say('\ndepois de editar: raiz $v2');
    say('  a raiz antiga ainda lê: ${utf8.decode(old).trim()}');

    // 3. Um CID de fora, ligado no MFS sem copiar (`files cp`).
    final logo = await api
        .unixfs()
        .add(ctx, goBoxo.files.newBytesFile(utf8.encode('a logo, say\n')));
    await goKubo.core.commands
        .filesCp(n, ctx, logo.value, '/site/logo.txt')
        .drain<void>();
    say('\nliguei $logo como /site/logo.txt (nenhum byte copiado)');

    // 4. O nível baixo: o mfs do boxo, na mesma árvore.
    //    Go:  f := mfs.Lookup(root, "/site/index.html").(*mfs.File)
    //         fd, _ := f.Open(ctx, mfs.Flags{Write: true, Sync: true})
    //         fd.Seek(0, io.SeekEnd); fd.Write(b); fd.Close()
    final root = n.filesRoot;
    final file = goBoxo.mfs.lookup(root, '/site/index.html').asBoxoMfsFile()!;
    final w = await file.open(ctx, BoxoMfsFlags(write: true, sync: true));
    w.seek(0, 2); // 2 = io.SeekEnd
    w.write(utf8.encode('<p>appended by mfs</p>\n'));
    w.close(); // o close é o que grava a mudança na árvore
    final r = await file.open(ctx, BoxoMfsFlags(read: true));
    final now = await r.ctxReadFull(ctx, 1024);
    r.close();
    say('\nmfs, depois de acrescentar:\n${utf8.decode(now)}');
    //    Go:  mfs.Mv(root, "/site/logo.txt", "/site/img/logo.txt")
    goBoxo.mfs.mkdir(root, '/site/img', BoxoMfsMkdirOpts(mkparents: true));
    goBoxo.mfs.mv(root, '/site/logo.txt', '/site/img/logo.txt');
    //    Go:  nd, _ := mfs.FlushPath(ctx, root, "/site")
    final site = await goBoxo.mfs.flushPath(ctx, root, '/site');
    say('/site gravado (flush): ${site.cid()}');
    final dir = goBoxo.mfs.lookup(root, '/site').asBoxoMfsDirectory()!;
    say('  entradas: ${(await dir.listNames(ctx)).join(', ')}');

    say('\n== Erros comuns\n');
    await mistake('gravar num caminho cuja pasta não existe',
        why: 'o files write cria o arquivo (create: true), não as pastas '
            'acima dele',
        instead: 'filesMkdir(..., parents: true) antes',
        action: () => goKubo.core.commands
            .filesWrite(n, ctx, '/nope/a.txt',
                goBoxo.files.newBytesFile(utf8.encode('x')),
                create: true)
            .drain<void>());
    // (Abrir um arquivo para escrita enquanto outro descritor está aberto não
    // falha: espera o primeiro ser fechado, como no Go. Feche cada descritor
    // num finally, senão a próxima abertura espera para sempre.)
    await mistake('remover uma pasta que não está vazia',
        why: 'o files rm recusa pastas, a menos que você mande remover o que '
            'tem dentro',
        instead: 'filesRm(..., recursive: true)',
        action: () =>
            goKubo.core.commands.filesRm(n, ctx, ['/site']).drain<void>());
    await mistake('ler um caminho que não existe',
        why: 'caminhos do MFS são nomes na árvore, não CIDs: um erro de '
            'digitação é um erro',
        instead: 'filesStat ou filesLs para conferir; caminhos /ipfs/<cid> vão '
            'para o cat',
        action: () =>
            goKubo.core.commands.filesStat(n, ctx, '/site/index.htm').single);
  } finally {
    await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
