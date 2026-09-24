// test/atomic/nivel_1/limit_defaults_atomic_tests.dart
// Testes atomicos 1 para 1 para go-libp2p/p2p/host/resource-manager (limit_defaults.go).
//
// Os valores esperados foram produzidos executando o proprio codigo Go
// dentro do modulo go-libp2p (Go versao 1.25.7 windows/amd64).

import 'package:test/test.dart';
import 'package:transpiled_libp2p/src/core/peer/peer_id.dart';
import 'package:transpiled_libp2p/src/core/protocol/protocol.dart';
import 'package:transpiled_libp2p/src/p2p/host/resource_manager/limit.dart'
    as rcmgr;
import 'package:transpiled_libp2p/src/p2p/host/resource_manager/limit_defaults.dart'
    as rcmgr;

void main() {
  group('BaseLimitConfig [Atomic Audit]', () {
    test('BaseLimitConfig() - holds baseLimit and baseLimitIncrease', () {
      const cfg = rcmgr.BaseLimitConfig(
        baseLimit: rcmgr.BaseLimit(streams: 42),
        baseLimitIncrease: rcmgr.BaseLimitIncrease(streams: 7),
      );
      expect(cfg.baseLimit.streams, equals(42));
      expect(cfg.baseLimitIncrease.streams, equals(7));
    });
  });

  group('BaseLimitIncrease [Atomic Audit]', () {
    test('BaseLimitIncrease() - defaults to zero values', () {
      const inc = rcmgr.BaseLimitIncrease();
      expect(inc.streams, equals(0));
      expect(inc.streamsInbound, equals(0));
      expect(inc.streamsOutbound, equals(0));
      expect(inc.conns, equals(0));
      expect(inc.connsInbound, equals(0));
      expect(inc.connsOutbound, equals(0));
      expect(inc.fd, equals(0));
      expect(inc.memory, equals(0));
      expect(inc.fdFraction, equals(0.0));
    });

    test('apply() - merges with another BaseLimitIncrease', () {
      const inc1 = rcmgr.BaseLimitIncrease(streams: 10, conns: 5);
      const inc2 = rcmgr.BaseLimitIncrease(
        streams: 20,
        streamsInbound: 15,
        conns: 0,
        memory: 1024,
      );
      final merged = inc1.apply(inc2);
      expect(merged.streams, equals(10));
      expect(merged.streamsInbound, equals(15));
      expect(merged.conns, equals(5));
      expect(merged.memory, equals(1024));
    });
  });

  group('ScalingLimitConfig [Atomic Audit]', () {
    test('ScalingLimitConfig() - initializes with defaults', () {
      final cfg = rcmgr.ScalingLimitConfig();
      expect(cfg.systemBaseLimit.streams, equals(0));
      expect(cfg.serviceLimits, isNull);
    });

    test('addServiceLimit() - adds service limit entry', () {
      final cfg = rcmgr.ScalingLimitConfig();
      cfg.addServiceLimit(
        'test-svc',
        const rcmgr.BaseLimit(streams: 100),
        const rcmgr.BaseLimitIncrease(streams: 10),
      );
      expect(cfg.serviceLimits, isNotNull);
      expect(cfg.serviceLimits!['test-svc'], isNotNull);
      expect(cfg.serviceLimits!['test-svc']!.baseLimit.streams, equals(100));
      expect(
        cfg.serviceLimits!['test-svc']!.baseLimitIncrease.streams,
        equals(10),
      );
    });

    test('addProtocolLimit() - adds protocol limit entry', () {
      final cfg = rcmgr.ScalingLimitConfig();
      const proto = '/test/1.0.0';
      cfg.addProtocolLimit(
        proto,
        const rcmgr.BaseLimit(conns: 50),
        const rcmgr.BaseLimitIncrease(conns: 5),
      );
      expect(cfg.protocolLimits, isNotNull);
      expect(cfg.protocolLimits![proto], isNotNull);
      expect(cfg.protocolLimits![proto]!.baseLimit.conns, equals(50));
    });

    test('addPeerLimit() - adds peer limit entry', () {
      final cfg = rcmgr.ScalingLimitConfig();
      final peer = PeerId.decode(
        '12D3KooWDsMmX7axDC6HTTXUNe4upxEvFbNQjmE2FToVVbBzUK6f',
      );
      cfg.addPeerLimit(
        peer,
        const rcmgr.BaseLimit(memory: 2048),
        const rcmgr.BaseLimitIncrease(memory: 512),
      );
      expect(cfg.peerLimits, isNotNull);
      expect(cfg.peerLimits![peer]!.baseLimit.memory, equals(2048));
    });

    test('addServicePeerLimit() - adds service peer limit entry', () {
      final cfg = rcmgr.ScalingLimitConfig();
      cfg.addServicePeerLimit(
        'test-svc',
        const rcmgr.BaseLimit(fd: 10),
        const rcmgr.BaseLimitIncrease(fd: 2),
      );
      expect(cfg.servicePeerLimits, isNotNull);
      expect(cfg.servicePeerLimits!['test-svc']!.baseLimit.fd, equals(10));
    });

    test('addProtocolPeerLimit() - adds protocol peer limit entry', () {
      final cfg = rcmgr.ScalingLimitConfig();
      const proto = '/test/1.0.0';
      cfg.addProtocolPeerLimit(
        proto,
        const rcmgr.BaseLimit(streamsInbound: 25),
        const rcmgr.BaseLimitIncrease(streamsInbound: 5),
      );
      expect(cfg.protocolPeerLimits, isNotNull);
      expect(
        cfg.protocolPeerLimits![proto]!.baseLimit.streamsInbound,
        equals(25),
      );
    });

    test('scale() - scales limits based on memory and numFD', () {
      // Valor gerado em Go 1.25.7 com Scale(128 << 20, 256):
      // ConnsInbound: 64, Conns: 128, StreamsInbound: 1024, Memory: 128 MiB, FD: 256
      final scaledBase = rcmgr.defaultLimits.scale(128 << 20, 256);
      expect(scaledBase.system.connsInbound, equals(64));
      expect(scaledBase.system.conns, equals(128));
      expect(scaledBase.system.streamsInbound, equals(1024));
      expect(scaledBase.system.memory, equals(128 << 20));
      expect(scaledBase.system.fd, equals(256));

      // Valor gerado em Go 1.25.7 com Scale(1 << 30, 256):
      // ConnsInbound: 128, Conns: 256, StreamsInbound: 2048, Memory: 1207959552, FD: 256
      final scaled1GiB = rcmgr.defaultLimits.scale(1 << 30, 256);
      expect(scaled1GiB.system.connsInbound, equals(128));
      expect(scaled1GiB.system.conns, equals(256));
      expect(scaled1GiB.system.streamsInbound, equals(2048));
      expect(scaled1GiB.system.memory, equals(1207959552));
      expect(scaled1GiB.system.fd, equals(256));
    });

    test('autoScale() - scales using system defaults', () {
      final autoScaled = rcmgr.defaultLimits.autoScale();
      expect(autoScaled.system.conns, greaterThan(0));
      expect(autoScaled.system.memory, greaterThan(0));
      expect(autoScaled.system.fd, greaterThan(0));
    });
  });

  group('PartialLimitConfig [Atomic Audit]', () {
    test(
      'PartialLimitConfig() - initializes default partial configuration',
      () {
        final partial = rcmgr.PartialLimitConfig();
        expect(partial.system.streams, equals(rcmgr.defaultLimit));
        expect(partial.service, isNull);
      },
    );

    test('apply() - merges partial configurations', () {
      final p1 = rcmgr.PartialLimitConfig(
        system: const rcmgr.ResourceLimits(streams: 50),
      );
      final p2 = rcmgr.PartialLimitConfig(
        system: const rcmgr.ResourceLimits(streams: 100, conns: 20),
      );
      p1.apply(p2);
      expect(p1.system.streams, equals(50));
      expect(p1.system.conns, equals(20));
    });

    test('build() - resolves into concrete limits using fallback', () {
      final partial = rcmgr.PartialLimitConfig(
        system: const rcmgr.ResourceLimits(streams: 50),
      );
      final concrete = partial.build(rcmgr.infiniteLimits);
      expect(concrete.system.streams, equals(50));
      expect(concrete.system.conns, equals(rcmgr.BaseLimit.unlimitedValue));
    });
  });

  group('ConcreteLimitConfig [Atomic Audit]', () {
    test('ConcreteLimitConfig() - creates concrete limit config', () {
      expect(
        rcmgr.infiniteLimits.system.streams,
        equals(rcmgr.BaseLimit.unlimitedValue),
      );
      expect(
        rcmgr.infiniteLimits.system.memory,
        equals(rcmgr.BaseLimit.unlimitedValue),
      );
    });

    test(
      'toPartialLimitConfig() - converts concrete configuration to partial',
      () {
        final partial = rcmgr.infiniteLimits.toPartialLimitConfig();
        expect(partial.system.streams, equals(rcmgr.unlimited));
        expect(partial.system.memory, equals(rcmgr.unlimited64));
      },
    );
  });

  group('LimitDefaults [Atomic Audit]', () {
    test('defaultLimits - provides default scaling limit config', () {
      expect(rcmgr.defaultLimits.systemBaseLimit.connsInbound, equals(64));
      expect(rcmgr.defaultLimits.systemBaseLimit.fd, equals(256));
    });

    test('infiniteBaseLimit - provides unbounded base limits', () {
      expect(
        rcmgr.infiniteBaseLimit.streams,
        equals(rcmgr.BaseLimit.unlimitedValue),
      );
      expect(
        rcmgr.infiniteBaseLimit.conns,
        equals(rcmgr.BaseLimit.unlimitedValue),
      );
    });

    test('infiniteLimits - provides infinite concrete limits', () {
      expect(
        rcmgr.infiniteLimits.system.streams,
        equals(rcmgr.BaseLimit.unlimitedValue),
      );
      expect(
        rcmgr.infiniteLimits.conn.conns,
        equals(rcmgr.BaseLimit.unlimitedValue),
      );
    });
  });
}
