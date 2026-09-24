// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// test/atomic/nivel_2/libp2p_autonat_atomic_tests.dart
// Testes atomicos 1 para 1 para go-libp2p/p2p/host/autonat.

import 'dart:typed_data';

import 'package:boilerplate/net/golang.dart';
import 'package:test/test.dart';
import 'package:transpiled_libp2p/src/core/crypto/ed25519_key.dart';
import 'package:transpiled_libp2p/src/core/crypto/key_types.dart';
import 'package:transpiled_libp2p/src/core/event/reachability.dart';
import 'package:transpiled_libp2p/src/core/network/network.dart';
import 'package:transpiled_libp2p/src/core/peer/addr_info.dart';
import 'package:transpiled_libp2p/src/core/peer/peer_id.dart';
import 'package:transpiled_libp2p/src/p2p/host/autonat/autonat.dart';
import 'package:transpiled_libp2p/src/p2p/host/blank/blank_host.dart';
import 'package:transpiled_libp2p/src/core/crypto/proto_varint.dart';
import 'package:transpiled_libp2p/src/core/protocol/protocol.dart';
import 'package:transpiled_libp2p/src/p2p/host/peerstore/pstoremem/peerstore.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

class _FakeConn implements Conn {
  _FakeConn({required this.local, required this.remote, Multiaddr? remoteMa})
    : _remoteMa = remoteMa ?? Multiaddr.parse('/ip4/127.0.0.1/tcp/4002');

  final PeerId local;
  final PeerId remote;
  final Multiaddr _remoteMa;

  @override
  PeerId localPeer() => local;

  @override
  PeerId remotePeer() => remote;

  @override
  PubKey remotePublicKey() => unmarshalEd25519PublicKey(Uint8List(32));

  @override
  ConnectionState connState() => const ConnectionState();

  @override
  Multiaddr localMultiaddr() => Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');

  @override
  Multiaddr remoteMultiaddr() => _remoteMa;

  @override
  ConnScope scope() => const NullScope();

  @override
  ConnStats stat() =>
      ConnStats(direction: Direction.inbound, opened: DateTime.now());

  @override
  String id() => 'fake-conn';

  @override
  Future<NetworkStream> newStream() async =>
      throw UnsupportedError('not supported');

  @override
  List<NetworkStream> getStreams() => const [];

  @override
  bool get isClosed => false;

  @override
  Future<void> close() async {}

  @override
  Future<void> closeWithError(ConnErrorCode errorCode) async {}
}

class _FakeStream implements NetworkStream {
  _FakeStream({required this.response});

  final Uint8List response;
  int _offset = 0;
  final List<Uint8List> written = [];

  @override
  String get id => 's1';

  @override
  PeerId get local => PeerId(value: Uint8List.fromList([1]));

  @override
  PeerId get remote => PeerId(value: Uint8List.fromList([2]));

  @override
  ProtocolId protocol() => autoNatProto;

  @override
  Future<void> setProtocol(ProtocolId id) async {}

  @override
  Stats stat() => Stats(direction: Direction.outbound, opened: DateTime.now());

  @override
  Conn conn() => _FakeConn(local: local, remote: remote);

  @override
  StreamScope scope() => const NullScope();

  @override
  Future<void> resetWithError(StreamErrorCode errorCode) async {}

  @override
  bool get isClosed => false;

  @override
  Future<Uint8List> read([int? maxLength]) async {
    final remaining = response.length - _offset;
    if (remaining <= 0) return Uint8List(0);
    final take = maxLength == null || maxLength > remaining
        ? remaining
        : maxLength;
    final chunk = response.sublist(_offset, _offset + take);
    _offset += take;
    return chunk;
  }

  @override
  Future<void> write(Uint8List data) async {
    written.add(data);
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> reset() async {}

  @override
  Future<void> closeWrite() async {}

  @override
  Future<void> closeRead() async {}

  @override
  Future<void> setDeadline(DateTime? time) async {}

  @override
  Future<void> setReadDeadline(DateTime? time) async {}

  @override
  Future<void> setWriteDeadline(DateTime? time) async {}
}

class _FakeNetwork implements Network {
  _FakeNetwork({List<Multiaddr> listenAddrs = const []})
    : _listenAddrs = listenAddrs;

  final List<Multiaddr> _listenAddrs;
  Uint8List streamResponse = Uint8List(0);
  final List<PeerId> connectedPeers = [];

  @override
  Connectedness connectedness(PeerId peer) => Connectedness.connected;

  @override
  bool canDial(PeerId peer, Multiaddr address) => true;

  @override
  Future<void> closePeer(PeerId peer) async {}

  @override
  List<Conn> conns() => [];

  @override
  List<Conn> connsToPeer(PeerId peer) => [];

  @override
  Future<Conn> dialPeer(NetworkContext context, PeerId peer) async =>
      _FakeConn(local: peer, remote: peer);

  @override
  Future<List<Multiaddr>> interfaceListenAddresses() async => _listenAddrs;

  @override
  Future<void> listen(List<Multiaddr> addresses) async {}

  @override
  List<Multiaddr> listenAddresses() => _listenAddrs;

  @override
  PeerId get localPeer => PeerId(value: Uint8List.fromList([1]));

  PeerId? dialedPeer;

  @override
  Future<NetworkStream> newStream(NetworkContext context, PeerId peer) async {
    dialedPeer = peer;
    return _FakeStream(response: streamResponse);
  }

  @override
  void notify(Notifiee notifiee) {}

  @override
  List<PeerId> peers() => connectedPeers;

  @override
  Object get peerstore => MemoryPeerstore();

  @override
  ResourceManager get resourceManager => const NullResourceManager();

  @override
  void setStreamHandler(StreamHandler handler) {}

  @override
  void stopNotify(Notifiee notifiee) {}

  @override
  Future<void> close() async {}
}

BlankHost _newTestHost({List<Multiaddr> addrs = const []}) {
  final ps = MemoryPeerstore();
  final net = _FakeNetwork(listenAddrs: addrs);
  final host = BlankHost(network: net, peerstore: ps);
  for (final a in addrs) {
    ps.addAddrs(host.id, [a], const Duration(hours: 1));
  }
  return host;
}

void main() {
  group('AutoNat [Atomic Audit]', () {
    test('status() - returns reachability status', () {
      final AutoNat nat = StaticAutoNat(reachability: Reachability.public_);
      expect(nat.status(), equals(Reachability.public_));
    });

    test('close() - closes AutoNat instance', () async {
      final AutoNat nat = StaticAutoNat(reachability: Reachability.public_);
      await nat.close();
      expect(nat.status(), equals(Reachability.public_));
    });
  });

  group('StaticAutoNat [Atomic Audit]', () {
    test('status() - returns configured status', () {
      final nat = StaticAutoNat(reachability: Reachability.private_);
      expect(nat.status(), equals(Reachability.private_));
    });

    test('close() - completes without error', () async {
      final nat = StaticAutoNat(reachability: Reachability.unknown);
      await nat.close();
      expect(nat.status(), equals(Reachability.unknown));
    });
  });

  group('AmbientAutoNat [Atomic Audit]', () {
    test('host() - gets and sets host', () {
      final h1 = _newTestHost();
      final h2 = _newTestHost();
      final nat = AmbientAutoNat(host: h1);
      expect(nat.host, equals(h1));
      nat.host = h2;
      expect(nat.host, equals(h2));
    });

    test('status() - returns initial reachability', () {
      final host = _newTestHost();
      final nat = AmbientAutoNat(
        host: host,
        initialReachability: Reachability.unknown,
      );
      expect(nat.status(), equals(Reachability.unknown));
    });

    test(
      'confidence - saturates at maxConfidence (3) on consecutive public observations',
      () {
        final host = _newTestHost();
        final nat = AmbientAutoNat(host: host);
        expect(nat.confidence, equals(0));

        // First public observation switches status to public and keeps confidence 0
        nat.recordObservation(Reachability.public_);
        expect(nat.status(), equals(Reachability.public_));
        expect(nat.confidence, equals(0));

        // Subsequent public observations increment confidence up to 3 (saturation)
        nat.recordObservation(Reachability.public_);
        expect(nat.confidence, equals(1));
        nat.recordObservation(Reachability.public_);
        expect(nat.confidence, equals(2));
        nat.recordObservation(Reachability.public_);
        expect(nat.confidence, equals(3));
        // Saturation: 4th observation stays at 3
        nat.recordObservation(Reachability.public_);
        expect(nat.confidence, equals(3));
      },
    );

    test(
      'recordObservation() - handles private and unknown transitions with confidence degradation',
      () {
        final host = _newTestHost();
        final nat = AmbientAutoNat(host: host);

        // Saturate confidence in public state
        nat.recordObservation(Reachability.public_);
        nat.recordObservation(Reachability.public_);
        nat.recordObservation(Reachability.public_);
        nat.recordObservation(Reachability.public_);
        expect(nat.status(), equals(Reachability.public_));
        expect(nat.confidence, equals(3));

        // Private observations decrease confidence before flipping
        nat.recordObservation(Reachability.private_);
        expect(nat.confidence, equals(2));
        expect(nat.status(), equals(Reachability.public_)); // not flipped yet

        nat.recordObservation(Reachability.private_);
        expect(nat.confidence, equals(1));
        expect(nat.status(), equals(Reachability.public_));

        nat.recordObservation(Reachability.private_);
        expect(nat.confidence, equals(0));
        expect(nat.status(), equals(Reachability.public_));

        // When confidence is 0, next private observation flips to private
        nat.recordObservation(Reachability.private_);
        expect(nat.status(), equals(Reachability.private_));
        expect(nat.confidence, equals(0));

        // Additional private observations build confidence in private state
        nat.recordObservation(Reachability.private_);
        expect(nat.confidence, equals(1));
        nat.recordObservation(Reachability.private_);
        expect(nat.confidence, equals(2));
        nat.recordObservation(Reachability.private_);
        expect(nat.confidence, equals(3));
        nat.recordObservation(Reachability.private_);
        expect(nat.confidence, equals(3)); // saturated at 3
      },
    );

    test(
      'handleDialResponse() - translates errors into reachability observations',
      () {
        final host = _newTestHost();
        final nat = AmbientAutoNat(host: host);

        // null dialErr -> public
        nat.handleDialResponse(null);
        expect(nat.status(), equals(Reachability.public_));

        // Dial error -> private (after confidence drops)
        final dialErr = AutoNatException(status: 100);
        nat.handleDialResponse(dialErr);
        expect(nat.status(), equals(Reachability.private_));

        // Other error -> unknown
        final otherErr = Exception('connection reset');
        nat.handleDialResponse(otherErr);
        expect(nat.status(), equals(Reachability.unknown));
      },
    );

    test(
      'setReachability() - explicitly updates reachability and emits event',
      () async {
        final host = _newTestHost();
        final nat = AmbientAutoNat(host: host);
        await nat.setReachability(Reachability.public_);
        expect(nat.status(), equals(Reachability.public_));
      },
    );

    test('emitStatus() - emits current status without changing it', () async {
      final host = _newTestHost();
      final nat = AmbientAutoNat(host: host);
      await nat.emitStatus();
      expect(nat.status(), equals(Reachability.unknown));
    });

    test(
      'scheduleProbe() - calculates probe interval based on confidence and reachability',
      () {
        final host = _newTestHost();
        final nat = AmbientAutoNat(host: host);
        final d1 = nat.scheduleProbe(false);
        expect(d1, equals(nat.config?.retryInterval));

        final d2 = nat.scheduleProbe(true);
        expect(d2, equals(const Duration(seconds: 2)));
      },
    );

    test(
      'checkAddrs() - detects new addresses and decrements max confidence',
      () {
        final host = _newTestHost();
        final nat = AmbientAutoNat(host: host);

        // Force confidence to 3
        nat.recordObservation(Reachability.public_);
        nat.recordObservation(Reachability.public_);
        nat.recordObservation(Reachability.public_);
        nat.recordObservation(Reachability.public_);
        expect(nat.confidence, equals(3));

        // Inject address function returning a new public address
        nat.config?.addressFunc = () => [
          Multiaddr.parse('/ip4/198.51.100.1/tcp/4001'),
        ];
        final changed = nat.checkAddrs();
        expect(changed, isTrue);
        expect(nat.confidence, equals(2));
      },
    );

    test('getPeerToProbe() - returns null when no peers are connected', () {
      final host = _newTestHost();
      final nat = AmbientAutoNat(host: host);
      expect(nat.getPeerToProbe(), isNull);
    });

    test('tryProbe() - initiates probe with client', () async {
      final host = _newTestHost();
      final nat = AmbientAutoNat(host: host);
      final peer = PeerId(value: Uint8List.fromList([42]));
      await nat.tryProbe(peer);
      expect(nat.pendingProbes, equals(0));
    });

    test(
      'onInboundPublicConn() - updates lastInbound on public inbound connection',
      () {
        final host = _newTestHost();
        final nat = AmbientAutoNat(host: host);
        expect(nat.lastInbound, isNull);

        final conn = _FakeConn(
          local: host.id,
          remote: PeerId(value: Uint8List.fromList([99])),
          remoteMa: Multiaddr.parse('/ip4/1.1.1.1/tcp/12345'),
        );
        nat.onInboundPublicConn(conn);
        expect(nat.lastInbound, isNotNull);
      },
    );

    test('close() - cleanly cancels timer and closes subscriptions', () async {
      final host = _newTestHost();
      final nat = AmbientAutoNat(host: host);
      await nat.close();
      expect(nat.status(), equals(Reachability.unknown));
    });

    test('listen() - no-op default', () {
      final host = _newTestHost();
      final nat = AmbientAutoNat(host: host);
      nat.listen(host.network, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      expect(nat.status(), equals(Reachability.unknown));
    });

    test('listenClose() - no-op default', () {
      final host = _newTestHost();
      final nat = AmbientAutoNat(host: host);
      nat.listenClose(host.network, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      expect(nat.status(), equals(Reachability.unknown));
    });

    test('connected() - handles connection notification', () {
      final host = _newTestHost();
      final nat = AmbientAutoNat(host: host);
      final conn = _FakeConn(
        local: host.id,
        remote: PeerId(value: Uint8List.fromList([99])),
        remoteMa: Multiaddr.parse('/ip4/1.1.1.1/tcp/4001'),
      );
      nat.connected(host.network, conn);
      expect(nat.lastInbound, isNotNull);
    });

    test('disconnected() - handles disconnection notification', () {
      final host = _newTestHost();
      final nat = AmbientAutoNat(host: host);
      final conn = _FakeConn(
        local: host.id,
        remote: PeerId(value: Uint8List.fromList([99])),
        remoteMa: Multiaddr.parse('/ip4/1.1.1.1/tcp/4001'),
      );
      nat.disconnected(host.network, conn);
      expect(nat.status(), equals(Reachability.unknown));
    });
  });

  group('DialPolicy [Atomic Audit]', () {
    test(
      'skipDial() - filters out circuit relays, private, loopback, and local IPs',
      () {
        final host = _newTestHost(
          addrs: [Multiaddr.parse('/ip4/1.1.1.1/tcp/4001')],
        );
        final policy = DialPolicy(host: host);

        // Relay address -> skip
        expect(
          policy.skipDial(
            Multiaddr.parse(
              '/p2p-circuit/p2p/12D3KooWDsMmX7axDC6HTTXUNe4upxEvFbNQjmE2FToVVbBzUK6f',
            ),
          ),
          isTrue,
        );
        // Loopback address -> skip
        expect(
          policy.skipDial(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')),
          isTrue,
        );
        // Private RFC1918 address -> skip
        expect(
          policy.skipDial(Multiaddr.parse('/ip4/192.168.1.10/tcp/4001')),
          isTrue,
        );
        expect(
          policy.skipDial(Multiaddr.parse('/ip4/10.0.0.5/tcp/4001')),
          isTrue,
        );
        // Local node's own address -> skip
        expect(
          policy.skipDial(Multiaddr.parse('/ip4/1.1.1.1/tcp/4001')),
          isTrue,
        );
        // Valid public external IP -> do not skip
        expect(
          policy.skipDial(Multiaddr.parse('/ip4/8.8.8.8/tcp/4001')),
          isFalse,
        );
      },
    );

    test(
      'skipPeer() - excludes peers without valid public non-self addresses',
      () {
        final host = _newTestHost(
          addrs: [Multiaddr.parse('/ip4/1.1.1.1/tcp/4001')],
        );
        final policy = DialPolicy(host: host);

        // Peer with only private addresses -> skip
        expect(
          policy.skipPeer([
            Multiaddr.parse('/ip4/192.168.1.1/tcp/4001'),
            Multiaddr.parse('/ip4/10.0.0.1/tcp/4001'),
          ]),
          isTrue,
        );

        // Peer with our own public IP -> skip
        expect(
          policy.skipPeer([
            Multiaddr.parse('/ip4/1.1.1.1/tcp/4001'),
            Multiaddr.parse('/ip4/8.8.8.8/tcp/4001'),
          ]),
          isTrue,
        );

        // Peer with distinct valid public IP -> do not skip
        expect(
          policy.skipPeer([Multiaddr.parse('/ip4/8.8.8.8/tcp/4001')]),
          isFalse,
        );
      },
    );
  });

  group('toIp [Atomic Audit]', () {
    test('toIp() - extracts Ip from ip4 and ip6 multiaddrs', () {
      final ip4Ma = Multiaddr.parse('/ip4/1.2.3.4/tcp/4001');
      final ip4 = toIp(ip4Ma);
      expect(ip4, isNotNull);
      expect(ip4!.equal(Ip.tryParse('1.2.3.4')!), isTrue);

      final ip6Ma = Multiaddr.parse('/ip6/::1/tcp/4001');
      final ip6 = toIp(ip6Ma);
      expect(ip6, isNotNull);
      expect(ip6!.equal(Ip.tryParse('::1')!), isTrue);

      final nonIp = Multiaddr.parse('/dns4/example.com/tcp/4001');
      expect(toIp(nonIp), isNull);
    });
  });

  group('isPublicAddr fromIp [Atomic Audit]', () {
    test(
      'isPublicAddr(fromIp()) - correctly identifies public vs non-public IPv4 and IPv6',
      () {
        expect(isPublicAddr(fromIp(Ip.tryParse('127.0.0.1')!)), isFalse);
        expect(isPublicAddr(fromIp(Ip.tryParse('10.0.0.1')!)), isFalse);
        expect(isPublicAddr(fromIp(Ip.tryParse('172.16.0.1')!)), isFalse);
        expect(isPublicAddr(fromIp(Ip.tryParse('192.168.1.1')!)), isFalse);
        expect(isPublicAddr(fromIp(Ip.tryParse('169.254.1.1')!)), isFalse);
        expect(isPublicAddr(fromIp(Ip.tryParse('100.64.0.1')!)), isFalse);
        expect(isPublicAddr(fromIp(Ip.tryParse('::1')!)), isFalse);
        expect(isPublicAddr(fromIp(Ip.tryParse('fc00::1')!)), isFalse);
        expect(isPublicAddr(fromIp(Ip.tryParse('fe80::1')!)), isFalse);

        expect(isPublicAddr(fromIp(Ip.tryParse('8.8.8.8')!)), isTrue);
        expect(isPublicAddr(fromIp(Ip.tryParse('1.1.1.1')!)), isTrue);
        expect(isPublicAddr(fromIp(Ip.tryParse('2600::')!)), isTrue);
      },
    );
  });

  group('isPublicAddr [Atomic Audit]', () {
    test('isPublicAddr() - validates multiaddresses for public routability', () {
      expect(isPublicAddr(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')), isFalse);
      expect(
        isPublicAddr(
          Multiaddr.parse(
            '/p2p-circuit/p2p/12D3KooWDsMmX7axDC6HTTXUNe4upxEvFbNQjmE2FToVVbBzUK6f',
          ),
        ),
        isFalse,
      );
      expect(isPublicAddr(Multiaddr.parse('/ip4/8.8.8.8/tcp/4001')), isTrue);
    });
  });

  group('Client [Atomic Audit]', () {
    test('dialBack() - sends dial request and receives response', () async {
      // Build a fake response message: OK (status = 0)
      final dialResBuilder = BytesBuilder();
      dialResBuilder.add(encodeProtoVarint((1 << 3) | 0));
      dialResBuilder.add(encodeProtoVarint(0)); // status = ok
      final dialResBytes = dialResBuilder.toBytes();

      final resBytes = BytesBuilder();
      // field 1: type = dialResponse (1)
      resBytes.add(encodeProtoVarint((1 << 3) | 0));
      resBytes.add(encodeProtoVarint(1));
      // field 3: dialResponse
      resBytes.add(encodeProtoVarint((3 << 3) | 2));
      resBytes.add(encodeProtoVarint(dialResBytes.length));
      resBytes.add(dialResBytes);

      final wireBytes = resBytes.toBytes();
      final prefix = encodeProtoVarint(wireBytes.length);
      final delimited = Uint8List.fromList([...prefix, ...wireBytes]);

      final net = _FakeNetwork()..streamResponse = delimited;
      final host = BlankHost(network: net, peerstore: MemoryPeerstore());
      final client = Client(host: host);

      final peer = PeerId(value: Uint8List.fromList([9, 9, 9]));
      await client.dialBack(peer);
      expect(net.dialedPeer, equals(peer));
    });
  });

  group('AutoNatException [Atomic Audit]', () {
    test('isDialError() - checks status for dial error', () {
      final err = AutoNatException(status: 100);
      expect(err.isDialError(), isTrue);
      expect(err.isDialRefused(), isFalse);
      expect(err.toString(), contains('status=100'));
    });

    test('isDialRefused() - checks status for dial refusal', () {
      final err = AutoNatException(status: 101);
      expect(err.isDialRefused(), isTrue);
      expect(err.isDialError(), isFalse);
    });

    test('toString() - returns string representation', () {
      final err = AutoNatException(status: 300, text: 'boom');
      expect(err.toString(), contains('boom'));
    });
  });

  group('isDialError [Atomic Audit]', () {
    test('isDialError() - tests error object', () {
      expect(isDialError(AutoNatException(status: 100)), isTrue);
      expect(isDialError(AutoNatException(status: 0)), isFalse);
      expect(isDialError(Exception('other')), isFalse);
    });
  });

  group('isDialRefused [Atomic Audit]', () {
    test('isDialRefused() - tests error object', () {
      expect(isDialRefused(AutoNatException(status: 101)), isTrue);
      expect(isDialRefused(AutoNatException(status: 0)), isFalse);
      expect(isDialRefused(Exception('other')), isFalse);
    });
  });

  group('AutoNatConfig [Atomic Audit]', () {
    test('applyDefaults() - sets default parameters', () {
      final host = _newTestHost();
      final cfg = AutoNatConfig(host: host);
      expect(cfg.bootDelay, equals(const Duration(seconds: 15)));
      expect(cfg.retryInterval, equals(const Duration(seconds: 90)));
      expect(cfg.refreshInterval, equals(const Duration(minutes: 15)));
      expect(cfg.requestTimeout, equals(const Duration(seconds: 30)));
    });
  });

  group('withReachability [Atomic Audit]', () {
    test('withReachability() - overrides reachability in config', () {
      final host = _newTestHost();
      final cfg = AutoNatConfig(host: host);
      withReachability(Reachability.public_)(cfg);
      expect(cfg.forceReachability, isTrue);
      expect(cfg.reachability, equals(Reachability.public_));
    });
  });

  group('usingAddresses [Atomic Audit]', () {
    test('usingAddresses() - overrides address function', () {
      final host = _newTestHost();
      final cfg = AutoNatConfig(host: host);
      usingAddresses(() => [Multiaddr.parse('/ip4/1.1.1.1/tcp/4001')])(cfg);
      expect(
        cfg.addressFunc?.call().first.toString(),
        equals('/ip4/1.1.1.1/tcp/4001'),
      );
    });
  });

  group('withSchedule [Atomic Audit]', () {
    test('withSchedule() - configures retry and refresh intervals', () {
      final host = _newTestHost();
      final cfg = AutoNatConfig(host: host);
      withSchedule(const Duration(seconds: 10), const Duration(minutes: 5))(
        cfg,
      );
      expect(cfg.retryInterval, equals(const Duration(seconds: 10)));
      expect(cfg.refreshInterval, equals(const Duration(minutes: 5)));
    });
  });

  group('withoutStartupDelay [Atomic Audit]', () {
    test('withoutStartupDelay() - clears boot delay', () {
      final host = _newTestHost();
      final cfg = AutoNatConfig(host: host);
      withoutStartupDelay()(cfg);
      expect(cfg.bootDelay, equals(Duration.zero));
    });
  });

  group('withoutThrottling [Atomic Audit]', () {
    test('withoutThrottling() - sets throttleGlobalMax to 0', () {
      final host = _newTestHost();
      final cfg = AutoNatConfig(host: host);
      withoutThrottling()(cfg);
      expect(cfg.throttleGlobalMax, equals(0));
    });
  });

  group('withThrottling [Atomic Audit]', () {
    test('withThrottling() - sets global throttling limits', () {
      final host = _newTestHost();
      final cfg = AutoNatConfig(host: host);
      withThrottling(10, const Duration(minutes: 2))(cfg);
      expect(cfg.throttleGlobalMax, equals(10));
      expect(cfg.throttleResetPeriod, equals(const Duration(minutes: 2)));
    });
  });

  group('withPeerThrottling [Atomic Audit]', () {
    test('withPeerThrottling() - sets peer throttling limits', () {
      final host = _newTestHost();
      final cfg = AutoNatConfig(host: host);
      withPeerThrottling(5)(cfg);
      expect(cfg.throttlePeerMax, equals(5));
    });
  });

  group('enableService [Atomic Audit]', () {
    test('enableService() - sets dialer in config', () {
      final host = _newTestHost();
      final cfg = AutoNatConfig(host: host);
      final net = _FakeNetwork();
      enableService(net)(cfg);
      expect(cfg.dialer, equals(net));
    });
  });
}
