import 'package:test/test.dart';
import 'package:transpiled_libp2p/src/core/host/host.dart';
import 'package:transpiled_libp2p/src/core/network/network.dart';
import 'package:transpiled_libp2p/src/core/peer/addr_info.dart';
import 'package:transpiled_libp2p/src/core/peer/peer_id.dart';
import 'package:transpiled_libp2p/src/p2p/discovery/mdns/mdns.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

// go-libp2p p2p/discovery/mdns/mdns.go (pinned revision: see
// doc/transpilation/UPSTREAM_LOCK.md), mirroring mdns_test.go's
// TestIsSuitableForMDNS table and covering the record-assembly/parsing
// logic extracted from the private startServer/startResolver methods
// (buildMdnsTxtRecords/mdnsAddrInfosFromTxtRecords) plus the TTL/service
// name constants. Everything exercised here is pure/in-memory -- no real
// multicast socket -- the private wire codec and the full announce/browse
// round trip over a real socket are covered by
// test/atomic/nivel_3/libp2p_mdns_atomic_tests.dart instead.
void main() {
  final selfId = PeerId.decode('12D3KooWCryG7Mon9orvQxcS1rYZjotPgpwoJNHHKcLLfE4Hf5mV');
  final otherId = PeerId.decode('12D3KooWStiM2F2p4k2c6c3H3c2wM7d8Xv5R7n3w4k7K2c6c3H3c');

  group('mdnsServiceName [Atomic Audit]', () {
    test('mdnsServiceName - matches go-libp2p ServiceName (mdns.go:21)', () {
      expect(mdnsServiceName, '_p2p._udp');
    });
  });

  group('mdnsRecordTtl [Atomic Audit]', () {
    test('mdnsRecordTtl - matches zeroconf defaultTTL of 3200 seconds', () {
      expect(mdnsRecordTtl, const Duration(seconds: 3200));
    });
  });

  group('mdnsAddressRecordTtl [Atomic Audit]', () {
    test('mdnsAddressRecordTtl - matches zeroconf appendAddrs override of 120 seconds', () {
      expect(mdnsAddressRecordTtl, const Duration(seconds: 120));
    });
    test('mdnsAddressRecordTtl - shorter than mdnsRecordTtl per RFC 6762 §10', () {
      expect(mdnsAddressRecordTtl < mdnsRecordTtl, isTrue);
    });
  });

  group('isSuitableForMdns() [Atomic Audit]', () {
    test('isSuitableForMdns() - returns false for a null multiaddr', () {
      expect(isSuitableForMdns(null), isFalse);
    });

    for (final case_ in const [
      // IP addresses with native transports - suitable for mDNS.
      ('/ip4/192.168.1.1/tcp/4001', true),
      ('/ip4/192.168.1.2/udp/4001/quic-v1', true),
      ('/ip6/fe80::1/tcp/4001', true),
      ('/ip6/fe80::2/udp/4001/quic-v1', true),
      // Browser transports - NOT suitable for mDNS.
      ('/ip4/192.168.1.1/udp/4001/quic-v1/webtransport', false),
      ('/ip4/192.168.1.1/udp/4001/webrtc-direct', false),
      ('/ip4/192.168.1.1/tcp/4001/ws', false),
      ('/ip4/192.168.1.1/tcp/443/wss', false),
      // .local DNS names - suitable for mDNS (RFC 6762).
      ('/dns/myhost.local/tcp/4001', true),
      ('/dns4/myhost.local/tcp/4001', true),
      ('/dns6/myhost.local/tcp/4001', true),
      ('/dnsaddr/myhost.local/tcp/4001', true),
      ('/dns4/MyHost.LOCAL/tcp/4001', true),
      // Non-.local DNS names - NOT suitable for mDNS.
      ('/dns4/example.com/tcp/4001', false),
      ('/dns6/example.com/tcp/4001', false),
      ('/dnsaddr/example.com/tcp/4001', false),
      ('/dns4/notlocal.com/tcp/4001', false),
      ('/dns4/local.example.com/tcp/4001', false),
      // Circuit relay - NOT suitable for mDNS.
      (
        '/ip4/198.51.100.1/tcp/4001/p2p/12D3KooWDpJ7As7BWAwRMfu1VU2WCqNjvq387JEYKDBj4kx6nXTN'
            '/p2p-circuit/p2p/12D3KooWGzBXWNvHpLALvz3jhwdCF6kfv9MfhMn9CuS2MBD2GpSy',
        false,
      ),
    ]) {
      final (addrString, expected) = case_;
      test('isSuitableForMdns() - $addrString -> $expected', () {
        expect(isSuitableForMdns(Multiaddr.parse(addrString)), expected);
      });
    }
  });

  group('buildMdnsTxtRecords() [Atomic Audit]', () {
    test('buildMdnsTxtRecords() - encodes suitable addrs as dnsaddr= entries with the peer id', () {
      final txts = buildMdnsTxtRecords(selfId, [Multiaddr.parse('/ip4/192.168.1.5/tcp/4001')]);
      expect(txts, hasLength(1));
      expect(txts.single, startsWith('dnsaddr='));
      expect(txts.single, contains('/ip4/192.168.1.5/tcp/4001/p2p/${selfId.toBase58()}'));
    });

    test('buildMdnsTxtRecords() - drops addrs unsuitable for mDNS (e.g. /ws)', () {
      final txts = buildMdnsTxtRecords(selfId, [Multiaddr.parse('/ip4/192.168.1.5/tcp/4001/ws')]);
      expect(txts, isEmpty);
    });

    test('buildMdnsTxtRecords() - empty interface address list yields no TXT entries', () {
      expect(buildMdnsTxtRecords(selfId, const []), isEmpty);
    });
  });

  group('mdnsAddrInfosFromTxtRecords() [Atomic Audit]', () {
    test('mdnsAddrInfosFromTxtRecords() - recovers the AddrInfo a matching buildMdnsTxtRecords() produced', () {
      final interfaceAddrs = [Multiaddr.parse('/ip4/192.168.1.5/tcp/4001')];
      final txts = buildMdnsTxtRecords(otherId, interfaceAddrs);
      final infos = mdnsAddrInfosFromTxtRecords(txts);
      expect(infos, hasLength(1));
      expect(infos.single.id, otherId);
      expect(infos.single.addrs, [Multiaddr.parse('/ip4/192.168.1.5/tcp/4001')]);
    });

    test('mdnsAddrInfosFromTxtRecords() - skips entries without the dnsaddr= prefix', () {
      expect(mdnsAddrInfosFromTxtRecords(['not-a-dnsaddr-entry']), isEmpty);
    });

    test('mdnsAddrInfosFromTxtRecords() - skips a malformed multiaddr after the prefix', () {
      expect(mdnsAddrInfosFromTxtRecords(['dnsaddr=not a multiaddr']), isEmpty);
    });

    test('mdnsAddrInfosFromTxtRecords() - discards the whole batch when an entry has no /p2p/ suffix', () {
      final txts = ['dnsaddr=/ip4/192.168.1.5/tcp/4001']; // no trailing /p2p/<id>
      expect(mdnsAddrInfosFromTxtRecords(txts), isEmpty);
    });

    test('mdnsAddrInfosFromTxtRecords() - empty input yields no AddrInfos', () {
      expect(mdnsAddrInfosFromTxtRecords(const []), isEmpty);
    });
  });

  group('Notifee [Atomic Audit]', () {
    test('handlePeerFound() - implementer receives the discovered AddrInfo', () {
      AddrInfo? received;
      final notifee = _RecordingNotifee((info) => received = info);
      final info = AddrInfo(id: otherId, addrs: [Multiaddr.parse('/ip4/10.0.0.1/tcp/4001')]);
      notifee.handlePeerFound(info);
      expect(received, info);
    });
  });

  group('MdnsService [Atomic Audit]', () {
    test('start() - propagates the StateError _hostIps() raises when the host has no interface addresses', () async {
      // Matches go-libp2p's `Start()` returning `startServer()`'s error
      // (`mdns.go:66-72`) before ever reaching `startResolver`/opening a
      // socket -- exercised here with the default (empty-string) service
      // name constructor argument (`mdns.go:53-55`).
      final host = _FakeHost(selfId, const []);
      final service = MdnsService(host, notifee: _RecordingNotifee((_) {}));
      await expectLater(service.start(), throwsA(isA<StateError>()));
    });

    test('close() - is safe to call before start() and idempotent', () async {
      final host = _FakeHost(selfId, const []);
      final service = MdnsService(host, notifee: _RecordingNotifee((_) {}));
      await expectLater(service.close(), completes);
      // Calling close() again must not throw (idempotent close, matching
      // this project's established Fd.close precedent).
      await expectLater(service.close(), completes);
    });
  });

  group('Service [Atomic Audit]', () {
    test('start() - propagates errors from the implementation through the interface', () async {
      final Service service = MdnsService(_FakeHost(selfId, const []), notifee: _RecordingNotifee((_) {}));
      await expectLater(service.start(), throwsA(isA<StateError>()));
    });

    test('close() - completes without error through the interface', () async {
      final Service service = MdnsService(_FakeHost(selfId, const []), notifee: _RecordingNotifee((_) {}));
      await expectLater(service.close(), completes);
    });
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
