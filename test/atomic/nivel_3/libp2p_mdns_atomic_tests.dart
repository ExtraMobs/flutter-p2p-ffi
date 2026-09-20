// test/atomic/nivel_3/libp2p_mdns_atomic_tests.dart
//
// Real-socket integration coverage for MdnsService
// (packages/transpiled_libp2p/lib/src/p2p/discovery/mdns/mdns.dart): two
// services, each on its own fake Host, actually announce over and browse
// a real IPv4 multicast UDP socket (224.0.0.251:5353) and must discover
// each other. This is the only place the private mDNS responder wire
// codec (record encode, incoming-query parse) is exercised -- it can't be
// unit-tested directly from outside mdns.dart because it's intentionally
// private (see that file's header comment) -- so this test is the proof
// that encode/decode/respond/browse compose into working discovery.
// Tagged 'network' and skipped by default (see dart_test.yaml); run with
// `dart test --preset network`.
@Tags(['network'])
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/src/core/host/host.dart';
import 'package:transpiled_libp2p/src/core/network/network.dart';
import 'package:transpiled_libp2p/src/core/peer/addr_info.dart';
import 'package:transpiled_libp2p/src/core/peer/peer_id.dart';
import 'package:transpiled_libp2p/src/p2p/discovery/mdns/mdns.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  group('MdnsService [Atomic Audit]', () {
    test('start() - two local hosts discover each other over a real multicast socket', () async {
      final idA = PeerId.decode('12D3KooWCryG7Mon9orvQxcS1rYZjotPgpwoJNHHKcLLfE4Hf5mV');
      final idB = PeerId.decode('12D3KooWStiM2F2p4k2c6c3H3c2wM7d8Xv5R7n3w4k7K2c6c3H3c');
      final hostA = _FakeHost(idA, [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')]);
      final hostB = _FakeHost(idB, [Multiaddr.parse('/ip4/127.0.0.1/tcp/4002')]);

      // A dedicated service name isolates this test from any real
      // _p2p._udp traffic already on the test machine (a running Kubo
      // node, etc.) in both directions.
      const testServiceName = '_p2p-mdns-atomic-test._udp';

      final foundByA = Completer<AddrInfo>();
      final foundByB = Completer<AddrInfo>();

      final serviceA = MdnsService(
        hostA,
        serviceName: testServiceName,
        notifee: _RecordingNotifee((info) {
          if (!foundByA.isCompleted) foundByA.complete(info);
        }),
      );
      final serviceB = MdnsService(
        hostB,
        serviceName: testServiceName,
        notifee: _RecordingNotifee((info) {
          if (!foundByB.isCompleted) foundByB.complete(info);
        }),
      );

      await serviceA.start();
      await serviceB.start();
      addTearDown(() async {
        await serviceA.close();
        await serviceB.close();
      });

      final infoOfAFoundByB = await foundByB.future.timeout(const Duration(seconds: 30));
      final infoOfBFoundByA = await foundByA.future.timeout(const Duration(seconds: 30));

      expect(infoOfAFoundByB.id, idA);
      expect(infoOfAFoundByB.addrs, contains(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')));
      expect(infoOfBFoundByA.id, idB);
      expect(infoOfBFoundByA.addrs, contains(Multiaddr.parse('/ip4/127.0.0.1/tcp/4002')));
    }, timeout: const Timeout(Duration(seconds: 45)));
  });
}

class _RecordingNotifee implements Notifee {
  _RecordingNotifee(this._onFound);
  final void Function(AddrInfo info) _onFound;

  @override
  void handlePeerFound(AddrInfo info) => _onFound(info);
}

class _FakeNetwork implements Network {
  _FakeNetwork(this._addrs);
  final List<Multiaddr> _addrs;

  @override
  Future<List<Multiaddr>> interfaceListenAddresses() async => _addrs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHost implements Host {
  _FakeHost(this.id, List<Multiaddr> interfaceAddrs) : network = _FakeNetwork(interfaceAddrs);

  @override
  final PeerId id;

  @override
  final Network network;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
