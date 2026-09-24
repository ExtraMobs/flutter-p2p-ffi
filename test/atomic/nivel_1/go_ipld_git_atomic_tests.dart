import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_block_format/transpiled_block_format.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_go_ipld_git/transpiled_go_ipld_git.dart';
import 'package:transpiled_ipld_prime/codec.dart' as ipld_prime;
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

class _SinkList implements Sink<List<int>> {
  final List<int> bytes = [];

  @override
  void add(List<int> data) {
    bytes.addAll(data);
  }

  @override
  void close() {}
}

void main() {
  group('Top-Level Functions [Git Raw Codec]', () {
    final sampleSha = Uint8List.fromList(List<int>.generate(20, (i) => i + 1));

    test('shaToCid() - converte 20 bytes SHA-1 em Cid com codec git-raw', () {
      final cid = shaToCid(sampleSha);
      expect(cid.version, equals(1));
      expect(cid.codec, equals('git-raw'));
      expect(cid.multihash.digest.length, equals(20));
      expect(cid.multihash.digest, equals(sampleSha));
    });

    test('cidToSha() - extrai os 20 bytes de SHA-1 do multihash do Cid', () {
      final cid = shaToCid(sampleSha);
      final sha = cidToSha(cid);
      expect(sha, equals(sampleSha));
    });

    test('linkToSha() - extrai digest SHA-1 de CidLink', () {
      final cid = shaToCid(sampleSha);
      final link = CidLink(cid);
      expect(linkToSha(link), equals(sampleSha));
      expect(linkToSha(null), isNull);
    });

    test('readNullTerminatedNumber() - le numero terminado por null byte', () {
      final bytes = Uint8List.fromList(utf8.encode('1234\x00extra'));
      final (num, nextOffset) = readNullTerminatedNumber(bytes, 0);
      expect(num, equals(1234));
      expect(nextOffset, equals(5));
    });

    test('parsePersonInfo() - faz parsing de linha git author/committer', () {
      final line = Uint8List.fromList(
        utf8.encode(
          'author Linus Torvalds <torvalds@linux-foundation.org> 1113000000 -0700',
        ),
      );
      final pi = parsePersonInfo(line);
      expect(pi.name, equals('Linus Torvalds'));
      expect(pi.email, equals('torvalds@linux-foundation.org'));
      expect(pi.date, equals('1113000000'));
      expect(pi.timezone, equals('-0700'));
    });

    test(
      'registerGitCodec() - registra encoder e decoder git-raw 0x78 no registro multicodec',
      () {
        final reg = ipld_prime.Registry();
        registerGitCodec(reg);
        expect(reg.lookupEncoder(0x78), isNotNull);
        expect(reg.lookupDecoder(0x78), isNotNull);
      },
    );

    test('decodeBlob() - decodifica dados de blob com header e body', () {
      final rawBlob = utf8.encode('blob 12\x00hello world\n');
      final builder = AnyBuilder();
      final end = decodeBlob(builder, Uint8List.fromList(rawBlob), 5);
      expect(end, equals(rawBlob.length));
      final node = builder.build();
      expect(node.asBytes(), equals(rawBlob));
    });

    test('encodeBlob() - serializa no blob para stream de bytes', () {
      final rawBlob = utf8.encode('blob 5\x00hello');
      final node = PlainBytes(Uint8List.fromList(rawBlob));
      final sink = _SinkList();
      encodeBlob(node, sink);
      expect(sink.bytes, equals(rawBlob));
    });

    test('decodeTreeEntry() - decodifica uma entrada individual de tree', () {
      final entryBytes = <int>[
        ...utf8.encode('100644 file.txt\x00'),
        ...sampleSha,
      ];
      final (name, node, next) = decodeTreeEntry(
        Uint8List.fromList(entryBytes),
        0,
      );
      expect(name, equals('file.txt'));
      expect(node.lookupByString('mode').asString(), equals('100644'));
      expect(next, equals(entryBytes.length));
    });

    test('decodeTree() - decodifica objeto git tree completo', () {
      final entryBytes = <int>[
        ...utf8.encode('100644 a.txt\x00'),
        ...sampleSha,
      ];
      final rawTree = <int>[
        ...utf8.encode('tree ${entryBytes.length}\x00'),
        ...entryBytes,
      ];
      final builder = AnyBuilder();
      final end = decodeTree(builder, Uint8List.fromList(rawTree), 5);
      expect(end, equals(rawTree.length));
      final node = builder.build();
      final aEntry = node.lookupByString('a.txt');
      expect(aEntry.lookupByString('mode').asString(), equals('100644'));
    });

    test('encodeTreeEntry() - serializa uma entrada individual de tree', () {
      final cid = shaToCid(sampleSha);
      final entryNode = PlainMap({
        'mode': const PlainString('100644'),
        'hash': PlainLink(CidLink(cid)),
      });
      final sink = _SinkList();
      encodeTreeEntry('test.dart', entryNode, sink);
      expect(sink.bytes, isNotEmpty);
      expect(sink.bytes.sublist(sink.bytes.length - 20), equals(sampleSha));
    });

    test('encodeTree() - serializa objeto git tree completo', () {
      final cid = shaToCid(sampleSha);
      final treeNode = PlainMap({
        'main.dart': PlainMap({
          'mode': const PlainString('100644'),
          'hash': PlainLink(CidLink(cid)),
        }),
      });
      final sink = _SinkList();
      encodeTree(treeNode, sink);
      expect(sink.bytes, isNotEmpty);
      expect(utf8.decode(sink.bytes.sublist(0, 5)), equals('tree '));
    });

    test(
      'decodeCommit() - decodifica objeto git commit com parents e personinfo',
      () {
        final commitText =
            'tree 0102030405060708090a0b0c0d0e0f1011121314\n'
            'parent 0102030405060708090a0b0c0d0e0f1011121314\n'
            'author Test <test@example.com> 1234567890 +0000\n'
            'committer Test <test@example.com> 1234567890 +0000\n'
            '\n'
            'initial commit\n';
        final rawCommit = <int>[
          ...utf8.encode('commit ${utf8.encode(commitText).length}\x00'),
          ...utf8.encode(commitText),
        ];
        final builder = AnyBuilder();
        final end = decodeCommit(builder, Uint8List.fromList(rawCommit), 7);
        expect(end, equals(rawCommit.length));
        final node = builder.build();
        expect(
          node.lookupByString('message').asString(),
          equals('initial commit\n'),
        );
      },
    );

    test('encodeCommit() - serializa objeto git commit completo', () {
      final cid = shaToCid(sampleSha);
      final commitNode = PlainMap({
        'tree': PlainLink(CidLink(cid)),
        'parents': PlainList([PlainLink(CidLink(cid))]),
        'author': const PlainMap({
          'name': PlainString('Author'),
          'email': PlainString('a@b.com'),
          'date': PlainString('123'),
          'timezone': PlainString('+0000'),
        }),
        'committer': const PlainMap({
          'name': PlainString('Committer'),
          'email': PlainString('c@d.com'),
          'date': PlainString('123'),
          'timezone': PlainString('+0000'),
        }),
        'message': const PlainString('feat: support git-raw'),
      });
      final sink = _SinkList();
      encodeCommit(commitNode, sink);
      expect(sink.bytes, isNotEmpty);
      expect(utf8.decode(sink.bytes.sublist(0, 7)), equals('commit '));
    });

    test('decodeTag() e encodeTag() - roundtrip de objeto git tag', () {
      final cid = shaToCid(sampleSha);
      final tagText =
          'object 0102030405060708090a0b0c0d0e0f1011121314\n'
          'type commit\n'
          'tag v1.0.0\n'
          'tagger Tagger <tag@example.com> 1234567890 +0000\n'
          '\n'
          'release v1.0.0\n';
      final rawTag = <int>[
        ...utf8.encode('tag ${utf8.encode(tagText).length}\x00'),
        ...utf8.encode(tagText),
      ];
      final builder = AnyBuilder();
      decodeTag(builder, Uint8List.fromList(rawTag), 4);
      final tagNode = builder.build();
      expect(tagNode.lookupByString('tag').asString(), equals('v1.0.0'));
      expect(tagNode.lookupByString('type').asString(), equals('commit'));

      final sink = _SinkList();
      encodeTag(tagNode, sink);
      expect(sink.bytes, isNotEmpty);
      expect(utf8.decode(sink.bytes.sublist(0, 4)), equals('tag '));
    });

    test('parseObject() - decodifica a partir do header de tipo git', () {
      final rawBlob = utf8.encode('blob 4\x00data');
      final node = parseObject(rawBlob);
      expect(node.asBytes(), equals(rawBlob));
    });

    test(
      'parseObjectFromBuffer() - decodifica a partir de Uint8List buffer',
      () {
        final rawBlob = Uint8List.fromList(utf8.encode('blob 4\x00data'));
        final node = parseObjectFromBuffer(rawBlob);
        expect(node.asBytes(), equals(rawBlob));
      },
    );

    test('decodeBlock() - decodifica bloco IPFS com codec git-raw', () {
      final rawBlob = Uint8List.fromList(utf8.encode('blob 4\x00data'));
      final cid = shaToCid(sampleSha);
      final block = BasicBlock(rawBlob, cid);
      final node = decodeBlock(block);
      expect(node.asBytes(), equals(rawBlob));
    });
  });

  group('PersonInfo', () {
    test(
      'PersonInfo.gitString() - formata identidade em formato padrao git',
      () {
        const pi = PersonInfo(
          name: 'Linus Torvalds',
          email: 'torvalds@linux-foundation.org',
          date: '1113000000',
          timezone: '-0700',
        );
        expect(
          pi.gitString(),
          equals(
            'Linus Torvalds <torvalds@linux-foundation.org> 1113000000 -0700',
          ),
        );
      },
    );

    test('PersonInfo.toNode() - converte para representacao em IPLD Map', () {
      const pi = PersonInfo(
        name: 'Dev',
        email: 'dev@ipfs.io',
        date: '123',
        timezone: '+0000',
      );
      final node = pi.toNode();
      expect(node.lookupByString('name').asString(), equals('Dev'));
      expect(node.lookupByString('email').asString(), equals('dev@ipfs.io'));
    });
  });
}
