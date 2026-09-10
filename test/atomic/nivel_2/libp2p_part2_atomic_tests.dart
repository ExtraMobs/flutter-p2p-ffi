// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages, deprecated_member_use, unnecessary_cast
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p/src/core/connmgr/decay.dart';
import 'package:transpiled_libp2p/src/core/connmgr/gater.dart';
import 'package:transpiled_libp2p/src/core/connmgr/manager.dart';
import 'package:transpiled_libp2p/src/core/connmgr/presets.dart';
import 'package:transpiled_libp2p/src/core/crypto/crypto_utils.dart';
import 'package:transpiled_libp2p/src/core/crypto/ecdsa_key.dart';
import 'package:transpiled_libp2p/src/core/crypto/ed25519_key.dart';
import 'package:transpiled_libp2p/src/core/crypto/key_codec.dart';
import 'package:transpiled_libp2p/src/core/crypto/key_types.dart';
import 'package:transpiled_libp2p/src/core/crypto/proto_varint.dart';
import 'package:transpiled_libp2p/src/core/crypto/rsa_key.dart';
import 'package:transpiled_libp2p/src/core/crypto/secp256k1_key.dart';
import 'package:transpiled_libp2p/src/core/discovery/discovery.dart';
import 'package:transpiled_libp2p/src/core/discovery/options.dart';
import 'package:transpiled_libp2p/src/core/network/network.dart';
import 'package:transpiled_libp2p/src/core/peer/addr_info.dart';
import 'package:transpiled_libp2p/src/core/peer/peer_id.dart';
import 'package:transpiled_libp2p/src/core/peer/peer_record.dart';
import 'package:transpiled_libp2p/src/core/protocol/protocol.dart';
import 'package:transpiled_libp2p/src/core/record/envelope.dart';
import 'package:transpiled_libp2p/src/core/record/record.dart';
import 'package:transpiled_libp2p/src/core/routing/options.dart';
import 'package:transpiled_libp2p/src/core/routing/query.dart';
import 'package:transpiled_libp2p/src/core/routing/routing.dart';
import 'package:transpiled_libp2p/src/p2p/host/resource_manager/limit.dart';
import 'package:transpiled_libp2p/src/p2p/host/resource_manager/resource_manager.dart';
import 'package:transpiled_libp2p/src/p2p/security/noise/noise_framing.dart';
import 'package:transpiled_libp2p/src/p2p/security/noise/noise_handshake_payload.dart';
import 'package:transpiled_libp2p/src/p2p/security/noise/noise_state.dart';

Uint8List _hexToBytes(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

Uint8List _hexDecode(String hex) => _hexToBytes(hex);

const _sampleRsaPrivateDerHex =
    '308204a30201000282010100ea0a1909618e3bb50febc31c695a97309a5f9f758b687a5350a0'
    '2c2b3144e9ad7520ebdafcafe1b824e82763cc4f3d673adbe07dec6d84029b39746d2e6e3fdf'
    '562ad14198652707844128c779067b513190970958847149ce23305ca7b1b413785278baf7da'
    'e91377c57f5c68d68bd4ae32e6ebdfa131de0350aad443f80ec4f4449cf97c5d702547523704'
    '1faa688e8b7dcd7db2237c016e0d98f824730f008dad3df2c5be40382b43f630fd2847292c47'
    '94d75c80728ffee525f2c9946d435b4db6591fde64231a3c13de7593a5652296093416a5ac8d'
    'a4bfd5bafd0d9b52f8d4f56510d4da3bcdcb8ac9dae9e3d818ebc1e58d3f42667865bfc22a9b'
    'e1cd020301000102820100375dcc2e7bf5ba0a4b89eace7dde00866efed02a6ea078cfdcf307'
    '7ff057ed302bd56df69070cb6554d5d6fbb509c9ecf1efb25c17e290a84d307a6a99e15b1aea'
    'b796697e33efd7c761e2d3cdbdcace9a7b2a3ffbc0d94c2c880698e4d31556c5d03cdf7e633b'
    '606fa5394c13412e335242987e9498fdc317e5ad8429d0352dcef8d3c85e43438da593cb8a1d'
    '5220a1560484cf24e2707b9b100e495a8c775ff95d07351dd4764b7b8660926957d4359a9bb5'
    'b516fb5a79e9b1d935b64c44a575ddecbf5ace8d92f937a343af27c904398bdd9e8dae3c6f30'
    '56ebebd4d2fa4705b19fbd4f15345f99b9d67108ee1b6e472e1bf9854dc25498a654d7a8cc92'
    '0102818100ec3e9c1091dcb35f18ff9f36f7968acc73ae0713b67495a9fcad4aa1fbe1021f79'
    '27e5a2e32cf31fb90933d40453df1cf264a08f54d3e71d58e7e53279cbb2ce3ce636be3a7e1a'
    'fb1314f20e4eff5a5c4bbcba6bc9325ddd8f1353c1367cc36593628703e9f86e67e5c4045092'
    '524291029755550d7f1f46e055efb77e35094902818100fd9c4838aae7bdd0dcaa057986b839'
    'e73be8b1bf280a7c2b658f2d6bf0baf7cd84963e62d2d27cea2ed4950aa52d36f3696b455fdc'
    '9a8e4458a6d09c20327cdf69e81da2b26c09327bbfe45586d1b6e3cf73364e0f6b36f408e450'
    '433547f11fdb65a90c1a236e63ebd61e77b573e4710ce0ebc72a4c08231c81310855ad786502'
    '81802075f5e1bcf9135874c9e2e99d997cd6dcea43a4acc45630363ce56d5e7bab5c01bcbeab'
    'e405301ee2c0e5f332e9075625e437bf9a0b47cd5b82f99636f00b50954398b008bf7d1b94a2'
    'a323de2cee1092838b25f64e4a6180204ab8d8b0c9f4720ceeba55f2c1d0dadc552f70fb8694'
    '004425007bcb44d3eb4d4393f5ee79a90281805c00b9168db19a63cdd98438ed0da23be7b8e7'
    'daa00d05b4bc982f732c16b7d4ffd77d745e64ebda0cf923c483dd9e44b9a6a7b93a0f7bb301'
    'b22a95a8fc87de88ce230a25ce199c0dd6b45fee93dfd44f2acdb58dd468502975a2446f6cd4'
    'e5a8b2fd9b9d53e3352e9633e15b9b5a7144a9c7ff2db1fd75b75e8aca2a42cf1d02818100c1'
    'dea6bb56e747fd25e3a3c407557e34a8990dab4fd3054de29d12fd1f5d1cfd729fc67ba843ce'
    '10a9dbda5de591da4c7a7442a59b019918c6f163555208efc6968b0efeabccaf15a26d76a61b'
    '85f43bd7afdb4635ff2a0a9ca69f5bd7aace119527c3566f3f0e1d2b10c99f33adf3c5ce6461'
    '8d71ade16f128d82c261125afb';

const _sampleRsaPublicDerHex =
    '30820122300d06092a864886f70d01010105000382010f003082010a0282010100ea0a190961'
    '8e3bb50febc31c695a97309a5f9f758b687a5350a02c2b3144e9ad7520ebdafcafe1b824e827'
    '63cc4f3d673adbe07dec6d84029b39746d2e6e3fdf562ad14198652707844128c779067b5131'
    '90970958847149ce23305ca7b1b413785278baf7dae91377c57f5c68d68bd4ae32e6ebdfa131'
    'de0350aad443f80ec4f4449cf97c5d7025475237041faa688e8b7dcd7db2237c016e0d98f824'
    '730f008dad3df2c5be40382b43f630fd2847292c4794d75c80728ffee525f2c9946d435b4db6'
    '591fde64231a3c13de7593a5652296093416a5ac8da4bfd5bafd0d9b52f8d4f56510d4da3bcd'
    'cb8ac9dae9e3d818ebc1e58d3f42667865bfc22a9be1cd0203010001';

class _TestConn implements Conn {
  final PeerId? remotePeer;
  final Multiaddr? localMultiaddr;
  final Multiaddr? remoteMultiaddr;
  _TestConn([this.remotePeer, this.localMultiaddr, this.remoteMultiaddr]);
}

class _TestDecayingTag implements DecayingTag {
  final String _name;
  final Duration _interval;
  final Map<PeerId, int> bumps = {};
  final List<PeerId> removals = [];
  bool isClosed = false;
  _TestDecayingTag(this._name, this._interval);
  @override
  String name() => _name;
  @override
  Duration interval() => _interval;
  @override
  void bump(PeerId peer, int delta) { bumps[peer] = delta; }
  @override
  void remove(PeerId peer) { removals.add(peer); }
  @override
  void close() { isClosed = true; }
}

class _TestDecayer implements Decayer {
  bool isClosed = false;
  @override
  DecayingTag registerDecayingTag(String name, Duration interval, DecayFn decayFn, BumpFn bumpFn) =>
      _TestDecayingTag(name, interval);
  @override
  void close() { isClosed = true; }
  Future<void> decayTag(PeerId peer, String tag) async {}
}

DecayingValue _makeDecayingValue(int val, {DateTime? lastVisit}) {
  final tag = _TestDecayingTag('tag', Duration.zero);
  final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
  final now = DateTime.now();
  return DecayingValue(
    tag: tag,
    peer: peer,
    added: now,
    lastVisit: lastVisit ?? now,
    value: val,
  );
}

class _TestConnMultiaddrs implements ConnMultiaddrs {
  final Multiaddr _addr;
  _TestConnMultiaddrs(this._addr);
  @override
  Multiaddr localMultiaddr() => _addr;
  @override
  Multiaddr remoteMultiaddr() => _addr;
}

class _TestConnectionGater implements ConnectionGater {
  @override
  bool interceptPeerDial(PeerId peer) => true;
  @override
  bool interceptAddrDial(PeerId peer, Multiaddr addr) => true;
  @override
  bool interceptAccept(ConnMultiaddrs addrs) => true;
  @override
  bool interceptSecured(Direction direction, PeerId peer, ConnMultiaddrs addrs) => true;
  @override
  ({bool allow, int reason}) interceptUpgraded(Conn conn) => (allow: true, reason: 0);
}

class _TestGetConnLimiter implements GetConnLimiter {
  final int limit;
  _TestGetConnLimiter(this.limit);
  @override
  int getConnLimit() => limit;
}

class _TestAdvertiser implements Advertiser {
  @override
  Future<Duration> advertise(String namespace, {List<DiscoveryOption> options = const []}) async => const Duration(minutes: 5);
}

class _TestDiscoverer implements Discoverer {
  @override
  Stream<AddrInfo> findPeers(String namespace, {List<DiscoveryOption> options = const []}) =>
      Stream.value(AddrInfo(id: PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N'), addrs: []));
}

class _TestNetworkStream implements NetworkStream {
  String _proto = '/echo/1.0.0';
  @override
  String get id => 'net-stream-1';
  @override
  ProtocolId protocol() => _proto;
  @override
  Future<void> setProtocol(ProtocolId id) async { _proto = id; }
  @override
  Stats stat() => ConnStats(direction: Direction.outbound, opened: DateTime.now());
  @override
  Conn conn() => _TestConn();
  @override
  StreamScope scope() => const NullScope();
  @override
  Future<void> resetWithError(StreamErrorCode errorCode) async {}
  @override
  bool get isClosed => false;
  @override
  Future<Uint8List> read([int? maxLength]) async => Uint8List(0);
  @override
  Future<void> write(Uint8List data) async {}
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

class _TestMultiaddrDnsResolver implements MultiaddrDnsResolver {
  @override
  Future<List<Multiaddr>> resolveDnsAddr(NetworkContext context, PeerId expectedPeerId, Multiaddr multiaddr, int recursionLimit, int outputLimit) async => [multiaddr];
  @override
  Future<List<Multiaddr>> resolveDnsComponent(NetworkContext context, Multiaddr multiaddr, int outputLimit) async => [multiaddr];
}

class _TestDialer implements Dialer {
  @override
  PeerId get localPeer => PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
  @override
  Object get peerstore => Object();
  @override
  List<PeerId> peers() => [PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N')];
  @override
  Connectedness connectedness(PeerId peer) => Connectedness.connected;
  @override
  List<Conn> conns() => [];
  @override
  List<Conn> connsToPeer(PeerId peer) => [];
  @override
  Future<void> closePeer(PeerId peer) async {}
  @override
  Future<Conn> dialPeer(NetworkContext context, PeerId peer) async => _TestConn();
  @override
  bool canDial(PeerId peer, Multiaddr address) => true;
  @override
  void notify(Notifiee notifiee) {}
  @override
  void stopNotify(Notifiee notifiee) {}
}

class _TestConnSecurity implements ConnSecurity {
  final PeerId _peer;
  final PubKey _pub;
  _TestConnSecurity(this._peer, this._pub);
  @override
  PeerId localPeer() => _peer;
  @override
  PeerId remotePeer() => _peer;
  @override
  PubKey remotePublicKey() => _pub;
  @override
  ConnectionState connState() => const ConnectionState(
    streamMultiplexer: '',
    security: '',
    transport: 'tcp',
    usedEarlyMuxerNegotiation: false,
  );
}

class _TestConnStat implements ConnStat {
  @override
  ConnStats stat() => ConnStats(direction: Direction.inbound, opened: DateTime.now());
}

class _TestConnScoper implements ConnScoper {
  @override
  ConnScope scope() => const NullScope();
}

class _TestNetwork implements Network {
  @override
  Dialer get dialer => throw UnimplementedError();
  @override
  Future<Conn> dialPeer(NetworkContext context, PeerId peer) async => throw UnimplementedError();
  @override
  Future<void> closePeer(PeerId peer) async {}
  @override
  Connectedness connectedness(PeerId peer) => Connectedness.notConnected;
  @override
  List<PeerId> peers() => [];
  @override
  List<Conn> conns() => [];
  @override
  List<Conn> connsToPeer(PeerId peer) => [];
  @override
  void notify(Notifiee notifiee) {}
  @override
  void stopNotify(Notifiee notifiee) {}
  @override
  Future<NetworkStream> newStream(NetworkContext context, PeerId peer) async => _TestNetworkStream();
  @override
  Future<void> listen(Iterable<Multiaddr> addrs) async {}
  @override
  List<Multiaddr> listenAddresses() => [];
  @override
  Future<List<Multiaddr>> interfaceListenAddresses() async => [];
  @override
  ResourceManager get resourceManager => const NullResourceManager();
  @override
  Future<void> close() async {}
  @override
  bool canDial(PeerId peer, Multiaddr address) => true;
  @override
  PeerId get localPeer => PeerId(value: Uint8List(0));
  @override
  Object get peerstore => Object();
  @override
  void setStreamHandler(StreamHandler handler) {}
}

class _TestRouter implements Router {
  final Map<ProtocolId, HandlerFunc> handlers = {};
  @override
  void addHandler(ProtocolId id, HandlerFunc handler) {
    handlers[id] = handler;
  }
  @override
  void addHandlerWithFunc(ProtocolId id, bool Function(ProtocolId) match, HandlerFunc handler) {
    handlers[id] = handler;
  }
  @override
  void removeHandler(ProtocolId id) {
    handlers.remove(id);
  }
  @override
  List<ProtocolId> protocols() => handlers.keys.toList();
}

class _TestNegotiator implements Negotiator {
  @override
  Future<(ProtocolId, HandlerFunc)> negotiate(Object stream) async => ('/echo/1', (p, s) async {});
  @override
  Future<void> handle(Object stream) async {}
}

class _TestContentProviding implements ContentProviding {
  final List<Cid> provided = [];
  @override
  Future<void> provide(Cid cid, bool local) async {
    provided.add(cid);
  }
}

class _TestContentDiscovery implements ContentDiscovery {
  @override
  Stream<AddrInfo> findProvidersAsync(Cid cid, int count) =>
      Stream.value(AddrInfo(id: PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N'), addrs: []));
}

class _TestPeerRouting implements PeerRouting {
  @override
  Future<AddrInfo> findPeer(PeerId id) async => AddrInfo(id: id, addrs: []);
}

class _TestValueStore implements ValueStore {
  final Map<String, Uint8List> store = {};
  @override
  Future<void> putValue(String key, Uint8List value, {List<RoutingOption> options = const []}) async {
    store[key] = value;
  }
  @override
  Future<Uint8List> getValue(String key, {List<RoutingOption> options = const []}) async {
    final v = store[key];
    if (v == null) throw const RoutingNotFoundException();
    return v;
  }
  @override
  Stream<Uint8List> searchValue(String key, {List<RoutingOption> options = const []}) {
    final v = store[key];
    if (v == null) return const Stream.empty();
    return Stream.value(v);
  }
}

class _TestRouting extends _TestValueStore implements Routing {
  bool bootstrapped = false;
  @override
  Future<void> bootstrap() async {
    bootstrapped = true;
  }
  @override
  Future<void> provide(Cid cid, bool local) async {}
  @override
  Stream<AddrInfo> findProvidersAsync(Cid cid, int count) => const Stream.empty();
  @override
  Future<AddrInfo> findPeer(PeerId id) async => AddrInfo(id: id, addrs: []);
}

class _TestPubKeyFetcher implements PubKeyFetcher {
  final PubKey key;
  _TestPubKeyFetcher(this.key);
  @override
  Future<PubKey> getPublicKey(PeerId id) async => key;
}

class _TestValueStoreRouting extends _TestValueStore implements PubKeyFetcher {
  final PubKeyFetcher _fetcher;
  _TestValueStoreRouting(this._fetcher);
  @override
  Future<PubKey> getPublicKey(PeerId id) => _fetcher.getPublicKey(id);
}

void main() {
group('NoiseHandshakeAuthException [Atomic Audit]', () {
    test('toString() - formats exception message without dots', () {
      final exc = NoiseHandshakeAuthException('auth failed');
      expect(exc.toString(), contains('auth failed'));
    });
  });

  group('CipherState [Atomic Audit]', () {
    test('hasKey - indicates whether key is initialized', () {
      final cs = CipherState();
      expect(cs.hasKey, isFalse);
      cs.initializeKey(Uint8List(32));
      expect(cs.hasKey, isTrue);
    });

    test('keyBytes - exposes underlying raw key bytes', () {
      final raw = Uint8List.fromList(List.generate(32, (i) => i));
      final cs = CipherState(key: raw);
      expect(cs.keyBytes, equals(raw));
    });

    test('initializeKey() - sets key and resets nonce', () {
      final cs = CipherState();
      final key = Uint8List(32);
      cs.initializeKey(key);
      expect(cs.hasKey, isTrue);
      expect(cs.keyBytes, equals(key));
    });

    test('encryptWithAd() - encrypts plaintext with associated data', () async {
      final cs = CipherState(key: Uint8List(32));
      final ad = Uint8List.fromList([1, 2]);
      final plaintext = Uint8List.fromList([10, 20, 30]);
      final ciphertext = await cs.encryptWithAd(ad, plaintext);
      expect(ciphertext, isNotEmpty);
      expect(ciphertext.length, greaterThan(plaintext.length));
    });

    test('decryptWithAd() - decrypts ciphertext back to plaintext', () async {
      final key = Uint8List(32);
      final sender = CipherState(key: key);
      final receiver = CipherState(key: key);
      final ad = Uint8List.fromList([1, 2]);
      final plaintext = Uint8List.fromList([10, 20, 30]);
      final ciphertext = await sender.encryptWithAd(ad, plaintext);
      final decrypted = await receiver.decryptWithAd(ad, ciphertext);
      expect(decrypted, equals(plaintext));
    });
  });

  group('SymmetricState [Atomic Audit]', () {
    test('initialize() - creates state with protocol name hash', () async {
      final ss = await SymmetricState.initialize(noiseProtocolName);
      expect(ss.cipherState.hasKey, isFalse);
    });

    test('mixKey() - mixes input material into chaining key', () async {
      final ss = await SymmetricState.initialize(noiseProtocolName);
      await ss.mixKey(Uint8List(32));
      expect(ss.cipherState.hasKey, isTrue);
    });

    test('mixHash() - incorporates data into handshake hash', () async {
      final ss = await SymmetricState.initialize(noiseProtocolName);
      await expectLater(ss.mixHash(Uint8List.fromList([1, 2, 3])), completes);
    });

    test('encryptAndHash() - encrypts plaintext and mixes into hash', () async {
      final ss = await SymmetricState.initialize(noiseProtocolName);
      final ciphertext = await ss.encryptAndHash(Uint8List.fromList([7, 8, 9]));
      expect(ciphertext, equals(Uint8List.fromList([7, 8, 9])));
    });

    test('decryptAndHash() - decrypts ciphertext and mixes into hash', () async {
      final ss = await SymmetricState.initialize(noiseProtocolName);
      final plaintext = await ss.decryptAndHash(Uint8List.fromList([7, 8, 9]));
      expect(plaintext, equals(Uint8List.fromList([7, 8, 9])));
    });

    test('split() - splits chaining key into bidirectional cipher states', () async {
      final ss = await SymmetricState.initialize(noiseProtocolName);
      await ss.mixKey(Uint8List(32));
      final (cs1, cs2) = await ss.split();
      expect(cs1.hasKey, isTrue);
      expect(cs2.hasKey, isTrue);
    });
  });

  group('HandshakeState [Atomic Audit]', () {
    test('initialize() - creates handshake state for initiator and responder', () async {
      final staticKp = await generateNoiseKeyPair();
      final hs = await HandshakeState.initialize(initiator: true, staticKeyPair: staticKp);
      expect(hs.initiator, isTrue);
      expect(hs.remoteStaticKey, isNull);
    });

    test('writeMessage() - writes handshake pattern tokens and payload', () async {
      final initStatic = await generateNoiseKeyPair();
      final respStatic = await generateNoiseKeyPair();
      final initHs = await HandshakeState.initialize(initiator: true, staticKeyPair: initStatic);
      final respHs = await HandshakeState.initialize(initiator: false, staticKeyPair: respStatic);

      final (msg1, split1) = await initHs.writeMessage(Uint8List(0));
      expect(msg1, isNotEmpty);
      expect(split1, isNull);

      final (payload1, splitResp1) = await respHs.readMessage(msg1);
      expect(payload1, isEmpty);
      expect(splitResp1, isNull);
    });

    test('readMessage() - consumes handshake messages and completes handshake', () async {
      final initStatic = await generateNoiseKeyPair();
      final respStatic = await generateNoiseKeyPair();
      final initHs = await HandshakeState.initialize(initiator: true, staticKeyPair: initStatic);
      final respHs = await HandshakeState.initialize(initiator: false, staticKeyPair: respStatic);

      final (msg1, _) = await initHs.writeMessage(Uint8List(0));
      await respHs.readMessage(msg1);

      final (msg2, _) = await respHs.writeMessage(Uint8List(0));
      await initHs.readMessage(msg2);

      final (msg3, initSplit) = await initHs.writeMessage(Uint8List(0));
      final (_, respSplit) = await respHs.readMessage(msg3);

      expect(initSplit, isNotNull);
      expect(respSplit, isNotNull);
    });

    test('remoteStaticKey - exposes remote static key after message exchange', () async {
      final initStatic = await generateNoiseKeyPair();
      final respStatic = await generateNoiseKeyPair();
      final initHs = await HandshakeState.initialize(initiator: true, staticKeyPair: initStatic);
      final respHs = await HandshakeState.initialize(initiator: false, staticKeyPair: respStatic);

      final (msg1, _) = await initHs.writeMessage(Uint8List(0));
      await respHs.readMessage(msg1);
      final (msg2, _) = await respHs.writeMessage(Uint8List(0));
      await initHs.readMessage(msg2);

      expect(initHs.remoteStaticKey, equals(respStatic.publicKeyBytes));
    });
  });

  group('Limit [Atomic Audit]', () {
    final Limit lim = const BaseLimit(
      streams: 10,
      streamsInbound: 6,
      streamsOutbound: 4,
      conns: 8,
      connsInbound: 5,
      connsOutbound: 3,
      fd: 12,
      memory: 1024,
    );

    test('memoryLimit - exposes memory limit value', () {
      expect(lim.memoryLimit, equals(1024));
    });

    test('getStreamLimit() - returns stream limit by direction', () {
      expect(lim.getStreamLimit(Direction.inbound), equals(6));
      expect(lim.getStreamLimit(Direction.outbound), equals(4));
    });

    test('streamTotalLimit - exposes total streams limit', () {
      expect(lim.streamTotalLimit, equals(10));
    });

    test('getConnLimit() - returns connection limit by direction', () {
      expect(lim.getConnLimit(Direction.inbound), equals(5));
      expect(lim.getConnLimit(Direction.outbound), equals(3));
    });

    test('connTotalLimit - exposes total connections limit', () {
      expect(lim.connTotalLimit, equals(8));
    });

    test('fdLimit - exposes file descriptor limit', () {
      expect(lim.fdLimit, equals(12));
    });

    test('getMemoryLimit() - method returns memory limit', () {
      expect(lim.getMemoryLimit(), equals(1024));
    });

    test('getStreamTotalLimit() - method returns total stream limit', () {
      expect(lim.getStreamTotalLimit(), equals(10));
    });

    test('getConnTotalLimit() - method returns total conn limit', () {
      expect(lim.getConnTotalLimit(), equals(8));
    });

    test('getFdLimit() - method returns fd limit', () {
      expect(lim.getFdLimit(), equals(12));
    });
  });

  group('BaseLimit [Atomic Audit]', () {
    const base = BaseLimit(
      streams: 20,
      streamsInbound: 12,
      streamsOutbound: 8,
      conns: 16,
      connsInbound: 10,
      connsOutbound: 6,
      fd: 24,
      memory: 4096,
    );

    test('memoryLimit - reads configured memory value', () {
      expect(base.memoryLimit, equals(4096));
    });

    test('getStreamLimit() - resolves direction stream limit', () {
      expect(base.getStreamLimit(Direction.inbound), equals(12));
      expect(base.getStreamLimit(Direction.outbound), equals(8));
    });

    test('streamTotalLimit - reads streams property', () {
      expect(base.streamTotalLimit, equals(20));
    });

    test('getConnLimit() - resolves direction conn limit', () {
      expect(base.getConnLimit(Direction.inbound), equals(10));
      expect(base.getConnLimit(Direction.outbound), equals(6));
    });

    test('connTotalLimit - reads conns property', () {
      expect(base.connTotalLimit, equals(16));
    });

    test('fdLimit - reads fd property', () {
      expect(base.fdLimit, equals(24));
    });

    test('getMemoryLimit() - returns memory limit', () {
      expect(base.getMemoryLimit(), equals(4096));
    });

    test('getStreamTotalLimit() - returns stream total', () {
      expect(base.getStreamTotalLimit(), equals(20));
    });

    test('getConnTotalLimit() - returns conn total', () {
      expect(base.getConnTotalLimit(), equals(16));
    });

    test('getFdLimit() - returns fd total', () {
      expect(base.getFdLimit(), equals(24));
    });

    test('apply() - merges with another BaseLimit prioritizing non zero', () {
      const baseOther = BaseLimit(streams: 99, conns: 50);
      final applied = const BaseLimit(streams: 0, conns: 10).apply(baseOther);
      expect(applied.streams, equals(99));
      expect(applied.conns, equals(10));
    });

    test('toResourceLimits() - converts to ResourceLimits', () {
      final rl = base.toResourceLimits();
      expect(rl.streams, equals(20));
      expect(rl.memory, equals(4096));
    });
  });

  group('ResourceLimits [Atomic Audit]', () {
    test('isDefault - returns true when untouched and false when changed', () {
      const def = ResourceLimits();
      expect(def.isDefault, isTrue);
      const custom = ResourceLimits(streams: 4);
      expect(custom.isDefault, isFalse);
    });

    test('apply() - overlays defined limits onto another set', () {
      const a = ResourceLimits(streams: 10);
      const b = ResourceLimits(conns: 20);
      final c = a.apply(b);
      expect(c.streams, equals(10));
      expect(c.conns, equals(20));
    });

    test('build() - produces BaseLimit substituting fallbacks', () {
      const rl = ResourceLimits(streams: 5);
      final bl = rl.build(const BaseLimit(conns: 12));
      expect(bl.streams, equals(5));
      expect(bl.conns, equals(12));
    });
  });

  group('Limiter [Atomic Audit]', () {
    final Limiter lim = FixedLimiter();
    final dummyPeer = PeerId(value: Uint8List.fromList([1, 2, 3]));

    test('getSystemLimits() - provides system limit contract', () {
      expect(lim.getSystemLimits(), isA<Limit>());
    });

    test('getTransientLimits() - provides transient limit contract', () {
      expect(lim.getTransientLimits(), isA<Limit>());
    });

    test('getAllowlistedSystemLimits() - provides allowlisted system limits', () {
      expect(lim.getAllowlistedSystemLimits(), isA<Limit>());
    });

    test('getAllowlistedTransientLimits() - provides allowlisted transient limits', () {
      expect(lim.getAllowlistedTransientLimits(), isA<Limit>());
    });

    test('getServiceLimits() - provides limits for named service', () {
      expect(lim.getServiceLimits('test-svc'), isA<Limit>());
    });

    test('getServicePeerLimits() - provides peer limits for service', () {
      expect(lim.getServicePeerLimits('test-svc'), isA<Limit>());
    });

    test('getProtocolLimits() - provides limits for protocol id', () {
      expect(lim.getProtocolLimits('/test/1'), isA<Limit>());
    });

    test('getProtocolPeerLimits() - provides peer limits for protocol', () {
      expect(lim.getProtocolPeerLimits('/test/1'), isA<Limit>());
    });

    test('getPeerLimits() - provides limits for specific peer', () {
      expect(lim.getPeerLimits(dummyPeer), isA<Limit>());
    });

    test('getStreamLimits() - provides stream limits for peer', () {
      expect(lim.getStreamLimits(dummyPeer), isA<Limit>());
    });

    test('getConnLimits() - provides connection limits', () {
      expect(lim.getConnLimits(), isA<Limit>());
    });
  });

  group('FixedLimiter [Atomic Audit]', () {
    final fl = FixedLimiter();
    final dummyPeer = PeerId(value: Uint8List.fromList([1, 2, 3]));

    test('getSystemLimits() - returns system limits', () {
      expect(fl.getSystemLimits().memoryLimit, greaterThan(0));
    });

    test('getTransientLimits() - returns transient limits', () {
      expect(fl.getTransientLimits().memoryLimit, greaterThan(0));
    });

    test('getAllowlistedSystemLimits() - returns allowlisted system limits', () {
      expect(fl.getAllowlistedSystemLimits().memoryLimit, greaterThan(0));
    });

    test('getAllowlistedTransientLimits() - returns allowlisted transient limits', () {
      expect(fl.getAllowlistedTransientLimits().memoryLimit, greaterThan(0));
    });

    test('getServiceLimits() - returns service limits', () {
      expect(fl.getServiceLimits('svc').memoryLimit, greaterThan(0));
    });

    test('getServicePeerLimits() - returns service peer limits', () {
      expect(fl.getServicePeerLimits('svc').memoryLimit, greaterThan(0));
    });

    test('getProtocolLimits() - returns protocol limits', () {
      expect(fl.getProtocolLimits('/p/1').memoryLimit, greaterThan(0));
    });

    test('getProtocolPeerLimits() - returns protocol peer limits', () {
      expect(fl.getProtocolPeerLimits('/p/1').memoryLimit, greaterThan(0));
    });

    test('getPeerLimits() - returns peer limits', () {
      expect(fl.getPeerLimits(dummyPeer).memoryLimit, greaterThan(0));
    });

    test('getStreamLimits() - returns stream limits', () {
      expect(fl.getStreamLimits(dummyPeer).streamTotalLimit, equals(1));
    });

    test('getConnLimits() - returns conn limits', () {
      expect(fl.getConnLimits().connTotalLimit, equals(1));
    });
  });

  group('Decayer [Atomic Audit]', () {
    test('registerDecayingTag() - registers a decaying tag handle', () {
      final Decayer decayer = _TestDecayer();
      final tag = decayer.registerDecayingTag(
        'sub',
        const Duration(seconds: 1),
        decayNone(),
        bumpSumUnbounded(),
      );
      expect(tag.name(), equals('sub'));
    });

    test('close() - closes decayer implementation', () {
      final Decayer decayer = _TestDecayer();
      decayer.close();
      expect((decayer as _TestDecayer).isClosed, isTrue);
    });
  });

  group('DecayingTag [Atomic Audit]', () {
    final DecayingTag tag = _TestDecayingTag('p2p', const Duration(seconds: 2));
    final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');

    test('name() - reports tag name', () {
      expect(tag.name(), equals('p2p'));
    });

    test('interval() - reports tick duration', () {
      expect(tag.interval(), equals(const Duration(seconds: 2)));
    });

    test('bump() - updates score delta for peer', () {
      tag.bump(peer, 5);
      expect((tag as _TestDecayingTag).bumps[peer], equals(5));
    });

    test('remove() - schedules peer score removal', () {
      tag.remove(peer);
      expect((tag as _TestDecayingTag).removals, contains(peer));
    });

    test('close() - closes decaying tag', () {
      tag.close();
      expect((tag as _TestDecayingTag).isClosed, isTrue);
    });
  });

  group('ConnectionGater [Atomic Audit]', () {
    final ConnectionGater gater = _TestConnectionGater();
    final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
    final addr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');

    test('interceptPeerDial() - decides whether peer dial is allowed', () {
      expect(gater.interceptPeerDial(peer), isTrue);
    });

    test('interceptAddrDial() - decides whether addr dial is allowed', () {
      expect(gater.interceptAddrDial(peer, addr), isTrue);
    });

    test('interceptAccept() - decides whether inbound connection is accepted', () {
      expect(gater.interceptAccept(_TestConnMultiaddrs(addr)), isTrue);
    });

    test('interceptSecured() - decides whether secured connection is allowed', () {
      expect(gater.interceptSecured(Direction.inbound, peer, _TestConnMultiaddrs(addr)), isTrue);
    });

    test('interceptUpgraded() - decides whether upgraded connection is accepted', () {
      final res = gater.interceptUpgraded(_TestConn());
      expect(res.allow, isTrue);
    });
  });

  group('ConnManager [Atomic Audit]', () {
    final ConnManager mgr = const NullConnMgr();
    final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');

    test('tagPeer() - associates tag with peer', () {
      expect(() => mgr.tagPeer(peer, 'tag', 1), returnsNormally);
    });

    test('untagPeer() - removes tag from peer', () {
      expect(() => mgr.untagPeer(peer, 'tag'), returnsNormally);
    });

    test('upsertTag() - modifies existing tag or inserts new', () {
      expect(() => mgr.upsertTag(peer, 'tag', (val) => val + 1), returnsNormally);
    });

    test('getTagInfo() - fetches tag metadata for peer', () {
      expect(mgr.getTagInfo(peer), isNotNull);
    });

    test('trimOpenConns() - trims excess connections', () {
      expect(() => mgr.trimOpenConns(), returnsNormally);
    });

    test('notifiee() - provides callback receiver', () {
      expect(mgr.notifiee(), isNotNull);
    });

    test('protect() - protects peer from eviction under tag', () {
      expect(() => mgr.protect(peer, 'tag'), returnsNormally);
    });

    test('unprotect() - removes protection flag', () {
      expect(mgr.unprotect(peer, 'tag'), isFalse);
    });

    test('isProtected() - queries whether peer has active protection', () {
      expect(mgr.isProtected(peer, 'tag'), isFalse);
    });

    test('checkLimit() - enforces connection manager limits against limiter', () {
      expect(() => mgr.checkLimit(_TestGetConnLimiter(10)), returnsNormally);
    });

    test('close() - closes connection manager', () {
      expect(() => mgr.close(), returnsNormally);
    });
  });

  group('GetConnLimiter [Atomic Audit]', () {
    test('getConnLimit() - retrieves maximum allowed connection count', () {
      final GetConnLimiter limiter = _TestGetConnLimiter(42);
      expect(limiter.getConnLimit(), equals(42));
    });
  });

  group('NullConnMgr [Atomic Audit]', () {
    const nullMgr = NullConnMgr();
    final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');

    test('tagPeer() - noop tag operation', () {
      expect(() => nullMgr.tagPeer(peer, 'p', 1), returnsNormally);
    });

    test('untagPeer() - noop untag operation', () {
      expect(() => nullMgr.untagPeer(peer, 'p'), returnsNormally);
    });

    test('upsertTag() - noop upsert operation', () {
      expect(() => nullMgr.upsertTag(peer, 'p', (x) => x), returnsNormally);
    });

    test('getTagInfo() - returns empty tag info instance', () {
      final ti = nullMgr.getTagInfo(peer);
      expect(ti.value, equals(0));
    });

    test('trimOpenConns() - noop trim operation', () {
      expect(() => nullMgr.trimOpenConns(), returnsNormally);
    });

    test('notifiee() - returns global noop notifiee', () {
      expect(nullMgr.notifiee(), equals(globalNoopNotifiee));
    });

    test('protect() - noop protect operation', () {
      expect(() => nullMgr.protect(peer, 'p'), returnsNormally);
    });

    test('unprotect() - returns false indicating no protections remain', () {
      expect(nullMgr.unprotect(peer, 'p'), isFalse);
    });

    test('isProtected() - returns false for any peer query', () {
      expect(nullMgr.isProtected(peer, 'p'), isFalse);
    });

    test('checkLimit() - noop check limit operation', () {
      expect(() => nullMgr.checkLimit(_TestGetConnLimiter(5)), returnsNormally);
    });

    test('close() - noop close operation', () {
      expect(() => nullMgr.close(), returnsNormally);
    });
  });

  group('EncryptedData [Atomic Audit]', () {
    test('toBytes() - serializes nonce and ciphertext into single buffer', () {
      final nonce = Uint8List.fromList(List.generate(12, (i) => i));
      final ciphertext = Uint8List.fromList([1, 2, 3, 4]);
      final data = EncryptedData(ciphertext: ciphertext, nonce: nonce);
      final bytes = data.toBytes();
      expect(bytes.length, equals(16));
    });

    test('fromBytes() - deserializes nonce and ciphertext from buffer', () {
      final bytes = Uint8List.fromList(List.generate(20, (i) => i));
      final data = EncryptedData.fromBytes(bytes);
      expect(data.nonce.length, equals(12));
      expect(data.ciphertext.length, equals(8));
    });
  });

  group('CryptoUtils [Atomic Audit]', () {
    test('deriveKey() - derives key from password and salt using pbkdf2', () {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final key = CryptoUtils.deriveKey('secret', salt, iterations: 100);
      expect(key.length, equals(32));
    });

    test('encrypt() - performs aes gcm encryption returning EncryptedData', () async {
      final key = Uint8List(32);
      final plaintext = Uint8List.fromList([1, 2, 3, 4]);
      final enc = await CryptoUtils.encrypt(plaintext, key);
      expect(enc.ciphertext, isNotEmpty);
      expect(enc.nonce.length, equals(12));
    });

    test('decrypt() - decrypts aes gcm ciphertext back to original bytes', () async {
      final key = Uint8List(32);
      final plaintext = Uint8List.fromList([1, 2, 3, 4]);
      final enc = await CryptoUtils.encrypt(plaintext, key);
      final dec = await CryptoUtils.decrypt(enc, key);
      expect(dec, equals(plaintext));
    });

    test('zeroMemory() - overwrites buffer with zeroes', () {
      final buf = Uint8List.fromList([1, 2, 3, 4]);
      CryptoUtils.zeroMemory(buf);
      expect(buf.every((b) => b == 0), isTrue);
    });

    test('randomBytes() - generates secure random bytes of given length', () {
      final bytes = CryptoUtils.randomBytes(16);
      expect(bytes.length, equals(16));
    });

    test('generateSalt() - produces 16 byte random salt', () {
      final salt = CryptoUtils.generateSalt();
      expect(salt.length, equals(16));
    });

    test('constantTimeEquals() - compares two buffers in constant time', () {
      final a = Uint8List.fromList([1, 2, 3]);
      final b = Uint8List.fromList([1, 2, 3]);
      final c = Uint8List.fromList([1, 2, 4]);
      expect(CryptoUtils.constantTimeEquals(a, b), isTrue);
      expect(CryptoUtils.constantTimeEquals(a, c), isFalse);
    });
  });

  group('EcdsaPrivateKey [Atomic Audit]', () {
    test('type - reports ecdsa key type', () {
      final key = generateEcdsaKeyPair();
      expect(key.type, equals(KeyType.ecdsa));
    });

    test('getPublic() - derives ecdsa public key', () {
      final key = generateEcdsaKeyPair();
      final pub = key.getPublic();
      expect(pub.type, equals(KeyType.ecdsa));
    });

    test('raw() - encodes private key in sec1 format', () {
      final key = generateEcdsaKeyPair();
      final bytes = key.raw();
      expect(bytes, isNotEmpty);
    });

    test('sign() - signs data returning der signature', () async {
      final key = generateEcdsaKeyPair();
      final sig = await key.sign(Uint8List.fromList([1, 2, 3]));
      expect(sig, isNotEmpty);
    });
  });

  group('EcdsaPublicKey [Atomic Audit]', () {
    test('type - reports ecdsa key type', () {
      final key = generateEcdsaKeyPair();
      final pub = key.getPublic() as EcdsaPublicKey;
      expect(pub.type, equals(KeyType.ecdsa));
    });

    test('raw() - encodes public key in pkix format', () {
      final key = generateEcdsaKeyPair();
      final pub = key.getPublic() as EcdsaPublicKey;
      final raw = pub.raw();
      expect(raw, isNotEmpty);
    });

    test('verify() - verifies signature against message bytes', () async {
      final key = generateEcdsaKeyPair();
      final pub = key.getPublic() as EcdsaPublicKey;
      final msg = Uint8List.fromList([1, 2, 3]);
      final sig = await key.sign(msg);
      expect(await pub.verify(msg, sig), isTrue);
      expect(await pub.verify(Uint8List.fromList([4, 5, 6]), sig), isFalse);
    });
  });

  group('Ed25519PrivKey [Atomic Audit]', () {
    test('type - reports ed25519 key type', () async {
      final key = await generateEd25519KeyPair();
      expect(key.type, equals(KeyType.ed25519));
    });

    test('getPublic() - derives ed25519 public key', () async {
      final key = await generateEd25519KeyPair();
      expect(key.getPublic().type, equals(KeyType.ed25519));
    });

    test('raw() - returns raw 64 byte private key bytes', () async {
      final key = await generateEd25519KeyPair();
      expect(key.raw().length, equals(64));
    });

    test('sign() - produces ed25519 signature', () async {
      final key = await generateEd25519KeyPair();
      final sig = await key.sign(Uint8List.fromList([1, 2, 3]));
      expect(sig.length, equals(64));
    });
  });

  group('Ed25519PubKey [Atomic Audit]', () {
    test('type - reports ed25519 key type', () async {
      final key = await generateEd25519KeyPair();
      final pub = key.getPublic() as Ed25519PubKey;
      expect(pub.type, equals(KeyType.ed25519));
    });

    test('raw() - returns raw 32 byte public key bytes', () async {
      final key = await generateEd25519KeyPair();
      final pub = key.getPublic() as Ed25519PubKey;
      expect(pub.raw().length, equals(32));
    });

    test('verify() - verifies ed25519 signature', () async {
      final key = await generateEd25519KeyPair();
      final pub = key.getPublic() as Ed25519PubKey;
      final msg = Uint8List.fromList([1, 2, 3]);
      final sig = await key.sign(msg);
      expect(await pub.verify(msg, sig), isTrue);
      expect(await pub.verify(Uint8List.fromList([9, 9, 9]), sig), isFalse);
    });
  });

  group('Ed25519Signer [Atomic Audit]', () {
    final signer = Ed25519Signer();

    test('generateKeyPair() - generates fresh key pair', () async {
      final kp = await signer.generateKeyPair();
      expect(kp, isNotNull);
    });

    test('keyPairFromSeed() - generates deterministic key pair from seed', () async {
      final seed = Uint8List(32);
      final kp = await signer.keyPairFromSeed(seed);
      expect(kp, isNotNull);
    });

    test('sign() - signs payload bytes using key pair', () async {
      final kp = await signer.generateKeyPair();
      final sig = await signer.sign(Uint8List.fromList([1, 2, 3]), kp);
      expect(sig.length, equals(64));
    });

    test('verify() - verifies signature with public key', () async {
      final kp = await signer.generateKeyPair();
      final msg = Uint8List.fromList([1, 2, 3]);
      final sig = await signer.sign(msg, kp);
      final pub = await signer.extractPublicKey(kp);
      expect(await signer.verify(msg, sig, pub), isTrue);
    });

    test('extractPublicKey() - extracts public key object', () async {
      final kp = await signer.generateKeyPair();
      final pub = await signer.extractPublicKey(kp);
      expect(pub.bytes.length, equals(32));
    });

    test('extractPublicKeyBytes() - extracts 32 raw public bytes', () async {
      final kp = await signer.generateKeyPair();
      final bytes = await signer.extractPublicKeyBytes(kp);
      expect(bytes.length, equals(32));
    });

    test('extractSeed() - extracts 32 byte seed from key pair', () async {
      final seed = Uint8List.fromList(List.generate(32, (i) => i));
      final kp = await signer.keyPairFromSeed(seed);
      final extracted = await signer.extractSeed(kp);
      expect(extracted, equals(seed));
    });

    test('publicKeyFromBytes() - creates public key from 32 bytes', () {
      final raw = Uint8List(32);
      final pub = signer.publicKeyFromBytes(raw);
      expect(pub.bytes.length, equals(32));
    });
  });

  group('KeyPairExtensions [Atomic Audit]', () {
    test('extractSeedAndZero() - extracts seed from key pair', () async {
      final signer = Ed25519Signer();
      final kp = await signer.keyPairFromSeed(Uint8List(32));
      final seed = await kp.extractSeedAndZero();
      expect(seed.length, equals(32));
    });
  });

  group('KeyType [Atomic Audit]', () {
    test('ecdsa - provides ecdsa member with wire value 3', () {
      expect(KeyType.ecdsa.protoValue, equals(3));
    });

    test('fromProtoValue() - decodes protobuf wire enum value', () {
      expect(KeyType.fromProtoValue(0), equals(KeyType.rsa));
      expect(KeyType.fromProtoValue(1), equals(KeyType.ed25519));
      expect(KeyType.fromProtoValue(2), equals(KeyType.secp256k1));
      expect(KeyType.fromProtoValue(3), equals(KeyType.ecdsa));
      expect(KeyType.fromProtoValue(999), isNull);
    });
  });

  group('Key [Atomic Audit]', () {
    test('type - exposes key type via base contract', () async {
      final Key key = await generateEd25519KeyPair();
      expect(key.type, equals(KeyType.ed25519));
    });

    test('raw() - exposes raw bytes via base contract', () async {
      final Key key = await generateEd25519KeyPair();
      expect(key.raw(), isNotEmpty);
    });

    test('keyEquals() - tests key equivalence based on raw bytes', () async {
      final Key key1 = await ed25519KeyPairFromSeed(Uint8List(32));
      final Key key2 = await ed25519KeyPairFromSeed(Uint8List(32));
      final Key key3 = await generateEd25519KeyPair();
      expect(key1.keyEquals(key2), isTrue);
      expect(key1.keyEquals(key3), isFalse);
    });
  });

  group('PrivKey [Atomic Audit]', () {
    test('sign() - signs message bytes via base contract', () async {
      final PrivKey key = await generateEd25519KeyPair();
      final sig = await key.sign(Uint8List.fromList([1, 2, 3]));
      expect(sig, isNotEmpty);
    });

    test('getPublic() - retrieves public key via base contract', () async {
      final PrivKey key = await generateEd25519KeyPair();
      final PubKey pub = key.getPublic();
      expect(pub.type, equals(KeyType.ed25519));
    });
  });

  group('PubKey [Atomic Audit]', () {
    test('verify() - verifies signature via base contract', () async {
      final PrivKey priv = await generateEd25519KeyPair();
      final PubKey pub = priv.getPublic();
      final data = Uint8List.fromList([1, 2, 3]);
      final sig = await priv.sign(data);
      expect(await pub.verify(data, sig), isTrue);
    });
  });

  group('RsaPrivateKey [Atomic Audit]', () {
    final rsaPriv = unmarshalRsaPrivateKey(_hexDecode(_sampleRsaPrivateDerHex));

    test('type - reports rsa key type', () {
      expect(rsaPriv.type, equals(KeyType.rsa));
    });

    test('getPublic() - derives rsa public key', () {
      expect(rsaPriv.getPublic().type, equals(KeyType.rsa));
    });

    test('raw() - encodes rsa private key in pkcs1 der', () {
      expect(rsaPriv.raw(), isNotEmpty);
    });

    test('sign() - creates sha256 pkcs1 signature', () async {
      final sig = await rsaPriv.sign(Uint8List.fromList([1, 2, 3]));
      expect(sig.length, equals(256));
    });
  });

  group('RsaPublicKey [Atomic Audit]', () {
    final rsaPub = unmarshalRsaPublicKey(_hexDecode(_sampleRsaPublicDerHex));

    test('type - reports rsa key type', () {
      expect(rsaPub.type, equals(KeyType.rsa));
    });

    test('raw() - encodes rsa public key in pkix der', () {
      expect(rsaPub.raw(), isNotEmpty);
    });

    test('verify() - validates sha256 pkcs1 signature', () async {
      final rsaPriv = unmarshalRsaPrivateKey(_hexDecode(_sampleRsaPrivateDerHex));
      final msg = Uint8List.fromList([1, 2, 3]);
      final sig = await rsaPriv.sign(msg);
      expect(await rsaPub.verify(msg, sig), isTrue);
      expect(await rsaPub.verify(Uint8List.fromList([4, 5, 6]), sig), isFalse);
    });
  });

  group('Secp256k1PrivateKey [Atomic Audit]', () {
    final priv = generateSecp256k1KeyPair();

    test('type - reports secp256k1 key type', () {
      expect(priv.type, equals(KeyType.secp256k1));
    });

    test('getPublic() - derives secp256k1 public key', () {
      expect(priv.getPublic().type, equals(KeyType.secp256k1));
    });

    test('raw() - returns 32 byte scalar', () {
      expect(priv.raw().length, equals(32));
    });

    test('sign() - creates der encoded signature', () async {
      final sig = await priv.sign(Uint8List.fromList([1, 2, 3]));
      expect(sig, isNotEmpty);
    });
  });

  group('Secp256k1PublicKey [Atomic Audit]', () {
    final priv = generateSecp256k1KeyPair();
    final pub = priv.getPublic() as Secp256k1PublicKey;

    test('type - reports secp256k1 key type', () {
      expect(pub.type, equals(KeyType.secp256k1));
    });

    test('raw() - returns 33 byte compressed sec1 point', () {
      expect(pub.raw().length, equals(33));
    });

    test('verify() - verifies secp256k1 signature', () async {
      final msg = Uint8List.fromList([1, 2, 3]);
      final sig = await priv.sign(msg);
      expect(await pub.verify(msg, sig), isTrue);
      expect(await pub.verify(Uint8List.fromList([7, 8, 9]), sig), isFalse);
    });
  });

  group('Advertiser [Atomic Audit]', () {
    test('advertise() - announces namespace returning ttl duration', () async {
      final Advertiser adv = _TestAdvertiser();
      final ttl = await adv.advertise('test-ns');
      expect(ttl, equals(const Duration(minutes: 5)));
    });
  });

  group('Discoverer [Atomic Audit]', () {
    test('findPeers() - discovers providers of given namespace', () async {
      final Discoverer disc = _TestDiscoverer();
      final peers = await disc.findPeers('test-ns').toList();
      expect(peers, isNotEmpty);
    });
  });

  group('DiscoveryOptions [Atomic Audit]', () {
    test('apply() - configures options iteratively', () {
      final opts = DiscoveryOptions();
      opts.apply([ttl(const Duration(seconds: 30)), limit(10)]);
      expect(opts.ttl, equals(const Duration(seconds: 30)));
      expect(opts.limit, equals(10));
    });
  });

  group('NetworkContext [Atomic Audit]', () {
    test('copyWith() - creates updated network context', () {
      const ctx = NetworkContext();
      final updated = ctx.copyWith(noDialReason: 'manual');
      expect(updated.noDialReason, equals('manual'));
    });
  });

  group('DirectionText [Atomic Audit]', () {
    test('text - returns string representation of direction', () {
      expect(Direction.inbound.text, equals('Inbound'));
      expect(Direction.outbound.text, equals('Outbound'));
      expect(Direction.unknown.text, equals('Unknown'));
    });
  });

  group('ConnectednessText [Atomic Audit]', () {
    test('text - returns string representation of connectedness', () {
      expect(Connectedness.connected.text, equals('Connected'));
      expect(Connectedness.notConnected.text, equals('NotConnected'));
      expect(Connectedness.canConnect.text, equals('CanConnect'));
      expect(Connectedness.cannotConnect.text, equals('CannotConnect'));
      expect(Connectedness.limited.text, equals('Limited'));
    });
  });

  group('ReachabilityText [Atomic Audit]', () {
    test('text - returns string representation of reachability', () {
      expect(Reachability.public_.text, equals('Public'));
      expect(Reachability.private_.text, equals('Private'));
      expect(Reachability.unknown.text, equals('Unknown'));
    });
  });

  group('NatDeviceTypeText [Atomic Audit]', () {
    test('text - returns string representation of nat device type', () {
      expect(NatDeviceType.endpointIndependent.text, equals('Endpoint Independent'));
      expect(NatDeviceType.endpointDependent.text, equals('Endpoint Dependent'));
      expect(NatDeviceType.unknown.text, equals('Unknown'));
    });
  });

  group('NatTransportProtocolText [Atomic Audit]', () {
    test('text - returns string representation of transport protocol', () {
      expect(NatTransportProtocol.udp.text, equals('UDP'));
      expect(NatTransportProtocol.tcp.text, equals('TCP'));
    });
  });

  group('StreamResetException [Atomic Audit]', () {
    test('toString() - returns message string without dots', () {
      const exc = StreamResetException();
      expect(exc.toString(), contains('stream reset'));
    });
  });

  group('StreamException [Atomic Audit]', () {
    test('matches() - matches errorCode and side', () {
      final e1 = StreamException(errorCode: 1, remote: true);
      final e2 = StreamException(errorCode: 1, remote: true);
      final e3 = StreamException(errorCode: 2, remote: true);
      expect(e1.matches(e2), isTrue);
      expect(e1.matches(e3), isFalse);
    });

    test('causes - exposes causes chain', () {
      final e = StreamException(errorCode: 1, remote: false);
      expect(e.causes, isNotEmpty);
    });

    test('toString() - formats stream error representation', () {
      final e = StreamException(errorCode: 1, remote: false);
      expect(e.toString(), contains('stream reset'));
    });
  });

  group('ConnException [Atomic Audit]', () {
    test('matches() - matches errorCode and side', () {
      final e1 = ConnException(errorCode: 1, remote: true);
      final e2 = ConnException(errorCode: 1, remote: true);
      final e3 = ConnException(errorCode: 2, remote: true);
      expect(e1.matches(e2), isTrue);
      expect(e1.matches(e3), isFalse);
    });

    test('causes - exposes connection causes chain', () {
      final e = ConnException(errorCode: 1, remote: false);
      expect(e.causes, isNotEmpty);
    });

    test('toString() - formats connection error string', () {
      final e = ConnException(errorCode: 1, remote: false);
      expect(e.toString(), contains('connection closed'));
    });
  });

  group('NetworkException [Atomic Audit]', () {
    test('toString() - outputs exception message', () {
      const exc = NetworkException('custom network error');
      expect(exc.toString(), equals('custom network error'));
    });
  });

  group('TemporaryNetworkException [Atomic Audit]', () {
    test('isTemporary - indicates temporary error status', () {
      const exc = TemporaryNetworkException('temp');
      expect(exc.isTemporary, isTrue);
    });

    test('isTimeout - indicates timeout status', () {
      const exc = TemporaryNetworkException('temp');
      expect(exc.isTimeout, isFalse);
    });
  });

  group('NetworkStream [Atomic Audit]', () {
    final NetworkStream stream = _TestNetworkStream();

    test('id - provides stream identifier string', () {
      expect(stream.id, equals('net-stream-1'));
    });

    test('protocol() - returns active protocol id', () {
      expect(stream.protocol(), equals('/echo/1.0.0'));
    });

    test('setProtocol() - modifies active protocol id', () async {
      await stream.setProtocol('/chat/1.0.0');
      expect(stream.protocol(), equals('/chat/1.0.0'));
    });

    test('stat() - reports stream statistics', () {
      expect(stream.stat().direction, equals(Direction.outbound));
    });

    test('conn() - returns underlying connection handle', () {
      expect(stream.conn(), isNotNull);
    });

    test('scope() - returns stream resource scope', () {
      expect(stream.scope(), isNotNull);
    });

    test('resetWithError() - resets stream with error code', () async {
      await expectLater(stream.resetWithError(0), completes);
    });

    test('isClosed - reports stream closed state', () {
      expect(stream.isClosed, isFalse);
    });

    test('read() - reads bytes from stream', () async {
      final data = await stream.read();
      expect(data, isNotNull);
    });

    test('write() - writes bytes to stream', () async {
      await expectLater(stream.write(Uint8List(0)), completes);
    });

    test('close() - closes stream', () async {
      await expectLater(stream.close(), completes);
    });

    test('reset() - resets stream', () async {
      await expectLater(stream.reset(), completes);
    });

    test('closeWrite() - closes write half', () async {
      await expectLater(stream.closeWrite(), completes);
    });

    test('closeRead() - closes read half', () async {
      await expectLater(stream.closeRead(), completes);
    });

    test('setDeadline() - sets overall deadline', () async {
      await expectLater(stream.setDeadline(null), completes);
    });

    test('setReadDeadline() - sets read deadline', () async {
      await expectLater(stream.setReadDeadline(null), completes);
    });

    test('setWriteDeadline() - sets write deadline', () async {
      await expectLater(stream.setWriteDeadline(null), completes);
    });
  });

  group('MultiaddrDnsResolver [Atomic Audit]', () {
    final MultiaddrDnsResolver resolver = _TestMultiaddrDnsResolver();
    final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
    final addr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');

    test('resolveDnsAddr() - resolves dns multiaddr for peer', () async {
      final res = await resolver.resolveDnsAddr(NetworkContext.empty, peer, addr, 5, 10);
      expect(res, contains(addr));
    });

    test('resolveDnsComponent() - resolves raw dns component', () async {
      final res = await resolver.resolveDnsComponent(NetworkContext.empty, addr, 10);
      expect(res, contains(addr));
    });
  });

  group('Dialer [Atomic Audit]', () {
    final Dialer dialer = _TestDialer();
    final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
    final addr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');

    test('peerstore - provides peerstore handle', () {
      expect(dialer.peerstore, isNotNull);
    });

    test('localPeer - identifies local peer id', () {
      expect(dialer.localPeer, isNotNull);
    });

    test('dialPeer() - opens connection to peer', () async {
      final conn = await dialer.dialPeer(NetworkContext.empty, peer);
      expect(conn, isNotNull);
    });

    test('closePeer() - disconnects all connections to peer', () async {
      await expectLater(dialer.closePeer(peer), completes);
    });

    test('connectedness() - returns connectedness state for peer', () {
      expect(dialer.connectedness(peer), equals(Connectedness.connected));
    });

    test('peers() - lists connected peers', () {
      expect(dialer.peers(), contains(peer));
    });

    test('conns() - lists all active connections', () {
      expect(dialer.conns(), isEmpty);
    });

    test('connsToPeer() - lists connections to target peer', () {
      expect(dialer.connsToPeer(peer), isEmpty);
    });

    test('notify() - registers notifiee callbacks', () {
      expect(() => dialer.notify(globalNoopNotifiee), returnsNormally);
    });

    test('stopNotify() - unregisters notifiee callbacks', () {
      expect(() => dialer.stopNotify(globalNoopNotifiee), returnsNormally);
    });

    test('canDial() - evaluates dialability of peer and address', () {
      expect(dialer.canDial(peer, addr), isTrue);
    });
  });

  group('Network [Atomic Audit]', () {
    final Network net = _TestNetwork();
    final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
    final addr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');

    test('close() - closes network instance', () async {
      await expectLater(net.close(), completes);
    });

    test('setStreamHandler() - registers protocol stream handler', () {
      expect(() => net.setStreamHandler((s) {}), returnsNormally);
    });

    test('newStream() - opens stream to peer', () async {
      final s = await net.newStream(NetworkContext.empty, peer);
      expect(s.id, equals('net-stream-1'));
    });

    test('listen() - listens on given multiaddrs', () async {
      await expectLater(net.listen([addr]), completes);
    });

    test('listenAddresses() - lists configured listen addresses', () {
      expect(net.listenAddresses(), isEmpty);
    });

    test('interfaceListenAddresses() - resolves system interface listen addresses', () async {
      final addrs = await net.interfaceListenAddresses();
      expect(addrs, isEmpty);
    });

    test('resourceManager - provides resource manager handle', () {
      expect(net.resourceManager, isNotNull);
    });
  });

  group('ConnSecurity [Atomic Audit]', () {
    final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
    final pub = Ed25519Signer().publicKeyFromBytes(Uint8List(32));
    final sec = _TestConnSecurity(peer, unmarshalEd25519PublicKey(Uint8List(32)));

    test('localPeer() - returns local peer id', () {
      expect(sec.localPeer(), equals(peer));
    });

    test('remotePeer() - returns remote peer id', () {
      expect(sec.remotePeer(), equals(peer));
    });

    test('remotePublicKey() - returns remote public key', () {
      expect(sec.remotePublicKey().type, equals(KeyType.ed25519));
    });

    test('connState() - returns negotiated connection state', () {
      expect(sec.connState().transport, equals('tcp'));
    });
  });

  group('ConnMultiaddrs [Atomic Audit]', () {
    final addr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
    final cm = _TestConnMultiaddrs(addr);

    test('localMultiaddr() - returns local endpoint', () {
      expect(cm.localMultiaddr(), equals(addr));
    });

    test('remoteMultiaddr() - returns remote endpoint', () {
      expect(cm.remoteMultiaddr(), equals(addr));
    });
  });

  group('ConnStat [Atomic Audit]', () {
    test('stat() - returns connection statistics', () {
      final ConnStat cs = _TestConnStat();
      expect(cs.stat().direction, equals(Direction.inbound));
    });
  });

  group('ConnScoper [Atomic Audit]', () {
    test('scope() - returns connection scope', () {
      final ConnScoper cs = _TestConnScoper();
      expect(cs.scope(), isNotNull);
    });
  });

  group('Notifiee [Atomic Audit]', () {
    final Notifiee n = globalNoopNotifiee;
    final net = _TestNetwork();
    final addr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
    final conn = _TestConn();

    test('listen() - callback when network starts listening', () {
      expect(() => n.listen(net, addr), returnsNormally);
    });

    test('listenClose() - callback when network stops listening', () {
      expect(() => n.listenClose(net, addr), returnsNormally);
    });

    test('connected() - callback when connection opened', () {
      expect(() => n.connected(net, conn), returnsNormally);
    });

    test('disconnected() - callback when connection closed', () {
      expect(() => n.disconnected(net, conn), returnsNormally);
    });
  });

  group('NotifyBundle [Atomic Audit]', () {
    var listened = false;
    var listenClosed = false;
    var wasConnected = false;
    var wasDisconnected = false;

    final nb = NotifyBundle(
      listenF: (n, a) => listened = true,
      listenCloseF: (n, a) => listenClosed = true,
      connectedF: (n, c) => wasConnected = true,
      disconnectedF: (n, c) => wasDisconnected = true,
    );

    final net = _TestNetwork();
    final addr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
    final conn = _TestConn();

    test('listen() - invokes listenF closure', () {
      nb.listen(net, addr);
      expect(listened, isTrue);
    });

    test('listenClose() - invokes listenCloseF closure', () {
      nb.listenClose(net, addr);
      expect(listenClosed, isTrue);
    });

    test('connected() - invokes connectedF closure', () {
      nb.connected(net, conn);
      expect(wasConnected, isTrue);
    });

    test('disconnected() - invokes disconnectedF closure', () {
      nb.disconnected(net, conn);
      expect(wasDisconnected, isTrue);
    });
  });

  group('NoopNotifiee [Atomic Audit]', () {
    const n = NoopNotifiee();
    final net = _TestNetwork();
    final addr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
    final conn = _TestConn();

    test('listen() - performs no operation on listen', () {
      expect(() => n.listen(net, addr), returnsNormally);
    });

    test('listenClose() - performs no operation on listenClose', () {
      expect(() => n.listenClose(net, addr), returnsNormally);
    });

    test('connected() - performs no operation on connected', () {
      expect(() => n.connected(net, conn), returnsNormally);
    });

    test('disconnected() - performs no operation on disconnected', () {
      expect(() => n.disconnected(net, conn), returnsNormally);
    });
  });

  group('ResourceScope [Atomic Audit]', () {
    final ResourceScope scope = const NullScope();

    test('reserveMemory() - attempts memory reservation', () {
      expect(() => scope.reserveMemory(1024, reservationPriorityLow), returnsNormally);
    });

    test('releaseMemory() - releases previously allocated memory', () {
      expect(() => scope.releaseMemory(1024), returnsNormally);
    });

    test('stat() - returns current scope usage statistics', () {
      expect(scope.stat(), isA<ScopeStat>());
    });

    test('beginSpan() - opens scoped transaction span', () {
      expect(scope.beginSpan(), isNotNull);
    });
  });

  group('ResourceScopeSpan [Atomic Audit]', () {
    test('done() - concludes resource scope span', () {
      final ResourceScopeSpan span = const NullScope();
      expect(() => span.done(), returnsNormally);
    });
  });

  group('ServiceScope [Atomic Audit]', () {
    test('name() - reports service scope name', () {
      final ServiceScope scope = const NullScope();
      expect(scope.name(), isA<String>());
    });
  });

  group('ProtocolScope [Atomic Audit]', () {
    test('protocol() - reports protocol identifier', () {
      final ProtocolScope scope = const NullScope();
      expect(scope.protocol(), isA<String>());
    });
  });

  group('PeerScope [Atomic Audit]', () {
    test('peer() - reports associated peer id', () {
      final PeerScope scope = const NullScope();
      expect(scope.peer(), isA<PeerId>());
    });
  });

  group('ConnManagementScope [Atomic Audit]', () {
    final ConnManagementScope scope = const NullScope();
    final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');

    test('peerScope() - retrieves associated peer scope', () {
      expect(scope.peerScope(), isNotNull);
    });

    test('setPeer() - binds peer to connection scope', () {
      expect(() => scope.setPeer(peer), returnsNormally);
    });
  });

  group('StreamManagementScope [Atomic Audit]', () {
    final StreamManagementScope scope = const NullScope();
    final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');

    test('protocolScope() - returns protocol scope handle', () {
      expect(scope.protocolScope(), isNotNull);
    });

    test('setProtocol() - assigns protocol identifier to stream scope', () {
      expect(() => scope.setProtocol('/echo/1'), returnsNormally);
    });

    test('serviceScope() - returns service scope handle', () {
      expect(scope.serviceScope(), isNotNull);
    });

    test('setService() - assigns service identifier to stream scope', () {
      expect(() => scope.setService('my-service'), returnsNormally);
    });

    test('peerScope() - returns peer scope handle', () {
      expect(scope.peerScope(), isNotNull);
    });
  });

  group('StreamScope [Atomic Audit]', () {
    test('setService() - sets service name on stream scope', () {
      final StreamScope scope = const NullScope();
      expect(() => scope.setService('svc'), returnsNormally);
    });
  });

  group('ResourceScopeViewer [Atomic Audit]', () {
    final ResourceScopeViewer viewer = const NullResourceManager();
    final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');

    test('viewSystem() - visits system resource scope', () {
      expect(() => viewer.viewSystem((s) {}), returnsNormally);
    });

    test('viewTransient() - visits transient resource scope', () {
      expect(() => viewer.viewTransient((s) {}), returnsNormally);
    });

    test('viewService() - visits service resource scope', () {
      expect(() => viewer.viewService('svc', (s) {}), returnsNormally);
    });

    test('viewProtocol() - visits protocol resource scope', () {
      expect(() => viewer.viewProtocol('/p/1', (s) {}), returnsNormally);
    });

    test('viewPeer() - visits peer resource scope', () {
      expect(() => viewer.viewPeer(peer, (s) {}), returnsNormally);
    });
  });

  group('ResourceManager [Atomic Audit]', () {
    final ResourceManager mgr = const NullResourceManager();
    final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
    final addr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');

    test('openConnection() - creates connection management scope', () {
      final connScope = mgr.openConnection(Direction.inbound, false, addr);
      expect(connScope, isNotNull);
    });

    test('verifySourceAddress() - validates source address against limiter', () {
      expect(mgr.verifySourceAddress(addr), isFalse);
    });

    test('openStream() - creates stream management scope', () {
      final streamScope = mgr.openStream(peer, Direction.outbound);
      expect(streamScope, isNotNull);
    });

    test('close() - shuts down resource manager instance', () {
      expect(() => mgr.close(), returnsNormally);
    });
  });

  group('MissingConnManagementScopeException [Atomic Audit]', () {
    test('toString() - returns message description without dots', () {
      const exc = MissingConnManagementScopeException();
      expect(exc.toString(), contains('no ConnManagementScope'));
    });
  });

  group('NullResourceManager [Atomic Audit]', () {
    const mgr = NullResourceManager();
    final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
    final addr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');

    test('viewSystem() - visits null scope on system', () {
      expect(() => mgr.viewSystem((s) {}), returnsNormally);
    });

    test('viewTransient() - visits null scope on transient', () {
      expect(() => mgr.viewTransient((s) {}), returnsNormally);
    });

    test('viewService() - visits null scope on service', () {
      expect(() => mgr.viewService('svc', (s) {}), returnsNormally);
    });

    test('viewProtocol() - visits null scope on protocol', () {
      expect(() => mgr.viewProtocol('/p/1', (s) {}), returnsNormally);
    });

    test('viewPeer() - visits null scope on peer', () {
      expect(() => mgr.viewPeer(peer, (s) {}), returnsNormally);
    });

    test('openConnection() - returns null scope for connection', () {
      expect(mgr.openConnection(Direction.inbound, false, addr), isA<NullScope>());
    });

    test('verifySourceAddress() - returns false in null resource manager', () {
      expect(mgr.verifySourceAddress(addr), isFalse);
    });

    test('openStream() - returns null scope for stream', () {
      expect(mgr.openStream(peer, Direction.outbound), isA<NullScope>());
    });

    test('close() - performs no operation on close', () {
      expect(() => mgr.close(), returnsNormally);
    });
  });

  group('NullScope [Atomic Audit]', () {
    const scope = NullScope();
    final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');

    test('reserveMemory() - noop reserve memory', () {
      expect(() => scope.reserveMemory(10, 1), returnsNormally);
    });

    test('releaseMemory() - noop release memory', () {
      expect(() => scope.releaseMemory(10), returnsNormally);
    });

    test('stat() - returns empty scope stat', () {
      expect(scope.stat().memory, equals(0));
    });

    test('beginSpan() - returns null scope span', () {
      expect(scope.beginSpan(), isA<NullScope>());
    });

    test('done() - noop done on span', () {
      expect(() => scope.done(), returnsNormally);
    });

    test('name() - returns empty string', () {
      expect(scope.name(), isEmpty);
    });

    test('protocol() - returns empty protocol string', () {
      expect(scope.protocol(), isEmpty);
    });

    test('peer() - returns empty peer id', () {
      expect(scope.peer().value, isEmpty);
    });

    test('peerScope() - returns null scope', () {
      expect(scope.peerScope(), isA<NullScope>());
    });

    test('setPeer() - noop setPeer', () {
      expect(() => scope.setPeer(peer), returnsNormally);
    });

    test('protocolScope() - returns null scope for protocol', () {
      expect(scope.protocolScope(), isA<NullScope>());
    });

    test('setProtocol() - noop setProtocol', () {
      expect(() => scope.setProtocol('/p/1'), returnsNormally);
    });

    test('serviceScope() - returns null scope for service', () {
      expect(scope.serviceScope(), isA<NullScope>());
    });

    test('setService() - noop setService', () {
      expect(() => scope.setService('svc'), returnsNormally);
    });
  });

  group('AddrInfo [Atomic Audit]', () {
    final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
    final addr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
    final info = AddrInfo(id: peer, addrs: [addr]);

    test('toString() - produces formatted string without dots', () {
      expect(info.toString(), contains(peer.toString()));
    });

    test('loggable() - creates map with loggable properties', () {
      final log = info.loggable();
      expect(log['peerID'], equals(peer.toString()));
    });

    test('toJson() - serializes to json map representation', () {
      final json = info.toJson();
      expect(json['ID'], equals(peer.toBase58()));
      expect((json['Addrs'] as List), isNotEmpty);
    });

    test('toJsonString() - encodes to json string', () {
      final str = info.toJsonString();
      expect(str, contains(peer.toBase58()));
    });

    test('operator == - compares AddrInfo instances for structural equality', () {
      final info2 = AddrInfo(id: peer, addrs: [addr]);
      final info3 = AddrInfo(id: peer, addrs: []);
      expect(info == info2, isTrue);
      expect(info == info3, isFalse);
    });

    test('hashCode - computes consistent hash code', () {
      final info2 = AddrInfo(id: peer, addrs: [addr]);
      expect(info.hashCode, equals(info2.hashCode));
    });
  });

  group('EmptyPeerIdException [Atomic Audit]', () {
    test('toString() - returns exception description without dots', () {
      const exc = EmptyPeerIdException();
      expect(exc.toString(), contains('empty'));
    });
  });

  group('NoPublicKeyException [Atomic Audit]', () {
    test('toString() - returns exception description without dots', () {
      const exc = NoPublicKeyException();
      expect(exc.toString(), contains('public key'));
    });
  });

  group('InvalidPeerIdSourceException [Atomic Audit]', () {
    test('toString() - returns exception description without dots', () {
      const exc = InvalidPeerIdSourceException();
      expect(exc.toString(), contains('invalid'));
    });
  });

  group('PeerId [Atomic Audit]', () {
    final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');

    test('isEmpty - checks if underlying value buffer is empty', () {
      expect(peer.isEmpty, isFalse);
      expect(PeerId(value: Uint8List(0)).isEmpty, isTrue);
    });

    test('validate() - verifies peer id integrity', () {
      expect(() => peer.validate(), returnsNormally);
    });

    test('toBase58() - encodes peer id in base58btc', () {
      expect(peer.toBase58(), isNotEmpty);
    });

    test('toBase36() - encodes peer id in base36 string', () {
      expect(peer.toBase36(), isNotEmpty);
    });

    test('shortString() - produces abbreviated representation', () {
      expect(peer.shortString(), isNotEmpty);
    });

    test('toCid() - converts peer id to cid instance', () {
      final cid = peer.toCid();
      expect(cid.version, equals(1));
    });

    test('matchesPublicKey() - tests if peer matches given public key', () async {
      final key = await generateEd25519KeyPair();
      final pub = key.getPublic();
      final p = PeerId.fromPublicKey(pub.raw(), type: 'ed25519');
      expect(p.matchesPublicKey(pub), isTrue);
    });

    test('matchesPrivateKey() - tests if peer matches given private key', () async {
      final key = await generateEd25519KeyPair();
      final p = PeerId.fromPublicKey(key.getPublic().raw(), type: 'ed25519');
      expect(p.matchesPrivateKey(key), isTrue);
    });

    test('extractPublicKey() - extracts embedded public key if present', () {
      final rawKey = Uint8List(32);
      final p = PeerId.fromPublicKey(rawKey, type: 'ed25519');
      expect(p.extractPublicKey().type, equals(KeyType.ed25519));
    });

    test('marshalBinary() - serializes raw peer id bytes', () {
      expect(peer.marshalBinary(), equals(peer.value));
    });

    test('unmarshalBinary() - restores peer id from binary bytes', () {
      final restored = PeerId.unmarshalBinary(peer.marshalBinary());
      expect(restored, equals(peer));
    });

    test('marshalText() - serializes peer id as text bytes', () {
      expect(peer.marshalText(), isNotEmpty);
    });

    test('unmarshalText() - decodes peer id from text bytes', () {
      final text = peer.marshalText();
      final restored = PeerId.unmarshalText(text);
      expect(restored, equals(peer));
    });

    test('operator == - tests structural equality of peer ids', () {
      final p2 = PeerId(value: Uint8List.fromList(peer.value));
      final p3 = PeerId(value: Uint8List.fromList([9, 8, 7]));
      expect(peer == p2, isTrue);
      expect(peer == p3, isFalse);
    });

    test('hashCode - returns consistent hash code', () {
      final p2 = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
      expect(peer.hashCode, equals(p2.hashCode));
    });

    test('toString() - returns base58 or text representation', () {
      expect(peer.toString(), isNotEmpty);
    });

    test('compareTo() - orders peer ids lexicographically', () {
      final pSmall = PeerId(value: Uint8List.fromList([1]));
      final pLarge = PeerId(value: Uint8List.fromList([2]));
      expect(pSmall.compareTo(pLarge), lessThan(0));
    });

    test('verifyPoW() - verifies proof of work difficulty on peer id', () {
      expect(peer.verifyPoW(difficulty: 0), isTrue);
    });
  });

  group('PeerRecord [Atomic Audit]', () {
    final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
    final rec = PeerRecord(peerId: peer, addrs: []);

    test('domain() - returns peer record signature domain', () {
      expect(rec.domain(), equals(peerRecordEnvelopeDomain));
    });

    test('codec() - returns peer record payload codec bytes', () {
      expect(rec.codec(), equals(peerRecordEnvelopePayloadType));
    });

    test('marshalRecord() - serializes peer record payload bytes', () {
      expect(rec.marshalRecord(), isNotEmpty);
    });

    test('unmarshalRecord() - updates record from serialized bytes', () {
      final bytes = rec.marshalRecord();
      final rec2 = PeerRecord(peerId: PeerId(value: Uint8List(0)));
      rec2.unmarshalRecord(bytes);
      expect(rec2.peerId, equals(peer));
    });

    test('toProtobuf() - encodes record to protobuf bytes', () {
      expect(rec.toProtobuf(), isNotEmpty);
    });

    test('equals() - checks equality of peer records', () {
      final rec2 = PeerRecord(peerId: peer, addrs: [], seq: rec.seq);
      expect(rec.equals(rec2), isTrue);
    });
  });

  group('EmptyDomainException [Atomic Audit]', () {
    test('toString() - returns descriptive exception string without dots', () {
      const exc = EmptyDomainException();
      expect(exc.toString(), contains('domain'));
    });
  });

  group('EmptyPayloadTypeException [Atomic Audit]', () {
    test('toString() - returns descriptive exception string without dots', () {
      const exc = EmptyPayloadTypeException();
      expect(exc.toString(), contains('payloadType'));
    });
  });

  group('InvalidSignatureException [Atomic Audit]', () {
    test('toString() - returns descriptive exception string without dots', () {
      const exc = InvalidSignatureException();
      expect(exc.toString(), contains('signature'));
    });
  });

  group('PayloadTypeNotRegisteredException [Atomic Audit]', () {
    test('toString() - returns descriptive exception string without dots', () {
      const exc = PayloadTypeNotRegisteredException();
      expect(exc.toString(), contains('payload type'));
    });
  });

  group('RoutingNotFoundException [Atomic Audit]', () {
    test('toString() - returns descriptive exception string without dots', () {
      const exc = RoutingNotFoundException();
      expect(exc.toString(), contains('not found'));
    });
  });

  group('RoutingNotSupportedException [Atomic Audit]', () {
    test('toString() - returns descriptive exception string without dots', () {
      const exc = RoutingNotSupportedException();
      expect(exc.toString(), contains('not supported'));
    });
  });

  group('Record [Atomic Audit]', () {
    final Record rec = PeerRecord(peerId: PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N'));

    test('domain() - returns record domain identifier', () {
      expect(rec.domain(), isNotEmpty);
    });

    test('codec() - returns record codec payload type', () {
      expect(rec.codec(), isNotEmpty);
    });

    test('marshalRecord() - serializes record to payload bytes', () {
      expect(rec.marshalRecord(), isNotEmpty);
    });

    test('unmarshalRecord() - deserializes payload bytes into record', () {
      final bytes = rec.marshalRecord();
      final rec2 = PeerRecord(peerId: PeerId(value: Uint8List(0)));
      rec2.unmarshalRecord(bytes);
      expect((rec2 as PeerRecord).peerId, equals((rec as PeerRecord).peerId));
    });
  });

  group('Envelope [Atomic Audit]', () {
    test('seal() - signs a record into an envelope', () async {
      final key = await generateEd25519KeyPair();
      final rec = PeerRecord(peerId: PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N'));
      final env = await Envelope.seal(rec, key);
      expect(env, isNotNull);
      expect(env.payloadType, equals(rec.codec()));
    });

    test('consumeEnvelope() - validates and opens envelope using registered type', () async {
      registerType(() => PeerRecord(peerId: PeerId(value: Uint8List(0))));
      final key = await generateEd25519KeyPair();
      final rec = PeerRecord(peerId: PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N'));
      final env = await Envelope.seal(rec, key);
      final marshaled = env.marshal();

      final (consumedEnv, consumedRec) = await Envelope.consumeEnvelope(marshaled, rec.domain());
      expect(consumedEnv.equals(env), isTrue);
      expect((consumedRec as PeerRecord).peerId, equals(rec.peerId));
    });

    test('consumeTypedEnvelope() - validates and opens envelope into target record', () async {
      final key = await generateEd25519KeyPair();
      final rec = PeerRecord(peerId: PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N'));
      final env = await Envelope.seal(rec, key);
      final marshaled = env.marshal();

      final dest = PeerRecord(peerId: PeerId(value: Uint8List(0)));
      final consumedEnv = await Envelope.consumeTypedEnvelope(marshaled, dest);
      expect(consumedEnv.equals(env), isTrue);
      expect(dest.peerId, equals(rec.peerId));
    });

    test('marshal() - serializes envelope to protobuf binary format', () async {
      final key = await generateEd25519KeyPair();
      final rec = PeerRecord(peerId: PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N'));
      final env = await Envelope.seal(rec, key);
      final bytes = env.marshal();
      expect(bytes, isNotEmpty);
    });

    test('equals() - checks envelope equality based on key payload and sig', () async {
      final key = await generateEd25519KeyPair();
      final rec = PeerRecord(peerId: PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N'));
      final env1 = await Envelope.seal(rec, key);
      final env2 = Envelope.unmarshal(env1.marshal());
      expect(env1.equals(env2), isTrue);
    });

    test('record() - unmarshals payload via registered type factory', () async {
      registerType(() => PeerRecord(peerId: PeerId(value: Uint8List(0))));
      final key = await generateEd25519KeyPair();
      final rec = PeerRecord(peerId: PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N'));
      final env = await Envelope.seal(rec, key);
      final r = env.record();
      expect((r as PeerRecord).peerId, equals(rec.peerId));
    });

    test('typedRecord() - unmarshals raw payload into explicit record instance', () async {
      final key = await generateEd25519KeyPair();
      final rec = PeerRecord(peerId: PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N'));
      final env = await Envelope.seal(rec, key);
      final dest = PeerRecord(peerId: PeerId(value: Uint8List(0)));
      env.typedRecord(dest);
      expect(dest.peerId, equals(rec.peerId));
    });
  });

  group('Router [Atomic Audit]', () {
    final Router router = _TestRouter();
    Future<void> dummyHandler(ProtocolId p, Object s) async {}

    test('addHandler() - registers protocol handler', () {
      router.addHandler('/echo/1', dummyHandler);
      expect(router.protocols(), contains('/echo/1'));
    });

    test('addHandlerWithFunc() - registers protocol with custom match function', () {
      router.addHandlerWithFunc('/match/1', (p) => p == '/match/1', dummyHandler);
      expect(router.protocols(), contains('/match/1'));
    });

    test('removeHandler() - unregisters protocol handler', () {
      router.addHandler('/temp/1', dummyHandler);
      router.removeHandler('/temp/1');
      expect(router.protocols(), isNot(contains('/temp/1')));
    });

    test('protocols() - lists registered protocols', () {
      expect(router.protocols(), isA<List<ProtocolId>>());
    });
  });

  group('Negotiator [Atomic Audit]', () {
    final Negotiator neg = _TestNegotiator();

    test('negotiate() - negotiates protocol over stream', () async {
      final (proto, handler) = await neg.negotiate(Object());
      expect(proto, equals('/echo/1'));
      expect(handler, isNotNull);
    });

    test('handle() - handles incoming negotiation on stream', () async {
      await expectLater(neg.handle(Object()), completes);
    });
  });

  group('RoutingOptions [Atomic Audit]', () {
    test('apply() - applies sequence of routing option functions', () {
      final opts = RoutingOptions();
      opts.apply([expiredOption, offlineOption]);
      expect(opts.expired, isTrue);
      expect(opts.offline, isTrue);
    });

    test('toOption() - converts options to composable option function', () {
      final opts1 = RoutingOptions()..expired = true..offline = true;
      final opt = opts1.toOption();
      final opts2 = RoutingOptions();
      opt(opts2);
      expect(opts2.expired, isTrue);
      expect(opts2.offline, isTrue);
    });
  });

  group('QueryEvent [Atomic Audit]', () {
    final event = QueryEvent(
      id: PeerId(value: Uint8List.fromList([1, 2, 3])),
      type: sendingQuery,
      responses: [],
      extra: 'test-event',
    );

    test('toJson() - converts event to map representation', () {
      final map = event.toJson();
      expect(map['Extra'], equals('test-event'));
      expect(map['Type'], equals(sendingQuery));
    });

    test('toJsonString() - encodes event as json string', () {
      final str = event.toJsonString();
      expect(str, contains('test-event'));
    });
  });

  group('QueryEventRegistration [Atomic Audit]', () {
    test('events - exposes stream of query events', () {
      final reg = registerForQueryEvents();
      expect(reg.events, isA<Stream<QueryEvent>>());
      reg.close();
    });

    test('run() - executes action within query event zone', () {
      final reg = registerForQueryEvents();
      final result = reg.run(() {
        expect(subscribesToQueryEvents(), isTrue);
        return 42;
      });
      expect(result, equals(42));
      reg.close();
    });

    test('close() - closes query event stream', () {
      final reg = registerForQueryEvents();
      expect(() => reg.close(), returnsNormally);
    });
  });

  group('ContentProviding [Atomic Audit]', () {
    final cid = Cid.decode('bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi');
    final ContentProviding cp = _TestContentProviding();

    test('provide() - publishes cid to routing system', () async {
      await cp.provide(cid, true);
      expect((cp as _TestContentProviding).provided, contains(cid));
    });
  });

  group('ContentDiscovery [Atomic Audit]', () {
    final cid = Cid.decode('bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi');
    final ContentDiscovery cd = _TestContentDiscovery();

    test('findProvidersAsync() - streams providers for cid', () async {
      final providers = await cd.findProvidersAsync(cid, 0).toList();
      expect(providers, isNotEmpty);
      expect(providers.first.id, equals(PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N')));
    });
  });

  group('PeerRouting [Atomic Audit]', () {
    final PeerRouting pr = _TestPeerRouting();
    final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');

    test('findPeer() - searches for peer address information', () async {
      final info = await pr.findPeer(peer);
      expect(info.id, equals(peer));
    });
  });

  group('ValueStore [Atomic Audit]', () {
    final ValueStore vs = _TestValueStore();
    final data = Uint8List.fromList([10, 20, 30]);

    test('putValue() - adds value to store', () async {
      await vs.putValue('k1', data);
      expect(await vs.getValue('k1'), equals(data));
    });

    test('getValue() - retrieves value by key from store', () async {
      await vs.putValue('k2', data);
      final res = await vs.getValue('k2');
      expect(res, equals(data));
    });

    test('searchValue() - searches stream for best value matches', () async {
      await vs.putValue('k3', data);
      final values = await vs.searchValue('k3').toList();
      expect(values, contains(data));
    });
  });

  group('Routing [Atomic Audit]', () {
    final Routing routing = _TestRouting();

    test('bootstrap() - signals routing system to bootstrap', () async {
      await routing.bootstrap();
      expect((routing as _TestRouting).bootstrapped, isTrue);
    });
  });

  group('PubKeyFetcher [Atomic Audit]', () {
    test('getPublicKey() - fetches public key directly from optimized source', () async {
      final kp = await generateEd25519KeyPair();
      final pub = kp.getPublic();
      final PubKeyFetcher fetcher = _TestPubKeyFetcher(pub);
      final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
      final retrieved = await fetcher.getPublicKey(peer);
      expect(retrieved.keyEquals(pub), isTrue);
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test('addrInfoFromP2pAddr() - constructs addr info from multiaddr with p2p', () {
      final ma = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001/p2p/QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
      final info = addrInfoFromP2pAddr(ma);
      expect(info.id.toBase58(), equals('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N'));
      expect(info.addrs, isNotEmpty);
    });

    test('addrInfoFromString() - parses multiaddr string to addr info', () {
      final info = addrInfoFromString('/ip4/127.0.0.1/tcp/4001/p2p/QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
      expect(info.id.toBase58(), equals('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N'));
    });

    test('addrInfoToP2pAddrs() - formats addr info back into p2p multiaddrs', () {
      final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
      final info = AddrInfo(id: peer, addrs: [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')]);
      final addrs = addrInfoToP2pAddrs(info);
      expect(addrs, isNotEmpty);
      expect(addrs.first.toString(), contains('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N'));
    });

    test('addrInfosFromP2pAddrs() - groups multiple p2p addresses by peer', () {
      final ma = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001/p2p/QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
      final list = addrInfosFromP2pAddrs([ma]);
      expect(list.length, equals(1));
      expect(list.first.id.toBase58(), equals('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N'));
    });

    test('addrInfosToIds() - maps list of addr infos to peer ids', () {
      final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
      final info = AddrInfo(id: peer, addrs: []);
      final ids = addrInfosToIds([info]);
      expect(ids, equals([peer]));
    });

    test('bumpOverwrite() - replaces score with incoming delta', () {
      final fn = bumpOverwrite();
      final res = fn(_makeDecayingValue(10, lastVisit: DateTime.now()), 99);
      expect(res, equals(99));
    });

    test('bumpSumBounded() - adds delta respecting min and max boundaries', () {
      final fn = bumpSumBounded(0, 50);
      expect(fn(_makeDecayingValue(10, lastVisit: DateTime.now()), 20), equals(30));
      expect(fn(_makeDecayingValue(10, lastVisit: DateTime.now()), 60), equals(50));
      expect(fn(_makeDecayingValue(10, lastVisit: DateTime.now()), -30), equals(0));
    });

    test('bumpSumUnbounded() - adds delta without ceiling or floor', () {
      final fn = bumpSumUnbounded();
      expect(fn(_makeDecayingValue(10, lastVisit: DateTime.now()), 100), equals(110));
    });

    test('convertFromStrings() - casts string list to protocol id list', () {
      final protos = convertFromStrings(['/echo/1', '/chat/1']);
      expect(protos, equals(['/echo/1', '/chat/1']));
    });

    test('convertToStrings() - casts protocol id list to strings', () {
      final list = convertToStrings(['/echo/1']);
      expect(list, equals(['/echo/1']));
    });

    test('decayExpireWhenInactive() - removes tag if inactive duration exceeded', () {
      final fn = decayExpireWhenInactive(const Duration(minutes: 30));
      final futureTime = DateTime.now().add(const Duration(hours: 1));
      final res = fn(_makeDecayingValue(10, lastVisit: futureTime));
      expect(res.remove, isTrue);
    });

    test('decayFixed() - decrements score by constant amount', () {
      final fn = decayFixed(4);
      final res = fn(_makeDecayingValue(10, lastVisit: DateTime.now()));
      expect(res.after, equals(6));
      expect(res.remove, isFalse);
    });

    test('decayLinear() - scales score by linear fractional factor', () {
      final fn = decayLinear(0.5);
      final res = fn(_makeDecayingValue(20, lastVisit: DateTime.now()));
      expect(res.after, equals(10));
      expect(res.remove, isFalse);
    });

    test('decayNone() - preserves existing score without decay', () {
      final fn = decayNone();
      final res = fn(_makeDecayingValue(42, lastVisit: DateTime.now()));
      expect(res.after, equals(42));
      expect(res.remove, isFalse);
    });

    test('decryptFrame() - decrypts single ciphertext frame', () async {
      final key = Uint8List(32);
      final csSender = CipherState(key: key);
      final csReceiver = CipherState(key: key);
      final plain = Uint8List.fromList([5, 6, 7, 8]);
      final frames = await encryptFrames(csSender, plain);
      final decrypted = await decryptFrame(csReceiver, frames.first.sublist(2));
      expect(decrypted, equals(plain));
    });

    test('ed25519KeyPairFromSeed() - generates ed25519 key from 32 byte seed', () async {
      final seed = Uint8List(32);
      final kp = await ed25519KeyPairFromSeed(seed);
      expect(kp.type, equals(KeyType.ed25519));
    });

    test('encodePkcs1PrivateKey() - encodes rsa key to pkcs1 der structure', () {
      final der = _hexToBytes(_sampleRsaPrivateDerHex);
      final seq = ASN1Sequence.fromBytes(der);
      BigInt intAt(int i) => (seq.elements![i] as ASN1Integer).integer!;
      final pcKey = pc.RSAPrivateKey(intAt(1), intAt(3), intAt(4), intAt(5));
      final encoded = encodePkcs1PrivateKey(pcKey);
      expect(encoded, equals(der));
    });

    test('encodePkixEcPublicKey() - encodes ecdsa public key to pkix', () {
      final pcParams = pc.ECCurve_secp256r1();
      final pcPub = pc.ECPublicKey((pcParams.G * BigInt.two)!, pcParams);
      final der = encodePkixEcPublicKey(pcPub);
      expect(der, isNotEmpty);
    });

    test('encodePkixPublicKey() - encodes rsa public key to pkix spki', () {
      final der = _hexToBytes(_sampleRsaPublicDerHex);
      final seq = ASN1Sequence.fromBytes(der);
      final bitString = seq.elements![1] as ASN1BitString;
      final inner = ASN1Sequence.fromBytes(Uint8List.fromList(bitString.stringValues!));
      final n = (inner.elements![0] as ASN1Integer).integer!;
      final e = (inner.elements![1] as ASN1Integer).integer!;
      final encoded = encodePkixPublicKey(pc.RSAPublicKey(n, e));
      expect(encoded, equals(der));
    });

    test('encodeProtoVarint() - encodes integer value as leb128 varint bytes', () {
      final bytes = encodeProtoVarint(300);
      expect(bytes, equals(Uint8List.fromList([0xac, 0x02])));
    });

    test('encodeSec1EcPrivateKey() - encodes ecdsa private key in sec1 format', () {
      final pcParams = pc.ECCurve_secp256r1();
      final pcPriv = pc.ECPrivateKey(BigInt.two, pcParams);
      final pcPub = pc.ECPublicKey((pcParams.G * BigInt.two)!, pcParams);
      final der = encodeSec1EcPrivateKey(pcPriv, pcPub);
      expect(der, isNotEmpty);
    });

    test('encryptFrames() - splits and encrypts plaintext into length prefixed frames', () async {
      final cs = CipherState(key: Uint8List(32));
      final plain = Uint8List.fromList([1, 2, 3]);
      final frames = await encryptFrames(cs, plain);
      expect(frames, isNotEmpty);
      expect(frames.first.length, greaterThan(3));
    });

    test('expiredOption() - sets expired flag on routing options', () {
      final opts = RoutingOptions();
      expiredOption(opts);
      expect(opts.expired, isTrue);
    });

    test('generateEcdsaKeyPair() - generates ecdsa private public keypair', () {
      final priv = generateEcdsaKeyPair();
      expect(priv.type, equals(KeyType.ecdsa));
      expect(priv.getPublic().type, equals(KeyType.ecdsa));
    });

    test('generateEd25519KeyPair() - generates random ed25519 keypair', () async {
      final kp = await generateEd25519KeyPair();
      expect(kp.type, equals(KeyType.ed25519));
    });

    test('generateNoiseHandshakePayload() - builds signed noise handshake payload', () async {
      final idKey = await generateEd25519KeyPair();
      final staticKp = await generateNoiseKeyPair();
      final payload = await generateNoiseHandshakePayload(
        localIdentityKey: idKey,
        localNoiseStaticPublicKey: staticKp.publicKeyBytes,
      );
      expect(payload, isNotEmpty);
    });

    test('generateNoiseKeyPair() - generates 25519 keypair for noise session', () async {
      final kp = await generateNoiseKeyPair();
      expect(kp.publicKeyBytes.length, equals(32));
    });

    test('generateRsaKeyPair() - validates minimum rsa bit length', () {
      expect(() => generateRsaKeyPair(1024), throwsArgumentError);
    });

    test('generateSecp256k1KeyPair() - generates secp256k1 keypair', () {
      final priv = generateSecp256k1KeyPair();
      expect(priv.type, equals(KeyType.secp256k1));
    });

    test('getAllowLimitedConn() - extracts allow limited conn flag from context', () {
      final ctx = withAllowLimitedConn(NetworkContext.empty, 'testing');
      final (allow, reason) = getAllowLimitedConn(ctx);
      expect(allow, isTrue);
      expect(reason, equals('testing'));
    });

    test('getDialPeerTimeout() - retrieves dial peer timeout from context', () {
      final ctx = withDialPeerTimeout(NetworkContext.empty, const Duration(seconds: 15));
      expect(getDialPeerTimeout(ctx), equals(const Duration(seconds: 15)));
    });

    test('getForceDirectDial() - extracts force direct dial reason from context', () {
      final ctx = withForceDirectDial(NetworkContext.empty, 'force');
      final (force, reason) = getForceDirectDial(ctx);
      expect(force, isTrue);
      expect(reason, equals('force'));
    });

    test('getNoDial() - reads no dial flag and reason from network context', () {
      final ctx = withNoDial(NetworkContext.empty, 'nodial');
      final (nodial, reason) = getNoDial(ctx);
      expect(nodial, isTrue);
      expect(reason, equals('nodial'));
    });

    test('getPublicKey() - retrieves public key from value store or peer id', () async {
      final kp = await generateEd25519KeyPair();
      final pub = kp.getPublic();
      final fetcher = _TestPubKeyFetcher(pub);
      final store = _TestValueStoreRouting(fetcher);
      final p = PeerId.fromPublicKey(pub.raw(), type: 'ed25519');
      final result = await getPublicKey(store, p);
      expect(result.keyEquals(pub), isTrue);
    });

    test('getSimultaneousConnect() - extracts simultaneous connect details', () {
      final ctx = withSimultaneousConnect(NetworkContext.empty, true, 'simult');
      final (simult, isClient, reason) = getSimultaneousConnect(ctx);
      expect(simult, isTrue);
      expect(isClient, isTrue);
      expect(reason, equals('simult'));
    });

    test('getUseTransient() - reads use transient alias flag from context', () {
      final ctx = withUseTransient(NetworkContext.empty, 'transient');
      final (use, reason) = getUseTransient(ctx);
      expect(use, isTrue);
      expect(reason, equals('transient'));
    });

    test('idFromP2pAddr() - parses peer id component from p2p multiaddr', () {
      final ma = Multiaddr.parse('/p2p/QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
      final peer = idFromP2pAddr(ma);
      expect(peer.toBase58(), equals('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N'));
    });

    test('keyForPublicKey() - generates storage routing key for public key lookup', () {
      final peer = PeerId(value: Uint8List.fromList([65, 66, 67]));
      expect(keyForPublicKey(peer), equals('/pk/ABC'));
    });

    test('limit() - creates discovery option setting result limit', () {
      final opt = limit(25);
      final opts = DiscoveryOptions();
      opt(opts);
      expect(opts.limit, equals(25));
    });

    test('marshalKeyProto() - serializes key type and data into protobuf payload', () {
      final bytes = marshalKeyProto(KeyType.ed25519, Uint8List(32));
      expect(bytes, isNotEmpty);
    });

    test('marshalPrivateKey() - encodes private key to protobuf bytes', () async {
      final kp = await generateEd25519KeyPair();
      final bytes = marshalPrivateKey(kp);
      expect(bytes, isNotEmpty);
    });

    test('marshalPublicKey() - encodes public key to protobuf bytes', () async {
      final kp = await generateEd25519KeyPair();
      final bytes = marshalPublicKey(kp.getPublic());
      expect(bytes, isNotEmpty);
    });

    test('offlineOption() - sets offline flag on routing options', () {
      final opts = RoutingOptions();
      offlineOption(opts);
      expect(opts.offline, isTrue);
    });

    test('peerIdFromCid() - extracts peer id from libp2p key cid', () {
      final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
      final cid = peer.toCid();
      final restored = peerIdFromCid(cid);
      expect(restored, equals(peer));
    });

    test('peerIdToCid() - converts peer id into cid format', () {
      final peer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
      final cid = peerIdToCid(peer);
      expect(cid.version, equals(1));
    });

    test('publishQueryEvent() - broadcasts event to active registration channel', () async {
      final reg = registerForQueryEvents();
      final futureEvent = reg.events.first;
      reg.run(() {
        publishQueryEvent(QueryEvent(
          id: PeerId(value: Uint8List.fromList([1])),
          type: sendingQuery,
          extra: 'ev',
        ));
      });
      final ev = await futureEvent;
      expect(ev.extra, equals('ev'));
      await reg.close();
    });

    test('readProtoVarint() - reads leb128 varint integer from byte buffer', () {
      final encoded = encodeProtoVarint(12345);
      final (val, len) = readProtoVarint(encoded, 0);
      expect(val, equals(12345));
      expect(len, equals(encoded.length));
    });

    test('registerForQueryEvents() - initializes query event registration channel', () {
      final reg = registerForQueryEvents();
      expect(reg, isNotNull);
      reg.close();
    });

    test('registerType() - registers record factory with global type registry', () {
      registerType(() => PeerRecord(peerId: PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N')));
      final targetPeer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
      final unmarshaled = unmarshalRecordPayload(
        peerRecordEnvelopePayloadType,
        PeerRecord(peerId: targetPeer).marshalRecord(),
      );
      expect((unmarshaled as PeerRecord).peerId, equals(targetPeer));
    });

    test('splitAddr() - separates transport address from trailing peer id', () {
      final ma = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001/p2p/QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
      final (transport, peer) = splitAddr(ma);
      expect(transport.toString(), equals('/ip4/127.0.0.1/tcp/4001'));
      expect(peer?.toBase58(), equals('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N'));
    });

    test('subscribesToQueryEvents() - checks if current zone has event listener', () {
      expect(subscribesToQueryEvents(), isFalse);
      final reg = registerForQueryEvents();
      reg.run(() {
        expect(subscribesToQueryEvents(), isTrue);
      });
      reg.close();
    });

    test('supportsDecay() - checks if connection manager supports decaying tags', () {
      final (decayer, supported) = supportsDecay(const NullConnMgr());
      expect(supported, isFalse);
      expect(decayer, isNull);
    });

    test('timestampSeq() - produces monotonically increasing timestamp sequence', () {
      final s1 = timestampSeq();
      final s2 = timestampSeq();
      expect(s2, greaterThanOrEqualTo(s1));
    });

    test('ttl() - creates discovery option setting ttl duration', () {
      final opt = ttl(const Duration(minutes: 10));
      final opts = DiscoveryOptions();
      opt(opts);
      expect(opts.ttl, equals(const Duration(minutes: 10)));
    });

    test('unmarshalEcdsaPrivateKey() - deserializes ecdsa private key from sec1 bytes', () {
      final pcParams = pc.ECCurve_secp256r1();
      final pcPriv = pc.ECPrivateKey(BigInt.two, pcParams);
      final pcPub = pc.ECPublicKey((pcParams.G * BigInt.two)!, pcParams);
      final der = encodeSec1EcPrivateKey(pcPriv, pcPub);
      final restored = unmarshalEcdsaPrivateKey(der);
      expect(restored.type, equals(KeyType.ecdsa));
    });

    test('unmarshalEcdsaPublicKey() - deserializes ecdsa public key from pkix bytes', () {
      final pcParams = pc.ECCurve_secp256r1();
      final pcPub = pc.ECPublicKey((pcParams.G * BigInt.two)!, pcParams);
      final der = encodePkixEcPublicKey(pcPub);
      final restored = unmarshalEcdsaPublicKey(der);
      expect(restored.type, equals(KeyType.ecdsa));
    });

    test('unmarshalEd25519PrivateKey() - restores ed25519 private key from raw bytes', () async {
      final kp = await generateEd25519KeyPair();
      final restored = await unmarshalEd25519PrivateKey(kp.raw());
      expect(restored.type, equals(KeyType.ed25519));
    });

    test('unmarshalEd25519PublicKey() - restores ed25519 public key from 32 byte buffer', () {
      final pub = unmarshalEd25519PublicKey(Uint8List(32));
      expect(pub.type, equals(KeyType.ed25519));
    });

    test('unmarshalKeyProto() - parses key type and raw payload from protobuf', () {
      final payload = marshalKeyProto(KeyType.ed25519, Uint8List(32));
      final (type, raw) = unmarshalKeyProto(payload);
      expect(type, equals(KeyType.ed25519));
      expect(raw.length, equals(32));
    });

    test('unmarshalPrivateKey() - deserializes generic private key from envelope', () async {
      final kp = await generateEd25519KeyPair();
      final marshaled = marshalPrivateKey(kp);
      final restored = await unmarshalPrivateKey(marshaled);
      expect(restored.type, equals(KeyType.ed25519));
    });

    test('unmarshalPublicKey() - deserializes generic public key from envelope', () async {
      final kp = await generateEd25519KeyPair();
      final marshaled = marshalPublicKey(kp.getPublic());
      final restored = unmarshalPublicKey(marshaled);
      expect(restored.type, equals(KeyType.ed25519));
    });

    test('unmarshalRecordPayload() - builds and unmarshals registered payload type', () {
      final targetPeer = PeerId.decode('QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N');
      registerType(() => PeerRecord(peerId: targetPeer));
      final rec = PeerRecord(peerId: targetPeer);
      final restored = unmarshalRecordPayload(peerRecordEnvelopePayloadType, rec.marshalRecord());
      expect((restored as PeerRecord).peerId, equals(targetPeer));
    });

    test('unmarshalRsaPrivateKey() - parses pkcs1 rsa private key from der bytes', () {
      final der = _hexToBytes(_sampleRsaPrivateDerHex);
      final key = unmarshalRsaPrivateKey(der);
      expect(key.type, equals(KeyType.rsa));
    });

    test('unmarshalRsaPublicKey() - parses pkix rsa public key from der bytes', () {
      final der = _hexToBytes(_sampleRsaPublicDerHex);
      final key = unmarshalRsaPublicKey(der);
      expect(key.type, equals(KeyType.rsa));
    });

    test('unmarshalSecp256k1PrivateKey() - parses 32 byte scalar into secp256k1 key', () {
      final priv = generateSecp256k1KeyPair();
      final restored = unmarshalSecp256k1PrivateKey(priv.raw());
      expect(restored.type, equals(KeyType.secp256k1));
    });

    test('unmarshalSecp256k1PublicKey() - parses sec1 point into secp256k1 public key', () {
      final priv = generateSecp256k1KeyPair();
      final pub = priv.getPublic();
      final restored = unmarshalSecp256k1PublicKey(pub.raw());
      expect(restored.type, equals(KeyType.secp256k1));
    });

    test('unwrapConnManagementScope() - extracts conn scope or throws missing exception', () {
      final ctx = withConnManagementScope(NetworkContext.empty, const NullScope());
      final scope = unwrapConnManagementScope(ctx);
      expect(scope, isA<NullScope>());
    });

    test('verifyNoiseHandshakePayload() - verifies signature on remote static key', () async {
      final idKey = await generateEd25519KeyPair();
      final staticKp = await generateNoiseKeyPair();
      final payload = await generateNoiseHandshakePayload(
        localIdentityKey: idKey,
        localNoiseStaticPublicKey: staticKp.publicKeyBytes,
      );
      final identity = await verifyNoiseHandshakePayload(payload, staticKp.publicKeyBytes);
      expect(identity.publicKey.keyEquals(idKey.getPublic()), isTrue);
    });

    test('withAllowLimitedConn() - decorates network context with allow limited flag', () {
      final ctx = withAllowLimitedConn(NetworkContext.empty, 'allow-lim');
      expect(ctx.allowLimitedConnReason, equals('allow-lim'));
    });

    test('withConnManagementScope() - attaches conn management scope to context', () {
      final ctx = withConnManagementScope(NetworkContext.empty, const NullScope());
      expect(ctx.connManagementScope, isA<NullScope>());
    });

    test('withDialPeerTimeout() - attaches dial peer timeout duration to context', () {
      final ctx = withDialPeerTimeout(NetworkContext.empty, const Duration(seconds: 45));
      expect(ctx.dialPeerTimeout, equals(const Duration(seconds: 45)));
    });

    test('withForceDirectDial() - attaches force direct dial reason to context', () {
      final ctx = withForceDirectDial(NetworkContext.empty, 'forced');
      expect(ctx.forceDirectDialReason, equals('forced'));
    });

    test('withNoDial() - attaches no dial reason to network context', () {
      final ctx = withNoDial(NetworkContext.empty, 'nodial-reason');
      expect(ctx.noDialReason, equals('nodial-reason'));
    });

    test('withSimultaneousConnect() - attaches simultaneous connect client or server reason', () {
      final ctx = withSimultaneousConnect(NetworkContext.empty, false, 'server-side');
      expect(ctx.simultaneousConnectServerReason, equals('server-side'));
    });

    test('withUseTransient() - attaches deprecated use transient reason to context', () {
      final ctx = withUseTransient(NetworkContext.empty, 'transient-reason');
      expect(ctx.allowLimitedConnReason, equals('transient-reason'));
    });
  });
}
