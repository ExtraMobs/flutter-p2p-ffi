// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Parity vectors from go-libp2p core/record's own envelope_test.go
// (go-ipfs-reference/go-libp2p/core/record/envelope_test.go).
import 'dart:typed_data';

import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:test/test.dart';

class _SimpleRecord implements Record {
  _SimpleRecord({this.message = '', String? testDomain, Uint8List? testCodec})
    : _testDomain = testDomain,
      _testCodec = testCodec;

  String message;
  final String? _testDomain;
  final Uint8List? _testCodec;

  @override
  String domain() => _testDomain ?? 'libp2p-testing';

  @override
  Uint8List codec() => _testCodec ?? Uint8List.fromList('/libp2p/testdata'.codeUnits);

  @override
  Uint8List marshalRecord() => Uint8List.fromList(message.codeUnits);

  @override
  void unmarshalRecord(Uint8List data) {
    message = String.fromCharCodes(data);
  }
}

class _FailingRecord implements Record {
  _FailingRecord({this.allowMarshal = false});

  final bool allowMarshal;

  @override
  String domain() => 'testing';

  @override
  Uint8List codec() => Uint8List.fromList("doesn't matter".codeUnits);

  @override
  Uint8List marshalRecord() {
    if (allowMarshal) return Uint8List(0);
    throw Exception('marshal failed');
  }

  @override
  void unmarshalRecord(Uint8List data) {
    throw Exception('unmarshal failed');
  }
}

// Minimal re-implementation of the Envelope{1,2,3,5} wire encoding (see
// envelope.dart), used here only to tamper with a sealed envelope's bytes
// the same way go-libp2p's envelope_test.go's `alterMessageAndMarshal`
// does via direct protobuf field access.
Uint8List _varint(int value) {
  final out = <int>[];
  var v = value;
  while (v >= 0x80) {
    out.add((v & 0x7f) | 0x80);
    v >>= 7;
  }
  out.add(v);
  return Uint8List.fromList(out);
}

(int, int) _readVarint(Uint8List bytes, int offset) {
  var value = 0, shift = 0, index = offset;
  while (true) {
    final byte = bytes[index++];
    value |= (byte & 0x7f) << shift;
    if ((byte & 0x80) == 0) return (value, index - offset);
    shift += 7;
  }
}

Uint8List _field(int fieldNumber, Uint8List value) {
  final out = BytesBuilder();
  out.add(_varint((fieldNumber << 3) | 2));
  out.add(_varint(value.length));
  out.add(value);
  return out.toBytes();
}

Map<int, Uint8List> _decodeFields(Uint8List bytes) {
  final fields = <int, Uint8List>{};
  var offset = 0;
  while (offset < bytes.length) {
    final (tag, tagLen) = _readVarint(bytes, offset);
    offset += tagLen;
    final (length, lenLen) = _readVarint(bytes, offset);
    offset += lenLen;
    fields[tag >> 3] = bytes.sublist(offset, offset + length);
    offset += length;
  }
  return fields;
}

/// Re-encodes a sealed envelope's bytes with one field replaced, keeping
/// the original signature -- so the result has a *valid structure* but an
/// *invalid signature* for its (possibly altered) contents.
Uint8List _alterField(Uint8List sealed, int fieldNumber, Uint8List newValue) {
  final fields = _decodeFields(sealed);
  fields[fieldNumber] = newValue;
  final out = BytesBuilder();
  for (final n in [1, 2, 3, 5]) {
    out.add(_field(n, fields[n]!));
  }
  return out.toBytes();
}

void main() {
  group('Envelope happy path', () {
    test('seal, marshal, and consume round-trips the record', () async {
      final rec = _SimpleRecord(message: 'hello world!');
      final keyPair = await generateEd25519KeyPair();

      final payload = rec.marshalRecord();
      final envelope = await Envelope.seal(rec, keyPair);

      expect(envelope.publicKey.keyEquals(keyPair.getPublic()), isTrue);
      expect(envelope.payloadType, equals(rec.codec()));

      final serialized = envelope.marshal();
      registerType(_SimpleRecord.new);

      final (deserialized, rec2) = await Envelope.consumeEnvelope(
        serialized,
        rec.domain(),
      );

      expect(deserialized.rawPayload, equals(payload));
      expect(envelope.equals(deserialized), isTrue);
      expect(rec2, isA<_SimpleRecord>());
      expect((rec2 as _SimpleRecord).message, equals('hello world!'));
    });
  });

  group('Envelope.consumeTypedEnvelope', () {
    test('unmarshals into the given record instance', () async {
      final rec = _SimpleRecord(message: 'hello world!');
      final keyPair = await generateEd25519KeyPair();

      final envelope = await Envelope.seal(rec, keyPair);
      final envelopeBytes = envelope.marshal();

      final rec2 = _SimpleRecord();
      await Envelope.consumeTypedEnvelope(envelopeBytes, rec2);
      expect(rec2.message, equals('hello world!'));
    });
  });

  test('seal fails with an empty domain', () async {
    final rec = _SimpleRecord(message: 'hello world!', testDomain: '');
    final keyPair = await generateEd25519KeyPair();
    expect(
      () => Envelope.seal(rec, keyPair),
      throwsA(isA<EmptyDomainException>()),
    );
  });

  test('seal fails with an empty payload type', () async {
    final rec = _SimpleRecord(message: 'hello world!', testCodec: Uint8List(0));
    final keyPair = await generateEd25519KeyPair();
    expect(
      () => Envelope.seal(rec, keyPair),
      throwsA(isA<EmptyPayloadTypeException>()),
    );
  });

  test('seal fails if the record fails to marshal', () async {
    final keyPair = await generateEd25519KeyPair();
    expect(
      () => Envelope.seal(_FailingRecord(), keyPair),
      throwsException,
    );
  });

  test('consumeEnvelope fails if the envelope fails to unmarshal', () async {
    expect(
      () => Envelope.consumeEnvelope(
        Uint8List.fromList('not an Envelope protobuf'.codeUnits),
        "doesn't-matter",
      ),
      throwsA(anything),
    );
  });

  test('consumeEnvelope fails if the record fails to unmarshal', () async {
    final keyPair = await generateEd25519KeyPair();
    registerType(() => _FailingRecord(allowMarshal: true));
    final rec = _FailingRecord(allowMarshal: true);
    final envelope = await Envelope.seal(rec, keyPair);
    final envelopeBytes = envelope.marshal();

    expect(
      () => Envelope.consumeEnvelope(envelopeBytes, rec.domain()),
      throwsA(anything),
    );
  });

  test('consumeTypedEnvelope fails if the record fails to unmarshal', () async {
    final keyPair = await generateEd25519KeyPair();
    final rec = _FailingRecord(allowMarshal: true);
    final envelope = await Envelope.seal(rec, keyPair);
    final envelopeBytes = envelope.marshal();

    expect(
      () => Envelope.consumeTypedEnvelope(envelopeBytes, _FailingRecord()),
      throwsA(anything),
    );
  });

  test('validate fails for the wrong domain', () async {
    final rec = _SimpleRecord(message: 'hello world');
    final keyPair = await generateEd25519KeyPair();
    final envelope = await Envelope.seal(rec, keyPair);
    final serialized = envelope.marshal();

    expect(
      () => Envelope.consumeEnvelope(serialized, 'wrong-domain'),
      throwsA(isA<InvalidSignatureException>()),
    );
  });

  test('validate fails if the payload type is altered', () async {
    final rec = _SimpleRecord(message: 'hello world!');
    final keyPair = await generateEd25519KeyPair();
    final envelope = await Envelope.seal(rec, keyPair);
    final tampered = _alterField(
      envelope.marshal(),
      2,
      Uint8List.fromList('foo'.codeUnits),
    );

    expect(
      () => Envelope.consumeEnvelope(tampered, rec.domain()),
      throwsA(isA<InvalidSignatureException>()),
    );
  });

  test('validate fails if the payload contents are altered', () async {
    final rec = _SimpleRecord(message: 'hello world!');
    final keyPair = await generateEd25519KeyPair();
    final envelope = await Envelope.seal(rec, keyPair);
    final tampered = _alterField(
      envelope.marshal(),
      3,
      Uint8List.fromList('totally legit, trust me'.codeUnits),
    );

    expect(
      () => Envelope.consumeEnvelope(tampered, rec.domain()),
      throwsA(isA<InvalidSignatureException>()),
    );
  });
}
