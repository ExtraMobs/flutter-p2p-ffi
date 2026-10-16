// Passo 9: os comandos do `ipfs` (os mesmos do terminal: `ipfs files mkdir`,
// `ipfs pin ls`, `ipfs cat`...) chamados do Dart, e um tour pelo `Stream`, que
// é como todo comando devolve o resultado.
//
//   dart run example/09_comandos_e_streams.dart
//
// Não precisa do 01: o exemplo cria um repo temporário e o apaga no fim.
//
// Antes de começar, dois conceitos do Dart que aparecem em todo o arquivo:
//
// - `Future<T>`: a promessa de UM valor do tipo T que fica pronto mais tarde
//   (a resposta do nó IPFS leva um tempo). `await f` pausa esta função até o
//   valor ficar pronto e devolve o valor; enquanto isso, o resto do programa
//   continua rodando. Só dá para usar `await` dentro de uma função `async`.
//
// - `Stream<T>`: uma SEQUÊNCIA de valores do tipo T que vão chegando ao longo
//   do tempo (zero, um ou vários), e que no fim termina, com ou sem erro. Pense
//   numa esteira: os itens chegam um de cada vez. Um ponto importante: o
//   Stream é "preguiçoso". Criar o Stream não faz nada; o comando só roda no
//   nó quando alguém começa a ouvir o Stream (com `await for`, `.listen`,
//   `.single`, `.toList()`, `.drain()`...). Esquecer de ouvir = o comando
//   nunca roda.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/go/context.dart' as context;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsException, IpfsService;
import 'package:ipfs_ffi/kubo.dart' as kubo;

Future<void> main() async {
  // Uma pasta temporária só para este exemplo (o repo do IPFS mora nela).
  final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_ex09_');
  final repoPath = '${tmp.path}/repo';

  // Liga o serviço: lança o ipfs_host (o kubo, em outro processo; compile
  // antes com `dart run tool/build.dart`). Tudo abaixo conversa com ele.
  await IpfsService.start();

  // Os plugins do kubo (tipos de banco de dados do repo etc.): uma vez por
  // serviço, antes de abrir qualquer repo. Os `..` chamam dois métodos no
  // mesmo objeto, um depois do outro.
  kubo.PluginLoader('')
    ..initialize()
    ..inject();

  // Cria o repo: uma identidade nova (o par de chaves do nó) e a config
  // padrão do kubo, com o perfil `test` (sem rede, portas aleatórias).
  final cfg =
      kubo.initWithIdentity(kubo.createIdentity([kubo.key.type('ed25519')]));
  kubo.profiles['test']!.transform(cfg);
  kubo.init(repoPath, cfg);

  // O "contexto" do Go: toda chamada que pode demorar recebe um. O
  // `background()` é o contexto que nunca vence nem é cancelado (o exemplo 11
  // mostra prazos e cancelamento).
  final ctx = context.background();

  // Sobe o nó IPFS (offline: sem `online: true` ele não fala com a rede).
  // `newNode` devolve um Future, então esperamos com `await`.
  final n = await kubo.newNode(ctx, kubo.BuildCfg(repo: kubo.open(repoPath)));

  // `try { ... } finally { ... }`: o bloco do `finally` roda SEMPRE no fim,
  // dando certo ou dando erro, e é onde fechamos o nó e o serviço.
  try {
    // ------------------------------------------------------------------
    // 1. Comando sem resultado útil: `.drain()`
    // ------------------------------------------------------------------
    // `ipfs files mkdir -p /docs`. O comando devolve um Stream, mas aqui só
    // importa o efeito (criar a pasta). `.drain()` ouve o Stream até o fim
    // jogando fora os itens, e devolve um Future que completa quando o
    // comando termina. Sem o `.drain()`, a pasta NÃO seria criada (o Stream
    // é preguiçoso: ninguém ouviu, nada rodou).
    await kubo.filesMkdir(n, ctx, '/docs', parents: true).drain<void>();
    print('1. criei /docs');

    // `ipfs files write --create /docs/nota.txt`: grava bytes num arquivo do
    // MFS (o "sistema de arquivos" do nó IPFS). `utf8.encode` transforma o
    // texto em bytes; `files.newBytesFile` embrulha os bytes como arquivo.
    await kubo
        .filesWrite(n, ctx, '/docs/nota.txt',
            files.newBytesFile(utf8.encode('olá, IPFS!\n')),
            create: true)
        .drain<void>();
    print('   gravei /docs/nota.txt');

    // ------------------------------------------------------------------
    // 2. Comando que devolve UM valor: `.single`
    // ------------------------------------------------------------------
    // `ipfs files stat /docs/nota.txt` emite um único item (um StatOutput).
    // `.single` ouve o Stream inteiro e devolve um Future com o único item.
    // Cuidado: se o Stream vier vazio, ou com mais de um item, `.single` dá
    // erro (StateError). Use quando o comando, por natureza, responde uma vez.
    final st = await kubo.filesStat(n, ctx, '/docs/nota.txt').single;
    print('2. stat: ${st.type}, ${st.size} bytes, CID ${st.hash}');

    // `ipfs files ls /docs`: também um item só, que traz a lista `entries`.
    final ls = await kubo.filesLs(n, ctx, '/docs', long: true).single;
    for (final e in ls.entries) {
      print('   ls: ${e.name} (${e.size} bytes)');
    }

    // ------------------------------------------------------------------
    // 3. Comando que devolve BYTES em pedaços: `await for`
    // ------------------------------------------------------------------
    // `ipfs files read` emite o conteúdo em pedaços (Uint8List, uma lista de
    // bytes); um arquivo grande chega em vários pedaços. `await for` é um
    // laço `for` que espera cada item do Stream chegar: o corpo roda uma vez
    // por pedaço, e o laço termina quando o Stream termina.
    final conteudo = BytesBuilder(); // junta os pedaços num buffer só
    await for (final pedaco in kubo.filesRead(n, ctx, '/docs/nota.txt')) {
      print('3. chegou um pedaço de ${pedaco.length} bytes');
      conteudo.add(pedaco);
    }
    print('   conteúdo: ${utf8.decode(conteudo.takeBytes()).trim()}');

    // ------------------------------------------------------------------
    // 4. Juntar todos os itens: `.toList()`
    // ------------------------------------------------------------------
    // Um arquivo pinado (o pin impede o coletor de lixo de apagá-lo).
    final p = await kubo.newCoreApi(n).unixfs().add(
        ctx,
        files.newBytesFile(utf8.encode('fica guardado')),
        [kubo.unixfs.pin(true, '')]);
    // `ipfs pin ls --type=recursive` emite os pins (pode ser muitos).
    // `.toList()` espera o Stream terminar e devolve todos os itens numa
    // lista. Prático, mas só use quando sabe que a lista cabe na memória.
    final pins = await kubo.pinLs(n, ctx, [], type: 'recursive').toList();
    for (final w in pins) {
      // cada item traz um mapa: CID → tipo do pin
      w.keys.forEach((cid, info) => print('4. pin: $cid (${info.type})'));
    }

    // ------------------------------------------------------------------
    // 5. Ouvir com `.listen`: callbacks, em vez de esperar
    // ------------------------------------------------------------------
    // `await for` pausa a função até o Stream acabar. `.listen` NÃO pausa:
    // ele registra funções (callbacks) que o Dart chama mais tarde, e o
    // código logo abaixo do `.listen` segue imediatamente. É o jeito certo
    // quando a tela (ou outra tarefa) precisa continuar viva enquanto os
    // itens chegam, como as mensagens de um chat.
    //
    //   onData:  chamada uma vez para CADA item que chega
    //   onError: chamada se o comando falhar (aqui, uma IpfsException)
    //   onDone:  chamada uma vez, quando o Stream termina
    //
    // `.listen` devolve uma StreamSubscription: o "controle remoto" da
    // assinatura, com `.cancel()` (parar de ouvir) e `.pause()/.resume()`.
    final terminou = Completer<void>(); // um Future que completamos à mão
    var total = 0;
    final assinatura = kubo.cat(n, ctx, [p.value]).listen(
      (pedaco) {
        // onData: roda para cada pedaço de bytes do `ipfs cat`
        total += pedaco.length;
      },
      onError: (Object e) {
        // onError: o comando falhou; sem este callback o erro iria para o
        // tratador de erros não capturados da zona e derrubaria o programa
        print('5. erro no cat: $e');
        if (!terminou.isCompleted) terminou.complete();
      },
      onDone: () {
        // onDone: o Stream terminou (todos os pedaços chegaram)
        print('5. cat terminou: $total bytes');
        terminou.complete();
      },
      cancelOnError: true, // parar de ouvir no primeiro erro
    );
    print(
        '5. (esta linha aparece ANTES do "cat terminou": o listen não espera)');
    await terminou.future; // agora sim esperamos o onDone
    // Depois do onDone a assinatura já acabou; o cancel() aqui não faz nada,
    // mas é o que se chama para parar ANTES do fim (ex.: o usuário saiu da
    // tela), e liberar o comando no nó.
    await assinatura.cancel();

    // ------------------------------------------------------------------
    // 6. Erros: o comando falha → IpfsException
    // ------------------------------------------------------------------
    // Quando o kubo devolve erro (aqui: o caminho não existe), o Stream
    // termina com erro. Com `await` (incluindo `.single`, `.toList()`,
    // `await for`), o erro vira uma exceção que o `try/catch` pega.
    try {
      await kubo.filesStat(n, ctx, '/nao/existe').single;
    } on IpfsException catch (e) {
      print('6. erro esperado do kubo: $e');
    }

    // `ipfs files rm -r /docs` e conferir que sumiu
    await kubo.filesRm(n, ctx, ['/docs'], recursive: true).drain<void>();
    final raiz = await kubo.filesLs(n, ctx, '/').single;
    print('   depois do rm, a raiz tem ${raiz.entries.length} entradas');
  } finally {
    await n.close(); // fecha o nó (libera o repo)
    await IpfsService.stop(); // encerra o ipfs_host
    tmp.deleteSync(recursive: true); // apaga a pasta temporária
  }
}
