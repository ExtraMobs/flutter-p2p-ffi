import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart' as ds;
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

class _FailFirstWrite extends ds.MapDatastore {
  final failure = StateError('datastore write failed');
  int attempts = 0;

  @override
  Future<void> put(ds.Key key, List<int> value) async {
    if (++attempts == 1) throw failure;
    await super.put(key, value);
  }
}

void main() {
  group('Pstoreds [Atomic Audit]', () {
    test(
      'open() - migrates legacy keys without resurrecting removed peers',
      () async {
        final store = ds.MapDatastore();
        final key = await generateEd25519KeyPair();
        final peer = PeerId.fromPubKey(key.getPublic());
        final oldKey = ds.Key('/peers/keys/${peer.toBase58()}/priv');
        final oldMeta = ds.Key('/peers/metadata/${peer.toBase58()}/agent');
        final oldAddrs = ds.Key('/peers/addrs/${peer.toBase58()}');
        await store.put(oldKey, marshalPrivateKey(key));
        await store.put(oldMeta, '"old-agent"'.codeUnits);
        await store.put(
          oldAddrs,
          AddrBookRecord(
            id: peer.value,
            addrs: [
              AddrBookRecord_AddrEntry(
                addr: Multiaddr.parse('/ip4/127.0.0.1/tcp/4001').toBytes(),
                expiry: DateTime.now()
                    .add(const Duration(hours: 1))
                    .microsecondsSinceEpoch,
                ttl: const Duration(hours: 1).inMicroseconds,
              ),
            ],
          ).marshal(),
        );
        final peerstore = await Pstoreds.open(store);
        expect(peerstore.privKey(peer)!.raw(), key.raw());
        expect(peerstore.get(peer, 'agent'), 'old-agent');
        expect(peerstore.addrs(peer), hasLength(1));
        for (final legacy in [oldKey, oldMeta, oldAddrs]) {
          expect(await store.has(legacy), isFalse);
        }
        peerstore.clearAddrs(peer);
        peerstore.removePeer(peer);
        await peerstore.close();
        final reopened = await Pstoreds.open(store);
        expect(reopened.privKey(peer), isNull);
        expect(reopened.addrs(peer), isEmpty);
        expect(
          () => reopened.get(peer, 'agent'),
          throwsA(isA<ItemNotFoundException>()),
        );
        await reopened.close();
      },
    );

    test(
      'open() - migration write failure preserves the legacy record',
      () async {
        final store = _FailFirstWrite();
        store.attempts = 1;
        final key = await generateEd25519KeyPair();
        final peer = PeerId.fromPubKey(key.getPublic());
        final legacy = ds.Key('/peers/keys/${peer.toBase58()}/priv');
        await store.put(legacy, marshalPrivateKey(key));
        store.attempts = 0;
        await expectLater(Pstoreds.open(store), throwsA(same(store.failure)));
        expect(await store.has(legacy), isTrue);
      },
    );
  });
  group('DsPeerMetadata [Atomic Audit]', () {
    test('put() - uses the upstream unpadded Base32 peer key', () async {
      final store = ds.MapDatastore();
      final peer = PeerId.fromBytes(
        Uint8List.fromList([18, 32, ...List.generate(32, (i) => i)]),
      );
      final book = await DsPeerMetadata.open(store);
      book.put(peer, 'agent', 'dart');
      await book.flush();
      const encodedPeer =
          'CIQAAAICAMCAKBQHBAEQUCYMBUHA6EARCIJRIFIWC4MBSGQ3DQOR4HY';
      expect(
        await store.has(ds.Key('/peers/metadata/$encodedPeer/agent')),
        isTrue,
      );
      final reopened = await DsPeerMetadata.open(store);
      expect(reopened.get(peer, 'agent'), 'dart');
    });
  });
  group('DsAddrBook [Atomic Audit]', () {
    test('clearAddrs() - removes the canonical Base32 record', () async {
      final store = ds.MapDatastore();
      final peer = PeerId.fromBytes(
        Uint8List.fromList([18, 32, ...List.generate(32, (i) => i)]),
      );
      final book = await DsAddrBook.open(store, defaultOpts());
      book.addAddr(
        peer,
        Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'),
        const Duration(hours: 1),
      );
      await book.flush();
      final key = ds.Key(
        '/peers/addrs/CIQAAAICAMCAKBQHBAEQUCYMBUHA6EARCIJRIFIWC4MBSGQ3DQOR4HY',
      );
      expect(await store.has(key), isTrue);
      book.clearAddrs(peer);
      await book.flush();
      expect(await store.has(key), isFalse);
    });
  });
  group('DsKeyBook [Atomic Audit]', () {
    test(
      'flush() - preserves write failure and drains subsequent writes',
      () async {
        final store = _FailFirstWrite();
        final book = await DsKeyBook.open(store);
        final key = await generateEd25519KeyPair();
        final peer = PeerId.fromPubKey(key.getPublic());
        book.addPubKey(peer, key.getPublic());
        book.addPrivKey(peer, key);
        await expectLater(book.flush(), throwsA(same(store.failure)));
        expect(store.attempts, 2);
        final reopened = await DsKeyBook.open(store);
        expect(reopened.privKey(peer)!.raw(), key.raw());
        // A second flush cannot silently erase evidence of the failed write.
        await expectLater(book.flush(), throwsA(same(store.failure)));
      },
    );
  });

  group('DsPeerMetadata [Atomic Audit]', () {
    test(
      'flush() - reports failed write while retaining later durable values',
      () async {
        final store = _FailFirstWrite();
        final book = await DsPeerMetadata.open(store);
        final key = await generateEd25519KeyPair();
        final peer = PeerId.fromPubKey(key.getPublic());
        book.put(peer, 'lost', 'first');
        book.put(peer, 'saved', 'second');
        await expectLater(book.flush(), throwsA(same(store.failure)));
        final reopened = await DsPeerMetadata.open(store);
        expect(
          () => reopened.get(peer, 'lost'),
          throwsA(isA<ItemNotFoundException>()),
        );
        expect(reopened.get(peer, 'saved'), 'second');
      },
    );

    test('put() - encoding failure leaves previous value intact', () async {
      final book = await DsPeerMetadata.open(ds.MapDatastore());
      final key = await generateEd25519KeyPair();
      final peer = PeerId.fromPubKey(key.getPublic());
      book.put(peer, 'agent', 'valid');
      expect(() => book.put(peer, 'agent', Object()), throwsA(anything));
      expect(book.get(peer, 'agent'), 'valid');
      await book.flush();
    });
  });

  group('DsAddrBook [Atomic Audit]', () {
    test('flush() - surfaces address write failure', () async {
      final store = _FailFirstWrite();
      final book = await DsAddrBook.open(store, defaultOpts());
      final key = await generateEd25519KeyPair();
      final peer = PeerId.fromPubKey(key.getPublic());
      book.addAddr(
        peer,
        Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'),
        const Duration(hours: 1),
      );
      await expectLater(book.flush(), throwsA(same(store.failure)));
    });
  });

  group('Pstoreds [Atomic Audit]', () {
    test(
      'close() - cannot report success after a persistence failure',
      () async {
        final store = _FailFirstWrite();
        final peerstore = await Pstoreds.open(store);
        final key = await generateEd25519KeyPair();
        final peer = PeerId.fromPubKey(key.getPublic());
        peerstore.addPrivKey(peer, key);
        await expectLater(peerstore.close(), throwsA(same(store.failure)));
      },
    );
  });
}
