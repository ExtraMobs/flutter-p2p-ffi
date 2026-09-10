// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Parity vectors from go-libp2p-record's own validator_test.go
// (TestValidatePublicKey, TestValidateEd25519PublicKey, TestBadRecords).
import 'dart:typed_data';

import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p_record/transpiled_libp2p_record.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';
import 'package:test/test.dart';

String _pkKeyFor(Uint8List peerIdBytes) =>
    '/pk/${String.fromCharCodes(peerIdBytes)}';

void main() {
  group('PublicKeyValidator', () {
    test('a good RSA public key at its own hash passes', () async {
      const pkv = PublicKeyValidator();
      final keyPair = generateRsaKeyPair(2048);
      final pkb = marshalPublicKey(keyPair.getPublic());
      final pkh = MultihashUtils.sum('sha2-256', pkb);
      final k = '/pk/${String.fromCharCodes(pkh.toBytes())}';

      expect(() => pkv.validate(k, pkb), returnsNormally);
    });

    test('a bad namespace prefix is rejected', () async {
      const pkv = PublicKeyValidator();
      final keyPair = generateRsaKeyPair(2048);
      final pkb = marshalPublicKey(keyPair.getPublic());
      final id = PeerId.fromPubKey(keyPair.getPublic());
      final badKey = '/aa/${String.fromCharCodes(id.value)}';

      expect(() => pkv.validate(badKey, pkb), throwsArgumentError);
    });

    test('a bad key hash is rejected', () async {
      const pkv = PublicKeyValidator();
      final keyPair = generateRsaKeyPair(2048);
      final pkb = marshalPublicKey(keyPair.getPublic());
      final id = PeerId.fromPubKey(keyPair.getPublic());
      final badKey = '/pk/${'A' * id.value.length}';

      // Any exception counts as rejection here, matching Go's test (which
      // only checks err != nil): "AAAA..." isn't a well-formed multihash,
      // so the underlying multihash decoder's own exception type
      // (UnsupportedError, not this class's ArgumentError) surfaces.
      expect(() => pkv.validate(badKey, pkb), throwsA(anything));
    });

    test('a public key that does not match the hash is rejected', () async {
      const pkv = PublicKeyValidator();
      final keyPair = generateRsaKeyPair(2048);
      final otherKeyPair = generateRsaKeyPair(2048);
      final id = PeerId.fromPubKey(keyPair.getPublic());
      final k = _pkKeyFor(id.value);
      final wrongPkb = marshalPublicKey(otherKeyPair.getPublic());

      expect(() => pkv.validate(k, wrongPkb), throwsArgumentError);
    });

    test('a good Ed25519 public key at its own peer ID passes', () async {
      const pkv = PublicKeyValidator();
      final keyPair = await generateEd25519KeyPair();
      final id = PeerId.fromPubKey(keyPair.getPublic());
      final pkb = marshalPublicKey(keyPair.getPublic());
      final k = _pkKeyFor(id.value);

      expect(() => pkv.validate(k, pkb), returnsNormally);
    });

    test('select always returns index 0', () {
      const pkv = PublicKeyValidator();
      expect(
        pkv.select('/pk/thing', [
          Uint8List.fromList('first'.codeUnits),
          Uint8List.fromList('second'.codeUnits),
        ]),
        equals(0),
      );
    });
  });

  group('NamespacedValidator with PublicKeyValidator (TestBadRecords)', () {
    test('rejects every malformed path', () async {
      final v = NamespacedValidator({'pk': const PublicKeyValidator()});
      final keyPair = generateRsaKeyPair(2048);
      final pkb = marshalPublicKey(keyPair.getPublic());

      for (final badPath in const [
        'foo/bar/baz',
        '//foo/bar/baz',
        '/ns',
        'ns',
        'ns/',
        '',
        '//',
        '/',
        '////',
      ]) {
        expect(
          () => v.validate(badPath, pkb),
          throwsA(anything),
          reason: 'expected an error for path "$badPath"',
        );
      }
    });

    test('rejects an unregistered namespace', () async {
      final v = NamespacedValidator({'pk': const PublicKeyValidator()});
      final keyPair = generateRsaKeyPair(2048);
      final pkb = marshalPublicKey(keyPair.getPublic());

      expect(
        () => v.validate('/missing/ns', pkb),
        throwsA(isA<InvalidRecordTypeException>()),
      );
    });

    test('accepts a valid pk record', () async {
      final v = NamespacedValidator({'pk': const PublicKeyValidator()});
      final keyPair = generateRsaKeyPair(2048);
      final pkb = marshalPublicKey(keyPair.getPublic());
      final id = PeerId.fromPubKey(keyPair.getPublic());
      final k = _pkKeyFor(id.value);

      expect(() => v.validate(k, pkb), returnsNormally);
    });
  });

  group('NamespacedValidator.select (TestBestRecord)', () {
    test('selects the first record', () {
      final sel = NamespacedValidator({'pk': const PublicKeyValidator()});
      final i = sel.select('/pk/thing', [
        Uint8List.fromList('first'.codeUnits),
        Uint8List.fromList('second'.codeUnits),
      ]);
      expect(i, equals(0));
    });

    test('throws for no records', () {
      final sel = NamespacedValidator({'pk': const PublicKeyValidator()});
      expect(() => sel.select('/pk/thing', []), throwsArgumentError);
    });

    test('throws for an unregistered namespace', () {
      final sel = NamespacedValidator({'pk': const PublicKeyValidator()});
      expect(
        () => sel.select('/other/thing', [
          Uint8List.fromList('first'.codeUnits),
        ]),
        throwsA(isA<InvalidRecordTypeException>()),
      );
    });

    test('throws for a malformed key', () {
      final sel = NamespacedValidator({'pk': const PublicKeyValidator()});
      expect(
        () => sel.select('bad', [Uint8List.fromList('first'.codeUnits)]),
        throwsA(isA<InvalidRecordTypeException>()),
      );
    });
  });
}
