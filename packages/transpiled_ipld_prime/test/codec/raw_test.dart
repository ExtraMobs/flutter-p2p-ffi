// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-ipld-prime's codec/raw/codec_test.go TestRoundtrip and
// TestDecodeBuffer. TestRoundtripCidlink remains with linking/cid, which is
// not ported yet.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_ipld_prime/codec/raw.dart' as raw;
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

void main() {
  final vectors = <String, List<int>>{
    'Empty': const [],
    'Plaintext': 'hello there'.codeUnits,
    'JSON': '{"foo": "bar"}'.codeUnits,
    'NullBytes': const [0, 0],
  };

  test('Encode and Decode implement the codec function types', () {
    final Encoder encoder = raw.encode;
    final Decoder decoder = raw.decode;
    expect(encoder, isA<Encoder>());
    expect(decoder, isA<Decoder>());
  });

  for (final MapEntry(key: name, value: bytes) in vectors.entries) {
    test('TestRoundtrip/$name', () {
      final builder = prototype.bytes.newBuilder();
      raw.decode(builder, bytes);

      final sink = _CollectingSink();
      raw.encode(builder.build(), sink);

      expect(sink.bytes, bytes);
    });
  }

  test('TestDecodeBuffer: generic iterable is consumed', () {
    final builder = prototype.bytes.newBuilder();
    raw.decode(builder, 'hello there'.codeUnits.map((byte) => byte));
    expect(builder.build().asBytes(), 'hello there'.codeUnits);
  });

  test('TestDecodeBuffer: Uint8List backing bytes are reused', () {
    final bytes = Uint8List.fromList('hello there'.codeUnits);
    final builder = prototype.bytes.newBuilder();
    raw.decode(builder, bytes);
    expect(identical(builder.build().asBytes(), bytes), isTrue);
  });

  test('Decode wraps reader failures like Go', () {
    final builder = prototype.bytes.newBuilder();
    expect(
      () => raw.decode(builder, _failingReader()),
      throwsA(
        predicate(
          (Object error) =>
              error.toString() == 'could not decode raw node: Bad state: boom',
        ),
      ),
    );
  });
}

Iterable<int> _failingReader() sync* {
  throw StateError('boom');
}

final class _CollectingSink implements Sink<List<int>> {
  final BytesBuilder _builder = BytesBuilder();

  Uint8List get bytes => _builder.toBytes();

  @override
  void add(List<int> data) => _builder.add(data);

  @override
  void close() {}
}
