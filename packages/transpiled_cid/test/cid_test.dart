// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_multicodec/transpiled_multicodec.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

void main() {
  group('Cid', () {
    test('creates Cid v0 from 32-byte SHA2-256 hash', () {
      final hash = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        hash[i] = i;
      }
      final cid = Cid.v0(hash);
      expect(cid.version, equals(0));
      expect(cid.codec, equals('dag-pb'));
      expect(cid.encode(), startsWith('Qm'));
    });

    test('creates Cid v1 from content', () async {
      final data = Uint8List.fromList(utf8.encode('hello world'));
      final cid = await Cid.fromContent(data);
      expect(cid.version, equals(1));
      expect(cid.codec, equals('raw'));
      expect(cid.encode(), startsWith('b'));
    });

    test('round-trips Cid through string encoding', () async {
      final data = Uint8List.fromList(utf8.encode('round-trip'));
      final cid = await Cid.fromContent(data);
      final decoded = Cid.decode(cid.encode());
      expect(decoded, equals(cid));
      expect(decoded.multihash.toBytes(), equals(cid.multihash.toBytes()));
    });

    test('round-trips Cid v1 through bytes', () async {
      final data = Uint8List.fromList(utf8.encode('byte-trip'));
      final cid = await Cid.fromContent(data, codec: 'dag-cbor');
      final bytes = cid.toBytes();
      final decoded = Cid.fromBytes(bytes);
      expect(decoded, equals(cid));
    });

    test('returns CIDv0 bytes from toBytes', () {
      final hash = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        hash[i] = i;
      }
      final cid = Cid.v0(hash);
      final bytes = cid.toBytes();
      expect(bytes.length, equals(34));
      expect(bytes[0], equals(0x12));
      expect(bytes[1], equals(0x20));
    });

    test('toPrefixBytes omits digest', () async {
      final data = Uint8List.fromList(utf8.encode('prefix-test'));
      final cid = await Cid.fromContent(data);
      final prefix = cid.toPrefixBytes();
      final bytes = cid.toBytes();
      expect(prefix.length, lessThan(bytes.length));
      expect(bytes.sublist(0, prefix.length), equals(prefix));
    });

    test('Cid v1 encodes with different bases', () async {
      final data = Uint8List.fromList(utf8.encode('base-test'));
      final cid = await Cid.fromContent(data);
      final base32 = cid.encodeWithBaseName('base32');
      final base64 = cid.encodeWithBaseName('base64');
      expect(base32, isNot(equals(base64)));
      expect(Cid.decode(base32), equals(cid));
      expect(Cid.decode(base64), equals(cid));
    });

    test(' Cid v0 rejects non-32-byte hash', () {
      expect(() => Cid.v0(Uint8List(16)), throwsArgumentError);
    });
  });

  group('Multicodec', () {
    test('looks up codec codes', () {
      expect(Multicodec.code('raw'), equals(0x55));
      expect(Multicodec.code('dag-pb'), equals(0x70));
      expect(Multicodec.code('dag-cbor'), equals(0x71));
    });

    test('looks up codec names', () {
      expect(Multicodec.name(0x55), equals('raw'));
      expect(Multicodec.name(0x70), equals('dag-pb'));
    });

    test('rejects unsupported codec', () {
      expect(() => Multicodec.code('unsupported'), throwsArgumentError);
      expect(() => Multicodec.name(0xffff), throwsArgumentError);
    });
  });

  group('Cid gap-closing additions (Phase 1)', () {
    test('fromContent with version:0 produces a CIDv0', () async {
      final data = Uint8List.fromList(utf8.encode('cidv0-content'));
      final cid = await Cid.fromContent(data, version: 0);
      expect(cid.version, equals(0));
      expect(cid.codec, equals('dag-pb'));
      expect(cid.encode(), startsWith('Qm'));
    });

    test('fromContent rejects unsupported hashType', () async {
      final data = Uint8List.fromList(utf8.encode('x'));
      expect(
        () => Cid.fromContent(data, hashType: 'sha3-256'),
        throwsUnsupportedError,
      );
    });

    test('computeForData matches fromContent for the same input', () async {
      final data = Uint8List.fromList(utf8.encode('compute-for-data'));
      final a = await Cid.computeForData(data, format: 'dag-cbor');
      final b = await Cid.fromContent(data, codec: 'dag-cbor');
      expect(a, equals(b));
    });

    test('computeForDataSync matches the async fromContent digest', () async {
      final data = Uint8List.fromList(utf8.encode('sync-vs-async'));
      final sync = Cid.computeForDataSync(data);
      final async = await Cid.fromContent(data);
      expect(sync, equals(async));
    });

    test(
      'fromPrefixBytes reconstructs the same Cid given matching data',
      () async {
        final data = Uint8List.fromList(utf8.encode('prefix-reconstruction'));
        final original = await Cid.fromContent(data, codec: 'dag-cbor');
        final rebuilt = await Cid.fromPrefixBytes(
          original.toPrefixBytes(),
          data,
        );
        expect(rebuilt, equals(original));
      },
    );

    test('validate accepts a well-formed CIDv1', () async {
      final data = Uint8List.fromList(utf8.encode('valid'));
      final cid = await Cid.fromContent(data);
      expect(cid.validate(), isTrue);
    });

    test('validate rejects a CIDv0 with a non-dag-pb codec', () {
      final hash = Uint8List(32);
      final malformed = Cid(
        version: 0,
        multihash: MultihashUtils.sha256(hash),
        codec: 'raw',
      );
      expect(malformed.validate(), isFalse);
    });
  });

  group('MultihashUtils', () {
    test('encodes SHA2-256 digest', () {
      final digest = Uint8List(32);
      final mh = MultihashUtils.sha256(digest);
      final bytes = mh.toBytes();
      expect(bytes.length, greaterThan(32));
      expect(bytes[0], equals(0x12));
      expect(bytes[1], equals(0x20));
    });

    test('decodes multihash', () {
      final digest = Uint8List(32);
      final mh = MultihashUtils.sha256(digest);
      final info = MultihashUtils.decode(mh.toBytes());
      expect(info.name, equals('sha2-256'));
      expect(info.size, equals(32));
    });
  });
}
