import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/src/core/network/network.dart';
import 'package:transpiled_libp2p/src/core/peer/peer_id.dart';
import 'package:transpiled_libp2p/src/p2p/host/resource_manager/limit.dart';
import 'package:transpiled_libp2p/src/p2p/host/resource_manager/resource_manager.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

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
      final connection = manager.openConnection(Direction.inbound, false, Multiaddr.empty);
      connection.reserveMemory(9, reservationPriorityAlways);
      expect(manager.transientScope.stat().memory, 9);
      connection.done();
      expect(manager.transientScope.stat().memory, 0);
    });
    test('viewSystem() - visits the canonical scope and propagates errors', () {
      manager.viewSystem((scope) => expect(scope, same(manager.systemScope)));
      expect(() => manager.viewSystem((_) => throw StateError('visitor')), throwsStateError);
    });
    test('viewTransient() - visits the canonical transient scope', () {
      manager.viewTransient((scope) => expect(scope, same(manager.transientScope)));
    });
    test('viewPeer() - observes active streams and released accounting', () {
      final stream = manager.openStream(peer, Direction.outbound);
      manager.viewPeer(peer, (scope) => expect(scope.stat().numStreamsOutbound, 1));
      stream.done();
      manager.viewPeer(peer, (scope) => expect(scope.stat().numStreamsOutbound, 0));
    });
    test('viewProtocol() - observes protocol attachment and release', () {
      final stream = manager.openStream(peer, Direction.inbound)..setProtocol('/test');
      manager.viewProtocol('/test', (scope) => expect(scope.stat().numStreamsInbound, 1));
      stream.done();
      manager.viewProtocol('/test', (scope) => expect(scope.stat().numStreamsInbound, 0));
    });
    test('viewService() - observes service attachment and release', () {
      final stream = manager.openStream(peer, Direction.inbound)
        ..setProtocol('/test')..setService('test');
      manager.viewService('test', (scope) => expect(scope.stat().numStreamsInbound, 1));
      stream.done();
      manager.viewService('test', (scope) => expect(scope.stat().numStreamsInbound, 0));
    });
    test('openStream() - releases all accounting after repeated done', () {
      final stream = manager.openStream(peer, Direction.outbound);
      expect(manager.systemScope.stat().numStreamsOutbound, 1);
      stream.done();
      stream.done();
      expect(manager.systemScope.stat().numStreamsOutbound, 0);
    });
    test('openConnection() - accounts connections and file descriptors', () {
      final connection = manager.openConnection(Direction.inbound, true, Multiaddr.empty);
      expect(manager.systemScope.stat().numConnsInbound, 1);
      expect(manager.systemScope.stat().numFd, 1);
      connection.setPeer(peer);
      manager.viewPeer(peer, (scope) => expect(scope.stat().numConnsInbound, 1));
      connection.done();
      expect(manager.systemScope.stat().numConnsInbound, 0);
      expect(manager.systemScope.stat().numFd, 0);
    });
    test('verifySourceAddress() - default without verification rate limiter', () {
      expect(manager.verifySourceAddress('/ip4/127.0.0.1/tcp/4001'), isFalse);
    });
    test('close() - releases scopes and is idempotent', () {
      manager.systemScope.reserveMemory(5, reservationPriorityAlways);
      manager.close();
      manager.close();
      expect(manager.systemScope.stat().memory, 0);
      expect(() => manager.openStream(peer, Direction.outbound), throwsStateError);
    });
    test('openStream() - rejects stream limit without retaining counters', () {
      final limited = ResourceManagerImpl(limiter: FixedLimiter(
        system: const BaseLimit(streams: 0),
      ));
      addTearDown(limited.close);
      expect(() => limited.openStream(peer, Direction.outbound),
          throwsA(isA<ResourceLimitExceededException>()));
      expect(limited.systemScope.stat().numStreamsOutbound, 0);
    });
  });
}
