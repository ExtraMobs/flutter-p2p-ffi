// Passo 10: o MFS (o "sistema de arquivos" do nó IPFS) pelo baixo nível, as
// funções do `boxo/mfs` do Go, chamadas direto do Dart. É a mesma camada que o
// `ipfs files` (exemplo 09) usa por dentro, só que sem a casca do comando:
// mais controle (abrir um arquivo, ir a uma posição, escrever um pedaço), mais
// responsabilidade (fechar o que abriu, gravar no disco com flush).
//
//   dart run example/10_mfs_baixo_nivel.dart
//
// Cada passo traz, num comentário, o mesmo código em Go: a API do Dart é a do
// Go, gerada, com as mesmas funções, na mesma ordem de argumentos. Quem lê a
// documentação do boxo (pkg.go.dev/github.com/ipfs/boxo/mfs) sabe usar esta.
import 'dart:convert';
import 'dart:io';

import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/boxo/mfs.dart' as mfs;
import 'package:ipfs_ffi/go/context.dart' as context;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsService;
import 'package:ipfs_ffi/kubo.dart' as kubo;

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_ex10_');
  final repoPath = '${tmp.path}/repo';

  // Serviço, plugins e repo novo: igual ao exemplo 09 (lá cada linha está
  // explicada).
  await IpfsService.start();
  kubo.PluginLoader('')
    ..initialize()
    ..inject();
  final cfg = kubo
      .initWithIdentity(kubo.createIdentity(null, [kubo.key.type('ed25519')]));
  kubo.profiles['test']!.transform(cfg);
  kubo.init(repoPath, cfg);
  final ctx = context.background();
  final n = await kubo.newNode(ctx, kubo.BuildCfg(repo: kubo.open(repoPath)));
  final api = kubo.newCoreApi(n);

  try {
    // A raiz do MFS do nó. No Go é um CAMPO da struct IpfsNode; no Dart vira
    // um getter (lê-se como um campo, sem parênteses).
    //   Go:   root := node.FilesRoot
    final root = n.filesRoot;

    // Cria /docs/rascunhos (e o /docs no caminho, o "-p" do mkdir).
    // As opções do Go são uma struct (MkdirOpts); no Dart a mesma struct,
    // com os campos como parâmetros nomeados (o nome dentro dos parênteses).
    //   Go:   mfs.Mkdir(root, "/docs/rascunhos", mfs.MkdirOpts{Mkparents: true, Flush: true})
    mfs.mkdir(
        root, '/docs/rascunhos', mfs.MkdirOpts(mkparents: true, flush: true));
    print('1. criei /docs/rascunhos');

    // Coloca no MFS um arquivo que já está no IPFS: adiciona os bytes (o
    // `ipfs add`), pega o nó IPLD (o bloco que o CID aponta) e o pendura
    // num caminho do MFS. Nada é copiado: o MFS só aponta para o CID.
    //   Go:   p, _ := api.Unixfs().Add(ctx, files.NewBytesFile([]byte("primeira linha\n")))
    //         nd, _ := api.ResolveNode(ctx, p)
    //         mfs.PutNode(root, "/docs/nota.txt", nd)
    final p = await api
        .unixfs()
        .add(ctx, files.newBytesFile(utf8.encode('primeira linha\n')));
    mfs.putNode(root, '/docs/nota.txt', await api.resolveNode(ctx, p));
    print('2. pendurei $p em /docs/nota.txt');

    // Procura um caminho. O Go devolve a interface FSNode (pode ser pasta ou
    // arquivo) e o código faz um "type assertion" para descobrir qual é. No
    // Dart, o mesmo vira `asFile()`/`asDirectory()`, que devolvem `null`
    // quando o nó não é daquele tipo; o `!` diz ao Dart "tenho certeza de que
    // não é null" (se for, dá erro ali mesmo).
    //   Go:   nd, _ := mfs.Lookup(root, "/docs/nota.txt")
    //         file := nd.(*mfs.File)
    final file = mfs.lookup(root, '/docs/nota.txt').asFile()!;
    print('3. /docs/nota.txt tem ${file.size()} bytes');

    // Abre para escrever, vai para o fim e anexa uma linha. `seek(0, 2)`: o
    // 2 é o io.SeekEnd do Go ("a partir do fim"); 0 é "do começo", 1 é "da
    // posição atual". Feche SEMPRE o que abriu: o close é o que grava a
    // alteração no MFS (e libera o arquivo para outro escritor).
    //   Go:   fd, _ := file.Open(ctx, mfs.Flags{Write: true, Sync: true})
    //         fd.Seek(0, io.SeekEnd)
    //         fd.Write([]byte("segunda linha\n"))
    //         fd.Close()
    final escrita = await file.open(ctx, mfs.Flags(write: true, sync: true));
    escrita.seek(0, 2);
    escrita.write(utf8.encode('segunda linha\n'));
    escrita.close();
    // (este é o caso do bug ipfs/boxo#1221, que o build do ipfs_ffi corrige
    // por patch: sem a correção, a leitura abaixo traria só a segunda linha)

    // Abre para ler. O Go lê num buffer que você passa ([]byte); no Dart
    // você diz quantos bytes quer e recebe os bytes lidos (menos, se o
    // arquivo acabar antes; vazio no fim).
    //   Go:   fd, _ := file.Open(ctx, mfs.Flags{Read: true})
    //         buf := make([]byte, 1024)
    //         n, _ := fd.CtxReadFull(ctx, buf)
    //         fmt.Print(string(buf[:n]))
    //         fd.Close()
    final leitura = await file.open(ctx, mfs.Flags(read: true));
    final bytes = await leitura.ctxReadFull(ctx, 1024);
    leitura.close();
    print('4. conteúdo agora:\n${utf8.decode(bytes)}');

    // Move o arquivo para outra pasta (o `ipfs files mv`).
    //   Go:   mfs.Mv(root, "/docs/nota.txt", "/docs/rascunhos/nota.txt")
    mfs.mv(root, '/docs/nota.txt', '/docs/rascunhos/nota.txt');

    // Lista uma pasta: procurar, converter para pasta, listar.
    //   Go:   nd, _ := mfs.Lookup(root, "/docs/rascunhos")
    //         dir := nd.(*mfs.Directory)
    //         entries, _ := dir.List(ctx)
    final pasta = mfs.lookup(root, '/docs/rascunhos').asDirectory()!;
    for (final e in await pasta.list(ctx)) {
      print('5. /docs/rascunhos/${e.name}: ${e.size} bytes, CID ${e.hash}');
    }

    // Grava as alterações até a raiz e pega o CID novo da pasta: cada
    // mudança no MFS gera CIDs novos, da folha até a raiz (o conteúdo mudou,
    // então o endereço muda).
    //   Go:   nd, _ := mfs.FlushPath(ctx, root, "/docs")
    //         fmt.Println(nd.Cid())
    final docs = await mfs.flushPath(ctx, root, '/docs');
    print('6. /docs agora é o CID ${docs.cid()}');

    // Para comparar, a mesma leitura pelo alto nível (exemplo 09): um
    // comando, sem abrir nem fechar nada, com o resultado em Stream de
    // pedaços de bytes. `.fold` percorre os itens do Stream acumulando num
    // valor: começa com `[]` (uma lista vazia) e, a cada pedaço que chega,
    // chama a função com (o acumulado até aqui, o pedaço novo); o que a
    // função devolve vira o novo acumulado. No fim, devolve um Future com o
    // valor final. `junto..addAll(pedaco)` adiciona os bytes do pedaço à
    // lista e devolve a própria lista (o `..` devolve o objeto, não o
    // resultado do addAll).
    final viaComando = await kubo
        .filesRead(n, ctx, '/docs/rascunhos/nota.txt')
        .fold<List<int>>([], (junto, pedaco) => junto..addAll(pedaco));
    print('7. pelo comando ipfs files read: ${viaComando.length} bytes');
  } finally {
    await n.close();
    await IpfsService.stop();
    tmp.deleteSync(recursive: true);
  }
}
