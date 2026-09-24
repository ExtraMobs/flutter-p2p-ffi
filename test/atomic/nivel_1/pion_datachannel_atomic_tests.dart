// test/atomic/nivel_1/pion_datachannel_atomic_tests.dart
// Testes atomicos 1 para 1 para transpiled_pion_datachannel (github.com/pion/datachannel).

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_pion_datachannel/transpiled_pion_datachannel.dart';
import 'package:transpiled_pion_sctp/transpiled_pion_sctp.dart' as pion_sctp;

class _TestReader implements Reader {
  @override
  Future<(int, bool)> readDataChannel(Uint8List b) async => (0, false);
}

class _TestReadDeadliner implements ReadDeadliner {
  @override
  Future<void> setReadDeadline(DateTime? t) async {}
}

class _TestWriter implements Writer {
  @override
  Future<int> writeDataChannel(Uint8List b, bool isString) async => b.length;
}

class _TestWriteDeadliner implements WriteDeadliner {
  @override
  Future<void> setWriteDeadline(DateTime? t) async {}
}

class _TestReadWriteCloser implements ReadWriteCloser {
  @override
  Future<int> read(Uint8List b) async => 0;

  @override
  Future<int> write(Uint8List b) async => b.length;

  @override
  Future<(int, bool)> readDataChannel(Uint8List b) async => (0, false);

  @override
  Future<int> writeDataChannel(Uint8List b, bool isString) async => b.length;

  @override
  Future<void> close() async {}
}

class _MockAssoc implements pion_sctp.Association {
  _MockAssoc(this.stream);
  final pion_sctp.Stream stream;

  @override
  Future<pion_sctp.Stream> acceptStream() async => stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Top-level functions [Atomic Audit]', () {
    test('parse() - atomic test', () {
      final ack = ChannelAck();
      final rawAck = ack.marshal();
      final msg = parse(rawAck);
      expect(msg, isA<ChannelAck>());
      expect(
        () => parse(Uint8List(0)),
        throwsA(isA<DataChannelMessageTooShortException>()),
      );
      expect(
        () => parse(Uint8List.fromList([99])),
        throwsA(isA<InvalidMessageTypeException>()),
      );
    });

    test('parseExpectDataChannelOpen() - atomic test', () {
      final open = ChannelOpen(
        channelType: ChannelType.reliable,
        label: Uint8List.fromList(utf8.encode('lbl')),
      );
      final raw = open.marshal();
      final parsed = parseExpectDataChannelOpen(raw);
      expect(parsed.channelType, equals(ChannelType.reliable));

      final ack = ChannelAck();
      expect(
        () => parseExpectDataChannelOpen(ack.marshal()),
        throwsA(isA<UnexpectedDataChannelTypeException>()),
      );
    });

    test('tryMarshalUnmarshal() - atomic test', () {
      final open = ChannelOpen(
        channelType: ChannelType.reliable,
        label: Uint8List.fromList(utf8.encode('lbl')),
      );
      expect(tryMarshalUnmarshal(open.marshal()), equals(1));
      final ack = ChannelAck();
      expect(tryMarshalUnmarshal(ack.marshal()), equals(1));
      expect(tryMarshalUnmarshal(Uint8List.fromList([99])), equals(0));
    });

    test('client() - atomic test', () async {
      final assoc = pion_sctp.Association(config: pion_sctp.Config());
      final stream = pion_sctp.Stream(association: assoc, streamIdentifier: 0);
      final dc = await client(stream, Config(label: 'data', negotiated: true));
      expect(dc.streamIdentifier(), equals(0));
    });

    test('dial() - atomic test', () async {
      final assoc = pion_sctp.Association(config: pion_sctp.Config());
      final dc = await dial(
        assoc,
        2,
        Config(label: 'dial_test', negotiated: true),
      );
      expect(dc.streamIdentifier(), equals(2));
    });

    test('accept() - atomic test', () async {
      final baseAssoc = pion_sctp.Association(config: pion_sctp.Config());
      final s = pion_sctp.Stream(association: baseAssoc, streamIdentifier: 4);
      final assoc = _MockAssoc(s);

      final existingDc = DataChannel(
        stream: s,
        config: Config(label: 'existing'),
      );

      final accepted = await accept(assoc, Config(label: 'new'), [existingDc]);
      expect(accepted.streamIdentifier(), equals(4));
    });

    test('server() - atomic test', () async {
      final assoc = pion_sctp.Association(config: pion_sctp.Config());
      final stream = pion_sctp.Stream(association: assoc, streamIdentifier: 3);

      final openMsg = ChannelOpen(
        channelType: ChannelType.reliable,
        priority: 0,
        reliabilityParameter: 0,
        label: Uint8List.fromList(utf8.encode('server_test')),
        protocol: Uint8List.fromList(utf8.encode('proto')),
      );
      stream.handleInbound(
        openMsg.marshal(),
        pion_sctp.PayloadProtocolIdentifier.webRtcDcep,
      );

      final dc = await server(stream, Config());
      expect(dc.config.label, equals('server_test'));
      expect(dc.config.protocol, equals('proto'));
    });
  });

  group('ChannelType [Atomic Audit]', () {
    test('partialReliableTimedUnordered() - atomic test', () {
      final ct = ChannelType.partialReliableTimedUnordered;
      expect(ct.value, equals(0x82));
    });

    test('fromValue() - atomic test', () {
      expect(ChannelType.fromValue(0x00), equals(ChannelType.reliable));
      expect(
        ChannelType.fromValue(0x80),
        equals(ChannelType.reliableUnordered),
      );
      expect(
        ChannelType.fromValue(0x01),
        equals(ChannelType.partialReliableRexmit),
      );
      expect(
        ChannelType.fromValue(0x81),
        equals(ChannelType.partialReliableRexmitUnordered),
      );
      expect(
        ChannelType.fromValue(0x02),
        equals(ChannelType.partialReliableTimed),
      );
      expect(
        ChannelType.fromValue(0x82),
        equals(ChannelType.partialReliableTimedUnordered),
      );
      expect(ChannelType.fromValue(0xFF), equals(ChannelType.reliable));
    });

    test('string() - atomic test', () {
      expect(ChannelType.reliable.string(), equals('Unknown'));
      expect(
        ChannelType.reliableUnordered.string(),
        equals('ReliableUnordered'),
      );
      expect(
        ChannelType.partialReliableRexmit.string(),
        equals('PartialReliableRexmit'),
      );
      expect(
        ChannelType.partialReliableRexmitUnordered.string(),
        equals('PartialReliableRexmitUnordered'),
      );
      expect(
        ChannelType.partialReliableTimed.string(),
        equals('PartialReliableTimed'),
      );
      expect(
        ChannelType.partialReliableTimedUnordered.string(),
        equals('PartialReliableTimedUnordered'),
      );
    });

    test('toString() - atomic test', () {
      expect(ChannelType.reliable.toString(), equals('Unknown'));
    });
  });

  group('ChannelAck [Atomic Audit]', () {
    test('marshal() - atomic test', () {
      final ack = ChannelAck();
      final bytes = ack.marshal();
      expect(bytes, equals(Uint8List.fromList([2, 0, 0, 0])));
    });

    test('unmarshal() - atomic test', () {
      final ack = ChannelAck();
      ack.unmarshal(Uint8List.fromList([2, 0, 0, 0]));
      expect(ack.string(), equals('ACK'));
    });

    test('string() - atomic test', () {
      final ack = ChannelAck();
      expect(ack.string(), equals('ACK'));
    });

    test('toString() - atomic test', () {
      final ack = ChannelAck();
      expect(ack.toString(), equals('ACK'));
    });
  });

  group('ChannelOpen [Atomic Audit]', () {
    test('marshal() - atomic test', () {
      final open = ChannelOpen(
        channelType: ChannelType.reliable,
        priority: 10,
        reliabilityParameter: 20,
        label: Uint8List.fromList(utf8.encode('chat')),
        protocol: Uint8List.fromList(utf8.encode('proto')),
      );
      final raw = open.marshal();
      expect(raw.length, greaterThanOrEqualTo(12));
    });

    test('unmarshal() - atomic test', () {
      final open = ChannelOpen(
        channelType: ChannelType.reliable,
        priority: 10,
        reliabilityParameter: 20,
        label: Uint8List.fromList(utf8.encode('chat')),
        protocol: Uint8List.fromList(utf8.encode('proto')),
      );
      final raw = open.marshal();
      final parsed = ChannelOpen();
      parsed.unmarshal(raw);
      expect(parsed.channelType, equals(ChannelType.reliable));
      expect(parsed.priority, equals(10));
      expect(parsed.reliabilityParameter, equals(20));
      expect(utf8.decode(parsed.label), equals('chat'));
      expect(utf8.decode(parsed.protocol), equals('proto'));

      expect(
        () => parsed.unmarshal(Uint8List(5)),
        throwsA(isA<DataChannelMessageTooShortException>()),
      );
      expect(
        () => parsed.unmarshal(
          Uint8List.fromList([2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        ),
        throwsA(isA<UnexpectedDataChannelTypeException>()),
      );
    });

    test('string() - atomic test', () {
      final open = ChannelOpen(
        channelType: ChannelType.reliable,
        label: Uint8List.fromList(utf8.encode('test')),
      );
      expect(open.string(), contains('Open ChannelType'));
      expect(open.string(), contains('test'));
    });

    test('toString() - atomic test', () {
      final open = ChannelOpen();
      expect(open.toString(), contains('Open ChannelType'));
    });
  });

  group('MessageType [Atomic Audit]', () {
    test('dataChannelOpen() - atomic test', () {
      expect(MessageType.dataChannelOpen.value, equals(0x03));
      expect(MessageType.dataChannelAck.value, equals(0x02));
    });

    test('string() - atomic test', () {
      expect(MessageType.dataChannelOpen.string(), equals('DataChannelOpen'));
      expect(MessageType.dataChannelAck.string(), equals('DataChannelAck'));
    });
  });

  group('Exceptions [Atomic Audit]', () {
    test('DataChannelMessageTooShortException.toString() - atomic test', () {
      const e = DataChannelMessageTooShortException();
      expect(e.toString(), contains('DataChannel message is not long enough'));
    });

    test(
      'InvalidPayloadProtocolIdentifierException.toString() - atomic test',
      () {
        const e = InvalidPayloadProtocolIdentifierException('unknown');
        expect(
          e.toString(),
          contains('Payload Protocol Identifier is value we cannot handle'),
        );
      },
    );

    test('InvalidChannelTypeException.toString() - atomic test', () {
      const e = InvalidChannelTypeException('99');
      expect(e.toString(), contains('invalid Channel Type'));
    });

    test('InvalidMessageTypeException.toString() - atomic test', () {
      const e = InvalidMessageTypeException('99');
      expect(e.toString(), contains('invalid Message Type'));
    });

    test(
      'ExpectedAndActualLengthMismatchException.toString() - atomic test',
      () {
        const e = ExpectedAndActualLengthMismatchException();
        expect(
          e.toString(),
          contains('expected and actual length do not match'),
        );
      },
    );

    test('UnexpectedDataChannelTypeException.toString() - atomic test', () {
      const e = UnexpectedDataChannelTypeException('test');
      expect(
        e.toString(),
        contains('expected and actual message type does not match'),
      );
    });
  });

  group('Reader [Atomic Audit]', () {
    test('readDataChannel() - atomic test', () async {
      final r = _TestReader();
      final (n, isStr) = await r.readDataChannel(Uint8List(5));
      expect(n, equals(0));
      expect(isStr, isFalse);
    });
  });

  group('ReadDeadliner [Atomic Audit]', () {
    test('setReadDeadline() - atomic test', () async {
      final rd = _TestReadDeadliner();
      await rd.setReadDeadline(DateTime.now());
      expect(true, isTrue);
    });
  });

  group('Writer [Atomic Audit]', () {
    test('writeDataChannel() - atomic test', () async {
      final w = _TestWriter();
      final n = await w.writeDataChannel(Uint8List.fromList([1, 2, 3]), false);
      expect(n, equals(3));
    });
  });

  group('WriteDeadliner [Atomic Audit]', () {
    test('setWriteDeadline() - atomic test', () async {
      final wd = _TestWriteDeadliner();
      await wd.setWriteDeadline(DateTime.now());
      expect(true, isTrue);
    });
  });

  group('ReadWriteCloser [Atomic Audit]', () {
    test('read() - atomic test', () async {
      final rwc = _TestReadWriteCloser();
      expect(await rwc.read(Uint8List(5)), equals(0));
    });

    test('write() - atomic test', () async {
      final rwc = _TestReadWriteCloser();
      expect(await rwc.write(Uint8List.fromList([1])), equals(1));
    });

    test('close() - atomic test', () async {
      final rwc = _TestReadWriteCloser();
      await rwc.close();
      expect(true, isTrue);
    });
  });

  group('DataChannel [Atomic Audit]', () {
    late pion_sctp.Association assoc;
    late pion_sctp.Stream sctpStream;
    late DataChannel dc;

    setUp(() {
      assoc = pion_sctp.Association(config: pion_sctp.Config());
      sctpStream = pion_sctp.Stream(
        association: assoc,
        streamIdentifier: 1,
        defaultPayloadType: pion_sctp.PayloadProtocolIdentifier.webRtcBinary,
      );
      dc = DataChannel(
        stream: sctpStream,
        config: Config(label: 'test', protocol: 'webrtc'),
      );
    });

    test('messagesSent() - atomic test', () {
      expect(dc.messagesSent(), equals(0));
    });

    test('messagesReceived() - atomic test', () {
      expect(dc.messagesReceived(), equals(0));
    });

    test('bytesSent() - atomic test', () {
      expect(dc.bytesSent(), equals(0));
    });

    test('bytesReceived() - atomic test', () {
      expect(dc.bytesReceived(), equals(0));
    });

    test('streamIdentifier() - atomic test', () {
      expect(dc.streamIdentifier(), equals(1));
    });

    test('bufferedAmount() - atomic test', () {
      expect(dc.bufferedAmount(), equals(0));
    });

    test('bufferedAmountLowThreshold() - atomic test', () {
      expect(dc.bufferedAmountLowThreshold(), equals(0));
    });

    test('setBufferedAmountLowThreshold() - atomic test', () {
      dc.setBufferedAmountLowThreshold(1024);
      expect(dc.bufferedAmountLowThreshold(), equals(1024));
    });

    test('onBufferedAmountLow() - atomic test', () {
      var called = false;
      dc.onBufferedAmountLow(() {
        called = true;
      });
      expect(called, isFalse);
    });

    test('setReadDeadline() - atomic test', () async {
      await dc.setReadDeadline(DateTime.now().add(const Duration(seconds: 1)));
      expect(true, isTrue);
    });

    test('setWriteDeadline() - atomic test', () async {
      await dc.setWriteDeadline(DateTime.now().add(const Duration(seconds: 1)));
      expect(true, isTrue);
    });

    test('onOpen() - atomic test', () {
      var opened = false;
      dc.onOpen(() {
        opened = true;
      });
      expect(opened, isFalse);
    });

    test('write() - atomic test', () async {
      final n1 = await dc.write(Uint8List.fromList([1, 2, 3]));
      expect(n1, equals(3));
      expect(dc.bytesSent(), equals(3));
      expect(dc.messagesSent(), equals(1));
    });

    test('writeDataChannel() - atomic test', () async {
      final n2 = await dc.writeDataChannel(Uint8List.fromList([4, 5]), true);
      expect(n2, equals(2));
      expect(dc.bytesSent(), equals(2));
      expect(dc.messagesSent(), equals(1));

      final nEmpty = await dc.writeDataChannel(Uint8List(0), false);
      expect(nEmpty, equals(0));
      expect(dc.messagesSent(), equals(2));
    });

    test('read() - atomic test', () async {
      sctpStream.handleInbound(
        Uint8List.fromList(utf8.encode('hello')),
        pion_sctp.PayloadProtocolIdentifier.webRtcString,
      );

      final buf = Uint8List(10);
      final readBytes = await dc.read(buf);
      expect(readBytes, equals(5));
      expect(dc.bytesReceived(), equals(5));
      expect(dc.messagesReceived(), equals(1));
    });

    test('readDataChannel() - atomic test', () async {
      sctpStream.handleInbound(
        Uint8List.fromList([10, 20, 30]),
        pion_sctp.PayloadProtocolIdentifier.webRtcBinary,
      );

      final buf = Uint8List(10);
      final (n, isStr) = await dc.readDataChannel(buf);
      expect(n, equals(3));
      expect(isStr, isFalse);
      expect(dc.bytesReceived(), equals(3));
      expect(dc.messagesReceived(), equals(1));
    });

    test('close() - atomic test', () async {
      await dc.close();
      expect(true, isTrue);
    });
  });
}
