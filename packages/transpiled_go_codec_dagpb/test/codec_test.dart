// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:transpiled_go_codec_dagpb/transpiled_go_codec_dagpb.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

void main() {
  test('encoder validates Tsize in input order before sorting links', () {
    final builder = AnyBuilder();
    decodeBytes(
      builder,
      Uint8List.fromList([18, 36, 10, 34, 18, 32, ...List.filled(32, 0)]),
    );
    final hash = builder
        .build()
        .lookupByString('Links')
        .lookupByIndex(0)
        .lookupByString('Hash');
    final node = PlainMap({
      'Links': PlainList([
        PlainMap({'Hash': hash, 'Name': PlainString('z'), 'Tsize': PlainInt(-1)}),
        PlainMap({'Hash': hash, 'Name': PlainString('a'), 'Tsize': PlainInt(-2)}),
      ]),
    });
    expect(
      () => appendEncode(Uint8List(0), node),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'Link has negative Tsize value [-1]',
        ),
      ),
    );
  });

  test('PBLink duplicate checks precede order and wire checks', () {
    final hash = [10, 34, 18, 32, ...List.filled(32, 0)];
    final vectors = [
      ([...hash, 18, 0, 8], 'duplicate Hash section'),
      ([18, 0, 10], 'invalid order, found Name before Hash'),
      ([24, 0, 18], 'invalid order, found Tsize before Name'),
      ([8], 'wrong wireType (0) for Hash'),
      ([32], 'invalid fieldNumber, expected 1, 2 or 3, got 4'),
    ];
    for (final (body, message) in vectors) {
      expect(
        () => decodeBytes(
          AnyBuilder(),
          Uint8List.fromList([18, body.length, ...body]),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'protobuf: (PBLink) $message',
          ),
        ),
      );
    }
  });

  test('PBNode errors follow upstream tag and field precedence', () {
    final vectors = [
      ([0], 'invalid field number'),
      ([26], 'protobuf: (PBNode) invalid fieldNumber, expected 1 or 2, got 3'),
      ([10, 0, 10], 'protobuf: (PBNode) duplicate Data section'),
      ([10], 'unexpected EOF'),
      ([8], 'protobuf: (PBNode) invalid wireType, expected 2, got 0'),
    ];
    for (final (bytes, message) in vectors) {
      expect(
        () => decodeBytes(AnyBuilder(), Uint8List.fromList(bytes)),
        throwsA(
          isA<FormatException>().having((e) => e.message, 'message', message),
        ),
      );
    }
  });

  test('valid Cid assembler failure is not relabeled as invalid Cid', () {
    final failure = StateError('assembler rejected link');
    final bytes = Uint8List.fromList([
      18,
      36,
      10,
      34,
      18,
      32,
      ...List.filled(32, 0),
    ]);
    expect(
      () => decodeBytes(_RejectLinkAssembler(failure), bytes),
      throwsA(same(failure)),
    );
  });

  test('appendEncode preserves prefix and explicit empty Data', () {
    final prefix = Uint8List.fromList([7, 8]);
    final node = PlainMap({
      'Links': const PlainList([]),
      'Data': PlainBytes(Uint8List(0)),
    });
    expect(appendEncode(prefix, node), [7, 8, 10, 0]);
    expect(prefix, [7, 8]);
    expect(appendEncode(prefix, const PlainMap({'Links': PlainList([])})), [
      7,
      8,
    ]);
  });

  test('encode propagates writer failure and does not close writer', () {
    final failure = StateError('write failed');
    final sink = _FailingSink(failure);
    expect(
      () => encode(const PlainMap({'Links': PlainList([])}), sink),
      throwsA(same(failure)),
    );
    expect(sink.closed, isFalse);
  });

  test('Tsize follows Go uint64 to int64 conversion and overflow', () {
    final cases = [
      (bytes: [...List.filled(8, 255), 127], value: 0x7fffffffffffffff),
      (bytes: [...List.filled(9, 128), 1], value: -0x7fffffffffffffff - 1),
      (bytes: [...List.filled(9, 255), 1], value: -1),
    ];
    for (final vector in cases) {
      final body = [10, 34, 18, 32, ...List.filled(32, 0), 24, ...vector.bytes];
      final builder = AnyBuilder();
      decodeBytes(builder, Uint8List.fromList([18, body.length, ...body]));
      expect(
        builder
            .build()
            .lookupByString('Links')
            .lookupByIndex(0)
            .lookupByString('Tsize')
            .asInt(),
        vector.value,
      );
    }
    final body = [
      10,
      34,
      18,
      32,
      ...List.filled(32, 0),
      24,
      ...List.filled(9, 128),
      2,
    ];
    expect(
      () => decodeBytes(
        AnyBuilder(),
        Uint8List.fromList([18, body.length, ...body]),
      ),
      throwsFormatException,
    );
  });

  test('decoder rejects duplicate link fields at codec boundary', () {
    final hash = [10, 34, 0x12, 0x20, ...List.filled(32, 0)];
    for (final field in [
      [18, 0],
      [24, 0],
    ]) {
      final body = [...hash, ...field, ...field];
      expect(
        () => decodeBytes(
          AnyBuilder(),
          Uint8List.fromList([18, body.length, ...body]),
        ),
        throwsFormatException,
      );
    }
  });

  test('encoder rejects unknown schema fields', () {
    expect(
      () => appendEncode(
        Uint8List(0),
        PlainMap({'Links': const PlainList([]), 'Unknown': PlainInt(1)}),
      ),
      throwsFormatException,
    );
    expect(
      () => appendEncode(
        Uint8List(0),
        PlainMap({
          'Links': PlainList([
            PlainMap({'Unknown': PlainInt(1)}),
          ]),
        }),
      ),
      throwsFormatException,
    );
  });

  test('decoder rejects lengths that overflow signed runtime integers', () {
    expect(
      () => decodeBytes(
        AnyBuilder(),
        Uint8List.fromList([10, ...List.filled(9, 255), 1]),
      ),
      throwsFormatException,
    );
  });

  test('decodes empty node and rejects duplicate Data', () {
    final empty = AnyBuilder();
    decodeBytes(empty, Uint8List(0));
    expect(empty.build().lookupByString('Links').length(), 0);
    expect(
      () => decodeBytes(AnyBuilder(), Uint8List.fromList([10, 0, 10, 0])),
      throwsFormatException,
    );
  });
}

class _FailingSink implements Sink<List<int>> {
  _FailingSink(this.failure);
  final Object failure;
  bool closed = false;
  @override
  void add(List<int> data) => throw failure;
  @override
  void close() {
    closed = true;
  }
}

class _RejectLinkAssembler extends AnyBuilder {
  _RejectLinkAssembler(this.failure);
  final Object failure;
  @override
  MapAssembler beginMap(int sizeHint) => _RejectLinkMap(failure);
  @override
  ListAssembler beginList(int sizeHint) => _RejectLinkList(failure);
  @override
  void assignLink(Link value) => throw failure;
}

class _RejectLinkMap implements MapAssembler {
  _RejectLinkMap(this.failure);
  final Object failure;
  @override
  NodeAssembler assembleEntry(String key) => _RejectLinkAssembler(failure);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RejectLinkList implements ListAssembler {
  _RejectLinkList(this.failure);
  final Object failure;
  @override
  NodeAssembler assembleValue() => _RejectLinkAssembler(failure);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
