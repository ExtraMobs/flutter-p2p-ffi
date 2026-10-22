// O canal com o p2p_host (marco 0.9.0, P1): só a função Noop (0). Exige
// `dart run tool/build.dart` (native/p2p_host e a p2p_shm).
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart' show GolangException, P2pServiceException;
import 'package:p2p_ffi/src/shm.dart';
import 'package:test/test.dart';

final hostPath =
    Platform.isWindows ? r'native\p2p_host.exe' : 'native/p2p_host';

void main() {
  test('Noop síncrona e assíncrona; função desconhecida vira exceção',
      () async {
    final ch = await ShmChannel.start(hostPath);
    try {
      expect(ch.callSync(0), isEmpty);
      expect(await ch.call(0), isEmpty);
      final many =
          await Future.wait([for (var i = 0; i < 10000; i++) ch.call(0)]);
      expect(many, hasLength(10000));
      // Echo (função 2) maior que um quadro do anel: partida nos dois sentidos
      final big = Uint8List.fromList(List.generate(9 << 20, (i) => i * 31));
      expect(ch.callSync(2, big), big);
      expect(await ch.call(2, big), big);
      expect(() => ch.callSync(999), throwsA(isA<GolangException>()));
      await expectLater(ch.call(999), throwsA(isA<GolangException>()));
    } finally {
      await ch.close();
    }
    expect(await ch.exitCode, 0); // o host sai sozinho com o canal fechado
  });

  // sem giro, a thread que acorda o Dart dorme já de cara; a resposta que
  // chega entre o giro e o sono tem de ser entregue (antes girava para sempre)
  test('spin 0: só o sininho, sem espera ativa', () async {
    final ch = await ShmChannel.start(hostPath, spin: 0);
    try {
      for (var i = 0; i < 200; i++) {
        expect(ch.callSync(0), isEmpty);
        expect(await ch.call(0), isEmpty);
      }
      final many =
          await Future.wait([for (var i = 0; i < 10000; i++) ch.call(0)]);
      expect(many, hasLength(10000));
    } finally {
      await ch.close();
    }
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('o host morre: as pendentes falham com P2pServiceException', () async {
    final ch = await ShmChannel.start(hostPath);
    try {
      // Sleep (função 1) de 30 s: fica pendente até o host morrer
      final pending = ch.call(1,
          Uint8List(4)..buffer.asByteData().setUint32(0, 30000, Endian.little));
      expect(ch.callSync(0), isEmpty); // o host segue respondendo o resto
      Process.killPid(ch.hostPid, ProcessSignal.sigkill);
      await expectLater(pending, throwsA(isA<P2pServiceException>()));
      await ch.exitCode;
      await expectLater(ch.call(0), throwsA(isA<P2pServiceException>()));
      expect(() => ch.callSync(0), throwsA(isA<P2pServiceException>()));
    } finally {
      await ch.close();
    }
  });
}
