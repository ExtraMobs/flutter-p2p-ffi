// Lição 21 · Como o Go chama o meu código Dart?
//
// Pergunta: algumas funções Go recebem uma função: um handler de stream
// (lição 14), um validador do pubsub (lição 18), um callback por entrada de
// índice. O Go roda em outro processo; como ele chama uma função Dart, e
// quais são as regras?
//
// Resposta: uma função Dart passada onde o Go espera uma função vira um
// callback: quando o Go a chama, o p2p_host manda os argumentos para o Dart,
// o Dart roda a função no seu event loop, e a resposta (ou a exceção) volta
// para o Go. Quatro formatos:
//   - chamada durante a chamada, muitas vezes (o ForEach de um índice): o Go
//     manda as chamadas em lotes para poupar idas e voltas (`batchSize`);
//     lançar uma exceção na função para o Go, e a chamada falha com o seu
//     erro;
//   - guardada pelo Go depois que a chamada volta (um handler de stream, um
//     Notifiee, um validador): o Go a chama sempre que o evento acontece,
//     até você removê-la (removeStreamHandler, stopNotify...);
//   - uma interface Go implementada em Dart (network.Notifiee,
//     mdns.Notifee): uma função Dart por método Go, as que você omite não
//     fazem nada;
//   - uma função que recebe um objeto Go válido só durante a chamada (um
//     construtor de seletor): use-o dentro, nunca o guarde.
// Se, dentro de um callback, o seu código Dart chamar de volta um objeto Go
// que a função Go em espera mantém travado, o p2p_host percebe e lança
// GolangDeadlockException na sua função em vez de travar.
//
// Precisa de: lições 06 (um índice, um seletor), 14 (um handler de stream).
//
//   dart run example/pt_br/21_callbacks.dart
//
// Este é o fim do curso; as perguntas que ele responde estão no README.md.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

/// Lançada de um callback para parar o laço do Go antes do fim.
class Enough implements Exception {}

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson21_');
  try {
    final ctx = goContext.background();

    // 1. Chamada muitas vezes durante a chamada: cada entrada de um índice
    //    de CAR.
    //    Go:  idx.(index.IterableIndex).ForEach(func(mh multihash.Multihash, off uint64) error {...})
    final s = await Sample.build(ctx);
    final carFile = '${tmp.path}/sample.car';
    await s.writeCar(ctx, carFile);
    final idx =
        goCar.v2.generateIndexFromFile(carFile).asCarV2IndexIterableIndex()!;
    final offsets = <int>[];
    await idx.forEach((multihash, offset) => offsets.add(offset));
    say('o forEach chamou a função Dart ${offsets.length} vezes; posições '
        '${offsets..sort()}');
    //    Parar antes do fim: lance uma exceção; o Go para e a chamada falha
    //    com o seu erro.
    var seen = 0;
    try {
      await idx.forEach((_, __) {
        if (++seen == 2) throw Enough();
      }, batchSize: 1);
    } on Enough {
      say('  parou depois de $seen entradas, por uma exceção no callback');
    }

    // 2. Guardada pelo Go: um handler de stream, chamado para cada stream
    //    que chega, até ser removido.
    //    Go:  b.SetStreamHandler(proto, func(s network.Stream) {...})
    Future<Libp2pCoreHost> newHost() => goLibp2p.new$([
          goLibp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
        ]);
    final a = await newHost(), b = await newHost();
    var served = 0;
    b.setStreamHandler('/lesson/echo/1.0.0', (st) async {
      served++;
      final got = await readerStream(st).expand((c) => c).toList();
      await st.write(Uint8List.fromList(got.reversed.toList()));
      await st.close();
    });
    await a.connect(ctx, goLibp2p.core.host.infoFromHost(b));
    Future<String> echo(String text) async {
      final st = await a.newStream(ctx, b.id(), ['/lesson/echo/1.0.0']);
      await st.write(Uint8List.fromList(utf8.encode(text)));
      await st.closeWrite();
      return utf8.decode(await readerStream(st).expand((c) => c).toList());
    }

    say('\neco "abc" → "${await echo('abc')}", "dart" → '
        '"${await echo('dart')}" (o handler rodou $served vezes)');
    b.removeStreamHandler('/lesson/echo/1.0.0');

    // 3. Uma interface Go implementada em Dart: só os métodos de que você
    //    precisa.
    //    Go:  a.Network().Notify(&network.NotifyBundle{DisconnectedF: ...})
    final gone = Libp2pCoreNetworkNotifiee(
        disconnected: (_, c) =>
            say('  [Notifiee] perdi ${c.remotePeer().shortString()}'));
    a.network().notify(gone);
    final c = await newHost();
    await a.connect(ctx, goLibp2p.core.host.infoFromHost(c));
    say('\nfechando c, com um Notifiee em a:');
    await c.close();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    a.network().stopNotify(gone);

    // 4. Um objeto Go válido só durante a chamada: um construtor de seletor
    //    entrega um construtor de campos à função, que o preenche ali mesmo.
    //    Go:  ssb.ExploreFields(func(efsb builder.ExploreFieldsSpecBuilder) {
    //             efsb.Insert("Links", ssb.Matcher()) })
    final ssb = IpldPrimeTraversalSelectorBuilderSelectorSpecBuilder(
        IpldPrimeNodeBasicnodePrototypeAny());
    final spec =
        await ssb.exploreFields((f) => f.insert('Links', ssb.matcher()));
    say('\nexploreFields: montei uma especificação de seletor dentro do '
        'callback: ${spec.runtimeType}');

    say('\n== Erros comuns\n');
    await mistake('um lote grande num callback que recebe um objeto Go',
        why: 'com lote, o Go segue antes de o Dart rodar a função: o '
            'construtor de campos já terminou quando o Dart insere nele',
        instead: 'mantenha o padrão (1) quando o callback recebe um objeto '
            'Go; lotes só para valores simples (posições, bytes)',
        action: () => ssb.exploreFields((f) => f.insert('Links', ssb.matcher()),
            batchSize: 1024));
    await mistake('abrir um stream para um handler que foi removido',
        why: 'o removeStreamHandler tirou a função Dart do Go: b não fala '
            'mais o protocolo',
        instead: 'mantenha o handler enquanto atende; remova-o ao terminar',
        action: () => echo('again'));
    await a.close();
    await b.close();
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
