// test/atomic/nivel_1/cid_atomic_tests.dart
// Testes atômicos 1 para 1 para o módulo cid (transpiled_cid).

import 'dart:convert';
import 'dart:typed_data';
import 'package:multibase/multibase.dart' as mb;
import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';

void main() {
  final sampleData = Uint8List.fromList(utf8.encode('ipfs content addressing sample data'));

  group('Cid [Atomic Audit]', () {
    test('bytes() - delega para toBytes retornando representacao binaria', () {
      final cid = Cid.computeForDataSync(sampleData);
      expect(cid.bytes(), equals(cid.toBytes()));
      expect(cid.bytes().isNotEmpty, isTrue);
    });

    test('fromContent() - gera Cid v1 e v0 de forma assincrona a partir de payload binario', () async {
      final cidV1 = await Cid.fromContent(sampleData, codec: 'raw', version: 1);
      expect(cidV1.version, equals(1));
      expect(cidV1.codec, equals('raw'));

      final cidV0 = await Cid.fromContent(sampleData, version: 0);
      expect(cidV0.version, equals(0));
      expect(cidV0.codec, equals('dag-pb'));
    });

    test('computeForData() - conveniencia assincrona gerando Cid valido', () async {
      final cid = await Cid.computeForData(sampleData, format: 'raw');
      expect(cid.version, equals(1));
      expect(cid.validate(), isTrue);
    });

    test('computeForDataSync() - calcula Cid v1 sincronamente com SHA2-256', () {
      final cid = Cid.computeForDataSync(sampleData, codec: 'raw');
      expect(cid.version, equals(1));
      expect(cid.codec, equals('raw'));
      expect(cid.multihash.name, equals('sha2-256'));
    });

    test('fromPrefixBytes() - reconstroi Cid a partir do prefixo serializado e payload', () async {
      final cidOriginal = Cid.computeForDataSync(sampleData, codec: 'raw');
      final prefixBytes = cidOriginal.toPrefixBytes();
      final cidReconstructed = await Cid.fromPrefixBytes(prefixBytes, sampleData);
      expect(cidReconstructed, equals(cidOriginal));
    });

    test('fromBytes() - decodifica bytes binarios de Cid v0 e v1', () {
      final cidV1 = Cid.computeForDataSync(sampleData, codec: 'raw');
      final rawV1 = cidV1.toBytes();
      final decodedV1 = Cid.fromBytes(rawV1);
      expect(decodedV1, equals(cidV1));

      final cidV0 = Cid.v0(Uint8List(32));
      final rawV0 = cidV0.toBytes();
      final decodedV0 = Cid.fromBytes(rawV0);
      expect(decodedV0.version, equals(0));
    });

    test('decode() - decodifica strings representativas de Cid v0 e v1', () {
      final cidV1 = Cid.computeForDataSync(sampleData, codec: 'raw');
      final strV1 = cidV1.encode();
      final parsedV1 = Cid.decode(strV1);
      expect(parsedV1, equals(cidV1));
    });

    test('codec - getter retorna nome canonico do formato registrado', () {
      final cid = Cid.computeForDataSync(sampleData, codec: 'raw');
      expect(cid.codec, equals('raw'));
    });

    test('encode() - codifica Cid para string usando multibase padrao', () {
      final cid = Cid.computeForDataSync(sampleData, codec: 'raw');
      final str = cid.encode();
      expect(str.startsWith('b'), isTrue);
    });

    test('encodeWithBase() - codifica Cid v1 usando a base multibase informada', () {
      final cid = Cid.computeForDataSync(sampleData, codec: 'raw');
      final b58Str = cid.encodeWithBase(mb.Multibase.base58btc);
      expect(b58Str.startsWith('z'), isTrue);
    });

    test('encodeWithBaseName() - codifica Cid usando o nome da base textual', () {
      final cid = Cid.computeForDataSync(sampleData, codec: 'raw');
      final str = cid.encodeWithBaseName('base58btc');
      expect(str.startsWith('z'), isTrue);
    });

    test('toBytes() - serializa Cid para formato binario autodescritivo', () {
      final cid = Cid.computeForDataSync(sampleData, codec: 'raw');
      final bytes = cid.toBytes();
      expect(bytes[0], equals(0x01));
      expect(bytes.length, greaterThan(32));
    });

    test('toPrefixBytes() - extrai bytes do prefixo omitindo digest', () {
      final cid = Cid.computeForDataSync(sampleData, codec: 'raw');
      final prefixBytes = cid.toPrefixBytes();
      expect(prefixBytes.length, lessThan(cid.toBytes().length));
    });

    test('prefix - getter produz objeto Prefix com caracteristicas do Cid', () {
      final cid = Cid.computeForDataSync(sampleData, codec: 'raw');
      final pref = cid.prefix;
      expect(pref.version, equals(cid.version));
      expect(pref.codec, equals('raw'));
    });

    test('validate() - valida invariantes estruturais do Cid', () {
      final cid = Cid.computeForDataSync(sampleData, codec: 'raw');
      expect(cid.validate(), isTrue);
    });

    test('defined - getter retorna se Cid possui estrutura valida definida', () {
      final cid = Cid.computeForDataSync(sampleData, codec: 'raw');
      expect(cid.defined, isTrue);
    });

    test('toString() - converte Cid para sua representacao textual codificada', () {
      final cid = Cid.computeForDataSync(sampleData, codec: 'raw');
      expect(cid.toString(), equals(cid.encode()));
    });

    test('operator == - compara igualdade estrutural e de digest entre Cids', () {
      final cidA = Cid.computeForDataSync(sampleData, codec: 'raw');
      final cidB = Cid.computeForDataSync(sampleData, codec: 'raw');
      expect(cidA == cidB, isTrue);
    });

    test('hashCode - gera hash consistente para instancias estruturalmente equivalentes', () {
      final cidA = Cid.computeForDataSync(sampleData, codec: 'raw');
      final cidB = Cid.computeForDataSync(sampleData, codec: 'raw');
      expect(cidA.hashCode, equals(cidB.hashCode));
    });
  });

  group('Prefix [Atomic Audit]', () {
    final prefix = Prefix(version: 1, codec: 'raw', mhType: 'sha2-256', mhLength: 32);

    test('codec - getter retorna nome do codec configurado no prefixo', () {
      expect(prefix.codec, equals('raw'));
    });

    test('mhType - getter retorna nome da funcao multihash configurada', () {
      expect(prefix.mhType, equals('sha2-256'));
    });

    test('bytes() - serializa prefixo em quatro varints binarios', () {
      final b = prefix.bytes();
      expect(b.isNotEmpty, isTrue);
      final decodedPref = Prefix.fromBytes(b);
      expect(decodedPref, equals(prefix));
    });

    test('sum() - computa multihash dos dados gerando novo Cid compativel', () {
      final cid = prefix.sum(sampleData);
      expect(cid.version, equals(1));
      expect(cid.codec, equals('raw'));
    });

    test('operator == - compara igualdade entre prefixos', () {
      final prefixB = Prefix(version: 1, codec: 'raw', mhType: 'sha2-256', mhLength: 32);
      expect(prefix == prefixB, isTrue);
    });

    test('hashCode - produz codigo hash consistente para prefixos iguais', () {
      final prefixB = Prefix(version: 1, codec: 'raw', mhType: 'sha2-256', mhLength: 32);
      expect(prefix.hashCode, equals(prefixB.hashCode));
    });
  });

  group('InvalidCidException [Atomic Audit]', () {
    test('toString() - formata mensagem de erro de Cid invalido', () {
      const exNoCause = InvalidCidException();
      expect(exNoCause.toString(), equals('invalid cid'));

      const exWithCause = InvalidCidException('corrupted prefix');
      expect(exWithCause.toString(), equals('invalid cid: corrupted prefix'));
    });
  });

  group('CidTooShortException [Atomic Audit]', () {
    test('toString() - formata mensagem de erro de Cid excessivamente curto', () {
      const ex = CidTooShortException();
      expect(ex.toString(), equals('cid too short'));
    });
  });

  group('InvalidEncodingException [Atomic Audit]', () {
    test('toString() - formata mensagem de erro de codificacao base multibase invalida', () {
      const exNoCause = InvalidEncodingException();
      expect(exNoCause.toString(), equals('invalid base encoding'));

      const exWithCause = InvalidEncodingException('unsupported base character');
      expect(exWithCause.toString(), equals('invalid base encoding: unsupported base character'));
    });
  });
}
