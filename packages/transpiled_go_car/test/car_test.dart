// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_go_car/transpiled_go_car.dart';

const _fixture =
    '3aa265726f6f747381d82a58250001711220151fe9e73c6267a7060c6f6c4cca943c236f4b196723489608edb42a8b8fa80b6776657273696f6e012c01711220151fe9e73c6267a7060c6f6c4cca943c236f4b196723489608edb42a8b8fa80ba165646f646779f5';

// go-car's WriteHeader with the same root and an explicit Version: 2.
const _versionTwoHeader =
    '3aa265726f6f747381d82a58250001711220151fe9e73c6267a7060c6f6c4cca943c236f4b196723489608edb42a8b8fa80b6776657273696f6e02';

const _largeVersionHeader =
    '42a265726f6f747381d82a58250001711220151fe9e73c6267a7060c6f6c4cca943c236f4b196723489608edb42a8b8fa80b6776657273696f6e1b0000000100000000';

// CARv1 containing the Cid for an empty payload. The section is Cid-only,
// which go-car's util.ReadNode returns with data == []byte{}.
const _emptyBlockCar =
    '3aa265726f6f747381d82a58250001551220e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8556776657273696f6e012401551220e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

Uint8List _hex(String value) => Uint8List.fromList([
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
]);

void main() {
  test('writes the canonical go-car single-block vector', () async {
    final cid = Cid.decode(
      'bafyreiavd7u6opdcm6tqmddpnrgmvfb4enxuwglhenejmchnwqvixd5ibm',
    );
    final car = await CarWriter(
      roots: [cid],
      get: (_) => _hex('a165646f646779f5'),
      links: (_) => const <Cid>[],
    ).toBytes();
    expect(car, _hex(_fixture));
  });

  test('writes the explicit header version from go-car bytes', () {
    final cid = Cid.decode(
      'bafyreiavd7u6opdcm6tqmddpnrgmvfb4enxuwglhenejmchnwqvixd5ibm',
    );
    expect(
      writeHeader(CarHeader(roots: [cid], version: 2)),
      _hex(_versionTwoHeader),
    );
    expect(readHeader(_hex(_versionTwoHeader)).version, 2);
    expect(
      writeHeader(CarHeader(roots: [cid], version: 0x100000000)),
      _hex(_largeVersionHeader),
    );
    expect(readHeader(_hex(_largeVersionHeader)).version, 0x100000000);
  });

  test('reads incrementally and validates Cid/data', () {
    final reader = CarReader(_hex(_fixture));
    expect(reader.header!.roots, hasLength(1));
    final block = reader.next()!;
    expect(block.data, _hex('a165646f646779f5'));
    expect(reader.next(), isNull);
  });

  test('deduplicates depth-first traversal and loads blocks', () async {
    final a = Cid.computeForDataSync(Uint8List.fromList('a'.codeUnits));
    final b = Cid.computeForDataSync(Uint8List.fromList('b'.codeUnits));
    final calls = <String>[];
    final car = await CarWriter(
      roots: [a],
      get: (cid) {
        calls.add(cid.encode());
        return Uint8List.fromList((cid == a ? 'a' : 'b').codeUnits);
      },
      links: (cid) => cid == a ? [b, b] : const [],
    ).toBytes();
    final blocks = CarReader(car).blocks().toList();
    expect(await blocks, hasLength(2));
    expect(calls, hasLength(2));
  });

  test('rejects corruption, truncation and oversized sections', () {
    final bytes = _hex(_fixture);
    bytes[bytes.length - 1] ^= 1;
    expect(
      () => CarReader(bytes).next(),
      throwsA(isA<CarIntegrityException>()),
    );
    expect(
      () => CarReader(bytes.sublist(0, bytes.length - 1)).next(),
      throwsFormatException,
    );
    expect(() => readHeader(Uint8List.fromList([0x80])), throwsFormatException);
    expect(
      () => readHeader(Uint8List.fromList([0xff, 0xff, 0xff, 0xff, 0x7f])),
      throwsFormatException,
    );
  });

  test('reads fragmented streams', () async {
    final bytes = _hex(_fixture);
    final stream = Stream.fromIterable([
      for (var i = 0; i < bytes.length; i++) Uint8List.fromList([bytes[i]]),
    ]);
    final reader = CarReader(stream);
    expect((await reader.nextAsync())!.data, _hex('a165646f646779f5'));
    expect(await reader.nextAsync(), isNull);
  });

  test(
    'accepts an empty block payload in bytes and fragmented streams',
    () async {
      final bytes = _hex(_emptyBlockCar);
      final expectedCid = Cid.computeForDataSync(Uint8List(0));

      final byteReader = CarReader(bytes);
      final byteBlock = byteReader.next()!;
      expect(byteBlock.cid(), expectedCid);
      expect(byteBlock.data, isEmpty);
      expect(byteReader.next(), isNull);

      final stream = Stream.fromIterable([
        for (var i = 0; i < bytes.length; i++) Uint8List.fromList([bytes[i]]),
      ]);
      final streamReader = CarReader(stream);
      final streamBlock = await streamReader.nextAsync();
      expect(streamBlock!.cid(), expectedCid);
      expect(streamBlock.data, isEmpty);
      expect(await streamReader.nextAsync(), isNull);
    },
  );

  test('loadCar accepts a block store callback', () async {
    final blocks = <CarBlock>[];
    final header = await loadCar(_hex(_fixture), blocks.add);
    expect(header.roots, hasLength(1));
    expect(blocks, hasLength(1));
  });
}
