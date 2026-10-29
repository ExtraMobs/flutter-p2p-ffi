// Lição 19 · Como ponho prazo e cancelo? Que erros podem vir?
//
// Pergunta: buscar um CID que ninguém tem, ou esperar uma mensagem, pode
// levar para sempre (lições 16-18). Como paro de esperar, e como distingo as
// diferentes falhas?
//
// Resposta: o `context` do Go, o primeiro argumento de toda chamada que pode
// esperar:
//   - goContext.withTimeout(pai, d) / withDeadline: o próprio Go desiste
//     quando o tempo acaba, e a chamada lança
//     GolangDeadlineExceededException;
//   - goContext.withCancel(pai): chame cancel() quando quiser; a chamada lança
//     GolangCanceledException;
//   - sempre chame a função de cancelamento que recebeu ao terminar: ela
//     solta o que o Go guarda para aquele context.
// Um prazo do lado do Go para o trabalho do Go; um `.timeout()` do Dart no
// Future só faz o Dart parar de esperar, enquanto o Go continua trabalhando.
// Os erros, do mais específico ao mais geral (capture os específicos antes):
//   - GolangNotFoundException, GolangEofException, GolangCanceledException,
//     GolangDeadlineExceededException...: os erros conhecidos do Go;
//   - a classe de cada erro exportado de um pacote Go, com o nome do
//     pacote na frente: IoFsErrNotExist (fs.ErrNotExist), IoFsPathError
//     (com op e path), CidErrInvalidCid...;
//   - GolangException: qualquer outro erro do Go, com a mensagem do Go;
// Todas levam a corrente: errTexts (o texto de cada elo embrulhado, de fora
// para dentro; errText é a causa original), errno (o número do sistema
// operacional, quando há) e isA<T>() / find<T>(), o errors.Is / errors.As
// do Go.
//   - P2pServiceException: o próprio serviço não está lá (não iniciado,
//     parado, ou caiu). Ela também conta como GolangException, então capture
//     antes.
// Se o p2p_host cai (um panic do Go fora de qualquer chamada), só o serviço
// vai embora; o app recebe o onStop com o motivo e o relatório do Go, e pode
// reiniciar: um processo novo, então plugins, repositório e nó são abertos
// de novo e os handles antigos deixam de valer.
//
// Precisa de: lição 08 (um nó) e 17 (algo que espera pela rede).
//
//   dart run example/pt_br/19_deadlines_and_errors.dart
//
// Próxima pergunta: "O nó e todo objeto que abri vivem no Go. Quando são
// liberados?" → lição 20.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/p2p_ffi.dart';
// ignore: implementation_imports
import 'package:p2p_ffi/src/runtime.dart' show $callSync;

import 'lesson.dart';

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('lesson19_');
  var stopped = Completer<P2pStop>();
  await P2pService.start(
      crashLog:
          '${tmp.path}/crash.log', // onde o Go grava um relatório de queda
      onStop: (s) => stopped.complete(s));
  var bg = goContext.background();
  // Um nó online sozinho (perfil test: sem peers de bootstrap): pedir a ele
  // um CID que ninguém tem espera para sempre, a coisa perfeita para limitar.
  var n = await newNode(bg, '${tmp.path}/repo', online: true);
  final nowhere = BoxoPath('/ipfs/'
      '${goCid.newPrefixV1(goMulticodec.raw, goMultihash.sha2256).sum(utf8.encode('nobody has this'))}');
  try {
    var api = goKubo.core.coreapi.newCoreApi(n);

    // 1. Um prazo: o Go para o trabalho quando o tempo acaba.
    //    Go:  ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
    //         defer cancel()
    final (withDeadline, cancelDeadline) =
        goContext.withTimeout(bg, const Duration(seconds: 2));
    final watch = Stopwatch()..start();
    try {
      await api.unixfs().get(withDeadline, nowhere);
    } on GolangDeadlineExceededException catch (e) {
      say('1. prazo: depois de ${watch.elapsedMilliseconds} ms, '
          '${e.runtimeType}: ${e.message}');
    } finally {
      cancelDeadline();
    }

    // 2. Cancelar à mão, de qualquer lugar (um botão, o app fechando).
    //    Go:  ctx, cancel := context.WithCancel(context.Background())
    final (cancelable, cancel) = goContext.withCancel(bg);
    Timer(const Duration(milliseconds: 500), cancel);
    try {
      await api.unixfs().get(cancelable, nowhere);
    } on GolangCanceledException catch (e) {
      say('2. cancelado depois de ~500 ms: ${e.runtimeType}: ${e.message}');
    }

    // 3. Os tipos de erro, os específicos primeiro.
    Future<String> kindOf(Future<Object?> Function() call) async {
      try {
        await call();
        return 'sem erro';
      } on P2pServiceException catch (e) {
        return 'P2pServiceException (o serviço): ${brief(e)}';
      } on GolangNotFoundException catch (e) {
        return 'GolangNotFoundException: ${brief(e)}';
      } on IoFsPathError catch (e) {
        return 'fs.PathError: op "${e.op}", errno ${e.errno}';
      } on GolangException catch (e) {
        return '${className(e)}: ${brief(e)}';
      }
    }

    say('\n3. tipos de erro:');
    say('  um caminho do MFS que não existe → '
        '${await kindOf(() => goKubo.core.commands.filesStat(n, bg, '/nope').single)}');
    say('  um bloco que não está no blockstore → '
        '${await kindOf(() => n.blockstore.get(bg, goCid.decode(nowhere.value.substring(6))))}');
    say('  um CID que não é um → '
        '${await kindOf(() async => goCid.decode('not-a-cid'))}');
    say('  um arquivo que não existe (goOs.open) → '
        '${await kindOf(() async => goOs.open('${tmp.path}/nope.bin'))}');

    //    A corrente de um erro: o que cada camada acrescentou, até a causa.
    try {
      goOs.open('${tmp.path}/nope.bin');
    } on GolangException catch (e) {
      say('  a corrente de um erro do goOs.open, de fora para dentro:');
      for (final t in e.errTexts) {
        say('    - ${t.replaceAll(tmp.path, '<tmp>')}');
      }
      say('    a causa: "${e.errText}", errno ${e.errno}, lançado como '
          '${className(e)}');
    }

    // 4. Uma queda do serviço (SÓ PARA TESTE: um gancho que dá panic numa
    //    goroutine do Go, como um bug dentro do kubo). Só o p2p_host cai;
    //    este programa continua, avisado pelo onStop.
    const panicInGoroutineHook = 24; // WIRE.md
    $callSync(panicInGoroutineHook);
    final s = await stopped.future;
    say('\n4. o serviço parou: ${s.reason}, código de saída ${s.exitCode}, '
        'ativo por ${s.uptime.inSeconds} s');
    say('   o relatório do Go começa com: ${s.report.split('\n').first}');
    say('   o nó antigo agora: '
        '${await kindOf(() => api.unixfs().add(bg, goBoxo.files.newBytesFile(utf8.encode('x'))))}');

    // 5. Reiniciar: um processo novo; abra tudo de novo no mesmo
    //    repositório. Todo handle pertence ao serviço antigo, o context
    //    também: crie novos.
    stopped = Completer<P2pStop>();
    await P2pService.restart();
    bg = goContext.background();
    n = await openNode(bg, '${tmp.path}/repo', online: true);
    api = goKubo.core.coreapi.newCoreApi(n);
    final p = await api
        .unixfs()
        .add(bg, goBoxo.files.newBytesFile(utf8.encode('back')));
    say('5. reiniciado: o serviço novo adicionou $p');

    say('\n== Erros comuns\n');
    await mistake('um .timeout() do Dart em vez de um prazo do Go',
        why: 'o Dart para de esperar, mas o Go continua procurando o CID: o '
            'trabalho e o que ele segura seguem no p2p_host',
        instead: 'goContext.withTimeout: o próprio Go para e solta',
        action: () =>
            api.unixfs().get(bg, nowhere).timeout(const Duration(seconds: 1)));
    final (done, cancelDone) = goContext.withCancel(bg);
    cancelDone();
    await mistake('reusar um context que já foi cancelado',
        why: 'um context cancelado continua cancelado: toda chamada com ele '
            'falha na hora, e o kubo pode embrulhar a causa (aqui como '
            '"could not resolve name", não como GolangCanceledException)',
        instead: 'um context novo por operação (ou por tela, por pedido)',
        action: () => api.unixfs().get(done, nowhere));
  } finally {
    if (P2pService.isRunning) await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}

/// O nome da classe de uma exceção do Go, com o pacote Go
/// (`fs.ErrNotExist`, `GolangNotFoundException`): o começo do toString.
String className(Object e) => '$e'.split(': ').first;
