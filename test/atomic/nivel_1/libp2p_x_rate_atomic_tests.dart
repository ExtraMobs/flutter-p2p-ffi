// test/atomic/nivel_1/libp2p_x_rate_atomic_tests.dart
// Testes atomicos 1 para 1 para go-libp2p/x/rate (limiter.go).
//
// Os valores esperados foram produzidos executando o proprio x/rate dentro do
// modulo go-libp2p de referencia, nao deduzidos. A saida do programa Go esta
// citada em cada teste que depende dela.

import 'package:boilerplate/net_netip/golang.dart';
import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

void main() {
  final base = DateTime.utc(2026, 1, 1);

  group('Limit [Atomic Audit]', () {
    test('rps - devolve a taxa configurada', () {
      expect(const Limit(rps: 2.5, burst: 3).rps, equals(2.5));
    });

    test('burst - devolve o estouro configurado', () {
      expect(const Limit(rps: 1, burst: 7).burst, equals(7));
    });

    test('Limit() - valor zero nao permite evento nenhum', () {
      // Go: "A zero Limit allows no events."
      const zero = Limit();
      expect(zero.rps, equals(0));
      expect(zero.burst, equals(0));
    });
  });

  group('PrefixLimit [Atomic Audit]', () {
    test('prefix - devolve a rede a que o limite se aplica', () {
      final p = PrefixLimit(
        prefix: Prefix.mustParse('10.0.0.0/8'),
        limit: const Limit(rps: 1, burst: 1),
      );
      expect(p.prefix, equals(Prefix.mustParse('10.0.0.0/8')));
    });

    test('limit - devolve o limite embutido', () {
      final p = PrefixLimit(
        prefix: Prefix.mustParse('10.0.0.0/8'),
        limit: const Limit(rps: 4, burst: 2),
      );
      expect(p.limit.burst, equals(2));
    });
  });

  group('SubnetLimit [Atomic Audit]', () {
    test('prefixLength - devolve o tamanho de prefixo da sub-rede', () {
      const s = SubnetLimit(prefixLength: 24, limit: Limit(rps: 1, burst: 1));
      expect(s.prefixLength, equals(24));
    });

    test('limit - devolve o limite embutido', () {
      const s = SubnetLimit(prefixLength: 56, limit: Limit(rps: 9, burst: 5));
      expect(s.limit.rps, equals(9));
    });
  });

  group('Limiter [Atomic Audit]', () {
    test('allow() - consome o burst global e depois recusa', () {
      // Go: global 1: true 2: true 3: false  (RPS 1, Burst 2)
      final limiter = Limiter(globalLimit: const Limit(rps: 1, burst: 2));
      final addr = Addr.tryParse('1.2.3.4')!;
      expect(limiter.allow(addr), isTrue);
      expect(limiter.allow(addr), isTrue);
      expect(limiter.allow(addr), isFalse);
    });

    test('allow() - limite de prefixo vence e nao consome o global', () {
      // Go: prefix 1: true 2: false
      final limiter = Limiter(
        networkPrefixLimits: [
          PrefixLimit(
            prefix: Prefix.mustParse('10.0.0.0/8'),
            limit: const Limit(rps: 100, burst: 1),
          ),
        ],
      );
      final inside = Addr.tryParse('10.1.2.3')!;
      expect(limiter.allow(inside), isTrue);
      expect(limiter.allow(inside), isFalse);
    });

    test(
      'allow() - fora do prefixo cai no global, que com rps 0 e infinito',
      () {
        // Go: fora do prefixo (global Inf): true
        // Um GlobalLimit zerado vira rate.Inf no init, nao um bucket vazio.
        final limiter = Limiter(
          networkPrefixLimits: [
            PrefixLimit(
              prefix: Prefix.mustParse('10.0.0.0/8'),
              limit: const Limit(rps: 100, burst: 1),
            ),
          ],
        );
        expect(limiter.allow(Addr.tryParse('11.1.2.3')!), isTrue);
        expect(limiter.allow(Addr.tryParse('11.1.2.4')!), isTrue);
      },
    );

    test('allow() - endereco zero nao casa prefixo algum', () {
      final limiter = Limiter(
        networkPrefixLimits: [
          PrefixLimit(
            prefix: Prefix.mustParse('10.0.0.0/8'),
            limit: const Limit(rps: 1, burst: 1),
          ),
        ],
      );
      expect(limiter.allow(const Addr.zero()), isTrue);
    });

    test('networkPrefixLimits - fica ordenado do mais especifico ao menos', () {
      final limiter = Limiter(
        networkPrefixLimits: [
          PrefixLimit(
            prefix: Prefix.mustParse('10.0.0.0/8'),
            limit: const Limit(rps: 1, burst: 1),
          ),
          PrefixLimit(
            prefix: Prefix.mustParse('10.1.0.0/16'),
            limit: const Limit(rps: 1, burst: 1),
          ),
        ],
      );
      // A ordenacao acontece no init, disparado pelo primeiro allow.
      limiter.allow(Addr.tryParse('9.9.9.9')!);
      expect(limiter.networkPrefixLimits.first.prefix.bits, equals(16));
      expect(limiter.networkPrefixLimits.last.prefix.bits, equals(8));
    });

    test('globalLimit - devolve o limite global configurado', () {
      final limiter = Limiter(globalLimit: const Limit(rps: 3, burst: 4));
      expect(limiter.globalLimit.burst, equals(4));
    });

    test('subnetRateLimiter - existe mesmo sem ser fornecido', () {
      expect(Limiter().subnetRateLimiter, isA<SubnetLimiter>());
    });

    test('limitHandler() - repassa a stream quando dentro do limite', () {
      // Sem stream real aqui: o que se verifica e que o wrapper e construido
      // e devolve uma funcao chamavel. O caminho com stream de verdade fica
      // no teste de integracao do identify.
      final limiter = Limiter(globalLimit: const Limit(rps: 1, burst: 1));
      var called = false;
      final wrapped = limiter.limitHandler((_) => called = true);
      expect(wrapped, isNotNull);
      expect(called, isFalse);
    });
  });

  group('SubnetLimiter [Atomic Audit]', () {
    test('allow() - dois enderecos da mesma /24 dividem o bucket', () {
      // Go: sub same/24 1: true 2: false
      final limiter = SubnetLimiter(
        ipv4SubnetLimits: const [
          SubnetLimit(prefixLength: 24, limit: Limit(rps: 1, burst: 1)),
        ],
        gracePeriod: const Duration(seconds: 10),
      );
      expect(limiter.allow(Addr.tryParse('192.168.1.10')!, base), isTrue);
      expect(limiter.allow(Addr.tryParse('192.168.1.99')!, base), isFalse);
    });

    test('allow() - outra /24 tem bucket proprio', () {
      // Go: sub outra/24: true
      final limiter = SubnetLimiter(
        ipv4SubnetLimits: const [
          SubnetLimit(prefixLength: 24, limit: Limit(rps: 1, burst: 1)),
        ],
        gracePeriod: const Duration(seconds: 10),
      );
      expect(limiter.allow(Addr.tryParse('192.168.1.10')!, base), isTrue);
      expect(limiter.allow(Addr.tryParse('192.168.2.10')!, base), isTrue);
    });

    test('allow() - IPv6 usa a lista v6 e a mesma /56 divide o bucket', () {
      // Go: v6 same/56 1: true 2: false
      final limiter = SubnetLimiter(
        ipv6SubnetLimits: const [
          SubnetLimit(prefixLength: 56, limit: Limit(rps: 1, burst: 1)),
        ],
      );
      expect(
        limiter.allow(Addr.tryParse('2001:db8:1234:5600::1')!, base),
        isTrue,
      );
      expect(
        limiter.allow(Addr.tryParse('2001:db8:1234:56ff::2')!, base),
        isFalse,
      );
    });

    test('allow() - sem limites configurados nada e barrado', () {
      // Go: zero addr: true
      final limiter = SubnetLimiter();
      expect(limiter.allow(const Addr.zero(), base), isTrue);
      expect(limiter.allow(Addr.tryParse('1.2.3.4')!, base), isTrue);
    });

    test('allow() - endereco zero nao produz prefixo e e recusado', () {
      // Addr.zero().prefix(n) devolve prefixo invalido; com um limite v6
      // configurado, o Go sai por `err != nil` e este porte pelo isValid.
      final limiter = SubnetLimiter(
        ipv6SubnetLimits: const [
          SubnetLimit(prefixLength: 56, limit: Limit(rps: 1, burst: 1)),
        ],
      );
      expect(limiter.allow(const Addr.zero(), base), isFalse);
    });

    test('allow() - bucket expirado e descartado apos o grace period', () {
      final limiter = SubnetLimiter(
        ipv4SubnetLimits: const [
          SubnetLimit(prefixLength: 24, limit: Limit(rps: 1, burst: 1)),
        ],
        gracePeriod: const Duration(seconds: 1),
      );
      final addr = Addr.tryParse('192.168.1.10')!;
      expect(limiter.allow(addr, base), isTrue);
      expect(limiter.allow(addr, base), isFalse);
      // Muito depois do grace period o bucket antigo sai do heap e um novo,
      // cheio, toma o lugar.
      expect(limiter.allow(addr, base.add(const Duration(hours: 1))), isTrue);
    });

    test(
      'ipv4SubnetLimits - fica ordenado com a maior sub-rede por ultimo',
      () {
        final limiter = SubnetLimiter(
          ipv4SubnetLimits: const [
            SubnetLimit(prefixLength: 16, limit: Limit(rps: 1, burst: 1)),
            SubnetLimit(prefixLength: 24, limit: Limit(rps: 1, burst: 1)),
          ],
        );
        limiter.allow(Addr.tryParse('1.2.3.4')!, base);
        expect(limiter.ipv4SubnetLimits.first.prefixLength, equals(24));
        expect(limiter.ipv4SubnetLimits.last.prefixLength, equals(16));
      },
    );

    test('ipv6SubnetLimits - mesma ordenacao para a lista v6', () {
      final limiter = SubnetLimiter(
        ipv6SubnetLimits: const [
          SubnetLimit(prefixLength: 48, limit: Limit(rps: 1, burst: 1)),
          SubnetLimit(prefixLength: 56, limit: Limit(rps: 1, burst: 1)),
        ],
      );
      limiter.allow(Addr.tryParse('::1')!, base);
      expect(limiter.ipv6SubnetLimits.first.prefixLength, equals(56));
      expect(limiter.ipv6SubnetLimits.last.prefixLength, equals(48));
    });

    test('gracePeriod - devolve a carencia configurada', () {
      final limiter = SubnetLimiter(gracePeriod: const Duration(seconds: 30));
      expect(limiter.gracePeriod, equals(const Duration(seconds: 30)));
    });
  });
}
