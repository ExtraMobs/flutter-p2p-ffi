// test/atomic/nivel_1/protobuf_atomic_tests.dart
// Testes atomicos 1 para 1 para o modulo protobuf (transpiled_protobuf).

import 'dart:typed_data';
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';
import 'package:transpiled_protobuf/transpiled_protobuf.dart';

void main() {
  group('Top-Level Functions [Atomic Audit]', () {
    test('consumeVarint() - decodifica varint de 1 byte varios bytes e lida com truncamento e overflow', () {
      // 1 byte
      final (v0, n0) = consumeVarint(Uint8List.fromList([0]));
      expect(v0.toBigInt().toInt(), equals(0));
      expect(n0, equals(1));

      final (v1, n1) = consumeVarint(Uint8List.fromList([1]));
      expect(v1.toBigInt().toInt(), equals(1));
      expect(n1, equals(1));

      final (v127, n127) = consumeVarint(Uint8List.fromList([127]));
      expect(v127.toBigInt().toInt(), equals(127));
      expect(n127, equals(1));

      // Multiplos bytes (300 = 0xAC, 0x02)
      final (v300, n300) = consumeVarint(Uint8List.fromList([0xAC, 0x02]));
      expect(v300.toBigInt().toInt(), equals(300));
      expect(n300, equals(2));

      // Max uint64 (10 bytes)
      final maxBytes = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01]);
      final (vMax, nMax) = consumeVarint(maxBytes);
      expect(vMax, equals(Golang.Uint64.fromBigInt(BigInt.parse('18446744073709551615'))));
      expect(nMax, equals(10));

      // Buffer vazio (EOF -1)
      final (vEmpty, nEmpty) = consumeVarint(Uint8List(0));
      expect(vEmpty.toBigInt().toInt(), equals(0));
      expect(nEmpty, equals(-1));

      // Buffer truncado no meio de varint multi-byte (EOF -1)
      final (vTrunc, nTrunc) = consumeVarint(Uint8List.fromList([0x80, 0x80]));
      expect(vTrunc.toBigInt().toInt(), equals(0));
      expect(nTrunc, equals(-1));

      // Overflow de 10 bytes com 10o byte > 1 (overflow -3)
      final overflowBytes = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x02]);
      final (vOver, nOver) = consumeVarint(overflowBytes);
      expect(vOver.toBigInt().toInt(), equals(0));
      expect(nOver, equals(-3));

      // Overflow de 10 bytes com bit msb setado no 10o byte (overflow -3)
      final overMsbBytes = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x80]);
      final (vOverMsb, nOverMsb) = consumeVarint(overMsbBytes);
      expect(vOverMsb.toBigInt().toInt(), equals(0));
      expect(nOverMsb, equals(-3));
    });

    test('decodeTag() - decodifica numero de campo e wire type e detecta overflow', () {
      // Campo 1 tipo 2 (length-delimited): (1 << 3) | 2 = 10
      final (num1, type1) = decodeTag(Golang.Uint64(10));
      expect(num1, equals(1));
      expect(type1, equals(2));

      // Campo 2 tipo 0 (varint): (2 << 3) | 0 = 16
      final (num2, type2) = decodeTag(Golang.Uint64(16));
      expect(num2, equals(2));
      expect(type2, equals(0));

      // Campo maximo int32 permitido (0x7fffffff)
      final maxFieldTag = (Golang.Uint64(0x7fffffff) << 3) | Golang.Uint64(1);
      final (maxNum, maxType) = decodeTag(maxFieldTag);
      expect(maxNum, equals(0x7fffffff));
      expect(maxType, equals(1));

      // Overflow de numero de campo maior que 0x7fffffff retorna -1 e 0
      final overflowTag = (Golang.Uint64(0x80000000) << 3) | Golang.Uint64(0);
      final (overNum, overType) = decodeTag(overflowTag);
      expect(overNum, equals(-1));
      expect(overType, equals(0));
    });

    test('encodeTag() - codifica numero de campo e wire type aplicando mascara de 3 bits', () {
      final tag1 = encodeTag(1, 2);
      expect(tag1, equals(Golang.Uint64(10)));

      final tag2 = encodeTag(2, 0);
      expect(tag2, equals(Golang.Uint64(16)));

      // Wire type e mascarado com & 7 (10 & 7 == 2)
      final tagMasked = encodeTag(1, 10);
      expect(tagMasked, equals(Golang.Uint64(10)));

      // Numero de campo grande
      final tagLarge = encodeTag(0x0fffffff, 5);
      expect(tagLarge, equals((Golang.Uint64(0x0fffffff) << 3) | Golang.Uint64(5)));
    });

    test('consumeTag() - consome tag valida do buffer e lida com buffer truncado e campo invalido', () {
      // Campo 1 varint (0x08)
      final (num1, type1, n1) = consumeTag(Uint8List.fromList([0x08]));
      expect(num1, equals(1));
      expect(type1, equals(0));
      expect(n1, equals(1));

      // Campo 2 length-delimited (0x12)
      final (num2, type2, n2) = consumeTag(Uint8List.fromList([0x12]));
      expect(num2, equals(2));
      expect(type2, equals(2));
      expect(n2, equals(1));

      // Buffer vazio retorna erro de eof -1
      final (numEmpty, typeEmpty, nEmpty) = consumeTag(Uint8List(0));
      expect(numEmpty, equals(0));
      expect(typeEmpty, equals(0));
      expect(nEmpty, equals(-1));

      // Campo invalido menor que 1 (tag 0x00 tem campo 0) retorna erro -2
      final (numZero, typeZero, nZero) = consumeTag(Uint8List.fromList([0x00]));
      expect(numZero, equals(0));
      expect(typeZero, equals(0));
      expect(nZero, equals(-2));
    });

    test('consumeBytes() - consome bytes prefixados por comprimento e lida com truncamento', () {
      // Sucesso com payload
      final data = Uint8List.fromList([3, 10, 20, 30, 99]);
      final (view, consumed) = consumeBytes(data);
      expect(view, isNotNull);
      expect(view, equals(Uint8List.fromList([10, 20, 30])));
      expect(consumed, equals(4));

      // Sucesso com comprimento zero
      final emptyPayload = Uint8List.fromList([0, 99]);
      final (viewEmpty, consumedEmpty) = consumeBytes(emptyPayload);
      expect(viewEmpty, isNotNull);
      expect(viewEmpty!.length, equals(0));
      expect(consumedEmpty, equals(1));

      // Truncado sem tamanho suficiente
      final truncatedVarint = Uint8List(0);
      final (viewTrVar, consumedTrVar) = consumeBytes(truncatedVarint);
      expect(viewTrVar, isNull);
      expect(consumedTrVar, equals(-1));

      // Truncado: tamanho declarado maior que o restante do buffer
      final truncatedPayload = Uint8List.fromList([10, 1, 2, 3]);
      final (viewTrPay, consumedTrPay) = consumeBytes(truncatedPayload);
      expect(viewTrPay, isNull);
      expect(consumedTrPay, equals(-1));
    });

    test('appendVarint() - anexa valor uint64 a lista de bytes mutavel', () {
      final list = <int>[];
      final res0 = appendVarint(list, Golang.Uint64(0));
      expect(res0, equals([0]));
      expect(identical(res0, list), isTrue);

      final list300 = <int>[];
      appendVarint(list300, Golang.Uint64(300));
      expect(list300, equals([0xAC, 0x02]));

      final listPrefix = <int>[99];
      appendVarint(listPrefix, Golang.Uint64(1));
      expect(listPrefix, equals([99, 1]));
    });

    test('appendTag() - anexa tag codificada a lista de bytes', () {
      final list1 = <int>[];
      final res1 = appendTag(list1, 1, 2);
      expect(res1, equals([0x0A]));
      expect(identical(res1, list1), isTrue);

      final list2 = <int>[];
      appendTag(list2, 2, 0);
      expect(list2, equals([0x10]));

      final listPref = <int>[0xFF];
      appendTag(listPref, 1, 0);
      expect(listPref, equals([0xFF, 0x08]));
    });

    test('appendBytes() - anexa prefixo de comprimento e bytes de payload', () {
      final list = <int>[];
      final res = appendBytes(list, [10, 20, 30]);
      expect(res, equals([3, 10, 20, 30]));
      expect(identical(res, list), isTrue);

      final listEmpty = <int>[];
      appendBytes(listEmpty, []);
      expect(listEmpty, equals([0]));

      final listPref = <int>[42];
      appendBytes(listPref, [7, 8]);
      expect(listPref, equals([42, 2, 7, 8]));
    });

    test('sizeVarint() - calcula tamanho em bytes para codificacao varint de uint64', () {
      expect(sizeVarint(Golang.Uint64(0)), equals(1));
      expect(sizeVarint(Golang.Uint64(1)), equals(1));
      expect(sizeVarint(Golang.Uint64(127)), equals(1));
      expect(sizeVarint(Golang.Uint64(128)), equals(2));
      expect(sizeVarint(Golang.Uint64(16383)), equals(2));
      expect(sizeVarint(Golang.Uint64(16384)), equals(3));
      expect(sizeVarint(Golang.Uint64.fromBigInt(BigInt.parse('18446744073709551615'))), equals(10));
    });

    test('sizeTag() - calcula tamanho em bytes da tag para numero de campo', () {
      expect(sizeTag(1), equals(1));
      expect(sizeTag(15), equals(1));
      expect(sizeTag(16), equals(2));
      expect(sizeTag(2047), equals(2));
      expect(sizeTag(2048), equals(3));
    });

    test('sizeBytes() - calcula tamanho total incluindo prefixo varint e bytes', () {
      expect(sizeBytes(0), equals(1));
      expect(sizeBytes(10), equals(11));
      expect(sizeBytes(127), equals(128));
      expect(sizeBytes(128), equals(130));
    });

    test('appendFixed32() - anexa valor uint32 em little-endian a lista de bytes', () {
      final list = <int>[];
      final res = appendFixed32(list, Golang.Uint32(0x12345678));
      expect(res, equals([0x78, 0x56, 0x34, 0x12]));
      expect(identical(res, list), isTrue);

      final listPref = <int>[0xAA];
      appendFixed32(listPref, Golang.Uint32(0x01020304));
      expect(listPref, equals([0xAA, 0x04, 0x03, 0x02, 0x01]));
    });

    test('consumeFixed32() - consome uint32 little-endian e detecta buffer truncado', () {
      final buf = Uint8List.fromList([0x78, 0x56, 0x34, 0x12, 0x99]);
      final (val, consumed) = consumeFixed32(buf);
      expect(val, equals(Golang.Uint32(0x12345678)));
      expect(consumed, equals(4));

      // Menos de 4 bytes retorna 0 e -1
      final shortBuf = Uint8List.fromList([0x78, 0x56, 0x34]);
      final (shortVal, shortConsumed) = consumeFixed32(shortBuf);
      expect(shortVal, equals(Golang.Uint32(0)));
      expect(shortConsumed, equals(-1));

      // Vazio
      final (emptyVal, emptyConsumed) = consumeFixed32(Uint8List(0));
      expect(emptyVal, equals(Golang.Uint32(0)));
      expect(emptyConsumed, equals(-1));
    });

    test('sizeFixed32() - retorna tamanho fixo de 4 bytes', () {
      expect(sizeFixed32(), equals(4));
    });

    test('appendFixed64() - anexa valor uint64 em little-endian a lista de bytes', () {
      final list = <int>[];
      final res = appendFixed64(list, Golang.Uint64.fromBigInt(BigInt.parse('0x0102030405060708')));
      expect(res, equals([0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01]));
      expect(identical(res, list), isTrue);

      final listPref = <int>[0xEE];
      appendFixed64(listPref, Golang.Uint64(0));
      expect(listPref, equals([0xEE, 0, 0, 0, 0, 0, 0, 0, 0]));
    });

    test('consumeFixed64() - consome uint64 little-endian e detecta buffer truncado', () {
      final buf = Uint8List.fromList([0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01, 0x99]);
      final (val, consumed) = consumeFixed64(buf);
      expect(val, equals(Golang.Uint64.fromBigInt(BigInt.parse('0x0102030405060708'))));
      expect(consumed, equals(8));

      // Menos de 8 bytes retorna 0 e -1
      final shortBuf = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7]);
      final (shortVal, shortConsumed) = consumeFixed64(shortBuf);
      expect(shortVal, equals(Golang.Uint64(0)));
      expect(shortConsumed, equals(-1));

      // Vazio
      final (emptyVal, emptyConsumed) = consumeFixed64(Uint8List(0));
      expect(emptyVal, equals(Golang.Uint64(0)));
      expect(emptyConsumed, equals(-1));
    });

    test('sizeFixed64() - retorna tamanho fixo de 8 bytes', () {
      expect(sizeFixed64(), equals(8));
    });

    test('appendString() - anexa string codificada com prefixo varint de tamanho', () {
      final list = <int>[];
      final res = appendString(list, Golang.String.fromDart('hello'));
      expect(res, equals([5, 104, 101, 108, 108, 111]));
      expect(identical(res, list), isTrue);

      final listEmpty = <int>[];
      appendString(listEmpty, Golang.String());
      expect(listEmpty, equals([0]));

      final listPref = <int>[0x01];
      appendString(listPref, Golang.String.fromDart('a'));
      expect(listPref, equals([0x01, 1, 97]));
    });

    test('consumeString() - consome string prefixada por comprimento e detecta erro', () {
      final buf = Uint8List.fromList([5, 104, 101, 108, 108, 111, 99]);
      final (str, consumed) = consumeString(buf);
      expect(str, equals(Golang.String.fromDart('hello')));
      expect(consumed, equals(6));

      // String vazia
      final emptyBuf = Uint8List.fromList([0]);
      final (strEmpty, consumedEmpty) = consumeString(emptyBuf);
      expect(strEmpty, equals(Golang.String()));
      expect(consumedEmpty, equals(1));

      // Buffer truncado no payload
      final truncBuf = Uint8List.fromList([5, 104, 101]);
      final (strTrunc, consumedTrunc) = consumeString(truncBuf);
      expect(strTrunc, equals(Golang.String()));
      expect(consumedTrunc, equals(-1));

      // Buffer vazio
      final (strE, consumedE) = consumeString(Uint8List(0));
      expect(strE, equals(Golang.String()));
      expect(consumedE, equals(-1));
    });

    test('parseError() - mapeia codigos de erro negativos para FormatException', () {
      expect(parseError(0), isNull);
      expect(parseError(5), isNull);
      expect(parseError(-1)?.message, equals('unexpected EOF'));
      expect(parseError(-2)?.message, equals('invalid field number'));
      expect(parseError(-3)?.message, equals('variable length integer overflow'));
      expect(parseError(-4)?.message, equals('cannot parse reserved wire type'));
      expect(parseError(-5)?.message, equals('mismatching end group marker'));
      expect(parseError(-99)?.message, equals('parse error'));
    });
  });
}
