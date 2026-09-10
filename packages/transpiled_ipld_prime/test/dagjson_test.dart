// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

void main() {
  test('DAG-JSON encodes and decodes ordinary nodes and bytes', () {
    final node = PlainMap({
      'n': const PlainInt(3),
      'b': PlainBytes(Uint8List.fromList([1, 2])),
    });
    final out = <int>[];
    encodeDagJson(node, outSink(out));
    expect(String.fromCharCodes(out), '{"b":{"/":{"bytes":"AQI"}},"n":3}');
    final builder = const PrototypeAny().newBuilder();
    decodeDagJson(builder, out);
    expect(builder.build().lookupByString('n').asInt(), 3);
    expect(builder.build().lookupByString('b').asBytes(), [1, 2]);
  });

  test('DAG-JSON matches Go link and padded-bytes forms', () {
    final cid = Cid.decode(
      'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
    );
    final out = <int>[];
    encodeDagJson(PlainLink(CidLink(cid)), outSink(out));
    expect(
      String.fromCharCodes(out),
      '{"/":"bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"}',
    );
    final builder = const PrototypeAny().newBuilder();
    decodeDagJson(builder, '{"/":{"bytes":"ZGVhZGJlZWY="}}'.codeUnits);
    expect(String.fromCharCodes(builder.build().asBytes()), 'deadbeef');
  });

  test('DAG-JSON options can reject links and bytes', () {
    final out = <int>[];
    expect(
      () => encodeDagJsonWithOptions(
        PlainBytes(Uint8List.fromList([1])),
        outSink(out),
        const DagJsonEncodeOptions(encodeBytes: false),
      ),
      throwsA(isA<FormatException>()),
    );
    final bytesBuilder = const PrototypeAny().newBuilder();
    expect(
      () => decodeDagJsonWithOptions(
        bytesBuilder,
        '{"/":{"bytes":"AQI"}}'.codeUnits,
        const DagJsonDecodeOptions(parseBytes: false),
      ),
      throwsA(isA<FormatException>()),
    );
    final depthBuilder = const PrototypeAny().newBuilder();
    expect(
      () => decodeDagJsonWithOptions(
        depthBuilder,
        '[[1]]'.codeUnits,
        const DagJsonDecodeOptions(maxDepth: 1),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

Sink<List<int>> outSink(List<int> out) => _Sink(out);

final class _Sink implements Sink<List<int>> {
  _Sink(this.out);
  final List<int> out;
  @override
  void add(List<int> data) => out.addAll(data);
  @override
  void close() {}
}
