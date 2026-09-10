// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Parity vectors from go-libp2p core/routing's own routing.go (no
// dedicated _test.go upstream for these free functions -- ported behavior
// is exercised directly here and, more thoroughly, by
// transpiled_libp2p_record's PublicKeyValidator, which relies on the
// matching key format).
import 'dart:typed_data';

import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:test/test.dart';

class _FakeValueStore implements ValueStore {
  _FakeValueStore(this.values);

  final Map<String, Uint8List> values;

  @override
  Future<void> putValue(
    String key,
    Uint8List value, {
    List<RoutingOption> options = const [],
  }) async {
    values[key] = value;
  }

  @override
  Future<Uint8List> getValue(
    String key, {
    List<RoutingOption> options = const [],
  }) async {
    final value = values[key];
    if (value == null) throw const RoutingNotFoundException();
    return value;
  }

  @override
  Stream<Uint8List> searchValue(
    String key, {
    List<RoutingOption> options = const [],
  }) async* {
    final value = values[key];
    if (value != null) yield value;
  }
}

class _FakePubKeyFetcher implements ValueStore, PubKeyFetcher {
  _FakePubKeyFetcher(this.key);

  final PubKey key;
  bool called = false;

  @override
  Future<PubKey> getPublicKey(PeerId id) async {
    called = true;
    return key;
  }

  @override
  Future<void> putValue(
    String key,
    Uint8List value, {
    List<RoutingOption> options = const [],
  }) async {}

  @override
  Future<Uint8List> getValue(
    String key, {
    List<RoutingOption> options = const [],
  }) async => throw const RoutingNotFoundException();

  @override
  Stream<Uint8List> searchValue(
    String key, {
    List<RoutingOption> options = const [],
  }) async* {}
}

void main() {
  group('keyForPublicKey', () {
    test('is "/pk/<raw peer id bytes>"', () async {
      final keyPair = await generateEd25519KeyPair();
      final id = PeerId.fromPubKey(keyPair.getPublic());
      expect(keyForPublicKey(id), equals('/pk/${String.fromCharCodes(id.value)}'));
    });
  });

  group('getPublicKey', () {
    test('extracts an embedded (identity-multihash) key without touching the store', () async {
      final keyPair = await generateEd25519KeyPair();
      final id = PeerId.fromPubKey(keyPair.getPublic());
      final store = _FakeValueStore({});

      final pk = await getPublicKey(store, id);
      expect(pk.keyEquals(keyPair.getPublic()), isTrue);
    });

    test('prefers a PubKeyFetcher store over a plain value lookup', () async {
      final keyPair = generateRsaKeyPair(2048);
      final id = PeerId.fromPubKey(keyPair.getPublic());
      final fetcher = _FakePubKeyFetcher(keyPair.getPublic());

      final pk = await getPublicKey(fetcher, id);
      expect(fetcher.called, isTrue);
      expect(pk.keyEquals(keyPair.getPublic()), isTrue);
    });

    test('falls back to a plain GetValue lookup for a hashed (RSA) ID', () async {
      final keyPair = generateRsaKeyPair(2048);
      final id = PeerId.fromPubKey(keyPair.getPublic());
      final store = _FakeValueStore({
        keyForPublicKey(id): marshalPublicKey(keyPair.getPublic()),
      });

      final pk = await getPublicKey(store, id);
      expect(pk.keyEquals(keyPair.getPublic()), isTrue);
    });
  });
}
