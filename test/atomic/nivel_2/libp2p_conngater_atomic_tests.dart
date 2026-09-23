// test/atomic/nivel_2/libp2p_conngater_atomic_tests.dart
// Testes atomicos 1 para 1 para go-libp2p/p2p/net/conngater (conngater.go).

import 'dart:typed_data';

import 'package:boilerplate/net/golang.dart';
import 'package:test/test.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:transpiled_libp2p/src/core/network/network.dart';
import 'package:transpiled_libp2p/src/core/peer/peer_id.dart';
import 'package:transpiled_libp2p/src/p2p/net/conngater/conngater.dart';

final class _MockConnMultiaddrs implements ConnMultiaddrs {
  _MockConnMultiaddrs({required this.local, required this.remote});

  final Multiaddr local;
  final Multiaddr remote;

  @override
  Multiaddr localMultiaddr() => local;

  @override
  Multiaddr remoteMultiaddr() => remote;
}

void main() {
  group('BasicConnectionGater [Atomic Audit]', () {
    test(
      'BasicConnectionGater() - initializes without datastore and default allows all',
      () {
        final gater = BasicConnectionGater();
        final peer = PeerId.decode(
          '12D3KooWDsMmX7axDC6HTTXUNe4upxEvFbNQjmE2FToVVbBzUK6f',
        );
        expect(gater.interceptPeerDial(peer), isTrue);
        expect(gater.listBlockedPeers(), isEmpty);
        expect(gater.listBlockedAddrs(), isEmpty);
        expect(gater.listBlockedSubnets(), isEmpty);
      },
    );

    test('loadRules() - loads persisted rules from datastore', () async {
      final ds = MapDatastore();
      final gater1 = BasicConnectionGater(ds);
      final ip = Ip.tryParse('192.168.1.100')!;
      await gater1.blockAddr(ip);

      final gater2 = BasicConnectionGater(ds);
      await gater2.loadRules();
      expect(gater2.listBlockedAddrs().any((a) => a.equal(ip)), isTrue);
    });

    test('blockPeer() - blocks peer from dialing', () async {
      final gater = BasicConnectionGater();
      final peer = PeerId.decode(
        '12D3KooWDsMmX7axDC6HTTXUNe4upxEvFbNQjmE2FToVVbBzUK6f',
      );
      await gater.blockPeer(peer);

      expect(gater.interceptPeerDial(peer), isFalse);
      expect(gater.listBlockedPeers(), contains(peer));
    });

    test('unblockPeer() - unblocks previously blocked peer', () async {
      final gater = BasicConnectionGater();
      final peer = PeerId.decode(
        '12D3KooWDsMmX7axDC6HTTXUNe4upxEvFbNQjmE2FToVVbBzUK6f',
      );
      await gater.blockPeer(peer);
      expect(gater.interceptPeerDial(peer), isFalse);

      await gater.unblockPeer(peer);
      expect(gater.interceptPeerDial(peer), isTrue);
      expect(gater.listBlockedPeers(), isEmpty);
    });

    test('listBlockedPeers() - returns list of blocked peers', () async {
      final gater = BasicConnectionGater();
      final p1 = PeerId.decode(
        '12D3KooWDsMmX7axDC6HTTXUNe4upxEvFbNQjmE2FToVVbBzUK6f',
      );
      final p2 = PeerId(value: Uint8List.fromList([1, 2, 3]));
      await gater.blockPeer(p1);
      await gater.blockPeer(p2);

      final list = gater.listBlockedPeers();
      expect(list.length, equals(2));
    });

    test('blockAddr() - blocks incoming connection by IP address', () async {
      final gater = BasicConnectionGater();
      final ip = Ip.tryParse('10.0.0.42')!;
      await gater.blockAddr(ip);

      final cma = _MockConnMultiaddrs(
        local: Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'),
        remote: Multiaddr.parse('/ip4/10.0.0.42/tcp/54321'),
      );
      expect(gater.interceptAccept(cma), isFalse);
    });

    test('unblockAddr() - removes IP address block', () async {
      final gater = BasicConnectionGater();
      final ip = Ip.tryParse('10.0.0.42')!;
      await gater.blockAddr(ip);
      final cma = _MockConnMultiaddrs(
        local: Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'),
        remote: Multiaddr.parse('/ip4/10.0.0.42/tcp/54321'),
      );
      expect(gater.interceptAccept(cma), isFalse);

      await gater.unblockAddr(ip);
      expect(gater.interceptAccept(cma), isTrue);
    });

    test('listBlockedAddrs() - returns list of blocked IP addresses', () async {
      final gater = BasicConnectionGater();
      final ip = Ip.tryParse('1.2.3.4')!;
      await gater.blockAddr(ip);
      expect(gater.listBlockedAddrs().any((a) => a.equal(ip)), isTrue);
    });

    test('blockSubnet() - blocks connections within subnet', () async {
      final gater = BasicConnectionGater();
      final subnet = IpNet.tryParseCidr('192.168.0.0/16')!;
      await gater.blockSubnet(subnet);

      final cma = _MockConnMultiaddrs(
        local: Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'),
        remote: Multiaddr.parse('/ip4/192.168.5.10/tcp/54321'),
      );
      expect(gater.interceptAccept(cma), isFalse);

      final cmaAllowed = _MockConnMultiaddrs(
        local: Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'),
        remote: Multiaddr.parse('/ip4/10.1.2.3/tcp/54321'),
      );
      expect(gater.interceptAccept(cmaAllowed), isTrue);
    });

    test('unblockSubnet() - unblocks previously blocked subnet', () async {
      final gater = BasicConnectionGater();
      final subnet = IpNet.tryParseCidr('192.168.0.0/16')!;
      await gater.blockSubnet(subnet);
      final cma = _MockConnMultiaddrs(
        local: Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'),
        remote: Multiaddr.parse('/ip4/192.168.5.10/tcp/54321'),
      );
      expect(gater.interceptAccept(cma), isFalse);

      await gater.unblockSubnet(subnet);
      expect(gater.interceptAccept(cma), isTrue);
    });

    test('listBlockedSubnets() - returns list of blocked subnets', () async {
      final gater = BasicConnectionGater();
      final subnet = IpNet.tryParseCidr('10.0.0.0/8')!;
      await gater.blockSubnet(subnet);
      expect(gater.listBlockedSubnets(), contains(subnet));
    });

    test('interceptPeerDial() - blocks only designated peers', () async {
      final gater = BasicConnectionGater();
      final p1 = PeerId.decode(
        '12D3KooWDsMmX7axDC6HTTXUNe4upxEvFbNQjmE2FToVVbBzUK6f',
      );
      final p2 = PeerId(value: Uint8List.fromList([4, 5, 6]));
      await gater.blockPeer(p1);

      expect(gater.interceptPeerDial(p1), isFalse);
      expect(gater.interceptPeerDial(p2), isTrue);
    });

    test(
      'interceptAddrDial() - checks blocked IP or subnet on dialing address',
      () async {
        final gater = BasicConnectionGater();
        final peer = PeerId.decode(
          '12D3KooWDsMmX7axDC6HTTXUNe4upxEvFbNQjmE2FToVVbBzUK6f',
        );
        final ip = Ip.tryParse('172.16.0.5')!;
        await gater.blockAddr(ip);

        expect(
          gater.interceptAddrDial(
            peer,
            Multiaddr.parse('/ip4/172.16.0.5/tcp/4001'),
          ),
          isFalse,
        );
        expect(
          gater.interceptAddrDial(
            peer,
            Multiaddr.parse('/ip4/172.16.0.6/tcp/4001'),
          ),
          isTrue,
        );
      },
    );

    test(
      'interceptAccept() - rejects blocked IP or subnet and accepts non-blocked',
      () async {
        final gater = BasicConnectionGater();
        final ip = Ip.tryParse('198.51.100.1')!;
        await gater.blockAddr(ip);

        final blocked = _MockConnMultiaddrs(
          local: Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'),
          remote: Multiaddr.parse('/ip4/198.51.100.1/tcp/12345'),
        );
        final allowed = _MockConnMultiaddrs(
          local: Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'),
          remote: Multiaddr.parse('/ip4/198.51.100.2/tcp/12345'),
        );

        expect(gater.interceptAccept(blocked), isFalse);
        expect(gater.interceptAccept(allowed), isTrue);
      },
    );

    test(
      'interceptSecured() - rejects blocked inbound peer and allows outbound',
      () async {
        final gater = BasicConnectionGater();
        final peer = PeerId.decode(
          '12D3KooWDsMmX7axDC6HTTXUNe4upxEvFbNQjmE2FToVVbBzUK6f',
        );
        await gater.blockPeer(peer);

        final cma = _MockConnMultiaddrs(
          local: Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'),
          remote: Multiaddr.parse('/ip4/1.2.3.4/tcp/12345'),
        );

        // Outbound is always allowed in interceptSecured (filtered at dial time)
        expect(gater.interceptSecured(Direction.outbound, peer, cma), isTrue);
        // Inbound with blocked peer is rejected
        expect(gater.interceptSecured(Direction.inbound, peer, cma), isFalse);
      },
    );

    test('interceptUpgraded() - returns allow true and zero reason', () {
      final gater = BasicConnectionGater();
      // Dummy conn for test
      final result = gater.interceptUpgraded(_DummyConn());
      expect(result.allow, isTrue);
      expect(result.reason, equals(0));
    });
  });
}

class _DummyConn implements Conn {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
