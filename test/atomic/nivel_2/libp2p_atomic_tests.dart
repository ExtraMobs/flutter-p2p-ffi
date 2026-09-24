import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/src/core/network/network.dart';
import 'package:transpiled_libp2p/src/core/peer/peer_id.dart';
import 'package:transpiled_libp2p/src/p2p/host/resource_manager/limit.dart';
import 'package:transpiled_libp2p/src/p2p/host/resource_manager/resource_manager.dart';
import 'package:transpiled_libp2p/src/p2p/net/interface_addrs.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

class _CountingInterfaceAddrsCache extends InterfaceAddrsCache {
  int updateCalls = 0;

  @override
  Future<List<Multiaddr>> update() async {
    updateCalls++;
    return super.update();
  }
}

// go-libp2p e20bb60ffc4b4ee33640e5fe8f45fccce893cecd:
// p2p/host/resource-manager/{rcmgr,scope}.go, libp2p-index counterpart.
void main() {
  final peer = PeerId(value: Uint8List.fromList([1, 2, 3]));
  group('ResourceManagerImpl [Atomic Audit]', () {
    late ResourceManagerImpl manager;
    setUp(() => manager = ResourceManagerImpl());
    tearDown(() => manager.close());

    test('systemScope - exposes accounting for reserved memory', () {
      manager.systemScope.reserveMemory(7, reservationPriorityAlways);
      expect(manager.systemScope.stat().memory, 7);
      manager.systemScope.releaseMemory(7);
      expect(manager.systemScope.stat().memory, 0);
    });
    test('transientScope - accounts unattached connection memory', () {
      final connection = manager.openConnection(
        Direction.inbound,
        false,
        Multiaddr.empty,
      );
      connection.reserveMemory(9, reservationPriorityAlways);
      expect(manager.transientScope.stat().memory, 9);
      connection.done();
      expect(manager.transientScope.stat().memory, 0);
    });
    test('viewSystem() - visits the canonical scope and propagates errors', () {
      manager.viewSystem((scope) => expect(scope, same(manager.systemScope)));
      expect(
        () => manager.viewSystem((_) => throw StateError('visitor')),
        throwsStateError,
      );
    });
    test('viewTransient() - visits the canonical transient scope', () {
      manager.viewTransient(
        (scope) => expect(scope, same(manager.transientScope)),
      );
    });
    test('viewPeer() - observes active streams and released accounting', () {
      final stream = manager.openStream(peer, Direction.outbound);
      manager.viewPeer(
        peer,
        (scope) => expect(scope.stat().numStreamsOutbound, 1),
      );
      stream.done();
      manager.viewPeer(
        peer,
        (scope) => expect(scope.stat().numStreamsOutbound, 0),
      );
    });
    test('viewProtocol() - observes protocol attachment and release', () {
      final stream = manager.openStream(peer, Direction.inbound)
        ..setProtocol('/test');
      manager.viewProtocol(
        '/test',
        (scope) => expect(scope.stat().numStreamsInbound, 1),
      );
      stream.done();
      manager.viewProtocol(
        '/test',
        (scope) => expect(scope.stat().numStreamsInbound, 0),
      );
    });
    test('viewService() - observes service attachment and release', () {
      final stream = manager.openStream(peer, Direction.inbound)
        ..setProtocol('/test')
        ..setService('test');
      manager.viewService(
        'test',
        (scope) => expect(scope.stat().numStreamsInbound, 1),
      );
      stream.done();
      manager.viewService(
        'test',
        (scope) => expect(scope.stat().numStreamsInbound, 0),
      );
    });
    test('openStream() - releases all accounting after repeated done', () {
      final stream = manager.openStream(peer, Direction.outbound);
      expect(manager.systemScope.stat().numStreamsOutbound, 1);
      stream.done();
      stream.done();
      expect(manager.systemScope.stat().numStreamsOutbound, 0);
    });
    test('openConnection() - accounts connections and file descriptors', () {
      final connection = manager.openConnection(
        Direction.inbound,
        true,
        Multiaddr.empty,
      );
      expect(manager.systemScope.stat().numConnsInbound, 1);
      expect(manager.systemScope.stat().numFd, 1);
      connection.setPeer(peer);
      manager.viewPeer(
        peer,
        (scope) => expect(scope.stat().numConnsInbound, 1),
      );
      connection.done();
      expect(manager.systemScope.stat().numConnsInbound, 0);
      expect(manager.systemScope.stat().numFd, 0);
    });
    test(
      'verifySourceAddress() - default without verification rate limiter',
      () {
        expect(manager.verifySourceAddress('/ip4/127.0.0.1/tcp/4001'), isFalse);
      },
    );
    test('close() - releases scopes and is idempotent', () {
      manager.systemScope.reserveMemory(5, reservationPriorityAlways);
      manager.close();
      manager.close();
      expect(manager.systemScope.stat().memory, 0);
      expect(
        () => manager.openStream(peer, Direction.outbound),
        throwsStateError,
      );
    });
    test('openStream() - rejects stream limit without retaining counters', () {
      final limited = ResourceManagerImpl(
        limiter: FixedLimiter(system: const BaseLimit(streams: 0)),
      );
      addTearDown(limited.close);
      expect(
        () => limited.openStream(peer, Direction.outbound),
        throwsA(isA<ResourceLimitExceededException>()),
      );
      expect(limited.systemScope.stat().numStreamsOutbound, 0);
    });
  });

  // go-multiaddr net.go:389-403 / resolve.go:74-88 e
  // go-libp2p p2p/host/basic/addrs_manager.go:794-835 (interfaceAddrsCache).
  group('interface_addrs.dart [Atomic Audit]', () {
    test(
      'interfaceMultiaddrs() - retorna ao menos o endereco de loopback da maquina',
      () async {
        final addrs = await interfaceMultiaddrs();
        expect(addrs, isNotEmpty);
        expect(addrs, everyElement(isA<Multiaddr>()));
        final hasLoopback = addrs.any(
          (a) => a.toString() == '/ip4/127.0.0.1' || a.toString() == '/ip6/::1',
        );
        expect(hasLoopback, isTrue);
      },
    );

    test(
      'interfaceAddresses() - remove enderecos IPv6 link-local (fe80::/10)',
      () async {
        final addrs = await interfaceAddresses();
        expect(addrs.any(isIp6LinkLocal), isFalse);
        // Deve continuar contendo o loopback, que não é link-local.
        final hasLoopback = addrs.any(
          (a) => a.toString() == '/ip4/127.0.0.1' || a.toString() == '/ip6/::1',
        );
        expect(hasLoopback, isTrue);
      },
    );

    test(
      'InterfaceAddrsCache.allSync() - devolve o par de loopback como fallback antes de qualquer atualizacao',
      () {
        final cache = InterfaceAddrsCache();
        expect(
          cache.allSync().map((a) => a.toString()).toList(),
          equals(['/ip4/127.0.0.1', '/ip6/::1']),
        );
      },
    );

    test(
      'InterfaceAddrsCache.update() - substitui o fallback pelos enderecos reais das interfaces',
      () async {
        final cache = InterfaceAddrsCache();
        final updated = await cache.update();
        expect(updated, isNotEmpty);
        expect(cache.allSync(), equals(updated));
      },
    );

    test(
      'InterfaceAddrsCache.all() - atualiza uma unica vez enquanto o TTL de 1 minuto nao expira',
      () async {
        final cache = _CountingInterfaceAddrsCache();
        final first = await cache.all();
        expect(first, isNotEmpty);
        expect(cache.updateCalls, equals(1));
        final second = await cache.all();
        expect(
          second.map((a) => a.toString()).toList(),
          equals(first.map((a) => a.toString()).toList()),
        );
        expect(cache.updateCalls, equals(1));
      },
    );
  });
}
