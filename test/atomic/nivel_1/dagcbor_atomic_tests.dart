import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_ipld_prime/codec.dart';
import 'package:transpiled_ipld_prime/src/codec/cbor/codec.dart' as cbor;
import 'package:transpiled_ipld_prime/src/codec/dagcbor/codec.dart' as dagcbor;
import 'package:transpiled_ipld_prime/src/linking/cid/cid_link.dart';
import 'package:transpiled_ipld_prime/src/multicodec/registry.dart'
    as multicodec;
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
  final testCid = Cid.decode(
    'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
  );

  group('Top-Level Functions [DAG-CBOR and CBOR]', () {
    test(
      'registerDagCborCodec() - registra encoder e decoder DAG-CBOR 0x71 no registro',
      () {
        final reg = multicodec.Registry();
        dagcbor.registerDagCborCodec(reg);
        expect(reg.lookupEncoder(0x71), isNotNull);
        expect(reg.lookupDecoder(0x71), isNotNull);
      },
    );

    test(
      'registerCborCodec() - registra encoder e decoder CBOR 0x51 no registro',
      () {
        final reg = multicodec.Registry();
        cbor.registerCborCodec(reg);
        expect(reg.lookupEncoder(0x51), isNotNull);
        expect(reg.lookupDecoder(0x51), isNotNull);
      },
    );

    test('uintLength() - calcula tamanho em bytes do inteiro', () {
      expect(dagcbor.uintLength(0), equals(1));
      expect(dagcbor.uintLength(23), equals(1));
      expect(dagcbor.uintLength(24), equals(2));
      expect(dagcbor.uintLength(255), equals(2));
      expect(dagcbor.uintLength(256), equals(3));
      expect(dagcbor.uintLength(65535), equals(3));
      expect(dagcbor.uintLength(65536), equals(5));
      expect(dagcbor.uintLength(4294967295), equals(5));
      expect(dagcbor.uintLength(4294967296), equals(9));
    });

    test('encodedLength() - calcula tamanho total esperado de codificacao', () {
      final b = const PrototypeMap().newBuilder();
      final ma = b.beginMap(2);
      ma.assembleEntry('hello').assignString('world');
      ma.assembleEntry('count').assignInt(42);
      ma.finish();
      final node = b.build();
      final len = dagcbor.encodedLength(node);
      expect(len, isPositive);
    });

    test('encodeDagCbor() - codifica no IPLD para DAG-CBOR', () {
      final b = const PrototypeMap().newBuilder();
      final ma = b.beginMap(1);
      ma.assembleEntry('a').assignInt(10);
      ma.finish();
      final node = b.build();
      final sink = _SinkList();
      dagcbor.encodeDagCbor(node, sink);
      expect(sink.bytes, isNotEmpty);
    });

    test('decodeDagCbor() - decodifica bytes DAG-CBOR em nó IPLD', () {
      final encoded = [0x65, 0x68, 0x65, 0x6c, 0x6c, 0x6f]; // "hello"
      final builder = const PrototypeString().newBuilder();
      dagcbor.decodeDagCbor(builder, encoded);
      final result = builder.build();
      expect(result.asString(), equals('hello'));
    });

    test('marshal() - serializa no com sink e opcoes', () {
      const node = PlainInt(99);
      final sink = _SinkList();
      dagcbor.marshal(
        node,
        sink,
        const dagcbor.EncodeOptions(allowLinks: true),
      );
      expect(sink.bytes, equals([0x18, 99]));
    });

    test('unmarshal() - decodifica com opcoes de DecodeOptions', () {
      final encoded = [0x05]; // int 5
      final builder = const PrototypeInt().newBuilder();
      dagcbor.unmarshal(builder, encoded, const dagcbor.DecodeOptions());
      final result = builder.build();
      expect(result.asInt(), equals(5));
    });

    test('encodeCbor() - codifica nó em CBOR e rejeita links', () {
      const validNode = PlainString('hello cbor');
      final sink = _SinkList();
      cbor.encodeCbor(validNode, sink);
      expect(sink.bytes, isNotEmpty);

      final linkNode = PlainLink(CidLink(testCid));
      final sinkLink = _SinkList();
      expect(
        () => cbor.encodeCbor(linkNode, sinkLink),
        throwsA(isA<FormatException>()),
      );
    });

    test('decodeCbor() - decodifica dados CBOR sem links', () {
      final encoded = [0x64, 0x74, 0x65, 0x73, 0x74]; // "test"
      final builder = const PrototypeString().newBuilder();
      cbor.decodeCbor(builder, encoded);
      expect(builder.build().asString(), equals('test'));

      // Link tag 42 deve falhar no CBOR puro
      final cidBytes = testCid.bytes();
      final linkEncoded = <int>[
        0xd8,
        0x2a,
        0x58,
        cidBytes.length + 1,
        0x00,
        ...cidBytes,
      ];
      final builderLink = const PrototypeAny().newBuilder();
      expect(
        () => cbor.decodeCbor(builderLink, linkEncoded),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'DAG-CBOR Link Roundtrip - codifica e decodifica CID com Tag 42 e prefixo 0x00',
      () {
        final b = const PrototypeMap().newBuilder();
        final ma = b.beginMap(1);
        ma.assembleEntry('link').assignLink(CidLink(testCid));
        ma.finish();
        final linkNode = b.build();
        final sink = _SinkList();
        dagcbor.encode(linkNode, sink);

        final builder = const PrototypeMap().newBuilder();
        dagcbor.decode(builder, sink.bytes);
        final decoded = builder.build();

        final retrievedLink = decoded.lookupByString('link').asLink();
        expect(retrievedLink, isA<CidLink>());
        expect((retrievedLink as CidLink).cid, equals(testCid));
      },
    );

    test(
      'DAG-CBOR RFC 7049 Map Sorting - ordena por tamanho de chave e depois lexicograficamente',
      () {
        final b = const PrototypeMap().newBuilder();
        final ma = b.beginMap(3);
        ma.assembleEntry('aa').assignInt(1);
        ma.assembleEntry('b').assignInt(2);
        ma.assembleEntry('a').assignInt(3);
        ma.finish();
        final mapNode = b.build();
        final sink = _SinkList();
        dagcbor.encode(mapNode, sink);

        expect(sink.bytes[0], equals(0xa3));
        expect(sink.bytes[1], equals(0x61));
        expect(sink.bytes[2], equals(0x61)); // 'a'
        expect(sink.bytes[3], equals(0x03)); // 3
        expect(sink.bytes[4], equals(0x61));
        expect(sink.bytes[5], equals(0x62)); // 'b'
        expect(sink.bytes[6], equals(0x02)); // 2
        expect(sink.bytes[7], equals(0x62));
        expect(sink.bytes[8], equals(0x61));
        expect(sink.bytes[9], equals(0x61)); // 'aa'
        expect(sink.bytes[10], equals(0x01)); // 1
      },
    );

    test('Constantes e Exceções do DAG-CBOR', () {
      expect(dagcbor.linkTag, equals(42));
      expect(dagcbor.lengthBoundaries.length, equals(5));
      expect(dagcbor.errInvalidMultibase.message, contains('multibase'));
      expect(
        dagcbor.errAllocationBudgetExceeded.message,
        contains('resources'),
      );
      expect(dagcbor.errDecodeDepthExceeded.message, contains('depth'));
      expect(
        dagcbor.errTrailingBytes.message.contains('trailing') ||
            dagcbor.errTrailingBytes.message.contains('unexpected'),
        isTrue,
      );
    });
  });

  group('EncodeOptions', () {
    test(
      'EncodeOptions.encode() - executa serializacao com opcoes customizadas',
      () {
        const opts = dagcbor.EncodeOptions(
          allowLinks: true,
          mapSortMode: MapSortMode.rfc7049,
        );
        const node = PlainString('test-encode');
        final sink = _SinkList();
        opts.encode(node, sink);
        expect(sink.bytes, isNotEmpty);
      },
    );
  });

  group('DecodeOptions', () {
    test(
      'DecodeOptions.effectiveBudget - retorna o orcamento de alocacao configurado ou padrao',
      () {
        const optsDefault = dagcbor.DecodeOptions();
        expect(optsDefault.effectiveBudget, equals(1048576 * 10));

        const optsCustom = dagcbor.DecodeOptions(allocationBudget: 500);
        expect(optsCustom.effectiveBudget, equals(500));
      },
    );

    test(
      'DecodeOptions.effectiveMaxPrealloc - retorna o limite maximo de prealocacao',
      () {
        const optsDefault = dagcbor.DecodeOptions();
        expect(optsDefault.effectiveMaxPrealloc, equals(1024));

        const optsCustom = dagcbor.DecodeOptions(maxCollectionPrealloc: 64);
        expect(optsCustom.effectiveMaxPrealloc, equals(64));
      },
    );

    test(
      'DecodeOptions.effectiveMaxDepth - retorna a profundidade maxima de recursao',
      () {
        const optsDefault = dagcbor.DecodeOptions();
        expect(optsDefault.effectiveMaxDepth, equals(1024));

        const optsCustom = dagcbor.DecodeOptions(maxDepth: 10);
        expect(optsCustom.effectiveMaxDepth, equals(10));
      },
    );

    test(
      'DecodeOptions.decode() - decodifica stream com opcoes especificadas',
      () {
        const opts = dagcbor.DecodeOptions();
        final builder = const PrototypeMap().newBuilder();
        final encoded = [0xa1, 0x61, 0x61, 0x01]; // {"a": 1}
        opts.decode(builder, encoded);
        final result = builder.build();
        expect(result.lookupByString('a').asInt(), equals(1));
      },
    );
  });
}
