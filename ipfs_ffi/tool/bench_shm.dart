// Mede o canal com o ipfs_host (marco 0.9.0, P1): latência síncrona de ida e
// volta e vazão com chamadas em voo, só com a função Noop.
// Uso: dart run tool/bench_shm.dart [caminho do ipfs_host]
import 'dart:io';

import 'package:ipfs_ffi/src/shm.dart';

Future<void> main(List<String> args) async {
  final host = args.isNotEmpty
      ? args.first
      : Platform.isWindows
          ? r'native\ipfs_host.exe'
          : 'native/ipfs_host';
  final ch = await ShmChannel.start(host);
  try {
    for (var i = 0; i < 20000; i++) {
      ch.callSync(0); // aquecimento
    }
    const sync = 200000;
    var sw = Stopwatch()..start();
    for (var i = 0; i < sync; i++) {
      ch.callSync(0);
    }
    final rtt = sw.elapsedMicroseconds / sync;
    print('síncrona: ${rtt.toStringAsFixed(2)} µs por ida e volta '
        '(${(1e6 / rtt).round()} chamadas/s)');

    const total = 1000000, batch = 50000;
    sw = Stopwatch()..start();
    for (var done = 0; done < total; done += batch) {
      await Future.wait([for (var i = 0; i < batch; i++) ch.call(0)]);
    }
    final secs = sw.elapsedMicroseconds / 1e6;
    print('em voo: $total em ${secs.toStringAsFixed(2)} s = '
        '${(total / secs).round()} chamadas/s');
  } finally {
    await ch.close();
  }
  print('host saiu com ${await ch.exitCode}');
}
