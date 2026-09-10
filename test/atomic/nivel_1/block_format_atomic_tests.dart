// test/atomic/nivel_1/block_format_atomic_tests.dart
// Testes atômicos 1 para 1 para o módulo block_format (transpiled_block_format).

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:transpiled_block_format/transpiled_block_format.dart';

void main() {
  group('WrongHashException [Atomic Audit]', () {
    test('toString() - retorna mensagem de erro de hash divergente', () {
      const ex = WrongHashException();
      expect(ex.toString(), equals('data did not match given hash'));
    });
  });

  group('Block [Atomic Audit]', () {
    test('rawData() - retorna payload binario do bloco via interface', () {
      final Block block = BasicBlock.fromData(Uint8List.fromList([1, 2, 3]));
      expect(block.rawData(), equals(Uint8List.fromList([1, 2, 3])));
    });

    test('cid() - retorna identificador de conteudo Cid via interface', () {
      final Block block = BasicBlock.fromData(Uint8List.fromList([1, 2, 3]));
      expect(block.cid(), isNotNull);
      expect(block.cid().version, equals(0));
    });

    test('toString() - formata bloco em representacao legivel via interface', () {
      final Block block = BasicBlock.fromData(Uint8List.fromList([1, 2, 3]));
      expect(block.toString(), contains('Block'));
    });

    test('loggable() - produz mapa de campos estruturados de log via interface', () {
      final Block block = BasicBlock.fromData(Uint8List.fromList([1, 2, 3]));
      final map = block.loggable();
      expect(map, containsPair('block', block.cid().toString()));
    });
  });

  group('BasicBlock [Atomic Audit]', () {
    test('rawData() - retorna bytes brutos encapsulados no bloco basico', () {
      final block = BasicBlock.fromData(Uint8List.fromList([10, 20, 30]));
      expect(block.rawData(), equals(Uint8List.fromList([10, 20, 30])));
    });

    test('cid() - retorna Cid do bloco basico gerado a partir dos dados', () {
      final block = BasicBlock.fromData(Uint8List.fromList([10, 20, 30]));
      expect(block.cid().version, equals(0));
    });

    test('multihash() - extrai bytes do multihash associado ao Cid do bloco', () {
      final block = BasicBlock.fromData(Uint8List.fromList([10, 20, 30]));
      expect(block.multihash().isNotEmpty, isTrue);
    });

    test('toString() - converte bloco basico para string formatada', () {
      final block = BasicBlock.fromData(Uint8List.fromList([10, 20, 30]));
      expect(block.toString(), equals('[Block ${block.cid()}]'));
    });

    test('loggable() - expoe mapa contendo a chave block com a string do Cid', () {
      final block = BasicBlock.fromData(Uint8List.fromList([10, 20, 30]));
      expect(block.loggable()['block'], equals(block.cid().toString()));
    });
  });
}
