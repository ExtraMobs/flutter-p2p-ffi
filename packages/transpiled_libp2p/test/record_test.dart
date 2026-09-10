// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Parity vectors from go-libp2p core/record's own record_test.go
// (go-ipfs-reference/go-libp2p/core/record/record_test.go).
import 'dart:typed_data';

import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:test/test.dart';

final _testPayloadType = Uint8List.fromList(
  '/libp2p/test/record/payload-type'.codeUnits,
);

class _TestPayload implements Record {
  bool unmarshalPayloadCalled = false;

  @override
  String domain() => 'testing';

  @override
  Uint8List codec() => _testPayloadType;

  @override
  Uint8List marshalRecord() => Uint8List.fromList('hello'.codeUnits);

  @override
  void unmarshalRecord(Uint8List data) {
    unmarshalPayloadCalled = true;
  }
}

void main() {
  group('unmarshalRecordPayload', () {
    test('fails if payload type is unregistered', () {
      expect(
        () => unmarshalRecordPayload(
          Uint8List.fromList('unknown type'.codeUnits),
          Uint8List(0),
        ),
        throwsA(isA<PayloadTypeNotRegisteredException>()),
      );
    });

    test('calls unmarshalRecord on the concrete Record type', () {
      registerType(_TestPayload.new);

      final payload = unmarshalRecordPayload(_testPayloadType, Uint8List(0));
      expect(payload, isA<_TestPayload>());
      expect((payload as _TestPayload).unmarshalPayloadCalled, isTrue);
    });
  });
}
