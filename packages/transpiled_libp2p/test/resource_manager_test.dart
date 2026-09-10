// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/src/core/network/network.dart';
import 'package:transpiled_libp2p/src/core/peer/peer_id.dart';
import 'package:transpiled_libp2p/src/p2p/host/resource_manager/limit.dart';
import 'package:transpiled_libp2p/src/p2p/host/resource_manager/resource_manager.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  final peer = PeerId(value: Uint8List.fromList([1, 2, 3]));

  test('stream accounting survives repeated open and done', () {
    final manager = ResourceManagerImpl();
    for (var i = 0; i < 1100; i++) {
      final stream = manager.openStream(peer, Direction.outbound);
      stream.setProtocol('/test/1.0.0');
      stream.done();
    }
    manager.viewSystem((scope) {
      expect(scope.stat().numStreamsOutbound, 0);
    });
    manager.viewPeer(peer, (scope) {
      expect(scope.stat().numStreamsOutbound, 0);
    });
    manager.close();
  });

  test('protocol and service changes roll back when a new edge is full', () {
    final manager = ResourceManagerImpl(
      limiter: FixedLimiter(
        protocols: {'/blocked/1.0.0': const BaseLimit(streams: 0)},
      ),
    );
    final stream = manager.openStream(peer, Direction.outbound);
    expect(
      () => stream.setProtocol('/blocked/1.0.0'),
      throwsA(isA<ResourceLimitExceededException>()),
    );
    expect(stream.protocolScope(), isNull);
    stream.done();
    manager.viewSystem((scope) => expect(scope.stat().numStreamsOutbound, 0));
    manager.close();
  });

  test('concurrent transactions leave all edges balanced', () async {
    final manager = ResourceManagerImpl();
    await Future.wait(
      List.generate(256, (_) async {
        final stream = manager.openStream(peer, Direction.outbound);
        stream.setProtocol('/test/1.0.0');
        stream.setService('test-service');
        stream.done();
      }),
    );
    manager.viewSystem((scope) => expect(scope.stat().numStreamsOutbound, 0));
    manager.close();
  });

  test('closed scopes reject new reservations and done is idempotent', () {
    final manager = ResourceManagerImpl();
    final stream = manager.openStream(peer, Direction.inbound);
    stream.done();
    stream.done();
    expect(
      () => stream.reserveMemory(1, reservationPriorityMedium),
      throwsA(same(errResourceScopeClosed)),
    );
    manager.close();
  });

  test('span resources are charged to and released from the owner', () {
    final manager = ResourceManagerImpl();
    final span = manager.systemScope.beginSpan();
    span.reserveMemory(7, reservationPriorityAlways);
    manager.viewSystem((scope) => expect(scope.stat().memory, 7));
    span.done();
    manager.viewSystem((scope) => expect(scope.stat().memory, 0));
    manager.close();
  });

  test('connection resources are accounted and moved to peer', () {
    final manager = ResourceManagerImpl();
    final connection = manager.openConnection(
      Direction.outbound,
      true,
      Multiaddr.empty,
    );
    connection.setPeer(peer);
    connection.done();
    manager.viewSystem((scope) => expect(scope.stat().numStreamsOutbound, 0));
    manager.close();
  });
}
