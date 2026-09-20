import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart' as hive;
import 'package:test/test.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart' as ds;
import 'package:transpiled_ipfs/transpiled_ipfs.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart' as p2p;
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../interop/lib/local_kubo_harness.dart';

class _TestRepo implements Repo {
  _TestRepo(this.settings, this.store);
  final IpfsConfig settings;
  final ds.Batching store;
  int closes = 0;

  @override
  Future<IpfsConfig> config() async => settings.copyWith(
    identity: settings.identity == null
        ? null
        : Identity(
            peerId: settings.identity!.peerId,
            privKey: settings.identity!.privKey,
          ),
  );

  @override
  ds.Batching datastore() => store;

  @override
  Future<void> close() async {
    closes++;
    await store.close();
  }
}

class _FailWrites extends ds.MapDatastore {
  final failure = StateError('storage unavailable');
  @override
  Future<void> put(ds.Key key, List<int> value) async => throw failure;
}

// Application-side datastore adapter used to prove the Repo integration with
// the installed Hive backend. No storage implementation is mocked here.
class _DiskDatastore extends ds.MapDatastore {
  _DiskDatastore(this.box);
  final hive.Box<dynamic> box;

  static Future<_DiskDatastore> open(String path) async {
    final store = _DiskDatastore(
      await hive.Hive.openBox<dynamic>('node-store', path: path),
    );
    for (final key in store.box.keys) {
      await store._load(
        ds.Key(key as String),
        List<int>.from(store.box.get(key) as List),
      );
    }
    return store;
  }

  Future<void> _load(ds.Key key, List<int> value) => super.put(key, value);

  @override
  Future<void> put(ds.Key key, List<int> value) async {
    await box.put(key.value, value);
    await super.put(key, value);
  }

  @override
  Future<void> delete(ds.Key key) async {
    await box.delete(key.value);
    await super.delete(key);
  }

  @override
  Future<void> sync(ds.Key prefix) => box.flush();

  @override
  Future<void> close() => box.close();
}

Future<_TestRepo> _openDiskRepo(Directory directory) async {
  final json =
      jsonDecode(await File('${directory.path}/config').readAsString())
          as Map<String, dynamic>;
  final identity = json['Identity'] as Map<String, dynamic>;
  return _TestRepo(
    IpfsConfig(
      identity: Identity(
        peerId: identity['PeerID'] as String,
        privKey: identity['PrivKey'] as String,
      ),
      network: NetworkConfig(
        mdnsEnabled: false,
        bootstrapPeers: List<String>.from(
          json['Bootstrap'] as List? ?? const [],
        ),
      ),
    ),
    await _DiskDatastore.open(directory.path),
  );
}

Future<IpfsConfig> _config() async {
  final key = await p2p.generateEd25519KeyPair();
  return IpfsConfig(
    identity: Identity(
      peerId: p2p.PeerId.fromPubKey(key.getPublic()).toString(),
      privKey: base64.encode(p2p.marshalPrivateKey(key)),
    ),
    network: const NetworkConfig(mdnsEnabled: false),
  );
}

void main() {
  group('Blockstore [Atomic Audit]', () {
    test(
      'allKeysChanWithErr() - delegates persistent key enumeration',
      () async {
        final store = Blockstore(datastore: ds.MapDatastore());
        final bytes = Uint8List.fromList([42]);
        final cid = await Cid.fromContent(bytes);
        await store.put(BasicBlock(bytes, cid));
        expect(await (await store.allKeysChanWithErr()).toList(), [cid]);
        await store.close();
      },
    );
  });
  test(
    'reprovider automatically announces a block restored from disk to Kubo',
    () async {
      final kubo = await LocalKuboHarness.start(routingType: 'dhtserver');
      addTearDown(kubo.dispose);
      final directory = await Directory.systemTemp.createTemp(
        'dart-ipfs-reprovide-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final config = await _config();
      await File('${directory.path}/config').writeAsString(
        jsonEncode({
          'Identity': {
            'PeerID': config.identity!.peerId,
            'PrivKey': config.identity!.privKey,
          },
          'Bootstrap': [kubo.swarmAddress],
        }),
        flush: true,
      );
      final offline = await IpfsNode.fromBuildCfg(
        BuildCfg(repo: await _openDiskRepo(directory)),
      );
      addTearDown(offline.close);
      final bytes = Uint8List.fromList(
        'persisted block for automatic reprovide ${DateTime.now().microsecondsSinceEpoch}'
            .codeUnits,
      );
      final cid = await offline.putRawBlock(bytes);
      await offline.close();
      final repo = await _openDiskRepo(directory);
      final online = await IpfsNode.fromBuildCfg(
        BuildCfg(online: true, repo: repo),
      );
      addTearDown(online.close);
      await online.connect(addrInfoFromString(kubo.swarmAddress));
      var providers = '';
      // No explicit provide: use the upstream one-minute initial timer.
      final deadline = DateTime.now().add(const Duration(seconds: 85));
      while (DateTime.now().isBefore(deadline)) {
        providers = await kubo.findProviders(cid.toString());
        if (providers.contains(online.peerId.toString())) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(providers, contains(online.peerId.toString()));
      expect(await kubo.getRawBlock(cid.toString()), bytes);
      expect(
        await repo.datastore().has(ds.Key('/provider/reprovide/lastreprovide')),
        isTrue,
      );
    },
    tags: ['p0'],
    timeout: const Timeout(Duration(seconds: 110)),
  );
  group('Repo [Atomic Audit]', () {
    test('config() - returns a snapshot used by the node', () async {
      final config = await _config();
      final Repo repo = _TestRepo(config, ds.MapDatastore());
      final snapshot = await repo.config();
      expect(snapshot.identity!.peerId, config.identity!.peerId);
      snapshot.identity!.peerId = 'changed';
      expect((await repo.config()).identity!.peerId, config.identity!.peerId);
    });
    test(
      'datastore() - node stores blocks in the supplied datastore',
      () async {
        final repo = _TestRepo(await _config(), ds.MapDatastore());
        final node = await IpfsNode.fromBuildCfg(BuildCfg(repo: repo));
        final cid = await node.putRawBlock(Uint8List.fromList([1, 2, 3]));
        expect(await node.blockstore.has(cid), isTrue);
        expect(
          (await repo.datastore().query(
            const ds.Query(prefix: '/blocks'),
          )).rest(),
          isNotEmpty,
        );
        await node.close();
      },
    );
    test('close() - node owns repository shutdown exactly once', () async {
      final repo = _TestRepo(await _config(), ds.MapDatastore());
      final node = await IpfsNode.fromBuildCfg(BuildCfg(repo: repo));
      await Future.wait([node.close(), node.close()]);
      expect(repo.closes, 1);
    });
  });
  group('IpfsNode [Atomic Audit]', () {
    test(
      'fromBuildCfg() - releases earlier listeners after a bind failure',
      () async {
        final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = probe.port;
        await probe.close();
        final busy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(busy.close);
        final config = (await _config()).copyWith(
          network: NetworkConfig(
            mdnsEnabled: false,
            listenAddresses: [
              '/ip4/127.0.0.1/tcp/$port',
              '/ip4/127.0.0.1/tcp/${busy.port}',
            ],
          ),
        );
        final repo = _TestRepo(config, ds.MapDatastore());
        await expectLater(
          IpfsNode.fromBuildCfg(BuildCfg(online: true, repo: repo)),
          throwsA(isA<SocketException>()),
        );
        expect(repo.closes, 1);
        final rebound = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          port,
        );
        await rebound.close();
      },
    );
    test(
      'fromBuildCfg() - restores identity, peers and content from disk',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'dart-ipfs-repo-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final config = await _config();
        await File('${directory.path}/config').writeAsString(
          jsonEncode({
            'Identity': {
              'PeerID': config.identity!.peerId,
              'PrivKey': config.identity!.privKey,
            },
          }),
          flush: true,
        );
        final first = await IpfsNode.fromBuildCfg(
          BuildCfg(online: true, repo: await _openDiskRepo(directory)),
        );
        addTearDown(first.close);
        final remoteKey = await p2p.generateEd25519KeyPair();
        final remote = p2p.PeerId.fromPubKey(remoteKey.getPublic());
        final addr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
        first.peerHost!.peerstore.addAddr(
          remote,
          addr,
          const Duration(hours: 1),
        );
        first.peerHost!.peerstore.addPubKey(remote, remoteKey.getPublic());
        final bytes = Uint8List.fromList('block preserved on disk'.codeUnits);
        final cid = await first.putRawBlock(bytes);
        final id = first.peerId;
        await first.close();
        final second = await IpfsNode.fromBuildCfg(
          BuildCfg(online: true, repo: await _openDiskRepo(directory)),
        );
        addTearDown(second.close);
        expect(second.peerId, id);
        expect(second.peerHost!.peerstore.addrs(remote), contains(addr));
        expect(
          second.peerHost!.peerstore.pubKey(remote)!.raw(),
          remoteKey.getPublic().raw(),
        );
        expect((await second.blockstore.get(cid)).rawData(), bytes);
      },
    );
    test(
      'fromBuildCfg() - repository restores identity, peers and blocks',
      () async {
        final config = await _config();
        final store = ds.MapDatastore();
        final repo = _TestRepo(config, store);
        final first = await IpfsNode.fromBuildCfg(
          BuildCfg(online: true, repo: repo),
        );
        final id = first.peerId;
        final remoteKey = await p2p.generateEd25519KeyPair();
        final remote = p2p.PeerId.fromPubKey(remoteKey.getPublic());
        final addr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
        first.peerHost!.peerstore.addAddr(
          remote,
          addr,
          const Duration(hours: 1),
        );
        first.peerHost!.peerstore.addPubKey(remote, remoteKey.getPublic());
        final data = Uint8List.fromList('repository-backed block'.codeUnits);
        final cid = await first.putRawBlock(data);
        await first.close();
        expect(repo.closes, 1);
        final secondRepo = _TestRepo(config, store);
        final second = await IpfsNode.fromBuildCfg(
          BuildCfg(online: true, repo: secondRepo),
        );
        addTearDown(second.close);
        expect(second.peerId, id);
        expect(second.peerHost!.peerstore, isA<p2p.Pstoreds>());
        expect(second.peerHost!.peerstore.addrs(remote), contains(addr));
        expect(
          second.peerHost!.peerstore.pubKey(remote)!.raw(),
          remoteKey.getPublic().raw(),
        );
        expect((await second.blockstore.get(cid)).rawData(), data);
      },
    );
    test('fromBuildCfg() - rejects mismatched persisted identity', () async {
      final config = await _config();
      config.identity!.peerId = (await _config()).identity!.peerId;
      final repo = _TestRepo(config, ds.MapDatastore());
      await expectLater(
        IpfsNode.fromBuildCfg(BuildCfg(online: true, repo: repo)),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('private key in config does not match id'),
          ),
        ),
      );
      expect(repo.closes, 1);
    });
    test(
      'close() - releases repository even when peerstore flush fails',
      () async {
        final store = _FailWrites();
        final repo = _TestRepo(await _config(), store);
        final node = await IpfsNode.fromBuildCfg(
          BuildCfg(
            online: true,
            repo: repo,
            shutdownTimeout: const Duration(seconds: 5),
          ),
        );
        await expectLater(node.close(), throwsA(same(store.failure)));
        expect(repo.closes, 1);
      },
    );
  });
  group('BuildCfg [Atomic Audit]', () {
    test('repo - preserves the repository hook', () async {
      final repo = _TestRepo(await _config(), ds.MapDatastore());
      expect(BuildCfg(repo: repo).repo, same(repo));
    });
  });
  group('Identity [Atomic Audit]', () {
    test('peerId - has mutable Go configuration semantics', () {
      final identity = Identity();
      expect(identity.peerId, '');
      identity.peerId = 'peer';
      expect(identity.peerId, 'peer');
    });
    test('privKey - has mutable Go configuration semantics', () {
      final identity = Identity();
      expect(identity.privKey, '');
      identity.privKey = 'key';
      expect(identity.privKey, 'key');
    });
    test(
      'decodePrivateKey() - decodes protobuf and rejects corrupt data',
      () async {
        final identity = (await _config()).identity!;
        final key = await identity.decodePrivateKey('ignored upstream');
        expect(
          p2p.PeerId.fromPubKey(key.getPublic()).toString(),
          identity.peerId,
        );
        identity.privKey = '!';
        expect(
          () => identity.decodePrivateKey(''),
          throwsA(isA<FormatException>()),
        );
      },
    );
    test(
      'decodePrivateKey() - preserves standard Base64 input constraints',
      () async {
        final identity = (await _config()).identity!;
        final encoded = identity.privKey;
        identity.privKey =
            '${encoded.substring(0, 4)}\r\n${encoded.substring(4)}';
        expect(
          p2p.PeerId.fromPubKey(
            (await identity.decodePrivateKey('')).getPublic(),
          ).toString(),
          identity.peerId,
        );
        identity.privKey =
            '%${encoded.codeUnitAt(0).toRadixString(16)}${encoded.substring(1)}';
        expect(
          () => identity.decodePrivateKey(''),
          throwsA(isA<FormatException>()),
        );
        identity.privKey = encoded.replaceAll('=', '');
        expect(
          () => identity.decodePrivateKey(''),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });
  group('IpfsConfig [Atomic Audit]', () {
    test('identity - is preserved by copyWith', () async {
      final config = await _config();
      expect(config.copyWith(offline: false).identity, same(config.identity));
    });
  });
}
