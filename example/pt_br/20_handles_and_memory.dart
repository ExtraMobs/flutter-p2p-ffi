// Lição 20 · Quando preciso liberar memória?
//
// Pergunta: o nó, um leitor de CAR, um buffer... todo objeto Go que abro
// vive no p2p_host (lição 01). O coletor de lixo do Dart libera a memória do
// Dart; o que libera o lado do Go?
//
// Resposta: um handle (GoHandle) é um objeto Dart pequeno que guarda um
// número; o p2p_host guarda o objeto Go de verdade numa tabela sob esse
// número, e o coletor de lixo do Go não pode liberá-lo enquanto ele estiver
// lá. A entrada sai:
//   - sozinha, quando o GC do Dart recolhe o handle (um Finalizer). Mas para
//     o Dart um handle pesa poucos bytes, segure o que segurar no Go (um
//     buffer de 64 MiB também): o Dart não sente pressão, o GC dele não roda,
//     e o p2p_host cresce ("lixo flutuante"). Serve para poucos objetos de
//     vida longa, não para laços.
//   - na hora, com release(): a entrada sai da tabela e o Go pode liberar o
//     objeto. `use(...)` libera no fim de um bloco; `withGoScope(...)` /
//     GoScope liberam de uma vez tudo o que foi registrado.
// close() é outra coisa: é o Close do Go (fecha um arquivo, um nó, um
// leitor); o handle continua existindo até ser liberado ou recolhido.
// Valores (um CID, um caminho, bytes, uma struct de dados) são cópias no
// Dart: não há o que liberar.
//
// Precisa de: lição 01 (valores e handles). Tecnicamente: o mesmo ponteiro
// Go visto duas vezes dá o mesmo número de handle com duas referências,
// então cada handle Dart pode ser liberado por conta própria.
//
//   dart run example/pt_br/20_handles_and_memory.dart
//
// Próxima pergunta: "Algumas funções Go recebem uma função (um handler de
// stream, um validador). Como o Go chama o meu código Dart?" → lição 21.
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

/// A memória residente do p2p_host, em MiB.
int hostMiB() {
  final pid = P2pService.hostPid;
  if (Platform.isWindows) {
    final out =
        Process.runSync('tasklist', ['/fi', 'PID eq $pid', '/fo', 'csv', '/nh'])
            .stdout as String;
    return int.parse(out.split('","').last.replaceAll(RegExp(r'[^0-9]'), '')) ~/
        1024;
  }
  for (final line in File('/proc/$pid/status').readAsLinesSync()) {
    if (line.startsWith('VmRSS:')) {
      return int.parse(line.replaceAll(RegExp(r'[^0-9]'), '')) ~/ 1024;
    }
  }
  return -1;
}

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('lesson20_');
  final big = '${tmp.path}/8mib.bin';
  File(big).writeAsBytesSync(Uint8List(8 << 20));
  await P2pService.start();
  try {
    // 1. Um handle: um número no Dart, o objeto no Go.
    final buf = BytesBuffer(Uint8List.fromList([1, 2, 3, 4]));
    say('um bytes.Buffer: handle #${buf.$h}, liberado: ${buf.isReleased}, '
        '${buf.bytes().length} bytes no Go');
    buf.release();
    buf.release(); // um segundo release não faz nada
    say('  depois do release(): liberado ${buf.isReleased}');

    // 2. O mesmo ponteiro Go duas vezes: uma entrada, duas referências.
    final f1 = Go.boxo.files.newBytesFile(Uint8List.fromList([7, 8, 9]));
    final f2 = f1.asBoxoFilesFile()!; // o mesmo objeto Go, visto como File
    say('\nf1 #${f1.$h} e f2 #${f2.$h}: a mesma entrada, 2 referências');
    f1.release();
    say('  f1 liberado; f2 ainda lê ${Go.io.readAll(f2)}');
    f2.release();

    // 3. Lixo flutuante: 20 × 8 MiB copiados para buffers do Go.
    say('\no p2p_host no início: ${hostMiB()} MiB');
    for (var i = 0; i < 20; i++) {
      // use(): liberado no fim do bloco, aconteça o que acontecer dentro.
      BytesBuffer(Uint8List(0)).use((b) {
        Go.os.open(big).use((f) {
          try {
            Go.io.copy(b, f);
          } finally {
            f.close(); // o Close do Go: o descritor do arquivo
          }
        });
      });
    }
    say('  depois de 20 cópias com use(): ${hostMiB()} MiB');
    for (var i = 0; i < 20; i++) {
      final b = BytesBuffer(Uint8List(0));
      final f = Go.os.open(big);
      Go.io.copy(b, f);
      f.close(); // fechado, mas nenhum dos handles liberado
    }
    say('  depois de 20 cópias deixadas ao Finalizer: ${hostMiB()} MiB (o '
        'Dart não viu motivo para recolher)');

    // 4. Muitos handles por iteração: um escopo os libera juntos, em ordem
    //    inversa, numa única mensagem ao p2p_host.
    final total = withGoScope((s) {
      final f = s.manage(Go.os.open(big));
      try {
        final out = s.manage(BytesBuffer(Uint8List(0)));
        return Go.io.copy(out, f);
      } finally {
        f.close();
      }
    });
    say('\nwithGoScope: copiei $total bytes; os dois handles liberados na '
        'saída');
    final scope = GoScope(); // o mesmo, para uma duração escolhida por você
    final kept = scope.manage(BytesBuffer(Uint8List(16)));
    scope.close();
    say('  GoScope.close(): liberado ${kept.isReleased}');

    say('\n== Erros comuns\n');
    await mistake('usar um handle depois do release()',
        why: 'a entrada saiu da tabela: o número não aponta para nada',
        instead: 'todo uso antes do release(), ou dentro de use((h) {...})',
        action: () => buf.bytes());
    final escaped = withGoScope((s) => s.manage(BytesBuffer(Uint8List(16))));
    await mistake('devolver um handle gerenciado para fora do withGoScope',
        why: 'o escopo o liberou na saída',
        instead: 'devolva um valor Dart (bytes, um CID, uma contagem) do '
            'escopo',
        action: () => escaped.bytes());
    if (Platform.isWindows) {
      final locked = '${tmp.path}/locked.bin';
      File(locked).writeAsBytesSync(Uint8List(64));
      final f = Go.os.open(locked);
      f.release();
      await mistake('release() sem close() num arquivo aberto',
          why: 'o release solta a entrada da tabela, não o arquivo: o Go o '
              'mantém aberto até o GC dele o finalizar (e o Windows então '
              'recusa apagá-lo)',
          instead: 'close() num finally, depois release (ou use())',
          action: () => File(locked).deleteSync());
    }
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
