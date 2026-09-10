// test/atomic/nivel_2/record_atomic_tests.dart
// Testes atomicos 1 para 1 para o modulo libp2p_record (transpiled_libp2p_record).

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart' hide Record;
import 'package:transpiled_libp2p_record/transpiled_libp2p_record.dart';

class _SimpleValidator implements Validator {
  @override
  void validate(String key, Uint8List value) {
    if (value.isEmpty) {
      throw ArgumentError('value cannot be empty');
    }
  }

  @override
  int select(String key, List<Uint8List> values) {
    if (values.isEmpty) {
      throw ArgumentError('cannot select from empty values');
    }
    return values.length - 1;
  }
}

void main() {
  group('PublicKeyValidator [Atomic Audit]', () {
    test('validate() - valida chave publica ed25519 e rsa correspondentes ao peer id da chave', () async {
      const pkv = PublicKeyValidator();
      final edPair = await generateEd25519KeyPair();
      final edPub = marshalPublicKey(edPair.getPublic());
      final edId = PeerId.fromPubKey(edPair.getPublic());
      final validKey = '/pk/${String.fromCharCodes(edId.value)}';

      expect(() => pkv.validate(validKey, edPub), returnsNormally);

      final badNsKey = '/wrong/${String.fromCharCodes(edId.value)}';
      expect(() => pkv.validate(badNsKey, edPub), throwsArgumentError);

      final otherPair = await generateEd25519KeyPair();
      final otherPub = marshalPublicKey(otherPair.getPublic());
      expect(() => pkv.validate(validKey, otherPub), throwsArgumentError);

      final malformedKey = '/pk/not-a-valid-multihash';
      expect(() => pkv.validate(malformedKey, edPub), throwsA(anything));
    });

    test('select() - retorna invariavelmente o indice zero para qualquer lista de valores', () {
      const pkv = PublicKeyValidator();
      final idx = pkv.select('/pk/key', [
        Uint8List.fromList([1, 2]),
        Uint8List.fromList([3, 4]),
      ]);
      expect(idx, equals(0));
    });
  });

  group('Record [Atomic Audit]', () {
    test('toProtobuf() - serializa Record para formato binario protobuf preservando campos', () {
      final key = Uint8List.fromList([1, 2, 3]);
      final value = Uint8List.fromList([10, 20, 30, 40]);
      final record = Record(
        key: key,
        value: value,
        timeReceived: '2026-09-08T22:00:00Z',
      );

      final encoded = record.toProtobuf();
      expect(encoded, isNotEmpty);

      final decoded = Record.fromProtobuf(encoded);
      expect(decoded.key, equals(key));
      expect(decoded.value, equals(value));
      expect(decoded.timeReceived, equals('2026-09-08T22:00:00Z'));
    });
  });

  group('InvalidRecordTypeException [Atomic Audit]', () {
    test('toString() - formata mensagem descritiva de erro de tipo de registro invalido', () {
      const ex = InvalidRecordTypeException();
      expect(ex.toString(), equals('invalid record keytype'));
    });
  });

  group('BetterRecordException [Atomic Audit]', () {
    test('toString() - formata mensagem indicando valor melhor encontrado para a chave', () {
      final ex = BetterRecordException(
        key: '/pk/target_peer',
        value: Uint8List.fromList([7, 8, 9]),
      );
      expect(ex.toString(), equals('found better value for "/pk/target_peer"'));
    });
  });

  group('Validator [Atomic Audit]', () {
    test('validate() - interface abstrata valida chave e valor conforme regras do validador', () {
      final Validator v = _SimpleValidator();
      expect(() => v.validate('/custom/key', Uint8List.fromList([1, 2])), returnsNormally);
      expect(() => v.validate('/custom/key', Uint8List(0)), throwsArgumentError);
    });

    test('select() - interface abstrata seleciona o indice do melhor registro', () {
      final Validator v = _SimpleValidator();
      final idx = v.select('/custom/key', [
        Uint8List.fromList([1]),
        Uint8List.fromList([2]),
      ]);
      expect(idx, equals(1));
    });
  });

  group('NamespacedValidator [Atomic Audit]', () {
    test('validatorByKey() - resolve validador registrado pelo namespace ou retorna nulo', () {
      final simple = _SimpleValidator();
      final nv = NamespacedValidator({'custom': simple});

      expect(nv.validatorByKey('/custom/sample'), equals(simple));
      expect(nv.validatorByKey('/unregistered/sample'), isNull);
      expect(nv.validatorByKey('malformed_key'), isNull);
    });

    test('validate() - despacha validacao para o validador registrado no namespace', () {
      final simple = _SimpleValidator();
      final nv = NamespacedValidator({'custom': simple});

      expect(
        () => nv.validate('/custom/sample', Uint8List.fromList([1, 2, 3])),
        returnsNormally,
      );
      expect(
        () => nv.validate('/custom/sample', Uint8List(0)),
        throwsArgumentError,
      );
      expect(
        () => nv.validate('/missing/sample', Uint8List.fromList([1])),
        throwsA(isA<InvalidRecordTypeException>()),
      );
      expect(
        () => nv.validate('bad_key', Uint8List.fromList([1])),
        throwsA(isA<InvalidRecordTypeException>()),
      );
    });

    test('select() - delega selecao para o validador correspondente ao namespace da chave', () {
      final simple = _SimpleValidator();
      final nv = NamespacedValidator({'custom': simple});

      final selected = nv.select('/custom/sample', [
        Uint8List.fromList([10]),
        Uint8List.fromList([20]),
      ]);
      expect(selected, equals(1));

      expect(
        () => nv.select('/custom/sample', []),
        throwsArgumentError,
      );
      expect(
        () => nv.select('/missing/sample', [Uint8List.fromList([1])]),
        throwsA(isA<InvalidRecordTypeException>()),
      );
      expect(
        () => nv.select('bad_key', [Uint8List.fromList([1])]),
        throwsA(isA<InvalidRecordTypeException>()),
      );
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test('splitKey() - separa chave nos componentes namespace e path lancando excecao para chaves invalidas', () {
      final (ns1, path1) = splitKey('/pk/12D3KooW');
      expect(ns1, equals('pk'));
      expect(path1, equals('12D3KooW'));

      final (ns2, path2) = splitKey('/ipns/sub/deep/path');
      expect(ns2, equals('ipns'));
      expect(path2, equals('sub/deep/path'));

      expect(() => splitKey(''), throwsA(isA<InvalidRecordTypeException>()));
      expect(() => splitKey('pk/no_slash'), throwsA(isA<InvalidRecordTypeException>()));
      expect(() => splitKey('/only_one_slash'), throwsA(isA<InvalidRecordTypeException>()));
      expect(() => splitKey('/'), throwsA(isA<InvalidRecordTypeException>()));
      expect(() => splitKey('//'), throwsA(isA<InvalidRecordTypeException>()));
    });
  });
}
