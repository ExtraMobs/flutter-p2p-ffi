// Ponte FFI → `dart:io` (etapa E1, `src/net/sys/ffi/bridge.dart`): conexão
// de fluxo do FFI vira `RawSocket` do `dart:io` por SCM_RIGHTS num par Unix
// abstrato privado (conferido por `SO_PEERCRED`) e roda no `Fd` do
// `internal/poll`, o caminho atual da VM.
@TestOn('vm && linux')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:golib_dart/src/internal/poll/fd.dart';
import 'package:golib_dart/src/net/sys/ffi/vm.dart';
import 'package:golib_dart/src/sysffi/sysffi.dart' as sf;
import 'package:test/test.dart';

import 'net_ffi_support.dart';

void main() {
  group('ponte para o dart:io', () {
    test('TCP do FFI vira RawSocket e roda no Fd do internal/poll', () async {
      final l = ffiListen();
      addTearDown(l.close);
      final port = l.localAddr()!.port;
      final c = FfiFd.socket(sf.AF_INET, sf.SOCK_STREAM);
      final acc = l.accept();
      await c.connect(ffiLo(port));
      final (s, _) = await acc;
      addTearDown(s.close);
      final localPort = c.localAddr()!.port;

      final raw = await ffiToRawSocket(c);
      expect(c.isClosed, isTrue);
      expect(raw.remoteAddress.address, '127.0.0.1');
      expect(raw.remotePort, port);
      expect(raw.port, localPort);

      final fd = Fd(raw);
      await fd.write(Uint8List.fromList(utf8.encode('do dart:io')));
      final buf = Uint8List(32);
      expect(utf8.decode(buf.sublist(0, await s.read(buf))), 'do dart:io');
      await s.write(Uint8List.fromList(utf8.encode('do FFI')));
      expect(utf8.decode(await fd.read(32)), 'do FFI');
      await fd.close();
      expect(await s.read(buf), 0);
    });

    test('várias conexões no mesmo turno reaproveitam a sessão', () async {
      final l = ffiListen();
      addTearDown(l.close);
      final port = l.localAddr()!.port;
      final conns = <FfiFd>[];
      for (var i = 0; i < 4; i++) {
        final c = FfiFd.socket(sf.AF_INET, sf.SOCK_STREAM);
        final acc = l.accept();
        await c.connect(ffiLo(port));
        final (s, _) = await acc;
        addTearDown(s.close);
        conns.add(c);
      }
      final raws = await Future.wait(conns.map(ffiToRawSocket));
      expect(raws.map((r) => r.remotePort).toSet(), {port});
      for (final r in raws) {
        await r.close();
      }
    });

    test('só fluxo conectado; o fd é consumido mesmo na falha', () async {
      final c = FfiFd.socket(sf.AF_INET, sf.SOCK_STREAM);
      await expectLater(
        ffiToRawSocket(c),
        throwsA(isA<FfiErrno>().having((e) => e.errno, 'errno', sf.ENOTCONN)),
      );
      expect(c.isClosed, isTrue);
      final u = FfiFd.socket(sf.AF_INET, sf.SOCK_DGRAM);
      await expectLater(
        ffiToRawSocket(u),
        throwsA(isA<FfiErrno>().having((e) => e.errno, 'errno', sf.EPROTOTYPE)),
      );
      expect(u.isClosed, isTrue);
    });
  });
}
