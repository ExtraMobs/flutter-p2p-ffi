// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-ipld-prime/codec/json/marshal_test.go, plus decoder roundtrips.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_ipld_prime/codec/json.dart' as json_codec;
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

void main() {
  test('encode ordinary values with Go-compatible formatting', () {
    final builder = prototype.any.newBuilder();
    final map = builder.beginMap(2);
    map.assembleEntry('a').assignInt(1);
    map.assembleEntry('b').assignNode(_list(2, 'x'));
    map.finish();
    final sink = _Sink();
    json_codec.encode(builder.build(), sink);
    expect(
      String.fromCharCodes(sink.bytes),
      '{\n\t"a": 1,\n\t"b": [\n\t\t"x",\n\t\t"x"\n\t]\n}\n',
    );
  });

  test('decode ordinary JSON', () {
    final builder = prototype.any.newBuilder();
    json_codec.decode(builder, '{"ok":true,"n":2.5,"none":null}'.codeUnits);
    final node = builder.build();
    expect(node.lookupByString('ok').asBool(), isTrue);
    expect(node.lookupByString('n').asFloat(), 2.5);
    expect(node.lookupByString('none').isNull(), isTrue);
  });

  test('links and bytes are rejected exactly as Go codec', () {
    expect(
      () => json_codec.encode(PlainBytes(Uint8List.fromList([1])), _Sink()),
      throwsA(
        predicate(
          (Object e) =>
              e.toString() == 'cannot marshal IPLD bytes to this codec',
        ),
      ),
    );
    expect(
      () => json_codec.encode(PlainLink(_Link()), _Sink()),
      throwsA(
        predicate(
          (Object e) =>
              e.toString() == 'cannot marshal IPLD links to this codec',
        ),
      ),
    );
  });
}

Node _list(int count, String value) {
  final builder = prototype.list.newBuilder();
  final list = builder.beginList(count);
  for (var i = 0; i < count; i++) {
    list.assembleValue().assignString(value);
  }
  list.finish();
  return builder.build();
}

final class _Sink implements Sink<List<int>> {
  final bytes = <int>[];
  @override
  void add(List<int> data) => bytes.addAll(data);
  @override
  void close() {}
}

final class _Link implements Link {
  @override
  String toString() => 'link';

  @override
  List<int> binary() => const [1];

  @override
  LinkPrototype prototype() => _LinkPrototype();
}

final class _LinkPrototype implements LinkPrototype {
  @override
  Link buildLink(List<int> hashsum) => _Link();
}
