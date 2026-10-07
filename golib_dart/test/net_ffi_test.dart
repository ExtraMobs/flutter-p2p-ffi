// Rede FFI da VM (etapa E1, decisões F1/F3): `src/sysffi/` (libc, errno,
// layouts), o poller (`src/net/sys/ffi/poller*.dart`, `fd.dart`) e a ponte
// para o `dart:io` (`bridge.dart`, em `net_ffi_bridge_test.dart`). Os testes de processo inteiro (VM
// encerrando com o poller vivo, AOT, JS/Wasm sem `dart:ffi`) estão em
// `net_ffi_build_test.dart`.
//
// Só linux/amd64 (F3); só loopback e pares Unix.
@TestOn('vm && linux')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:golib_dart/src/net/sys/common.dart';
import 'package:golib_dart/src/net/sys/ffi/vm.dart';
import 'package:golib_dart/src/runtime/sched.dart';
import 'package:golib_dart/src/sysffi/sysffi.dart' as sf;
import 'package:test/test.dart';

import 'net_ffi_support.dart';

/// Lê sem esperar do fd cru [fd]: bytes lidos, 0 = EOF, `-errno`.
int _peek(int fd) => sf.recvfrom(
  fd,
  Uint8List(1),
  sf.MSG_DONTWAIT | sf.MSG_PEEK,
  nullptr,
  nullptr,
);

/// Isolate que só aloca: provoca GC no heap compartilhado do grupo.
void _churn(SendPort ready) {
  ready.send(null);
  var keep = <List<int>>[];
  while (true) {
    keep.add(List<int>.filled(512, 1));
    if (keep.length > 4000) keep = [];
  }
}

void main() {
  test('plataforma suportada (linux/amd64)', () {
    expect(sysFfiAvailable, isTrue);
  });

  group('sysffi', () {
    test('errno sob GC: ponteiro prévio, chamada leaf', () async {
      final ready = ReceivePort();
      final churn = await Isolate.spawn(_churn, ready.sendPort);
      await ready.first;
      final fd = sf.socket(sf.AF_UNIX, sf.SOCK_STREAM | sf.SOCK_NONBLOCK, 0);
      final sa = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
      final len = sf.encodeSockaddr(
        sf.Sockaddr.unix('/nao/existe/golib-ffi.sock'),
        sa,
      );
      final sink = <Object>[];
      var calls = 0, wrong = 0;
      final sw = Stopwatch()..start();
      while (sw.elapsedMilliseconds < 1500) {
        for (var i = 0; i < 2000; i++) {
          calls++;
          if (sf.connect(fd, sa, len) != -sf.ENOENT) wrong++;
          // Alocação e trabalho da VM entre as chamadas (não no meio).
          sink.add(List<int>.filled(32, i));
          if (sink.length > 5000) sink.clear();
        }
        await Future<void>.delayed(Duration.zero);
      }
      churn.kill(priority: Isolate.immediate);
      sf.libcAlloc.free(sa);
      sf.close(fd);
      expect(wrong, 0, reason: '$wrong de $calls com errno errado');
      expect(calls, greaterThan(10000));
    });

    test('sockaddr: ida e volta, abstrato, sem nome, caminho longo', () {
      final p = sf.libcAlloc<Uint8>(sf.sockaddrStorageSize);
      addTearDown(() => sf.libcAlloc.free(p));
      for (final a in [
        ffiLo(8080),
        sf.Sockaddr.inet(Uint8List(16)..[15] = 1, 443, scopeId: 3),
        sf.Sockaddr.unix('/tmp/x.sock'),
        sf.Sockaddr.unix('@abstrato'),
      ]) {
        final n = sf.encodeSockaddr(a, p);
        expect(sf.decodeSockaddr(p, n).toString(), a.toString());
      }
      expect(sf.encodeSockaddr(sf.Sockaddr.unix(''), p), 2);
      expect(sf.decodeSockaddr(p, 2).path, '');
      expect(sf.encodeSockaddr(sf.Sockaddr.unix('a' * 108), p), -sf.EINVAL);
      expect(sf.encodeSockaddr(sf.Sockaddr.unix('@${'a' * 107}'), p), 110);
    });

    test('getifaddrs lista o loopback', () {
      final out = sf.libcAlloc<Pointer<sf.IfAddrs>>();
      expect(sf.getifaddrs(out), 0);
      final names = <String>{};
      for (var p = out.value; p != nullptr; p = p.ref.next) {
        final a = p.ref.addr;
        if (a == nullptr) continue;
        final sa = sf.decodeSockaddr(a, sf.sockaddrStorageSize);
        if (sa.family == sf.AF_INET) {
          var n = 0;
          while (p.ref.name[n] != 0) {
            n++;
          }
          names.add(
            '${ascii.decode(p.ref.name.asTypedList(n))} ${sa.ip.join('.')}',
          );
        }
      }
      sf.freeifaddrs(out.value);
      sf.libcAlloc.free(out);
      expect(names, contains('lo 127.0.0.1'));
    });
  });

  group('poller', () {
    test(
      'prazo de leitura vence; no passado, na hora; re-armar vale',
      () async {
        final (a, b) = ffiPair();
        addTearDown(a.close);
        addTearDown(b.close);
        final sw = Stopwatch()..start();
        a.readDeadline = DateTime.now().add(const Duration(milliseconds: 50));
        await expectLater(a.waitRead(), throwsA(isA<SysTimeout>()));
        expect(sw.elapsedMilliseconds, inInclusiveRange(40, 2000));

        a.readDeadline = DateTime.now().subtract(const Duration(seconds: 1));
        await expectLater(a.read(Uint8List(4)), throwsA(isA<SysTimeout>()));

        // Prazo estendido com a espera pendente.
        sw.reset();
        a.readDeadline = DateTime.now().add(const Duration(milliseconds: 40));
        final w = a.waitRead();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        a.readDeadline = DateTime.now().add(const Duration(milliseconds: 200));
        await expectLater(w, throwsA(isA<SysTimeout>()));
        expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(180));

        // Sem prazo: o dado acorda a leitura.
        a.readDeadline = null;
        final buf = Uint8List(8);
        final r = a.read(buf);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(await b.write(Uint8List.fromList([1, 2, 3])), 3);
        expect(await r, 3);
        expect(buf.sublist(0, 3), [1, 2, 3]);
      },
    );

    test(
      'prazo de escrita com o buffer cheio traz o que foi escrito',
      () async {
        final (a, b) = ffiPair();
        addTearDown(a.close);
        addTearDown(b.close);
        a.writeDeadline = DateTime.now().add(const Duration(milliseconds: 100));
        try {
          await a.write(Uint8List(16 << 20));
          fail('escreveu 16 MiB sem leitor');
        } on SysTimeout catch (e) {
          expect(e.written, greaterThan(0));
          expect(e.written, lessThan(16 << 20));
        }
      },
    );

    test(
      'close acorda a espera com SysClosed; close(2) só após o ack',
      () async {
        final (a, b) = ffiPair();
        addTearDown(b.close);
        final fd = a.fd;
        final r = a.read(Uint8List(4));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        a.close();
        a.close(); // idempotente
        expect(a.isClosed, isTrue);
        // O fd está no `poll` do auxiliar: ainda aberto até o ack.
        expect(sf.fcntl(fd, sf.F_GETFD), greaterThanOrEqualTo(0));
        expect(_peek(b.fd), -sf.EAGAIN);
        await expectLater(r, throwsA(isA<SysClosed>()));
        await a.done;
        expect(_peek(b.fd), 0, reason: 'o par vê EOF depois do close(2)');
        await expectLater(a.waitRead(), throwsA(isA<SysClosed>()));
      },
    );

    test('cancelamento acorda com SysCanceled', () async {
      final (a, b) = ffiPair();
      addTearDown(a.close);
      addTearDown(b.close);
      final cancel = Completer<void>();
      final w = a.waitRead(cancel: cancel.future);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      cancel.complete();
      await expectLater(w, throwsA(isA<SysCanceled>()));
    });

    test('espera FFI segura o detector de deadlock', () async {
      final (a, b) = ffiPair();
      addTearDown(a.close);
      addTearDown(b.close);
      goroutineBlocked();
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 100))
            .then((_) => b.write(Uint8List.fromList([7]))),
      );
      final n = await a.read(Uint8List(1));
      goroutineUnblocked();
      expect(n, 1);
    });

    test('fd esquecido é fechado pelo NativeFinalizer', () async {
      // A outra ponta some sem close: o GC fecha, e `a` lê EOF.
      final a = pairForgettingOne();
      addTearDown(a.close);
      final peer = a.fd;
      final sw = Stopwatch()..start();
      var junk = <Object>[];
      while (_peek(peer) != 0 && sw.elapsed < const Duration(seconds: 20)) {
        for (var i = 0; i < 20000; i++) {
          junk.add(Uint8List(64));
        }
        junk = [];
        await Future<void>.delayed(Duration.zero);
      }
      expect(_peek(peer), 0);
    });

    test('connect/accept TCP; recusado; prazo do accept', () async {
      final l = ffiListen();
      addTearDown(l.close);
      final port = l.localAddr()!.port;
      final c = FfiFd.socket(sf.AF_INET, sf.SOCK_STREAM);
      addTearDown(c.close);
      final acc = l.accept();
      await c.connect(ffiLo(port));
      final (s, peer) = await acc;
      addTearDown(s.close);
      expect(peer.port, c.localAddr()!.port);
      expect(c.peerAddr()!.port, port);
      await c.write(Uint8List.fromList(utf8.encode('oi')));
      final buf = Uint8List(8);
      expect(utf8.decode(buf.sublist(0, await s.read(buf))), 'oi');
      c.close();
      expect(await s.read(buf), 0); // EOF

      l.readDeadline = DateTime.now().add(const Duration(milliseconds: 30));
      await expectLater(l.accept(), throwsA(isA<SysTimeout>()));

      l.close();
      await l.done;
      final d = FfiFd.socket(sf.AF_INET, sf.SOCK_STREAM);
      addTearDown(d.close);
      await expectLater(
        d.connect(ffiLo(port)),
        throwsA(
          isA<FfiErrno>()
              .having((e) => e.syscall, 'syscall', 'connect')
              .having((e) => e.errno, 'errno', sf.ECONNREFUSED),
        ),
      );
    });
  });
}
