// test/atomic/nivel_1/dagpb_atomic_tests.dart
// Testes atômicos 1 para 1 para o módulo go_codec_dagpb (transpiled_go_codec_dagpb).

import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_go_codec_dagpb/transpiled_go_codec_dagpb.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

void main() {
  group('Top-Level Functions [Atomic Audit]', () {
    test('decodeBytes() - decodifica dados binarios no formato DAG-PB para o assembler', () {
      final sampleCid = Cid.decode('bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi');
      final sampleBytes = Uint8List.fromList(utf8.encode('conteudo de teste DAG-PB'));

      final originalNode = PlainMap({
        'Data': PlainBytes(sampleBytes),
        'Links': PlainList([
          PlainMap({
            'Hash': PlainLink(CidLink(sampleCid)),
            'Name': PlainString('link-alpha'),
            'Tsize': PlainInt(1024),
          }),
        ]),
      });

      final encoded = appendEncode(Uint8List(0), originalNode);
      expect(encoded.isNotEmpty, isTrue);

      final builder = AnyBuilder();
      decodeBytes(builder, encoded);
      final decoded = builder.build();

      expect(decoded.lookupByString('Data').asBytes(), equals(sampleBytes));
      final links = decoded.lookupByString('Links');
      expect(links.length(), equals(1));

      final firstLink = links.lookupByIndex(0);
      expect(firstLink.lookupByString('Name').asString(), equals('link-alpha'));
      expect(firstLink.lookupByString('Tsize').asInt(), equals(1024));
      final decodedLink = firstLink.lookupByString('Hash').asLink();
      expect(decodedLink, isA<CidLink>());
      expect((decodedLink as CidLink).cid.toString(), equals(sampleCid.toString()));
    });

    test('decodeBytes() - lanca FormatException ao receber campos duplicados ou formato corrompido', () {
      // Secao Data duplicada: tag 1 wireType 2 com 0 bytes seguida de tag 1 wireType 2
      final duplicateDataBytes = Uint8List.fromList([10, 0, 10, 0]);
      expect(
        () => decodeBytes(AnyBuilder(), duplicateDataBytes),
        throwsA(isA<FormatException>()),
      );

      // Numero de campo invalido para PBNode (ex: tag 3 wireType 2 = 26)
      final invalidFieldBytes = Uint8List.fromList([26, 0]);
      expect(
        () => decodeBytes(AnyBuilder(), invalidFieldBytes),
        throwsA(isA<FormatException>()),
      );

      // Tag truncada / inesperado EOF
      final truncatedBytes = Uint8List.fromList([10]);
      expect(
        () => decodeBytes(AnyBuilder(), truncatedBytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('appendEncode() - serializa no IPLD para DAG-PB preservando prefixo fornecido', () {
      final sampleCid = Cid.decode('bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi');
      final prefix = Uint8List.fromList([99, 100, 101]);

      final node = PlainMap({
        'Data': PlainBytes(Uint8List.fromList([1, 2, 3])),
        'Links': PlainList([
          PlainMap({
            'Hash': PlainLink(CidLink(sampleCid)),
            'Name': PlainString('arquivo txt'),
            'Tsize': PlainInt(42),
          }),
        ]),
      });

      final result = appendEncode(prefix, node);
      expect(result.length, greaterThan(prefix.length));
      expect(result.sublist(0, prefix.length), equals(prefix));

      // Prefixo original permanece inalterado
      expect(prefix, equals(Uint8List.fromList([99, 100, 101])));
    });

    test('appendEncode() - lanca FormatException se estrutura do no contiver campos invalidos ou Tsize negativo', () {
      final sampleCid = Cid.decode('bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi');

      // Tsize negativo deve ser rejeitado
      final negativeTsizeNode = PlainMap({
        'Links': PlainList([
          PlainMap({
            'Hash': PlainLink(CidLink(sampleCid)),
            'Name': PlainString('invalido'),
            'Tsize': PlainInt(-10),
          }),
        ]),
      });
      expect(
        () => appendEncode(Uint8List(0), negativeTsizeNode),
        throwsA(isA<FormatException>()),
      );

      // Campo nao reconhecido em PBNode
      final invalidFieldNode = PlainMap({
        'Links': const PlainList([]),
        'CampoInvalido': PlainString('violacao'),
      });
      expect(
        () => appendEncode(Uint8List(0), invalidFieldNode),
        throwsA(isA<FormatException>()),
      );

      // No que nao seja Map
      final nonMapNode = PlainString('nao sou mapa');
      expect(
        () => appendEncode(Uint8List(0), nonMapNode),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
