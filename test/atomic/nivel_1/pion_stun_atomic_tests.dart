// test/atomic/nivel_1/pion_stun_atomic_tests.dart
// Testes atômicos 1 para 1 para o codec de mensagens/atributos STUN puro
// (transpiled_pion_stun): message.dart, attributes.dart, addr.dart,
// xoraddr.dart, integrity.dart, fingerprint.dart, errorcode.dart,
// errors.dart, checks.dart, helpers.dart, textattrs.dart, uattrs.dart,
// uri.dart e stun.dart. Vetores adaptados de
// go-ipfs-reference/pion-stun/{message,attributes,addr,xoraddr,integrity,
// fingerprint,errorcode,rfc5769}_test.go byte a byte.
// Nível 1: codec binário puro em memória, sem I/O nem rede.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_pion_stun/transpiled_pion_stun.dart';
import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart'
    show NetConn;

// RFC 5769 test vectors, transcribed byte-for-byte from
// go-ipfs-reference/pion-stun/rfc5769_test.go.
final Uint8List _rfc5769Request = Uint8List.fromList([
  0x00,
  0x01,
  0x00,
  0x58,
  0x21,
  0x12,
  0xa4,
  0x42,
  0xb7,
  0xe7,
  0xa7,
  0x01,
  0xbc,
  0x34,
  0xd6,
  0x86,
  0xfa,
  0x87,
  0xdf,
  0xae,
  0x80,
  0x22,
  0x00,
  0x10,
  0x53,
  0x54,
  0x55,
  0x4e,
  0x20,
  0x74,
  0x65,
  0x73,
  0x74,
  0x20,
  0x63,
  0x6c,
  0x69,
  0x65,
  0x6e,
  0x74,
  0x00,
  0x24,
  0x00,
  0x04,
  0x6e,
  0x00,
  0x01,
  0xff,
  0x80,
  0x29,
  0x00,
  0x08,
  0x93,
  0x2f,
  0xf9,
  0xb1,
  0x51,
  0x26,
  0x3b,
  0x36,
  0x00,
  0x06,
  0x00,
  0x09,
  0x65,
  0x76,
  0x74,
  0x6a,
  0x3a,
  0x68,
  0x36,
  0x76,
  0x59,
  0x20,
  0x20,
  0x20,
  0x00,
  0x08,
  0x00,
  0x14,
  0x9a,
  0xea,
  0xa7,
  0x0c,
  0xbf,
  0xd8,
  0xcb,
  0x56,
  0x78,
  0x1e,
  0xf2,
  0xb5,
  0xb2,
  0xd3,
  0xf2,
  0x49,
  0xc1,
  0xb5,
  0x71,
  0xa2,
  0x80,
  0x28,
  0x00,
  0x04,
  0xe5,
  0x7a,
  0x3b,
  0xcf,
]);

final Uint8List _rfc5769LongTermRequest = Uint8List.fromList([
  0x00,
  0x01,
  0x00,
  0x60,
  0x21,
  0x12,
  0xa4,
  0x42,
  0x78,
  0xad,
  0x34,
  0x33,
  0xc6,
  0xad,
  0x72,
  0xc0,
  0x29,
  0xda,
  0x41,
  0x2e,
  0x00,
  0x06,
  0x00,
  0x12,
  0xe3,
  0x83,
  0x9e,
  0xe3,
  0x83,
  0x88,
  0xe3,
  0x83,
  0xaa,
  0xe3,
  0x83,
  0x83,
  0xe3,
  0x82,
  0xaf,
  0xe3,
  0x82,
  0xb9,
  0x00,
  0x00,
  0x00,
  0x15,
  0x00,
  0x1c,
  0x66,
  0x2f,
  0x2f,
  0x34,
  0x39,
  0x39,
  0x6b,
  0x39,
  0x35,
  0x34,
  0x64,
  0x36,
  0x4f,
  0x4c,
  0x33,
  0x34,
  0x6f,
  0x4c,
  0x39,
  0x46,
  0x53,
  0x54,
  0x76,
  0x79,
  0x36,
  0x34,
  0x73,
  0x41,
  0x00,
  0x14,
  0x00,
  0x0b,
  0x65,
  0x78,
  0x61,
  0x6d,
  0x70,
  0x6c,
  0x65,
  0x2e,
  0x6f,
  0x72,
  0x67,
  0x00,
  0x00,
  0x08,
  0x00,
  0x14,
  0xf6,
  0x70,
  0x24,
  0x65,
  0x6d,
  0xd6,
  0x4a,
  0x3e,
  0x02,
  0xb8,
  0xe0,
  0x71,
  0x2e,
  0x85,
  0xc9,
  0xa2,
  0x8c,
  0xa8,
  0x96,
  0x66,
]);

final Uint8List _rfc5769ResponseIpv4 = Uint8List.fromList([
  0x01,
  0x01,
  0x00,
  0x3c,
  0x21,
  0x12,
  0xa4,
  0x42,
  0xb7,
  0xe7,
  0xa7,
  0x01,
  0xbc,
  0x34,
  0xd6,
  0x86,
  0xfa,
  0x87,
  0xdf,
  0xae,
  0x80,
  0x22,
  0x00,
  0x0b,
  0x74,
  0x65,
  0x73,
  0x74,
  0x20,
  0x76,
  0x65,
  0x63,
  0x74,
  0x6f,
  0x72,
  0x20,
  0x00,
  0x20,
  0x00,
  0x08,
  0x00,
  0x01,
  0xa1,
  0x47,
  0xe1,
  0x12,
  0xa6,
  0x43,
  0x00,
  0x08,
  0x00,
  0x14,
  0x2b,
  0x91,
  0xf5,
  0x99,
  0xfd,
  0x9e,
  0x90,
  0xc3,
  0x8c,
  0x74,
  0x89,
  0xf9,
  0x2a,
  0xf9,
  0xba,
  0x53,
  0xf0,
  0x6b,
  0xe7,
  0xd7,
  0x80,
  0x28,
  0x00,
  0x04,
  0xc0,
  0x7d,
  0x4c,
  0x96,
]);

final Uint8List _rfc5769ResponseIpv6 = Uint8List.fromList([
  0x01,
  0x01,
  0x00,
  0x48,
  0x21,
  0x12,
  0xa4,
  0x42,
  0xb7,
  0xe7,
  0xa7,
  0x01,
  0xbc,
  0x34,
  0xd6,
  0x86,
  0xfa,
  0x87,
  0xdf,
  0xae,
  0x80,
  0x22,
  0x00,
  0x0b,
  0x74,
  0x65,
  0x73,
  0x74,
  0x20,
  0x76,
  0x65,
  0x63,
  0x74,
  0x6f,
  0x72,
  0x20,
  0x00,
  0x20,
  0x00,
  0x14,
  0x00,
  0x02,
  0xa1,
  0x47,
  0x01,
  0x13,
  0xa9,
  0xfa,
  0xa5,
  0xd3,
  0xf1,
  0x79,
  0xbc,
  0x25,
  0xf4,
  0xb5,
  0xbe,
  0xd2,
  0xb9,
  0xd9,
  0x00,
  0x08,
  0x00,
  0x14,
  0xa3,
  0x82,
  0x95,
  0x4e,
  0x4b,
  0xe6,
  0x7b,
  0xf1,
  0x17,
  0x84,
  0xc9,
  0x7c,
  0x82,
  0x92,
  0xc2,
  0x75,
  0xbf,
  0xe3,
  0xed,
  0x41,
  0x80,
  0x28,
  0x00,
  0x04,
  0xc8,
  0xfb,
  0x0b,
  0x4c,
]);

void main() {
  group('RFC 5769 [Integration vectors]', () {
    test('Message.decode() - request vector: parses header, cookie, attrs', () {
      final m = Message()..raw = Uint8List.fromList(_rfc5769Request);
      m.decode();
      final software = Software('');
      software.getFrom(m);
      expect(software.toString(), 'STUN test client');
      fingerprint.check(m); // does not throw
    });

    test(
      'Message.decode() - long-term credentials vector: MESSAGE-INTEGRITY checks out',
      () {
        final m = Message()..raw = Uint8List.fromList(_rfc5769LongTermRequest);
        m.decode();
        final u = Username('');
        u.getFrom(m);
        expect(u.toString(), 'マトリックス');
        final n = Nonce('');
        n.getFrom(m);
        expect(n.toString(), 'f//499k954d6OL34oL9FSTvy64sA');
        final r = Realm('');
        r.getFrom(m);
        expect(r.toString(), 'example.org');
        final i = MessageIntegrity.longTerm(
          'マトリックス',
          'example.org',
          'TheMatrIX',
        );
        i.check(m); // does not throw
      },
    );

    test('XorMappedAddress.getFrom() - IPv4 response vector', () {
      final m = Message()..raw = Uint8List.fromList(_rfc5769ResponseIpv4);
      m.decode();
      fingerprint.check(m);
      final addr = XorMappedAddress(ip: Uint8List(0), port: 0);
      addr.getFrom(m);
      expect(ipToString(addr.ip), '192.0.2.1');
      expect(addr.port, 32853);
    });

    test('XorMappedAddress.getFrom() - IPv6 response vector', () {
      final m = Message()..raw = Uint8List.fromList(_rfc5769ResponseIpv6);
      m.decode();
      fingerprint.check(m);
      final addr = XorMappedAddress(ip: Uint8List(0), port: 0);
      addr.getFrom(m);
      expect(ipToString(addr.ip), '2001:db8:1234:5678:11:2233:4455:6677');
      expect(addr.port, 32853);
    });
  });

  group('Message [Atomic Audit]', () {
    test('Message.add() - appends a TLV attribute and updates length', () {
      final m = Message();
      m.add(AttrType.software, Uint8List.fromList('abc'.codeUnits));
      expect(m.attributes.length, 1);
      expect(m.attributes.first.type, AttrType.software);
      expect(m.length, greaterThan(0));
    });

    test(
      'Message.addTo() - copies transactionId onto another message (Setter)',
      () {
        final src = Message()
          ..transactionId = Uint8List.fromList(List.generate(12, (i) => i));
        final dst = Message();
        src.addTo(dst);
        expect(dst.transactionId, src.transactionId);
      },
    );

    test('Message.cloneTo() - decodes a copy of raw into another message', () {
      final src = Message();
      src.build([bindingRequest, Software('x')]);
      final dst = Message();
      src.cloneTo(dst);
      expect(dst.type, src.type);
      expect(dst.raw, src.raw);
    });

    test(
      'Message.contains() - reports whether an attribute type is present',
      () {
        final m = Message()..build([bindingRequest, Software('x')]);
        expect(m.contains(AttrType.software), isTrue);
        expect(m.contains(AttrType.username), isFalse);
      },
    );

    test(
      'Message.equalTo() - compares type, transactionId, length and attributes',
      () {
        final a = Message()..build([bindingRequest, Software('x')]);
        final b = Message();
        a.cloneTo(b);
        expect(a.equalTo(b), isTrue);
        final c = Message()..build([bindingRequest, Software('y')]);
        expect(a.equalTo(c), isFalse);
      },
    );

    test(
      'Message.grow() - grows raw to at least n bytes, preserving content',
      () {
        final m = Message()..raw = Uint8List.fromList([1, 2, 3]);
        m.grow(10);
        expect(m.raw.length, 10);
        expect(m.raw.sublist(0, 3), [1, 2, 3]);
      },
    );

    test('Message.marshalBinary() - returns a copy of raw', () {
      final m = Message()..build([bindingRequest]);
      final copy = m.marshalBinary();
      expect(copy, m.raw);
      expect(identical(copy, m.raw), isFalse);
    });

    test(
      'Message.newTransactionId() - sets a fresh random transactionId and writes it',
      () {
        final m = Message();
        final before = Uint8List.fromList(m.transactionId);
        m.raw = Uint8List(20);
        m.newTransactionId();
        expect(m.transactionId.length, transactionIdSize);
        expect(m.transactionId, isNot(before));
        expect(m.raw.sublist(8, 20), m.transactionId);
      },
    );

    test(
      'Message.readFrom() - reads from a NetConn-like source and decodes',
      () async {
        final m = Message()..build([bindingRequest, Software('x')]);
        final conn = _LoopbackConn(m.raw);
        final other = Message();
        final n = await other.readFrom(conn);
        expect(n, m.raw.length);
        expect(other.equalTo(m), isTrue);
      },
    );

    test('Message.reset() - clears raw, length and attributes', () {
      final m = Message()..build([bindingRequest, Software('x')]);
      m.reset();
      expect(m.length, 0);
      expect(m.attributes, isEmpty);
      expect(m.raw, isEmpty);
    });

    test('Message.setType() - sets type and writes it to raw', () {
      final m = Message()..raw = Uint8List(20);
      m.setType(bindingSuccess);
      expect(m.type, bindingSuccess);
    });

    test(
      'Message.toString() - includes type, length, attrs count and transaction id',
      () {
        final m = Message()..build([bindingRequest]);
        expect(m.toString(), contains('l=0'));
      },
    );

    test('Message.unmarshalBinary() - copies data into raw and decodes', () {
      final src = Message()..build([bindingRequest, Software('x')]);
      final dst = Message();
      dst.unmarshalBinary(src.raw);
      expect(dst.equalTo(src), isTrue);
    });

    test('Message.write() - decodes tBuf into raw, returns byte count', () {
      final src = Message()..build([bindingRequest]);
      final dst = Message();
      final n = dst.write(src.raw);
      expect(n, src.raw.length);
      expect(dst.equalTo(src), isTrue);
    });

    test(
      'Message.writeAttributes() - re-encodes all attributes to raw (as Encode() uses it, after Length is zeroed)',
      () {
        final m = Message()..build([bindingRequest, Software('x')]);
        final lengthBefore = m.length;
        // Mirrors Message.encode()'s own sequence: Length must be zeroed
        // first, since writeAttributes() re-Adds every attribute on top of
        // the current Length (it does not reset Length itself -- matching
        // Go's WriteAttributes, which is only ever called from Encode right
        // after `m.Length = 0`).
        m.length = 0;
        m.writeAttributes();
        expect(m.length, lengthBefore);
        expect(m.attributes.single.type, AttrType.software);
      },
    );

    test(
      'Message.writeHeader() - writes type, length, cookie and transactionId',
      () {
        final m = Message()
          ..raw = Uint8List(20)
          ..type = bindingRequest
          ..transactionId = Uint8List.fromList(List.generate(12, (i) => i + 1));
        m.writeHeader();
        final view = ByteData.sublistView(m.raw);
        expect(view.getUint32(4, Endian.big), magicCookie);
        expect(m.raw.sublist(8, 20), m.transactionId);
      },
    );

    test('Message.writeLength() - writes length to bytes [2:4]', () {
      final m = Message()
        ..raw = Uint8List(4)
        ..length = 42;
      m.writeLength();
      expect(ByteData.sublistView(m.raw).getUint16(2, Endian.big), 42);
    });

    test('Message.writeTo() - writes raw to a NetConn-like sink', () async {
      final m = Message()..build([bindingRequest]);
      final conn = _LoopbackConn(Uint8List(0));
      final n = await m.writeTo(conn);
      expect(n, m.raw.length);
      expect(conn.written, m.raw);
    });

    test(
      'Message.writeTransactionId() - writes transactionId to bytes [8:20]',
      () {
        final m = Message()
          ..raw = Uint8List(20)
          ..transactionId = Uint8List.fromList(List.generate(12, (i) => 9));
        m.writeTransactionId();
        expect(m.raw.sublist(8, 20), m.transactionId);
      },
    );

    test('Message.writeType() - writes the encoded type to bytes [0:2]', () {
      final m = Message()
        ..raw = Uint8List(2)
        ..type = bindingSuccess;
      m.writeType();
      expect(
        ByteData.sublistView(m.raw).getUint16(0, Endian.big),
        bindingSuccess.value(),
      );
    });
  });

  group('MessageType [Atomic Audit]', () {
    test(
      'MessageType.value() - encodes method+class per RFC 5389 Figure 3',
      () {
        expect(bindingRequest.value(), 0x0001);
        expect(bindingSuccess.value(), 0x0101);
        expect(bindingError.value(), 0x0111);
      },
    );

    test(
      'MessageType.readValue() - decodes method+class, inverse of value()',
      () {
        final t = MessageType(
          method: Method(0),
          messageClass: MessageClass.request,
        );
        t.readValue(bindingSuccess.value());
        expect(t, bindingSuccess);
      },
    );

    test('MessageType.addTo() - sets a message type via Setter', () {
      final m = Message()..raw = Uint8List(20);
      bindingSuccess.addTo(m);
      expect(m.type, bindingSuccess);
    });

    test('MessageType.toString() - combines method and class text', () {
      expect(bindingRequest.toString(), 'Binding request');
    });

    test('MessageType.operator == - compares method and class', () {
      expect(
        MessageType(method: Method.binding, messageClass: MessageClass.request),
        bindingRequest,
      );
      expect(bindingRequest == bindingSuccess, isFalse);
    });

    test('MessageType.hashCode() - equal values hash equally', () {
      final other = MessageType(
        method: Method.binding,
        messageClass: MessageClass.request,
      );
      expect(other.hashCode, bindingRequest.hashCode);
    });
  });

  group('MessageClass [Atomic Audit]', () {
    test('MessageClass.toString() - renders the four known class names', () {
      expect(MessageClass.request.toString(), 'request');
      expect(MessageClass.indication.toString(), 'indication');
      expect(MessageClass.successResponse.toString(), 'success response');
      expect(MessageClass.errorResponse.toString(), 'error response');
    });

    test('MessageClass.operator == - compares by underlying value', () {
      expect(MessageClass.request == MessageClass.request, isTrue);
      expect(MessageClass.request == MessageClass.indication, isFalse);
    });

    test('MessageClass.hashCode() - equal values hash equally', () {
      expect(MessageClass.request.hashCode, MessageClass.request.hashCode);
    });
  });

  group('Method [Atomic Audit]', () {
    test(
      'Method.toString() - known methods render their name, unknown falls back to hex',
      () {
        expect(Method.binding.toString(), 'Binding');
        expect(Method(0x0f0).toString(), '0xf0');
      },
    );

    test('Method.operator == - compares by underlying value', () {
      expect(Method.binding == Method(0x001), isTrue);
      expect(Method.binding == Method.allocate, isFalse);
    });

    test('Method.hashCode() - equal values hash equally', () {
      expect(Method.binding.hashCode, Method(0x001).hashCode);
    });
  });

  group('AttrType [Atomic Audit]', () {
    test(
      'AttrType.toString() - known attrs render their wire name, unknown falls back to hex',
      () {
        expect(AttrType.software.toString(), 'SOFTWARE');
        expect(AttrType(0x9999).toString(), '0x9999');
      },
    );

    test('AttrType.known() - true only for registered attribute types', () {
      expect(AttrType.software.known, isTrue);
      expect(AttrType(0x9999).known, isFalse);
    });

    test(
      'AttrType.required() - true for comprehension-required range (<= 0x7FFF)',
      () {
        expect(AttrType.username.required, isTrue);
        expect(AttrType.software.required, isFalse);
      },
    );

    test(
      'AttrType.optional() - true for comprehension-optional range (>= 0x8000)',
      () {
        expect(AttrType.software.optional, isTrue);
        expect(AttrType.username.optional, isFalse);
      },
    );

    test('AttrType.operator == - compares by underlying value', () {
      expect(AttrType.software == AttrType(0x8022), isTrue);
      expect(AttrType.software == AttrType.username, isFalse);
    });

    test('AttrType.hashCode() - equal values hash equally', () {
      expect(AttrType.software.hashCode, AttrType(0x8022).hashCode);
    });
  });

  group('RawAttribute [Atomic Audit]', () {
    test('RawAttribute.addTo() - adds itself to a message as a Setter', () {
      final m = Message();
      RawAttribute(
        type: AttrType.software,
        length: 3,
        value: Uint8List.fromList('abc'.codeUnits),
      ).addTo(m);
      expect(m.attributes.single.type, AttrType.software);
    });

    test('RawAttribute.equalTo() - compares type, length and value bytes', () {
      final a = RawAttribute(
        type: AttrType.software,
        length: 1,
        value: Uint8List.fromList([1]),
      );
      final b = RawAttribute(
        type: AttrType.software,
        length: 1,
        value: Uint8List.fromList([1]),
      );
      final c = RawAttribute(
        type: AttrType.software,
        length: 1,
        value: Uint8List.fromList([2]),
      );
      expect(a.equalTo(b), isTrue);
      expect(a.equalTo(c), isFalse);
    });

    test('RawAttribute.toString() - renders type and hex value', () {
      final a = RawAttribute(
        type: AttrType.software,
        length: 1,
        value: Uint8List.fromList([0xab]),
      );
      expect(a.toString(), 'SOFTWARE: 0xab');
    });
  });

  group('AttributesX [Atomic Audit]', () {
    test(
      'AttributesX.get() - returns the first matching attribute or null',
      () {
        final list = <RawAttribute>[
          RawAttribute(type: AttrType.software, length: 0, value: Uint8List(0)),
        ];
        expect(list.get(AttrType.software), isNotNull);
        expect(list.get(AttrType.username), isNull);
      },
    );
  });

  group('MessageGetX [Atomic Audit]', () {
    test(
      'MessageGetX.get() - returns attribute value bytes or throws AttributeNotFoundException',
      () {
        final m = Message()..build([bindingRequest, Software('hi')]);
        expect(String.fromCharCodes(m.get(AttrType.software)), 'hi');
        expect(
          () => m.get(AttrType.username),
          throwsA(isA<AttributeNotFoundException>()),
        );
      },
    );
  });

  group('Funções top-level de codec [Atomic Audit]', () {
    test(
      'isMessage() - true iff buffer is long enough and carries the magic cookie',
      () {
        final m = Message()..build([bindingRequest]);
        expect(isMessage(m.raw), isTrue);
        expect(isMessage(Uint8List(4)), isFalse);
      },
    );

    test(
      'compatAttrType() - maps legacy 0x8020 to XOR-MAPPED-ADDRESS, passes through otherwise',
      () {
        expect(compatAttrType(0x8020), AttrType.xorMappedAddress);
        expect(compatAttrType(0x0006), AttrType.username);
      },
    );

    test(
      'nearestPaddedValueLength() - rounds up to the next multiple of 4',
      () {
        expect(nearestPaddedValueLength(0), 0);
        expect(nearestPaddedValueLength(1), 4);
        expect(nearestPaddedValueLength(4), 4);
        expect(nearestPaddedValueLength(5), 8);
      },
    );

    test(
      'randomTransactionId() - returns 12 cryptographically random bytes',
      () {
        final a = randomTransactionId();
        final b = randomTransactionId();
        expect(a.length, transactionIdSize);
        expect(a, isNot(b));
      },
    );

    test(
      'transactionIdSetter() - returns a Setter fixing the transaction id',
      () {
        final id = Uint8List.fromList(List.generate(12, (i) => 5));
        final m = Message()..raw = Uint8List(20);
        transactionIdSetter(id).addTo(m);
        expect(m.transactionId, id);
      },
    );

    test(
      'build() - allocates a Message and applies setters, throwing on first failure',
      () {
        final m = build([bindingRequest, Software('x')]);
        expect(m.type, bindingRequest);
        expect(m.contains(AttrType.software), isTrue);
      },
    );

    test(
      'mustBuild() - same as build(), preserved for API parity with the Go panic-on-error variant',
      () {
        final m = mustBuild([bindingRequest]);
        expect(m.type, bindingRequest);
      },
    );

    test(
      'fingerprintValue() - CRC-32 IEEE of bytes XOR-ed with 0x5354554e',
      () {
        final v = fingerprintValue(Uint8List.fromList('123456789'.codeUnits));
        // CRC-32/IEEE of the standard check string "123456789" is 0xCBF43926.
        expect(v, 0xCBF43926 ^ 0x5354554e);
      },
    );

    test(
      'checkSize() - throws AttributeSizeInvalidException when got != expected',
      () {
        expect(() => checkSize(AttrType.software, 3, 3), returnsNormally);
        expect(
          () => checkSize(AttrType.software, 3, 4),
          throwsA(isA<AttributeSizeInvalidException>()),
        );
      },
    );

    test(
      'checkOverflow() - throws AttributeSizeOverflowException when got > maxVal',
      () {
        expect(() => checkOverflow(AttrType.software, 3, 4), returnsNormally);
        expect(
          () => checkOverflow(AttrType.software, 5, 4),
          throwsA(isA<AttributeSizeOverflowException>()),
        );
      },
    );

    test(
      'checkHmac() - throws IntegrityMismatchException on mismatch, passes on match',
      () {
        final a = Uint8List.fromList([1, 2, 3]);
        expect(
          () => checkHmac(a, Uint8List.fromList([1, 2, 3])),
          returnsNormally,
        );
        expect(
          () => checkHmac(a, Uint8List.fromList([1, 2, 4])),
          throwsA(isA<IntegrityMismatchException>()),
        );
      },
    );

    test(
      'checkFingerprint() - throws FingerprintMismatchException on mismatch, passes on match',
      () {
        expect(() => checkFingerprint(1, 1), returnsNormally);
        expect(
          () => checkFingerprint(1, 2),
          throwsA(isA<FingerprintMismatchException>()),
        );
      },
    );

    test(
      'isAttrSizeInvalid() - true only for AttributeSizeInvalidException',
      () {
        expect(
          isAttrSizeInvalid(const AttributeSizeInvalidException()),
          isTrue,
        );
        expect(
          isAttrSizeInvalid(const AttributeSizeOverflowException()),
          isFalse,
        );
      },
    );

    test(
      'isAttrSizeOverflow() - true only for AttributeSizeOverflowException',
      () {
        expect(
          isAttrSizeOverflow(const AttributeSizeOverflowException()),
          isTrue,
        );
        expect(
          isAttrSizeOverflow(const AttributeSizeInvalidException()),
          isFalse,
        );
      },
    );

    test('ipToString() - formats a 4- or 16-byte address', () {
      expect(ipToString(Uint8List.fromList([192, 0, 2, 1])), '192.0.2.1');
    });

    test('isIpv4() - true for a 16-byte ::ffff:0:0/96-mapped IPv4 address', () {
      final mapped = Uint8List(16)
        ..[10] = 0xff
        ..[11] = 0xff
        ..[12] = 192
        ..[15] = 1;
      expect(isIpv4(mapped), isTrue);
      expect(isIpv4(Uint8List(16)), isFalse);
    });

    test('isZeros() - true iff every byte is zero', () {
      expect(isZeros(Uint8List(4)), isTrue);
      expect(isZeros(Uint8List.fromList([0, 0, 1])), isFalse);
    });
  });

  group('MessageBuildX [Atomic Audit]', () {
    test(
      'MessageBuildX.build() - resets, writes header and applies setters',
      () {
        final m = Message();
        m.build([bindingRequest, Software('x')]);
        expect(m.type, bindingRequest);
        expect(m.contains(AttrType.software), isTrue);
      },
    );

    test(
      'MessageBuildX.check() - applies checkers, throwing on first failure',
      () {
        final m = Message()
          ..build([
            bindingRequest,
            MessageIntegrity.shortTerm('pw'),
            fingerprint,
          ]);
        m.check([fingerprint]);
        final tampered = Message();
        m.cloneTo(tampered);
        tampered.raw[tampered.raw.length - 1] ^= 0xff;
        tampered.decode();
        expect(
          () => tampered.check([fingerprint]),
          throwsA(isA<FingerprintMismatchException>()),
        );
      },
    );

    test(
      'MessageBuildX.parse() - applies getters, throwing on first failure',
      () {
        final m = Message()..build([bindingRequest, Software('hi')]);
        final software = Software('');
        m.parse([software]);
        expect(software.toString(), 'hi');
      },
    );

    test(
      'MessageBuildX.forEach() - iterates all attributes of a given type',
      () {
        final m = Message();
        m.build([
          bindingRequest,
          RawAttribute(
            type: AttrType.unknownAttributes,
            length: 0,
            value: Uint8List(0),
          ),
        ]);
        var calls = 0;
        m.forEach(AttrType.unknownAttributes, (msg) {
          calls++;
        });
        expect(calls, 1);
      },
    );
  });

  group('Setter [Atomic Audit]', () {
    test(
      'Setter.addTo() - adds an attribute to a message, dispatched through the interface',
      () {
        final Setter s = Software('impl');
        final m = Message();
        s.addTo(m);
        expect(m.contains(AttrType.software), isTrue);
      },
    );
  });

  group('Getter [Atomic Audit]', () {
    test(
      'Getter.getFrom() - parses an attribute from a message, dispatched through the interface',
      () {
        final m = Message()..build([bindingRequest, Software('hi')]);
        final Getter g = Software('');
        g.getFrom(m);
        expect((g as Software).toString(), 'hi');
      },
    );
  });

  group('Checker [Atomic Audit]', () {
    test(
      'Checker.check() - checks a message condition, dispatched through the interface',
      () {
        final m = Message()..build([bindingRequest, fingerprint]);
        final Checker c = fingerprint;
        expect(() => c.check(m), returnsNormally);
      },
    );
  });

  group('MappedAddress [Atomic Audit]', () {
    test('MappedAddress.addTo() - encodes MAPPED-ADDRESS (IPv4)', () {
      final m = Message();
      MappedAddress(
        ip: Uint8List.fromList([192, 0, 2, 1]),
        port: 32853,
      ).addTo(m);
      expect(m.contains(AttrType.mappedAddress), isTrue);
    });

    test('MappedAddress.getFrom() - decodes MAPPED-ADDRESS (IPv4)', () {
      final m = Message();
      MappedAddress(
        ip: Uint8List.fromList([192, 0, 2, 1]),
        port: 32853,
      ).addTo(m);
      final a = MappedAddress(ip: Uint8List(0), port: 0);
      a.getFrom(m);
      expect(ipToString(a.ip), '192.0.2.1');
      expect(a.port, 32853);
    });

    test(
      'MappedAddress.addToAs() - encodes as an arbitrary address attribute type',
      () {
        final m = Message();
        MappedAddress(
          ip: Uint8List.fromList([10, 0, 0, 1]),
          port: 1,
        ).addToAs(m, AttrType.responseOrigin);
        expect(m.contains(AttrType.responseOrigin), isTrue);
      },
    );

    test(
      'MappedAddress.getFromAs() - decodes an arbitrary address attribute type',
      () {
        final m = Message();
        MappedAddress(
          ip: Uint8List.fromList([10, 0, 0, 1]),
          port: 1,
        ).addToAs(m, AttrType.responseOrigin);
        final a = MappedAddress(ip: Uint8List(0), port: 0);
        a.getFromAs(m, AttrType.responseOrigin);
        expect(a.port, 1);
      },
    );

    test('MappedAddress.toString() - host:port form', () {
      final a = MappedAddress(ip: Uint8List.fromList([192, 0, 2, 1]), port: 80);
      expect(a.toString(), '192.0.2.1:80');
    });
  });

  group('AlternateServer [Atomic Audit]', () {
    test('AlternateServer.addTo() - encodes ALTERNATE-SERVER', () {
      final m = Message();
      AlternateServer(
        ip: Uint8List.fromList([192, 0, 2, 1]),
        port: 3478,
      ).addTo(m);
      expect(m.contains(AttrType.alternateServer), isTrue);
    });

    test('AlternateServer.getFrom() - decodes ALTERNATE-SERVER', () {
      final m = Message();
      AlternateServer(
        ip: Uint8List.fromList([192, 0, 2, 1]),
        port: 3478,
      ).addTo(m);
      final a = AlternateServer(ip: Uint8List(0), port: 0);
      a.getFrom(m);
      expect(a.port, 3478);
    });
  });

  group('OtherAddress [Atomic Audit]', () {
    test('OtherAddress.addTo() - encodes OTHER-ADDRESS', () {
      final m = Message();
      OtherAddress(ip: Uint8List.fromList([192, 0, 2, 1]), port: 3479).addTo(m);
      expect(m.contains(AttrType.otherAddress), isTrue);
    });

    test('OtherAddress.getFrom() - decodes OTHER-ADDRESS', () {
      final m = Message();
      OtherAddress(ip: Uint8List.fromList([192, 0, 2, 1]), port: 3479).addTo(m);
      final a = OtherAddress(ip: Uint8List(0), port: 0);
      a.getFrom(m);
      expect(a.port, 3479);
    });

    test('OtherAddress.toString() - host:port form', () {
      final a = OtherAddress(ip: Uint8List.fromList([192, 0, 2, 1]), port: 80);
      expect(a.toString(), '192.0.2.1:80');
    });
  });

  group('ResponseOrigin [Atomic Audit]', () {
    test('ResponseOrigin.addTo() - encodes RESPONSE-ORIGIN', () {
      final m = Message();
      ResponseOrigin(
        ip: Uint8List.fromList([192, 0, 2, 1]),
        port: 3478,
      ).addTo(m);
      expect(m.contains(AttrType.responseOrigin), isTrue);
    });

    test('ResponseOrigin.getFrom() - decodes RESPONSE-ORIGIN', () {
      final m = Message();
      ResponseOrigin(
        ip: Uint8List.fromList([192, 0, 2, 1]),
        port: 3478,
      ).addTo(m);
      final a = ResponseOrigin(ip: Uint8List(0), port: 0);
      a.getFrom(m);
      expect(a.port, 3478);
    });

    test('ResponseOrigin.toString() - host:port form', () {
      final a = ResponseOrigin(
        ip: Uint8List.fromList([192, 0, 2, 1]),
        port: 80,
      );
      expect(a.toString(), '192.0.2.1:80');
    });
  });

  group('XorMappedAddress [Atomic Audit]', () {
    test('XorMappedAddress.addTo() - encodes XOR-MAPPED-ADDRESS', () {
      final m = Message()..raw = Uint8List(20);
      XorMappedAddress(
        ip: Uint8List.fromList([192, 0, 2, 1]),
        port: 32853,
      ).addTo(m);
      expect(m.contains(AttrType.xorMappedAddress), isTrue);
    });

    test(
      'XorMappedAddress.getFrom() - decodes XOR-MAPPED-ADDRESS, inverse of addTo()',
      () {
        final m = Message()..raw = Uint8List(20);
        XorMappedAddress(
          ip: Uint8List.fromList([192, 0, 2, 1]),
          port: 32853,
        ).addTo(m);
        final a = XorMappedAddress(ip: Uint8List(0), port: 0);
        a.getFrom(m);
        expect(ipToString(a.ip), '192.0.2.1');
        expect(a.port, 32853);
      },
    );

    test(
      'XorMappedAddress.addToAs() - encodes as an arbitrary address attribute type',
      () {
        final m = Message()..raw = Uint8List(20);
        XorMappedAddress(
          ip: Uint8List.fromList([192, 0, 2, 1]),
          port: 1,
        ).addToAs(m, AttrType.xorPeerAddress);
        expect(m.contains(AttrType.xorPeerAddress), isTrue);
      },
    );

    test(
      'XorMappedAddress.getFromAs() - decodes an arbitrary address attribute type',
      () {
        final m = Message()..raw = Uint8List(20);
        XorMappedAddress(
          ip: Uint8List.fromList([192, 0, 2, 1]),
          port: 1,
        ).addToAs(m, AttrType.xorPeerAddress);
        final a = XorMappedAddress(ip: Uint8List(0), port: 0);
        a.getFromAs(m, AttrType.xorPeerAddress);
        expect(a.port, 1);
      },
    );

    test('XorMappedAddress.toString() - host:port form', () {
      final a = XorMappedAddress(
        ip: Uint8List.fromList([192, 0, 2, 1]),
        port: 80,
      );
      expect(a.toString(), '192.0.2.1:80');
    });
  });

  group('MessageIntegrity [Atomic Audit]', () {
    test(
      'MessageIntegrity.addTo() - appends a valid HMAC-SHA1 MESSAGE-INTEGRITY',
      () {
        final m = Message()
          ..build([bindingRequest, MessageIntegrity.shortTerm('pw')]);
        expect(m.contains(AttrType.messageIntegrity), isTrue);
      },
    );

    test(
      'MessageIntegrity.check() - passes for an untampered message, throws otherwise',
      () {
        final integrity = MessageIntegrity.shortTerm('pw');
        final m = Message()..build([bindingRequest, integrity]);
        integrity.check(m); // does not throw
        m.raw[m.raw.length - 1] ^= 0xff;
        m.decode();
        expect(
          () => integrity.check(m),
          throwsA(isA<IntegrityMismatchException>()),
        );
      },
    );

    test('MessageIntegrity.toString() - renders the key as hex', () {
      final integrity = MessageIntegrity(Uint8List.fromList([0xab, 0xcd]));
      expect(integrity.toString(), 'KEY: 0xabcd');
    });
  });

  group('FingerprintAttr [Atomic Audit]', () {
    test('FingerprintAttr.addTo() - appends a valid FINGERPRINT attribute', () {
      final m = Message()..build([bindingRequest, fingerprint]);
      expect(m.contains(AttrType.fingerprint), isTrue);
    });

    test(
      'FingerprintAttr.check() - passes for an untampered message, throws otherwise',
      () {
        final m = Message()..build([bindingRequest, fingerprint]);
        fingerprint.check(m);
        m.raw[10] ^= 0xff;
        m.decode();
        expect(
          () => fingerprint.check(m),
          throwsA(isA<FingerprintMismatchException>()),
        );
      },
    );
  });

  group('ErrorCodeAttribute [Atomic Audit]', () {
    test(
      'ErrorCodeAttribute.addTo() - encodes ERROR-CODE (class/number/reason)',
      () {
        final m = Message();
        ErrorCodeAttribute(
          code: ErrorCode.codeBadRequest,
          reason: Uint8List.fromList('Bad Request'.codeUnits),
        ).addTo(m);
        expect(m.contains(AttrType.errorCode), isTrue);
      },
    );

    test(
      'ErrorCodeAttribute.getFrom() - decodes ERROR-CODE, inverse of addTo()',
      () {
        final m = Message();
        ErrorCodeAttribute(
          code: ErrorCode.codeBadRequest,
          reason: Uint8List.fromList('Bad Request'.codeUnits),
        ).addTo(m);
        final a = ErrorCodeAttribute(
          code: const ErrorCode(0),
          reason: Uint8List(0),
        );
        a.getFrom(m);
        expect(a.code, ErrorCode.codeBadRequest);
        expect(String.fromCharCodes(a.reason), 'Bad Request');
      },
    );

    test('ErrorCodeAttribute.toString() - "code: reason" form', () {
      final a = ErrorCodeAttribute(
        code: ErrorCode.codeBadRequest,
        reason: Uint8List.fromList('Bad Request'.codeUnits),
      );
      expect(a.toString(), '400: Bad Request');
    });
  });

  group('ErrorCode [Atomic Audit]', () {
    test('ErrorCode.addTo() - adds ERROR-CODE with its default reason', () {
      final m = Message();
      ErrorCode.codeBadRequest.addTo(m);
      expect(m.contains(AttrType.errorCode), isTrue);
    });

    test(
      'ErrorCode.addTo() - throws NoDefaultReasonException when no default reason exists',
      () {
        final m = Message();
        expect(
          () => const ErrorCode(999).addTo(m),
          throwsA(isA<NoDefaultReasonException>()),
        );
      },
    );

    test('ErrorCode.operator == - compares by underlying value', () {
      expect(ErrorCode.codeBadRequest == const ErrorCode(400), isTrue);
      expect(ErrorCode.codeBadRequest == ErrorCode.codeUnauthorized, isFalse);
    });

    test('ErrorCode.hashCode() - equal values hash equally', () {
      expect(ErrorCode.codeBadRequest.hashCode, const ErrorCode(400).hashCode);
    });
  });

  group('TurnException [Atomic Audit]', () {
    test(
      'TurnException.toString() - combines message type and error code text',
      () {
        final e = TurnException(
          stunMessageType: bindingError,
          errorCodeAttr: ErrorCodeAttribute(
            code: ErrorCode.codeBadRequest,
            reason: Uint8List.fromList('Bad Request'.codeUnits),
          ),
        );
        expect(e.toString(), contains('400: Bad Request'));
      },
    );
  });

  group('Username [Atomic Audit]', () {
    test('Username.addTo() - encodes USERNAME as UTF-8 bytes', () {
      final m = Message();
      Username('bob').addTo(m);
      expect(m.contains(AttrType.username), isTrue);
    });

    test('Username.getFrom() - decodes USERNAME', () {
      final m = Message()..build([bindingRequest, Username('bob')]);
      final u = Username('');
      u.getFrom(m);
      expect(u.toString(), 'bob');
    });

    test('Username.toString() - decodes value as UTF-8', () {
      expect(Username('bob').toString(), 'bob');
    });
  });

  group('Realm [Atomic Audit]', () {
    test('Realm.addTo() - encodes REALM', () {
      final m = Message();
      Realm('example.org').addTo(m);
      expect(m.contains(AttrType.realm), isTrue);
    });

    test('Realm.getFrom() - decodes REALM', () {
      final m = Message()..build([bindingRequest, Realm('example.org')]);
      final r = Realm('');
      r.getFrom(m);
      expect(r.toString(), 'example.org');
    });

    test('Realm.toString() - decodes value as UTF-8', () {
      expect(Realm('example.org').toString(), 'example.org');
    });
  });

  group('Software [Atomic Audit]', () {
    test('Software.addTo() - encodes SOFTWARE', () {
      final m = Message();
      Software('dart-stun').addTo(m);
      expect(m.contains(AttrType.software), isTrue);
    });

    test('Software.getFrom() - decodes SOFTWARE', () {
      final m = Message()..build([bindingRequest, Software('dart-stun')]);
      final s = Software('');
      s.getFrom(m);
      expect(s.toString(), 'dart-stun');
    });

    test('Software.toString() - decodes value as UTF-8', () {
      expect(Software('dart-stun').toString(), 'dart-stun');
    });
  });

  group('Nonce [Atomic Audit]', () {
    test('Nonce.addTo() - encodes NONCE', () {
      final m = Message();
      Nonce('abc123').addTo(m);
      expect(m.contains(AttrType.nonce), isTrue);
    });

    test('Nonce.getFrom() - decodes NONCE', () {
      final m = Message()..build([bindingRequest, Nonce('abc123')]);
      final n = Nonce('');
      n.getFrom(m);
      expect(n.toString(), 'abc123');
    });

    test('Nonce.toString() - decodes value as UTF-8', () {
      expect(Nonce('abc123').toString(), 'abc123');
    });
  });

  group('TextAttribute [Atomic Audit]', () {
    test(
      'TextAttribute.addToAs() - checks max length, then adds raw bytes',
      () {
        final m = Message();
        TextAttribute(
          Uint8List.fromList([97, 98, 99]),
        ).addToAs(m, AttrType.software, 763);
        expect(m.contains(AttrType.software), isTrue);
      },
    );

    test(
      'TextAttribute.addToAs() - throws AttributeSizeOverflowException past maxLen',
      () {
        final m = Message();
        expect(
          () => TextAttribute(Uint8List(10)).addToAs(m, AttrType.software, 2),
          throwsA(isA<AttributeSizeOverflowException>()),
        );
      },
    );

    test('TextAttribute.getFromAs() - returns the raw attribute bytes', () {
      final m = Message()..build([bindingRequest, Software('hi')]);
      expect(
        String.fromCharCodes(TextAttribute.getFromAs(m, AttrType.software)),
        'hi',
      );
    });
  });

  group('UnknownAttributes [Atomic Audit]', () {
    test(
      'UnknownAttributes.addTo() - encodes a list of 16-bit attribute types',
      () {
        final m = Message();
        UnknownAttributes([AttrType.username, AttrType.realm]).addTo(m);
        expect(m.contains(AttrType.unknownAttributes), isTrue);
      },
    );

    test(
      'UnknownAttributes.getFrom() - decodes the list, throws BadUnknownAttrsSizeException on bad length',
      () {
        final m = Message()
          ..build([
            bindingRequest,
            UnknownAttributes([AttrType.username, AttrType.realm]),
          ]);
        final decoded = UnknownAttributes();
        decoded.getFrom(m);
        expect(decoded.types, [AttrType.username, AttrType.realm]);

        final bad = Message();
        RawAttribute(
          type: AttrType.unknownAttributes,
          length: 1,
          value: Uint8List(1),
        ).addTo(bad);
        expect(
          () => UnknownAttributes().getFrom(bad),
          throwsA(isA<BadUnknownAttrsSizeException>()),
        );
      },
    );

    test(
      'UnknownAttributes.toString() - comma-joins the attribute names, "<nil>" if empty',
      () {
        expect(UnknownAttributes().toString(), '<nil>');
        expect(UnknownAttributes([AttrType.username]).toString(), 'USERNAME');
      },
    );
  });

  group('SchemeType [Atomic Audit]', () {
    test(
      'SchemeType.fromRaw() - parses stun/stuns/turn/turns, else unknown',
      () {
        expect(SchemeType.fromRaw('stun'), SchemeType.stun);
        expect(SchemeType.fromRaw('turns'), SchemeType.turns);
        expect(SchemeType.fromRaw('bogus'), SchemeType.unknown);
      },
    );

    test('SchemeType.toString() - renders the scheme text', () {
      expect(SchemeType.stuns.toString(), 'stuns');
    });
  });

  group('ProtoType [Atomic Audit]', () {
    test('ProtoType.fromRaw() - parses udp/tcp, else unknown', () {
      expect(ProtoType.fromRaw('udp'), ProtoType.udp);
      expect(ProtoType.fromRaw('bogus'), ProtoType.unknown);
    });

    test('ProtoType.toString() - renders the protocol text', () {
      expect(ProtoType.tcp.toString(), 'tcp');
    });
  });

  group('StunUri [Atomic Audit]', () {
    test(
      'StunUri.parse() - stun: URI without explicit port defaults to 3478/udp',
      () {
        final u = StunUri.parse('stun:example.org');
        expect(u.host, 'example.org');
        expect(u.port, 3478);
        expect(u.proto, ProtoType.udp);
      },
    );

    test(
      'StunUri.parse() - turn: URI with explicit port and transport query',
      () {
        final u = StunUri.parse('turn:example.org:19302?transport=tcp');
        expect(u.port, 19302);
        expect(u.proto, ProtoType.tcp);
      },
    );

    test(
      'StunUri.toString() - re-renders scheme:host:port (+ ?transport= for turn/turns)',
      () {
        final u = StunUri.parse('turn:example.org:19302?transport=tcp');
        expect(u.toString(), 'turn:example.org:19302?transport=tcp');
      },
    );

    test('StunUri.isSecure() - true only for stuns/turns schemes', () {
      expect(StunUri.parse('stuns:example.org').isSecure, isTrue);
      expect(StunUri.parse('stun:example.org').isSecure, isFalse);
    });
  });

  group('Exceptions [Atomic Audit]', () {
    test('AttributeNotFoundException.toString() - fixed message', () {
      expect(
        const AttributeNotFoundException().toString(),
        'attribute not found',
      );
    });
    test('AttributeSizeInvalidException.toString() - fixed message', () {
      expect(
        const AttributeSizeInvalidException().toString(),
        'attribute size is invalid',
      );
    });
    test('AttributeSizeOverflowException.toString() - fixed message', () {
      expect(
        const AttributeSizeOverflowException().toString(),
        'attribute size overflow',
      );
    });
    test('BadIpLengthException.toString() - fixed message', () {
      expect(
        const BadIpLengthException().toString(),
        'invalid length of IP value',
      );
    });
    test('BadUnknownAttrsSizeException.toString() - fixed message', () {
      expect(
        const BadUnknownAttrsSizeException().toString(),
        'bad UNKNOWN-ATTRIBUTES size',
      );
    });
    test('DecodeToNilException.toString() - fixed message', () {
      expect(
        const DecodeToNilException().toString(),
        'attempt to decode to nil message',
      );
    });
    test('FingerprintBeforeIntegrityException.toString() - fixed message', () {
      expect(
        const FingerprintBeforeIntegrityException().toString(),
        'FINGERPRINT before MESSAGE-INTEGRITY attribute',
      );
    });
    test('FingerprintMismatchException.toString() - fixed message', () {
      expect(
        const FingerprintMismatchException().toString(),
        'fingerprint check failed',
      );
    });
    test('HostException.toString() - fixed message', () {
      expect(const HostException().toString(), 'invalid hostname');
    });
    test('IntegrityMismatchException.toString() - fixed message', () {
      expect(
        const IntegrityMismatchException().toString(),
        'integrity check failed',
      );
    });
    test('InvalidQueryException.toString() - fixed message', () {
      expect(const InvalidQueryException().toString(), 'invalid query');
    });
    test('NoDefaultReasonException.toString() - fixed message', () {
      expect(
        const NoDefaultReasonException().toString(),
        'no default reason for ErrorCode',
      );
    });
    test('PortException.toString() - fixed message', () {
      expect(const PortException().toString(), 'invalid port');
    });
    test('ProtoTypeException.toString() - fixed message', () {
      expect(
        const ProtoTypeException().toString(),
        'invalid transport protocol type',
      );
    });
    test('SchemeTypeException.toString() - fixed message', () {
      expect(const SchemeTypeException().toString(), 'unknown scheme type');
    });
    test('StunQueryException.toString() - fixed message', () {
      expect(
        const StunQueryException().toString(),
        'queries not supported in stun address',
      );
    });
    test('UnexpectedEofException.toString() - fixed message', () {
      expect(const UnexpectedEofException().toString(), 'unexpected EOF');
    });
    test('UnexpectedHeaderEofException.toString() - fixed message', () {
      expect(
        const UnexpectedHeaderEofException().toString(),
        'unexpected EOF: not enough bytes to read header',
      );
    });
    test('UnknownTypeException.toString() - fixed message', () {
      expect(const UnknownTypeException().toString(), 'Unknown');
    });
  });

  group('DecodeErrPlace [Atomic Audit]', () {
    test('DecodeErrPlace.toString() - "parent/children" form', () {
      expect(
        const DecodeErrPlace(parent: 'message', children: 'cookie').toString(),
        'message/cookie',
      );
    });
    test('DecodeErrPlace.operator == - compares parent and children', () {
      expect(
        const DecodeErrPlace(parent: 'a', children: 'b') ==
            const DecodeErrPlace(parent: 'a', children: 'b'),
        isTrue,
      );
    });
    test('DecodeErrPlace.hashCode() - equal values hash equally', () {
      expect(
        const DecodeErrPlace(parent: 'a', children: 'b').hashCode,
        const DecodeErrPlace(parent: 'a', children: 'b').hashCode,
      );
    });
  });

  group('DecodeException [Atomic Audit]', () {
    test('DecodeException.toString() - "BadFormat for place: message"', () {
      final e = DecodeException.at('message', 'cookie', 'bad value');
      expect(e.toString(), 'BadFormat for message/cookie: bad value');
    });
    test(
      'DecodeException.isInvalidCookie() - true only for the message/cookie place',
      () {
        expect(
          DecodeException.at('message', 'cookie', 'x').isInvalidCookie,
          isTrue,
        );
        expect(
          DecodeException.at('attribute', 'family', 'x').isInvalidCookie,
          isFalse,
        );
      },
    );
    test('DecodeException.isPlaceParent() - matches the parent segment', () {
      expect(
        DecodeException.forAttribute('family', 'x').isPlaceParent('attribute'),
        isTrue,
      );
    });
    test(
      'DecodeException.isPlaceChildren() - matches the children segment',
      () {
        expect(
          DecodeException.forAttribute('family', 'x').isPlaceChildren('family'),
          isTrue,
        );
      },
    );
    test('DecodeException.isPlace() - matches the whole place', () {
      final e = DecodeException.forAttribute('family', 'x');
      expect(
        e.isPlace(
          const DecodeErrPlace(parent: 'attribute', children: 'family'),
        ),
        isTrue,
      );
    });
  });
}

/// Minimal in-memory [NetConn] used to exercise [Message.readFrom]/
/// [Message.writeTo] without a real socket (nível 1: no I/O).
class _LoopbackConn implements NetConn {
  _LoopbackConn(this._toRead);

  final Uint8List _toRead;
  Uint8List written = Uint8List(0);

  @override
  Future<int> read(Uint8List buffer) async {
    final n = _toRead.length < buffer.length ? _toRead.length : buffer.length;
    buffer.setRange(0, n, _toRead);
    return n;
  }

  @override
  Future<int> write(Uint8List buffer) async {
    written = Uint8List.fromList(buffer);
    return buffer.length;
  }

  @override
  Future<void> close() async {}
}
