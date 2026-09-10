// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_boxo/transpiled_boxo.dart';

void main() {
  test('DAG-PB serializes stable UTF8 link order without mutating input', () {
    Uint8List hex(String value) => Uint8List.fromList([
      for (var i = 0; i < value.length; i += 2)
        int.parse(value.substring(i, i + 2), radix: 16),
    ]);
    const hash =
        '1220d5888450c48a64a6e6bd920fe50ce44384438735929678f419a6bfdcaf45fd57';
    final names = ['z', 'a', 'a', '\u{10000}', '\uE000'];
    final node = DagPbNode(
      links: [
        for (var i = 0; i < names.length; i++)
          DagPbLink(hash: hex(hash), name: names[i], tsize: i + 1),
      ],
    );
    final decoded = DagPbNode.fromBytes(node.toBytes());
    // Locked Boxo ProtoNode.EncodeProtobuf(true), including stable duplicates.
    expect(
      node.toBytes(),
      hex(
        '12290a22${hash}1201611802'
        '12290a22${hash}1201611803'
        '12290a22${hash}12017a1801'
        '122b0a22${hash}1203ee80801805'
        '122c0a22${hash}1204f09080801804',
      ),
    );
    expect(decoded.links.map((link) => link.name), [
      'a',
      'a',
      'z',
      '\uE000',
      '\u{10000}',
    ]);
    expect(decoded.links.map((link) => link.tsize), [2, 3, 1, 5, 4]);
    expect(node.links.map((link) => link.name), names);
  });

  test('import failure cancels the input subscription', () async {
    var cancelled = false;
    final source = StreamController<List<int>>(
      onCancel: () {
        cancelled = true;
      },
    );
    final failure = StateError('block sink failed');
    final result = BalancedUnixFsImporter(
      chunkSize: 1,
      onBlock: (_) => throw failure,
    ).importStream(source.stream);
    source.add([1, 2]);
    await expectLater(result, throwsA(same(failure)));
    expect(cancelled, isTrue);
    await source.close();
  });

  test(
    'leaf limit checks input bytes before raw or protobuf wrapping',
    () async {
      final saved = importerBlockSizeLimit;
      try {
        importerBlockSizeLimit = 2;
        for (final raw in [false, true]) {
          final accepted = await BalancedUnixFsImporter(
            chunkSize: 3,
            rawLeaves: raw,
            retainBlocks: true,
          ).importStream(Stream.value([1, 2]));
          expect(accepted.blocks.single.fileSize, 2);
          await expectLater(
            BalancedUnixFsImporter(
              chunkSize: 3,
              rawLeaves: raw,
            ).importStream(Stream.value([1, 2, 3])),
            throwsA(same(errSizeLimitExceeded)),
          );
          // Internal node encoding can exceed the leaf input limit in Go.
          await BalancedUnixFsImporter(
            chunkSize: 1,
            rawLeaves: raw,
          ).importStream(Stream.value([1, 2, 3]));
        }
        importerBlockSizeLimit = -1;
        await expectLater(
          BalancedUnixFsImporter().importStream(Stream<List<int>>.empty()),
          throwsA(same(errSizeLimitExceeded)),
        );
      } finally {
        importerBlockSizeLimit = saved;
      }
    },
  );

  test(
    'default links apply to new importers and preserve explicit overrides',
    () async {
      final saved = defaultLinksPerBlock;
      try {
        defaultLinksPerBlock = 2;
        final first = BalancedUnixFsImporter(chunkSize: 1);
        defaultLinksPerBlock = 3;
        expect(first.maxLinks, 2);
        expect(BalancedUnixFsImporter().maxLinks, 3);
        expect(BalancedUnixFsImporter(maxLinks: 4).maxLinks, 4);
        final result = await buildDagFromReader(
          Stream.value([1, 2, 3]),
          chunkSize: 1,
          retainBlocks: true,
        );
        expect(
          DagPbNode.fromBytes(result.blocks.last.data).links,
          hasLength(3),
        );
      } finally {
        defaultLinksPerBlock = saved;
      }
    },
  );

  test(
    'default chunk size is read when each splitter is constructed',
    () async {
      final saved = defaultBlockSize;
      try {
        defaultBlockSize = 2;
        final first = FixedSizeChunker.defaultSize(Stream.value([1, 2, 3]));
        defaultBlockSize = 3;
        expect(first.size, 2);
        expect(await first.chunks().toList(), [
          [1, 2],
          [3],
        ]);
        expect(fromString(Stream<List<int>>.empty()).size, 3);
        expect(FixedSizeChunker.fromBytes(Uint8List(0)).size, 3);
        expect(BalancedUnixFsImporter().chunkSize, 3);
        expect(FixedSizeChunker.size(Stream<List<int>>.empty(), 4).size, 4);
        final result = await buildDagFromReader(
          Stream.value([1, 2, 3]),
          retainBlocks: true,
        );
        expect(result.blocks, hasLength(1));
      } finally {
        defaultBlockSize = saved;
      }
    },
  );

  test('size parser uses Go decimal syntax and format boundaries', () {
    expect(
      () => fromString(Stream<List<int>>.empty(), 'size-0'),
      throwsA(same(errSize)),
    );
    expect(
      () => fromString(Stream<List<int>>.empty(), 'size-${chunkSizeLimit + 1}'),
      throwsA(same(errSizeMax)),
    );
    for (final spec in [
      'size-0x10',
      'size- 2',
      'size-2 ',
      'size-2\n',
      'size',
      'size--2',
      'size-2-3',
      'size-',
      'size-0',
    ]) {
      expect(
        () => fromString(Stream<List<int>>.empty(), spec),
        throwsFormatException,
        reason: spec,
      );
    }
    for (final spec in ['size-2', 'size-+2', 'size-002']) {
      expect(fromString(Stream<List<int>>.empty(), spec).size, 2);
    }
  });

  test('fixed chunker preserves Boxo boundaries and size limit', () async {
    expect(blockSizeLimit, 2 * 1024 * 1024);
    expect(chunkSizeLimit + chunkOverheadBudget, blockSizeLimit);
    final chunks = await FixedSizeChunker.size(
      Stream<List<int>>.fromIterable([
        [0, 1, 2],
        [3, 4, 5],
      ]),
      4,
    ).chunks().toList();
    expect(chunks, [
      [0, 1, 2, 3],
      [4, 5],
    ]);
    expect(
      () => fromString(Stream<List<int>>.empty(), 'size-${chunkSizeLimit + 1}'),
      throwsFormatException,
    );
    // NewSizeSplitter has no parser ceiling in splitting.go.
    expect(
      await FixedSizeChunker.size(
        Stream.value([1, 2]),
        chunkSizeLimit + 1,
      ).chunks().toList(),
      [
        [1, 2],
      ],
    );
  });

  test('UnixFS protobuf vector and round trip', () {
    final bytes = wrapData(Uint8List.fromList([1, 2]));
    expect(bytes, [8, 0, 18, 2, 1, 2, 24, 2]);
    final decoded = UnixFsData.fromBytes(bytes);
    expect(decoded.type, UnixFsDataType.raw);
    expect(decoded.data, [1, 2]);
    expect(decoded.filesize, 2);
    expect(decoded.toBytes(), bytes);
  });

  test('DAG-PB link and node preserve wire order', () {
    final hash = [0x12, 0x20, ...List.filled(32, 0)];
    final link = DagPbLink(hash: Uint8List.fromList(hash), tsize: 7);
    final node = DagPbNode(data: Uint8List.fromList([9]), links: [link]);
    final decoded = DagPbNode.fromBytes(node.toBytes());
    expect(decoded.data, [9]);
    expect(decoded.links.single.hash, hash);
    expect(decoded.links.single.tsize, 7);
    expect(node.toBytes(), [18, 40, 10, 34, ...hash, 18, 0, 24, 7, 10, 1, 9]);
  });

  test('balanced importer builds a small regular file', () async {
    final result = await BalancedUnixFsImporter(
      chunkSize: 2,
      maxLinks: 2,
      retainBlocks: true,
    ).importStream(Stream.value([1, 2, 3, 4]));
    expect(result.blocks.length, 3); // two leaves and one File parent
    expect(result.root, result.blocks.last.cid);
    final root = result.blocks.last;
    final dag = DagPbNode.fromBytes(root.data);
    final fs = UnixFsData.fromBytes(dag.data);
    expect(fs.type, UnixFsDataType.file);
    expect(fs.filesize, 4);
    expect(fs.blocksizes, [2, 2]);
    expect(dag.links.length, 2);
  });

  test('balanced importer matches locked Boxo Cid vectors', () async {
    const vectors = [
      (
        size: 176,
        chunk: 1,
        links: 175,
        cid: 'QmbHp4zy1iwf1yRf2BZYToNsYf15AV8XjXcF1LyGjM3dZY',
      ),
      (
        size: 257,
        chunk: 1,
        links: 256,
        cid: 'QmYYtJRCNxnSCF6QBMSGw9VQ5LNRQwiBpfbEuo4QG8XNHm',
      ),
      (
        size: 0,
        chunk: 2,
        links: 2,
        cid: 'QmbFMke1KXqnYyBBWxB74N4c5SBnJMVAiMNRcGu6x1AwQH',
      ),
      (
        size: 3,
        chunk: 4,
        links: 2,
        cid: 'QmV8BswP26H2stWWUXgizp3iyL8YCqzjicgs9rFsoqGu12',
      ),
      (
        size: 4,
        chunk: 2,
        links: 2,
        cid: 'QmanqWKdkk8UXeythcrohz2o4Vg4d6B38xNPkUvukMVzj4',
      ),
      (
        size: 10,
        chunk: 2,
        links: 2,
        cid: 'QmTiJikwXGTygCnVD6pY9JHU4Bomi4Qy4otx1BsLKyyx9p',
      ),
      (
        size: 21,
        chunk: 3,
        links: 3,
        cid: 'QmRQzbrGo5tM8ptVgu4im6598NS6kKh7EBxRZtq7Vojz7Y',
      ),
    ];
    for (final vector in vectors) {
      final data = List<int>.generate(vector.size, (index) => index % 256);
      final result = await BalancedUnixFsImporter(
        chunkSize: vector.chunk,
        maxLinks: vector.links,
      ).importStream(Stream.value(data));
      expect(result.root.toString(), vector.cid);
    }
  });

  test('raw leaves use CIDv1/raw when requested', () async {
    final result = await BalancedUnixFsImporter(
      chunkSize: 4,
      rawLeaves: true,
      retainBlocks: true,
    ).importStream(Stream.value([1, 2, 3]));
    expect(result.blocks.single.raw, isTrue);
    expect(result.root.version, 1);
    expect(result.root.codec, 'raw');
  });

  test('configured fanout may exceed the default of 174', () async {
    final result = await BalancedUnixFsImporter(
      chunkSize: 1,
      maxLinks: 175,
      retainBlocks: true,
    ).importStream(Stream.value(List<int>.generate(175, (i) => i)));
    final root = DagPbNode.fromBytes(result.blocks.last.data);
    expect(root.links, hasLength(175));
    expect(UnixFsData.fromBytes(root.data).blocksizes, List.filled(175, 1));
  });

  test('raw leaves preserve the empty raw leaf', () async {
    final result = await BalancedUnixFsImporter(
      rawLeaves: true,
    ).importStream(Stream<List<int>>.empty());
    expect(
      result.root.toString(),
      'bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku',
    );
  });
}
