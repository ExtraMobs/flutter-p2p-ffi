// Passo 11: prazos e cancelamento (o `context` do Go), os dois tipos de erro e
// o que fazer quando o serviço cai.
//
//   dart run example/11_contexto_e_erros.dart
//
// Os conceitos de Future e Stream estão explicados no início do exemplo 09.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/go/context.dart' as context;
import 'package:ipfs_ffi/ipfs_ffi.dart'
    show IpfsException, IpfsService, IpfsServiceException, IpfsStop;
import 'package:ipfs_ffi/kubo.dart' as kubo;
// Só para o passo 4: uma função de TESTE do pacote, que derruba o ipfs_host de
// propósito. Não use num app; ela existe para provar a recuperação.
import 'package:ipfs_ffi/src/runtime.dart' show $callSync;

/// Os plugins do kubo: uma vez por serviço (o kubo recusa a segunda vez no
/// mesmo processo, e um serviço relançado é um processo novo, sem eles).
void plugins() => kubo.PluginLoader('')
  ..initialize()
  ..inject();

/// O nó sobre [repoPath]. Online, porque o pubsub do passo 1 só existe num
/// nó online (o `Pubsub.Enabled` do daemon); com o perfil `test` do repo, ele
/// escuta só em 127.0.0.1 e não sai para a internet.
Future<kubo.IpfsNode> abrirNo(String repoPath) => kubo.newNode(
    context.background(),
    kubo.BuildCfg(
        repo: kubo.open(repoPath), online: true, extraOpts: {'pubsub': true}));

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_ex11_');
  final repoPath = '${tmp.path}/repo';

  // `onStop` é chamado quando o serviço para sem você ter pedido (uma queda
  // do kubo, ou o app indo para o segundo plano no Android). O pacote NUNCA
  // relança sozinho: quem decide é você, aqui. Guardamos cada parada num
  // Completer (um Future que completamos à mão) para o passo 4 esperar por
  // ela.
  var parada = Completer<IpfsStop>();
  await IpfsService.start(
      crashLog: '${tmp.path}/crash.log', // onde o Go grava o relatório
      onStop: (s) => parada.complete(s));

  final cfg = kubo
      .initWithIdentity(kubo.createIdentity(null, [kubo.key.type('ed25519')]));
  kubo.profiles['test']!.transform(cfg);
  plugins();
  kubo.init(repoPath, cfg);
  var n = await abrirNo(repoPath);

  try {
    // ------------------------------------------------------------------
    // 1. Prazo: withTimeout
    // ------------------------------------------------------------------
    // `withTimeout` cria um contexto filho que vence sozinho depois do
    // prazo, e devolve DOIS valores (um "record" do Dart): o contexto e a
    // função `cancel`. Chame o cancel sempre que terminar, mesmo que o prazo
    // já tenha vencido: é o que libera o contexto no Go.
    final (comPrazo, cancelaPrazo) =
        context.withTimeout(context.background(), const Duration(seconds: 2));
    final sw = Stopwatch()..start();
    try {
      // `ipfs pubsub sub` nunca termina sozinho: fica esperando mensagens.
      // Com o prazo de 2 s, o kubo encerra o Stream com um erro de prazo
      // vencido, que o `await for` transforma em exceção.
      await for (final m in kubo.pubsubSub(n, comPrazo, 'sala-11')) {
        print('mensagem: ${m.data}'); // ninguém publica: não vai aparecer
      }
    } on IpfsException catch (e) {
      print('1. depois de ${sw.elapsed.inMilliseconds} ms: $e');
    } finally {
      cancelaPrazo();
    }

    // ------------------------------------------------------------------
    // 2. Cancelar na hora: withCancel
    // ------------------------------------------------------------------
    // Igual, mas sem prazo: o contexto só termina quando você chama o
    // cancel (ex.: o usuário saiu da tela do chat). Aqui ouvimos com
    // `.listen` (não pausa o código) e cancelamos depois de 1 s.
    final (cancelavel, cancela) = context.withCancel(context.background());
    final fim = Completer<String>();
    kubo.pubsubSub(n, cancelavel, 'sala-11').listen(
          (m) {}, // onData: cada mensagem (não vem nenhuma)
          onError: (Object e) => fim.complete('erro: $e'),
          onDone: () {
            // Depois de um erro, o Stream ainda avisa o fim (onDone), a menos
            // que se peça `cancelOnError: true` (abaixo). Por isso conferimos:
            // completar o mesmo Completer duas vezes é erro.
            if (!fim.isCompleted) fim.complete('terminou sem erro');
          },
          cancelOnError: true, // parar de ouvir no primeiro erro
        );
    await Future<void>.delayed(const Duration(seconds: 1));
    // O kubo vê o contexto cancelado e fecha a assinatura. Repare na saída:
    // no `pubsub sub`, o cancelamento termina o Stream SEM erro (onDone),
    // diferente do prazo do passo 1, que terminou com erro.
    cancela();
    print('2. depois do cancel: ${await fim.future}');

    // ------------------------------------------------------------------
    // 3. Erro do kubo: IpfsException
    // ------------------------------------------------------------------
    // A chamada chegou ao kubo, e ele respondeu com erro (no Go, o `error`
    // que a função devolveu). O serviço continua de pé; dá para seguir.
    try {
      await kubo.filesStat(n, context.background(), '/nao/existe').single;
    } on IpfsServiceException {
      rethrow; // (é subclasse de IpfsException: trate antes, se precisar)
    } on IpfsException catch (e) {
      print('3. erro do kubo, o serviço segue: $e');
    }

    // ------------------------------------------------------------------
    // 4. O serviço caiu: IpfsServiceException e onStop
    // ------------------------------------------------------------------
    // Um panic do Go que ninguém trata (uma goroutine interna do kubo, por
    // exemplo) derruba o processo do ipfs_host. O app continua vivo: as
    // chamadas pendentes falham com IpfsServiceException, e o onStop recebe
    // o motivo e o relatório do Go. Aqui provocamos a queda de propósito.
    $callSync(24); // SÓ PARA TESTE: panic numa goroutine do host
    final s = await parada.future; // espera o onStop
    print('4. o serviço parou: ${s.reason}, saída ${s.exitCode}, '
        'de pé por ${s.uptime.inSeconds} s');
    print('   relatório do Go: ${s.report.split('\n').first}');

    // Tudo que veio do serviço anterior (nó, CoreAPI, contextos...) morreu
    // com ele: usar agora dá IpfsServiceException.
    try {
      kubo.newCoreApi(n);
    } on IpfsServiceException catch (e) {
      // (a mensagem traz o relatório inteiro do Go; aqui, só a 1ª linha)
      print('   o nó antigo não vale mais: ${'$e'.split('\n').first}');
    }

    // Relançar é decisão sua: aqui, sim. O processo é novo, então refazemos
    // plugins e nó; os dados do repo estão no disco e continuam lá.
    parada = Completer<IpfsStop>();
    await IpfsService.restart();
    plugins();
    n = await abrirNo(repoPath);
    final p = await kubo
        .newCoreApi(n)
        .unixfs()
        .add(context.background(), files.newBytesFile(utf8.encode('de volta')));
    print('5. de volta: o serviço novo já adicionou $p');
  } finally {
    if (IpfsService.isRunning) await n.close();
    await IpfsService.stop();
    tmp.deleteSync(recursive: true);
  }
}
