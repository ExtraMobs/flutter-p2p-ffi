// test/atomic/nivel_1/pion_transport_v4_atomic_tests.dart
// Testes atômicos 1 para 1 para os subpacotes utils/xor e replaydetector, e
// para os tipos puros de net.dart e netctx.dart, de pion/transport v4
// (transpiled_pion_transport_v4). Vetores adaptados de
// go-ipfs-reference/pion-transport-v4/utils/xor/xor_test.go e
// go-ipfs-reference/pion-transport-v4/replaydetector/{replaydetector,fixedbig}_test.go.
// Nível 1: funções puras / manipulação de bytes em memória, sem I/O.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';
import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart';

void main() {
  group('xorBytes [Atomic Audit]', () {
    test(
      'xorBytes() - XORa byte a byte e retorna a contagem (porta TestXOR)',
      () {
        final rnd = Random(42);
        for (var j = 1; j <= 64; j++) {
          final a = Uint8List.fromList(
            List.generate(j, (_) => rnd.nextInt(256)),
          );
          final b = Uint8List.fromList(
            List.generate(j, (_) => rnd.nextInt(256)),
          );
          final dst = Uint8List(j);
          final n = xorBytes(dst, a, b);
          expect(n, equals(j));
          for (var i = 0; i < j; i++) {
            expect(dst[i], equals(a[i] ^ b[i]));
          }
        }
      },
    );

    test('xorBytes() - trunca no menor comprimento entre a e b', () {
      final a = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]);
      final b = Uint8List.fromList([0x0F, 0x0F]);
      final dst = Uint8List(4)..fillRange(0, 4, 42);
      final n = xorBytes(dst, a, b);
      expect(n, equals(2));
      expect(dst[0], equals(0xF0));
      expect(dst[1], equals(0xF0));
      // Bytes além de n não são tocados, tal qual o guard byte do teste Go.
      expect(dst[2], equals(42));
      expect(dst[3], equals(42));
    });

    test('xorBytes() - entrada vazia não escreve nada e retorna 0', () {
      final dst = Uint8List(1)..fillRange(0, 1, 7);
      final n = xorBytes(dst, Uint8List(0), Uint8List(0));
      expect(n, equals(0));
      expect(dst[0], equals(7));
    });
  });

  group('ReplayDetector [Atomic Audit]', () {
    Golang.Uint64 seq(int v) => Golang.Uint64(v);

    test('ReplayDetector() - aceita sequência contínua crescente '
        '(porta commonCases["Continuous"])', () {
      final d = ReplayDetector(16, seq(0x0000FFFFFFFFFFFF));
      for (var i = 0; i <= 20; i++) {
        final accept = d.check(seq(i));
        expect(accept, isNotNull, reason: 'seq $i deveria ser aceita');
        expect(accept!(), isTrue, reason: 'seq $i deveria ser a mais nova');
      }
    });

    test('ReplayDetector() - rejeita salto que excede maxSeq '
        '(porta commonCases["InvalidLargeJump"])', () {
      const hugeSeq = 0x1000000000000;
      final d = ReplayDetector(16, seq(0x0000FFFFFFFFFFFF));
      for (var i = 0; i < 10; i++) {
        expect(d.check(seq(i)), isNotNull);
      }
      expect(d.check(seq(hugeSeq)), isNull);
      // A sequência continua normalmente após a rejeição.
      expect(d.check(seq(11)), isNotNull);
    });

    test('check() - rejeita duplicata dentro da janela '
        '(porta commonCases["ContinuousReplayed"])', () {
      final d = ReplayDetector(8, seq(0x0000FFFFFFFFFFFF));
      for (final v in [16, 17, 18, 19, 20, 21, 22, 23, 24, 25]) {
        final accept = d.check(seq(v));
        expect(accept, isNotNull);
        accept!();
      }
      // Replaying the exact same sequence must now be rejected.
      for (final v in [16, 17, 18, 19, 20, 21, 22, 23, 24, 25]) {
        expect(
          d.check(seq(v)),
          isNull,
          reason: 'seq $v é replay e deve ser rejeitada',
        );
      }
    });

    test('check() - registra pacotes reordenados como não-mais-recentes '
        '(porta commonCases["Reordered"])', () {
      final d = ReplayDetector(128, seq(0x0000FFFFFFFFFFFF));
      const input = [
        96,
        64,
        16,
        80,
        32,
        48,
        8,
        24,
        88,
        40,
        128,
        56,
        72,
        112,
        104,
        120,
      ];
      const expectedLatest = [
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
      ];
      for (var i = 0; i < input.length; i++) {
        final accept = d.check(seq(input[i]));
        expect(accept, isNotNull, reason: 'seq ${input[i]} deveria ser aceita');
        expect(
          accept!(),
          equals(expectedLatest[i]),
          reason: 'seq ${input[i]} latest esperado ${expectedLatest[i]}',
        );
      }
    });

    test(
      'ReplayDetector.withWrap() - lida com estouro de contador curto '
      '(porta TestWrappedReplayDetector, entrada crescente ao redor do wrap)',
      () {
        const maxSeq = 0x7FFF; // contador de 15 bits, como SRTP/SRTCP
        final d = ReplayDetector.withWrap(8, seq(maxSeq));
        // Sequência inicial válida.
        for (final v in [maxSeq - 2, maxSeq - 1, maxSeq]) {
          final accept = d.check(seq(v));
          expect(
            accept,
            isNotNull,
            reason: 'seq $v deveria ser aceita antes do wrap',
          );
          accept!();
        }
        // Passa por cima do limite (wrap para 0) -- deve continuar sendo aceito
        // porque withWrap tolera o estouro do contador.
        final wrapped = d.check(seq(0));
        expect(
          wrapped,
          isNotNull,
          reason: 'seq 0 após o wrap deveria ser aceita',
        );
        expect(wrapped!(), isTrue);
      },
    );

    test(
      'check() - rejeita sequência acima do maxSeq configurado em withWrap',
      () {
        const maxSeq = 0xFF;
        final d = ReplayDetector.withWrap(8, seq(maxSeq));
        expect(d.check(seq(maxSeq + 1)), isNull);
      },
    );
  });

  group('NetAddr [Atomic Audit]', () {
    test('network() - implementação UdpAddr retorna "udp"', () {
      final NetAddr addr = UdpAddr(InternetAddress.loopbackIPv4, 1234);
      expect(addr.network, equals('udp'));
    });
  });

  group('UdpAddr [Atomic Audit]', () {
    test('network() - sempre retorna "udp" (porta net go UDPAddr)', () {
      final addr = UdpAddr(InternetAddress.loopbackIPv4, 1234);
      expect(addr.network, equals('udp'));
    });

    test('toString() - formata host:porta sem zona IPv6', () {
      final addr = UdpAddr(InternetAddress.loopbackIPv4, 4242);
      expect(addr.toString(), equals('127.0.0.1:4242'));
    });

    test('toString() - inclui a zona IPv6 quando presente', () {
      final addr = UdpAddr(InternetAddress.loopbackIPv4, 53, 'eth0');
      expect(addr.toString(), equals('127.0.0.1%eth0:53'));
    });

    test('operator ==() - verdadeiro quando address/port/zone coincidem', () {
      final a = UdpAddr(InternetAddress.loopbackIPv4, 80);
      final b = UdpAddr(InternetAddress.loopbackIPv4, 80);
      final c = UdpAddr(InternetAddress.loopbackIPv4, 81);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode() - igual para dois endereços equivalentes', () {
      final a = UdpAddr(InternetAddress.loopbackIPv4, 80);
      final b = UdpAddr(InternetAddress.loopbackIPv4, 80);
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('ClosingException [Atomic Audit]', () {
    test('toString() - identifica o fechamento da conexão', () {
      expect(
        ClosingException().toString(),
        contains('use of closed network connection'),
      );
    });
  });
}
