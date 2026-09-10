// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Parity vectors taken from go-libp2p core/peer's own addrinfo_test.go
// (go-ipfs-reference/go-libp2p/core/peer/addrinfo_test.go).
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:test/test.dart';

void main() {
  final testId = PeerId.decode('QmS3zcG7LhYZYSJMhyRZvTddvbNUqtt8BJpaSs6mi1K5Va');
  final maddrTpt = Multiaddr.parse('/ip4/127.0.0.1/tcp/1234');
  final maddrPeer = Multiaddr.parse('/p2p/${testId.toBase58()}');
  final maddrFull = maddrTpt.encapsulate(maddrPeer);

  group('splitAddr', () {
    test('splits a transport + /p2p/... address into both halves', () {
      final (tpt, id) = splitAddr(maddrFull);
      expect(tpt, equals(maddrTpt));
      expect(id, equals(testId));
    });

    test('a bare /p2p/... address has a null transport', () {
      final (tpt, id) = splitAddr(maddrPeer);
      expect(tpt, isNull);
      expect(id, equals(testId));
    });

    test('a transport-only address has a null peer ID', () {
      final (tpt, id) = splitAddr(maddrTpt);
      expect(tpt, equals(maddrTpt));
      expect(id, isNull);
    });

    test('a null multiaddr splits to (null, null)', () {
      final (tpt, id) = splitAddr(null);
      expect(tpt, isNull);
      expect(id, isNull);
    });
  });

  group('idFromP2pAddr', () {
    test('extracts the peer ID from a transport + /p2p/... address', () {
      expect(idFromP2pAddr(maddrFull), equals(testId));
    });

    test('extracts the peer ID from a bare /p2p/... address', () {
      expect(idFromP2pAddr(maddrPeer), equals(testId));
    });

    test('throws for a transport-only address', () {
      expect(
        () => idFromP2pAddr(maddrTpt),
        throwsA(isA<InvalidPeerIdSourceException>()),
      );
    });
  });

  group('addrInfoFromP2pAddr', () {
    test('splits a transport + /p2p/... address into id + one addr', () {
      final ai = addrInfoFromP2pAddr(maddrFull);
      expect(ai.id, equals(testId));
      expect(ai.addrs, equals([maddrTpt]));
    });

    test('a bare /p2p/... address has no addrs', () {
      final ai = addrInfoFromP2pAddr(maddrPeer);
      expect(ai.id, equals(testId));
      expect(ai.addrs, isEmpty);
    });

    test('throws for a transport-only address', () {
      expect(
        () => addrInfoFromP2pAddr(maddrTpt),
        throwsA(isA<InvalidPeerIdSourceException>()),
      );
    });
  });

  group('addrInfosFromP2pAddrs', () {
    test('the empty list produces no infos', () {
      expect(addrInfosFromP2pAddrs([]), isEmpty);
    });

    test('groups addresses by peer ID, preserving first-seen order', () {
      const peerA = 'QmSoLV4Bbm51jM9C4gDYZQ9Cy3U6aXMJDAbzgu2fzaDs64';
      const peerB = 'QmSoLer265NRgSp2LA3dPaeykiS1J6DifTC88f5uVQKNAd';
      const peerC = 'QmSoLPppuBtQSGwKDZT2M73ULpjvfd3aZ6ha4oFGL1KrGM';
      final addrs = [
        Multiaddr.parse('/ip4/128.199.219.111/tcp/4001/ipfs/$peerA'),
        Multiaddr.parse('/ip4/104.236.76.40/tcp/4001/ipfs/$peerA'),
        Multiaddr.parse('/ipfs/$peerB'),
        Multiaddr.parse('/ip4/178.62.158.247/tcp/4001/ipfs/$peerB'),
        Multiaddr.parse('/ipfs/$peerC'),
      ];
      final expected = <String, List<Multiaddr>>{
        peerA: [
          Multiaddr.parse('/ip4/128.199.219.111/tcp/4001'),
          Multiaddr.parse('/ip4/104.236.76.40/tcp/4001'),
        ],
        peerB: [Multiaddr.parse('/ip4/178.62.158.247/tcp/4001')],
        peerC: [],
      };

      final infos = addrInfosFromP2pAddrs(addrs);
      expect(infos, hasLength(3));
      for (final info in infos) {
        final exaddrs = expected.remove(info.id.toBase58());
        expect(exaddrs, isNotNull, reason: 'unexpected peer ${info.id}');
        expect(info.addrs, equals(exaddrs));
      }
      expect(expected, isEmpty);
    });
  });

  group('addrInfoToP2pAddrs', () {
    test('one address per addr, each with /p2p/... appended', () {
      final ai = AddrInfo(id: testId, addrs: [maddrTpt]);
      expect(addrInfoToP2pAddrs(ai), equals([maddrFull]));
    });

    test('a bare /p2p/... address for a peer with no addrs', () {
      final ai = AddrInfo(id: testId);
      expect(addrInfoToP2pAddrs(ai), equals([maddrPeer]));
    });
  });

  group('addrInfosToIds', () {
    test('extracts peer IDs in order', () {
      final a = AddrInfo(id: testId);
      final b = AddrInfo(id: PeerId(value: testId.value));
      expect(addrInfosToIds([a, b]), equals([testId, testId]));
    });
  });

  group('AddrInfo JSON round-trip', () {
    test('toJson / fromJson round-trips id and addrs', () {
      final ai = AddrInfo(id: testId, addrs: [maddrFull]);
      final decoded = AddrInfo.fromJson(ai.toJson());
      expect(decoded.id, equals(testId));
      expect(decoded.addrs, equals([maddrFull]));
    });

    test('toJsonString / fromJsonString round-trips', () {
      final ai = AddrInfo(id: testId, addrs: [maddrTpt]);
      final decoded = AddrInfo.fromJsonString(ai.toJsonString());
      expect(decoded, equals(ai));
    });
  });
}
