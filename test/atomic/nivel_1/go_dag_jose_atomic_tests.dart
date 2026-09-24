// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_go_dag_jose/transpiled_go_dag_jose.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart' as ipld_prime;

void main() {
  group('Base64Url', () {
    test('kind()', () {
      final b64 = Base64Url(Uint8List.fromList([1, 2, 3]));
      expect(b64.kind(), ipld_prime.Kind.string);
    });

    test('typeName', () {
      final b64 = Base64Url(Uint8List.fromList([1, 2, 3]));
      expect(b64.typeName, 'dagjose.Base64Url');
    });

    test('asBytes()', () {
      final sample = Uint8List.fromList([1, 2, 3, 4, 5]);
      final b64 = Base64Url(sample);
      expect(b64.asBytes(), equals(sample));
    });

    test('asString()', () {
      final sample = Uint8List.fromList([1, 2, 3, 4, 5]);
      final b64 = Base64Url(sample);
      expect(b64.asString(), encodeBase64Url(sample));
    });

    test('prototype()', () {
      final b64 = Base64Url(Uint8List.fromList([1, 2]));
      final proto = b64.prototype();
      expect(proto, isNotNull);
      final builder = proto.newBuilder();
      builder.assignBytes(Uint8List.fromList([10, 20]));
      expect(builder.build().asBytes(), equals([10, 20]));
    });

    test('link()', () {
      final cid = Cid.decode('bafkreigh2akiscaildcqabsyg3dfr6cvhpvdgahnpbtxdvqvue2whxuh35');
      final b64 = Base64Url(Uint8List.fromList(cid.bytes()));
      final link = b64.link();
      expect(link, isA<ipld_prime.CidLink>());
      expect((link as ipld_prime.CidLink).cid, equals(cid));
    });

    test('operator ==()', () {
      final sample = Uint8List.fromList([1, 2, 3]);
      final b1 = Base64Url(sample);
      final b2 = Base64Url.fromString(encodeBase64Url(sample));
      final b3 = Base64Url(Uint8List.fromList([1, 2, 4]));
      expect(b1 == b2, isTrue);
      expect(b1 == b3, isFalse);
    });

    test('hashCode()', () {
      final sample = Uint8List.fromList([1, 2, 3]);
      final b1 = Base64Url(sample);
      final b2 = Base64Url(Uint8List.fromList([1, 2, 3]));
      expect(b1.hashCode, equals(b2.hashCode));
    });
  });

  group('Raw', () {
    test('kind()', () {
      final raw = Raw(Uint8List.fromList([1, 2, 3]));
      expect(raw.kind(), ipld_prime.Kind.bytes);
    });

    test('typeName', () {
      final raw = Raw(Uint8List.fromList([1, 2, 3]));
      expect(raw.typeName, 'dagjose.Raw');
    });

    test('asBytes()', () {
      final sample = Uint8List.fromList([9, 8, 7]);
      final raw = Raw(sample);
      expect(raw.asBytes(), equals(sample));
    });

    test('asString()', () {
      final sample = Uint8List.fromList([9, 8, 7]);
      final raw = Raw(sample);
      expect(raw.asString(), encodeBase64Url(sample));
    });

    test('prototype()', () {
      final raw = Raw(Uint8List.fromList([1, 2]));
      final proto = raw.prototype();
      expect(proto, isNotNull);
      final builder = proto.newBuilder();
      builder.assignBytes(Uint8List.fromList([10, 20]));
      expect(builder.build().asBytes(), equals([10, 20]));
    });

    test('operator ==()', () {
      final sample = Uint8List.fromList([1, 2, 3]);
      final r1 = Raw(sample);
      final r2 = Raw.fromString(encodeBase64Url(sample));
      final r3 = Raw(Uint8List.fromList([1, 2, 4]));
      expect(r1 == r2, isTrue);
      expect(r1 == r3, isFalse);
    });

    test('hashCode()', () {
      final sample = Uint8List.fromList([1, 2, 3]);
      final r1 = Raw(sample);
      final r2 = Raw(Uint8List.fromList([1, 2, 3]));
      expect(r1.hashCode, equals(r2.hashCode));
    });
  });

  group('DecodeOptions', () {
    test('addLink', () {
      const opts1 = DecodeOptions();
      expect(opts1.addLink, isTrue);
      const opts2 = DecodeOptions(addLink: false);
      expect(opts2.addLink, isFalse);
    });

    test('decode()', () {
      final cid = Cid.decode('bafkreigh2akiscaildcqabsyg3dfr6cvhpvdgahnpbtxdvqvue2whxuh35');
      final jwsMap = ipld_prime.prototype.map.newBuilder();
      final ma = jwsMap.beginMap(1);
      ma.assembleKey().assignString('payload');
      ma.assembleValue().assignBytes(Uint8List.fromList(cid.bytes()));
      ma.finish();

      final encodedSink = <List<int>>[];
      final sink = StreamControllerSink<List<int>>(encodedSink.add);
      encode(jwsMap.build(), sink);
      final bytes = Uint8List.fromList(encodedSink.expand((e) => e).toList());

      const opts = DecodeOptions(addLink: true);
      final builder = ipld_prime.prototype.any.newBuilder();
      opts.decode(builder, bytes);
      final decoded = builder.build();
      expect(decoded.lookupByString('payload').asBytes(), equals(cid.bytes()));
      expect(decoded.lookupByString('link'), isNotNull);
    });

    test('decodeJws()', () {
      final cid = Cid.decode('bafkreigh2akiscaildcqabsyg3dfr6cvhpvdgahnpbtxdvqvue2whxuh35');
      final jwsMap = ipld_prime.prototype.map.newBuilder();
      final ma = jwsMap.beginMap(1);
      ma.assembleKey().assignString('payload');
      ma.assembleValue().assignBytes(Uint8List.fromList(cid.bytes()));
      ma.finish();

      final encodedSink = <List<int>>[];
      final sink = StreamControllerSink<List<int>>(encodedSink.add);
      encodeJws(jwsMap.build(), sink);
      final bytes = Uint8List.fromList(encodedSink.expand((e) => e).toList());

      const opts = DecodeOptions(addLink: false);
      final builder = ipld_prime.prototype.any.newBuilder();
      opts.decodeJws(builder, bytes);
      final decoded = builder.build();
      expect(decoded.lookupByString('payload').asBytes(), equals(cid.bytes()));
      expect(lookupIgnoreNoSuchField('link', decoded), isNull);
    });

    test('decodeJwe()', () {
      final jweMap = ipld_prime.prototype.map.newBuilder();
      final ma = jweMap.beginMap(1);
      ma.assembleKey().assignString('ciphertext');
      ma.assembleValue().assignBytes(Uint8List.fromList([1, 2, 3]));
      ma.finish();

      final encodedSink = <List<int>>[];
      final sink = StreamControllerSink<List<int>>(encodedSink.add);
      encodeJwe(jweMap.build(), sink);
      final bytes = Uint8List.fromList(encodedSink.expand((e) => e).toList());

      const opts = DecodeOptions();
      final builder = ipld_prime.prototype.any.newBuilder();
      opts.decodeJwe(builder, bytes);
      final decoded = builder.build();
      expect(decoded.lookupByString('ciphertext').asBytes(), equals([1, 2, 3]));
    });
  });

  group('Top-Level Functions and Constants', () {
    test('encodeBase64Url()', () {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final enc = encodeBase64Url(data);
      expect(enc, isNotEmpty);
      expect(enc.contains('='), isFalse);
    });

    test('decodeBase64Url()', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final enc = encodeBase64Url(data);
      final dec = decodeBase64Url(enc);
      expect(dec, equals(data));
    });

    test('lookupIgnoreAbsent()', () {
      final map = ipld_prime.prototype.map.newBuilder();
      final ma = map.beginMap(1);
      ma.assembleKey().assignString('foo');
      ma.assembleValue().assignString('bar');
      ma.finish();
      final node = map.build();

      expect(lookupIgnoreAbsent('foo', node)?.asString(), 'bar');
      expect(lookupIgnoreAbsent('non_existent', node), isNull);
    });

    test('lookupIgnoreNoSuchField()', () {
      final map = ipld_prime.prototype.map.newBuilder();
      final ma = map.beginMap(1);
      ma.assembleKey().assignString('hello');
      ma.assembleValue().assignInt(42);
      ma.finish();
      final node = map.build();

      expect(lookupIgnoreNoSuchField('hello', node)?.asInt(), 42);
      expect(lookupIgnoreNoSuchField('absent', node), isNull);
    });

    test('isJws()', () {
      final map = ipld_prime.prototype.map.newBuilder();
      final ma = map.beginMap(1);
      ma.assembleKey().assignString('payload');
      ma.assembleValue().assignString('cid');
      ma.finish();
      expect(isJws(map.build()), isTrue);

      final empty = ipld_prime.prototype.map.newBuilder();
      empty.beginMap(0).finish();
      expect(isJws(empty.build()), isFalse);
    });

    test('isJwe()', () {
      final map = ipld_prime.prototype.map.newBuilder();
      final ma = map.beginMap(1);
      ma.assembleKey().assignString('ciphertext');
      ma.assembleValue().assignString('ct');
      ma.finish();
      expect(isJwe(map.build()), isTrue);

      final empty = ipld_prime.prototype.map.newBuilder();
      empty.beginMap(0).finish();
      expect(isJwe(empty.build()), isFalse);
    });

    test('unflattenJws()', () {
      final cid = Cid.decode('bafkreigh2akiscaildcqabsyg3dfr6cvhpvdgahnpbtxdvqvue2whxuh35');
      final map = ipld_prime.prototype.map.newBuilder();
      final ma = map.beginMap(2);
      ma.assembleKey().assignString('payload');
      ma.assembleValue().assignString(encodeBase64Url(cid.bytes()));
      ma.assembleKey().assignString('signature');
      ma.assembleValue().assignString(encodeBase64Url(utf8.encode('s')));
      ma.finish();
      final unflattened = unflattenJws(map.build());
      expect(unflattened.lookupByString('signatures').length(), 1);
    });

    test('unflattenJwe()', () {
      final map = ipld_prime.prototype.map.newBuilder();
      final ma = map.beginMap(2);
      ma.assembleKey().assignString('ciphertext');
      ma.assembleValue().assignString('ct');
      ma.assembleKey().assignString('encrypted_key');
      ma.assembleValue().assignString('ek');
      ma.finish();
      final unflattened = unflattenJwe(map.build());
      expect(unflattened.lookupByString('recipients').length(), 1);
    });

    test('validateLink()', () {
      final cid = Cid.decode('bafkreigh2akiscaildcqabsyg3dfr6cvhpvdgahnpbtxdvqvue2whxuh35');
      final map = ipld_prime.prototype.map.newBuilder();
      final ma = map.beginMap(2);
      ma.assembleKey().assignString('payload');
      ma.assembleValue().assignBytes(Uint8List.fromList(cid.bytes()));
      ma.assembleKey().assignString('link');
      ma.assembleValue().assignLink(ipld_prime.CidLink(cid));
      ma.finish();
      expect(() => validateLink(map.build()), returnsNormally);
    });

    test('parseJose()', () {
      final cid = Cid.decode('bafkreigh2akiscaildcqabsyg3dfr6cvhpvdgahnpbtxdvqvue2whxuh35');
      final jwsJson = jsonEncode({
        'payload': encodeBase64Url(cid.bytes()),
        'signature': encodeBase64Url(utf8.encode('sig')),
      });
      final node = parseJose(utf8.encode(jwsJson));
      expect(isJws(node), isTrue);
    });

    test('encode()', () {
      final cid = Cid.decode('bafkreigh2akiscaildcqabsyg3dfr6cvhpvdgahnpbtxdvqvue2whxuh35');
      final map = ipld_prime.prototype.map.newBuilder();
      final ma = map.beginMap(1);
      ma.assembleKey().assignString('payload');
      ma.assembleValue().assignBytes(Uint8List.fromList(cid.bytes()));
      ma.finish();
      final sink = StreamControllerSink<List<int>>((_) {});
      expect(() => encode(map.build(), sink), returnsNormally);
    });

    test('encodeJws()', () {
      final cid = Cid.decode('bafkreigh2akiscaildcqabsyg3dfr6cvhpvdgahnpbtxdvqvue2whxuh35');
      final map = ipld_prime.prototype.map.newBuilder();
      final ma = map.beginMap(1);
      ma.assembleKey().assignString('payload');
      ma.assembleValue().assignBytes(Uint8List.fromList(cid.bytes()));
      ma.finish();
      final sink = StreamControllerSink<List<int>>((_) {});
      expect(() => encodeJws(map.build(), sink), returnsNormally);
    });

    test('encodeJwe()', () {
      final map = ipld_prime.prototype.map.newBuilder();
      final ma = map.beginMap(1);
      ma.assembleKey().assignString('ciphertext');
      ma.assembleValue().assignBytes(Uint8List.fromList([1, 2, 3]));
      ma.finish();
      final sink = StreamControllerSink<List<int>>((_) {});
      expect(() => encodeJwe(map.build(), sink), returnsNormally);
    });

    test('decode()', () {
      final cid = Cid.decode('bafkreigh2akiscaildcqabsyg3dfr6cvhpvdgahnpbtxdvqvue2whxuh35');
      final map = ipld_prime.prototype.map.newBuilder();
      final ma = map.beginMap(1);
      ma.assembleKey().assignString('payload');
      ma.assembleValue().assignBytes(Uint8List.fromList(cid.bytes()));
      ma.finish();

      final chunks = <List<int>>[];
      final sink = StreamControllerSink<List<int>>(chunks.add);
      encode(map.build(), sink);
      final bytes = Uint8List.fromList(chunks.expand((e) => e).toList());

      final builder = ipld_prime.prototype.any.newBuilder();
      decode(builder, bytes);
      expect(builder.build().lookupByString('payload').asBytes(), equals(cid.bytes()));
    });

    test('decodeJws()', () {
      final cid = Cid.decode('bafkreigh2akiscaildcqabsyg3dfr6cvhpvdgahnpbtxdvqvue2whxuh35');
      final map = ipld_prime.prototype.map.newBuilder();
      final ma = map.beginMap(1);
      ma.assembleKey().assignString('payload');
      ma.assembleValue().assignBytes(Uint8List.fromList(cid.bytes()));
      ma.finish();

      final chunks = <List<int>>[];
      final sink = StreamControllerSink<List<int>>(chunks.add);
      encodeJws(map.build(), sink);
      final bytes = Uint8List.fromList(chunks.expand((e) => e).toList());

      final builder = ipld_prime.prototype.any.newBuilder();
      decodeJws(builder, bytes);
      expect(builder.build().lookupByString('payload').asBytes(), equals(cid.bytes()));
    });

    test('decodeJwe()', () {
      final map = ipld_prime.prototype.map.newBuilder();
      final ma = map.beginMap(1);
      ma.assembleKey().assignString('ciphertext');
      ma.assembleValue().assignBytes(Uint8List.fromList([7, 8, 9]));
      ma.finish();

      final chunks = <List<int>>[];
      final sink = StreamControllerSink<List<int>>(chunks.add);
      encodeJwe(map.build(), sink);
      final bytes = Uint8List.fromList(chunks.expand((e) => e).toList());

      final builder = ipld_prime.prototype.any.newBuilder();
      decodeJwe(builder, bytes);
      expect(builder.build().lookupByString('ciphertext').asBytes(), equals([7, 8, 9]));
    });

    test('dagJoseCodecCode', () {
      expect(dagJoseCodecCode, 0x85);
    });

    test('registerDagJoseCodec()', () {
      final customRegistry = ipld_prime.Registry();
      registerDagJoseCodec(customRegistry);
      expect(customRegistry.listEncoders(), contains(0x85));
      expect(customRegistry.listDecoders(), contains(0x85));
    });
  });
}

class StreamControllerSink<T> implements Sink<T> {
  final void Function(T) _onAdd;

  StreamControllerSink(this._onAdd);

  @override
  void add(T data) => _onAdd(data);

  @override
  void close() {}
}
