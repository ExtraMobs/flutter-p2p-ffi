import 'dart:typed_data';

import 'package:test/test.dart';
import '../../../packages/transpiled_quic_go/lib/transpiled_quic_go.dart';

void main() {
  group('Top-Level Functions [Atomic Audit]', () {
    test('decodePacketNumber()', () {
      // quic-go internal/protocol/packet_number_test.go and RFC 9000 A.3.
      for (final (length, largest, truncated, expected) in [
        (1, 10, 255, 255),
        (1, 10, 0, 0),
        (1, 127, 0, 256),
        (1, 128, 0, 256),
        (1, 382, 0, 256),
        (1, 383, 0, 512),
        (2, 0xffff, 0xffff, 0xffff),
        (2, 0x10000, 0xffff, 0xffff),
        (2, 0xa82f30ea, 0x9b32, 0xa82f9b32),
      ]) {
        expect(decodePacketNumber(length, largest, truncated), expected);
      }
    });

    test('varIntLength()', () {
      expect(varIntLength(0), 1);
      expect(varIntLength(63), 1);
      expect(varIntLength(64), 2);
      expect(varIntLength(16383), 2);
      expect(varIntLength(16384), 4);
      expect(varIntLength(1073741823), 4);
      expect(varIntLength(1073741824), 8);
      expect(() => varIntLength(-1), throwsA(isA<RangeError>()));
      expect(() => varIntLength(maxVarInt + 1), throwsA(isA<RangeError>()));
    });

    test('appendVarInt()', () {
      expect(appendVarInt([], 25), Uint8List.fromList([25]));
      expect(appendVarInt([1, 2], 25), Uint8List.fromList([1, 2, 25]));
      final v2 = appendVarInt([], 494);
      expect(v2, Uint8List.fromList([0x40 | (494 >> 8), 494 & 0xff]));
    });

    test('parseVarInt()', () {
      final (v1, n1) = parseVarInt(Uint8List.fromList([25]));
      expect(v1, 25);
      expect(n1, 1);

      final (v2, n2) = parseVarInt(appendVarInt([], 494));
      expect(v2, 494);
      expect(n2, 2);

      expect(() => parseVarInt(Uint8List(0)), throwsFormatException);
      expect(
        () => parseVarInt(Uint8List.fromList([0x40])),
        throwsFormatException,
      );
    });

    test('parseFrame()', () {
      final ping = parseFrame(const PingFrame().encode());
      expect(ping, isA<PingFrame>());

      final crypto = parseFrame(
        CryptoFrame(10, Uint8List.fromList([1, 2, 3])).encode(),
      );
      expect(crypto, isA<CryptoFrame>());

      final stream = parseFrame(
        StreamFrame(
          streamId: 4,
          offset: 20,
          data: Uint8List.fromList([5, 6]),
          fin: true,
        ).encode(),
      );
      expect(stream, isA<StreamFrame>());

      final padding = parseFrame(const PaddingFrame(5).encode());
      expect(padding, isA<PaddingFrame>());

      final ack = parseFrame(
        const AckFrame(
          largestAcked: 3,
          delayTimeMicros: 100,
          firstAckRange: 1,
        ).encode(),
      );
      expect(ack, isA<AckFrame>());

      final done = parseFrame(const HandshakeDoneFrame().encode());
      expect(done, isA<HandshakeDoneFrame>());

      final close = parseFrame(
        const ConnectionCloseFrame(errorCode: 0, reasonPhrase: 'bye').encode(),
      );
      expect(close, isA<ConnectionCloseFrame>());

      expect(
        () => parseFrame(Uint8List.fromList([0x40, 0x40])),
        throwsFormatException,
      );
    });

    test('parseFrameWithLength()', () {
      final bytes = CryptoFrame(5, Uint8List.fromList([1, 2, 3])).encode();
      final (frame, len) = parseFrameWithLength(bytes, 0);
      expect(frame, isA<CryptoFrame>());
      expect(len, equals(bytes.length));
    });

    test('parseFrames()', () {
      final combined = BytesBuilder(copy: false);
      combined.add(const PingFrame().encode());
      combined.add(CryptoFrame(0, Uint8List.fromList([1, 2])).encode());
      combined.add(const PaddingFrame(3).encode());

      final frames = parseFrames(combined.toBytes());
      expect(frames.length, equals(3));
      expect(frames[0], isA<PingFrame>());
      expect(frames[1], isA<CryptoFrame>());
      expect(frames[2], isA<PaddingFrame>());
    });

    test('computeInitialSecrets()', () {
      final dcid = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final (clientSecret, serverSecret) = computeInitialSecrets(dcid);
      expect(clientSecret.length, equals(32));
      expect(serverSecret.length, equals(32));
      expect(clientSecret, isNot(orderedEquals(serverSecret)));
    });

    test('computeKeyAndIv()', () {
      final dcid = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final (clientSecret, _) = computeInitialSecrets(dcid);
      final (key, iv, hp) = computeKeyAndIv(clientSecret);
      expect(key.length, equals(16));
      expect(iv.length, equals(12));
      expect(hp.length, equals(16));
    });

    test('hkdfExtract()', () {
      final res = hkdfExtract(quicSaltV1, [1, 2, 3]);
      expect(res.length, equals(32));
    });

    test('hkdfExpand()', () {
      final prk = Uint8List(32);
      final res = hkdfExpand(prk, [1, 2], 16);
      expect(res.length, equals(16));
    });

    test('hkdfExpandLabel()', () {
      final secret = Uint8List(32);
      final res = hkdfExpandLabel(secret, 'test label', const [], 16);
      expect(res.length, equals(16));
    });
  });

  group('QuicFrame [Atomic Audit]', () {
    test('encode()', () {
      const QuicFrame frame = PingFrame();
      expect(frame.encode(), Uint8List.fromList([0x01]));
    });
  });

  group('PaddingFrame [Atomic Audit]', () {
    test('encode()', () {
      const frame = PaddingFrame(4);
      expect(frame.encode(), Uint8List.fromList([0, 0, 0, 0]));
    });
  });

  group('PingFrame [Atomic Audit]', () {
    test('encode()', () {
      const frame = PingFrame();
      expect(frame.encode(), Uint8List.fromList([0x01]));
    });
  });

  group('CryptoFrame [Atomic Audit]', () {
    test('encode()', () {
      final frame = CryptoFrame(0, Uint8List.fromList([10, 20]));
      final bytes = frame.encode();
      expect(bytes, isNotEmpty);
      expect(bytes.sublist(bytes.length - 2), Uint8List.fromList([10, 20]));
    });
  });

  group('StreamFrame [Atomic Audit]', () {
    test('encode()', () {
      final frame = StreamFrame(
        streamId: 1,
        offset: 0,
        data: Uint8List.fromList([99]),
        fin: false,
      );
      final bytes = frame.encode();
      expect(bytes, isNotEmpty);
      expect(bytes.last, 99);
    });
  });

  group('AckFrame [Atomic Audit]', () {
    test('encode()', () {
      const range = AckRange(gap: 1, length: 2);
      const frame = AckFrame(
        largestAcked: 5,
        delayTimeMicros: 50,
        firstAckRange: 1,
        additionalRanges: [range],
      );
      final bytes = frame.encode();
      expect(bytes[0], equals(0x02));
      final parsed = parseFrame(bytes) as AckFrame;
      expect(parsed.largestAcked, equals(5));
      expect(parsed.delayTimeMicros, equals(50));
      expect(parsed.firstAckRange, equals(1));
      expect(parsed.additionalRanges.length, equals(1));
    });
  });

  group('ResetStreamFrame [Atomic Audit]', () {
    test('encode()', () {
      const frame = ResetStreamFrame(
        streamId: 4,
        applicationErrorCode: 100,
        finalSize: 250,
      );
      final bytes = frame.encode();
      expect(bytes[0], equals(0x04));
      final parsed = parseFrame(bytes) as ResetStreamFrame;
      expect(parsed.streamId, equals(4));
      expect(parsed.applicationErrorCode, equals(100));
      expect(parsed.finalSize, equals(250));
    });
  });

  group('StopSendingFrame [Atomic Audit]', () {
    test('encode()', () {
      const frame = StopSendingFrame(streamId: 4, applicationErrorCode: 100);
      final bytes = frame.encode();
      expect(bytes[0], equals(0x05));
      final parsed = parseFrame(bytes) as StopSendingFrame;
      expect(parsed.streamId, equals(4));
      expect(parsed.applicationErrorCode, equals(100));
    });
  });

  group('HandshakeDoneFrame [Atomic Audit]', () {
    test('encode()', () {
      const frame = HandshakeDoneFrame();
      expect(frame.encode(), Uint8List.fromList([0x1e]));
    });
  });

  group('ConnectionCloseFrame [Atomic Audit]', () {
    test('encode()', () {
      const frame = ConnectionCloseFrame(
        errorCode: 10,
        frameType: 6,
        reasonPhrase: 'test close',
      );
      final bytes = frame.encode();
      expect(bytes[0], equals(0x1c));
      final parsed = parseFrame(bytes) as ConnectionCloseFrame;
      expect(parsed.errorCode, equals(10));
      expect(parsed.frameType, equals(6));
      expect(parsed.reasonPhrase, equals('test close'));
      expect(parsed.isApplicationError, isFalse);
    });
  });

  group('NewTokenFrame [Atomic Audit]', () {
    test('encode()', () {
      final token = Uint8List.fromList([1, 2, 3, 4]);
      final frame = NewTokenFrame(token);
      final bytes = frame.encode();
      expect(bytes[0], equals(0x07));
      final parsed = parseFrame(bytes) as NewTokenFrame;
      expect(parsed.token, equals(token));
    });
  });

  group('NewConnectionIdFrame [Atomic Audit]', () {
    test('encode()', () {
      final cid = Uint8List.fromList([10, 20, 30, 40]);
      final token = Uint8List(16);
      final frame = NewConnectionIdFrame(
        sequenceNumber: 1,
        retirePriorTo: 0,
        connectionId: cid,
        statelessResetToken: token,
      );
      final bytes = frame.encode();
      expect(bytes[0], equals(0x18));
      final parsed = parseFrame(bytes) as NewConnectionIdFrame;
      expect(parsed.sequenceNumber, equals(1));
      expect(parsed.retirePriorTo, equals(0));
      expect(parsed.connectionId, equals(cid));
      expect(parsed.statelessResetToken, equals(token));
    });
  });

  group('MaxDataFrame [Atomic Audit]', () {
    test('encode()', () {
      const frame = MaxDataFrame(1048576);
      final bytes = frame.encode();
      expect(bytes[0], equals(0x10));
      final parsed = parseFrame(bytes) as MaxDataFrame;
      expect(parsed.maximumData, equals(1048576));
    });
  });

  group('MaxStreamDataFrame [Atomic Audit]', () {
    test('encode()', () {
      const frame = MaxStreamDataFrame(streamId: 4, maximumStreamData: 65536);
      final bytes = frame.encode();
      expect(bytes[0], equals(0x11));
      final parsed = parseFrame(bytes) as MaxStreamDataFrame;
      expect(parsed.streamId, equals(4));
      expect(parsed.maximumStreamData, equals(65536));
    });
  });

  group('MaxStreamsFrame [Atomic Audit]', () {
    test('encode()', () {
      const frameBidi = MaxStreamsFrame(
        isBidirectional: true,
        maximumStreams: 100,
      );
      final bytesBidi = frameBidi.encode();
      expect(bytesBidi[0], equals(0x12));
      final parsedBidi = parseFrame(bytesBidi) as MaxStreamsFrame;
      expect(parsedBidi.isBidirectional, isTrue);
      expect(parsedBidi.maximumStreams, equals(100));

      const frameUni = MaxStreamsFrame(
        isBidirectional: false,
        maximumStreams: 50,
      );
      final bytesUni = frameUni.encode();
      expect(bytesUni[0], equals(0x13));
      final parsedUni = parseFrame(bytesUni) as MaxStreamsFrame;
      expect(parsedUni.isBidirectional, isFalse);
      expect(parsedUni.maximumStreams, equals(50));
    });
  });

  group('ExtendedHeader [Atomic Audit]', () {
    test('append()', () {
      final header = ExtendedHeader(
        isLongHeader: true,
        type: packetTypeInitial,
        version: quicVersion1,
        destConnectionId: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
        srcConnectionId: Uint8List.fromList([8, 7, 6, 5, 4, 3, 2, 1]),
        token: Uint8List.fromList([10, 20]),
        length: 100,
        packetNumber: 42,
        packetNumberLen: 4,
      );

      final bytes = header.append();
      expect(bytes[0] & 0x80, isNot(0));
      expect((bytes[0] >> 4) & 0x03, equals(packetTypeInitial));
    });

    test('parse()', () {
      final header = ExtendedHeader(
        isLongHeader: false,
        destConnectionId: Uint8List.fromList([1, 2, 3, 4]),
        packetNumber: 99,
        packetNumberLen: 2,
        keyPhase: 1,
      );

      final bytes = header.append();
      final (parsed, headerLen) = ExtendedHeader.parse(bytes, destConnIdLen: 4);
      expect(parsed.isLongHeader, isFalse);
      expect(parsed.destConnectionId, orderedEquals([1, 2, 3, 4]));
      expect(parsed.packetNumber, equals(99));
      expect(parsed.packetNumberLen, equals(2));
      expect(parsed.keyPhase, equals(1));
      expect(headerLen, equals(bytes.length));
    });
  });

  group('TransportParameters [Atomic Audit]', () {
    test('marshal()', () {
      final params = TransportParameters(
        initialMaxStreamDataBidiLocal: 1000,
        initialMaxStreamDataBidiRemote: 2000,
        initialMaxData: 10000,
      );
      final bytes = params.marshal();
      expect(bytes, isNotEmpty);
    });

    test('unmarshal()', () {
      final params = TransportParameters(
        initialMaxStreamDataBidiLocal: 1000,
        initialMaxStreamDataBidiRemote: 2000,
        initialMaxData: 10000,
      );
      final bytes = params.marshal();
      final parsed = TransportParameters.unmarshal(bytes);
      expect(parsed.initialMaxStreamDataBidiLocal, equals(1000));
      expect(parsed.initialMaxStreamDataBidiRemote, equals(2000));
      expect(parsed.initialMaxData, equals(10000));
    });
  });

  group('AesHeaderProtector [Atomic Audit]', () {
    test('apply()', () {
      final hpKey = Uint8List(16);
      final hp = AesHeaderProtector(hpKey);
      final sample = Uint8List(16);
      final headerBytes = Uint8List.fromList([0xc0, 0, 0, 0, 1]);
      hp.apply(
        sample: sample,
        headerBytes: headerBytes,
        pnOffset: 1,
        pnLen: 4,
        isLongHeader: true,
      );
      // Applying again inverts the mask
      hp.apply(
        sample: sample,
        headerBytes: headerBytes,
        pnOffset: 1,
        pnLen: 4,
        isLongHeader: true,
      );
      expect(headerBytes, orderedEquals([0xc0, 0, 0, 0, 1]));
    });
  });

  group('QuicPacketCipher [Atomic Audit]', () {
    test('seal()', () {
      final dcid = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final scid = Uint8List.fromList([8, 7, 6, 5, 4, 3, 2, 1]);
      final (clientSecret, _) = computeInitialSecrets(dcid);
      final (key, iv, hpKey) = computeKeyAndIv(clientSecret);

      final hp = AesHeaderProtector(hpKey);
      final cipher = QuicPacketCipher(key: key, iv: iv, hp: hp);

      final header = ExtendedHeader(
        isLongHeader: true,
        type: packetTypeInitial,
        version: quicVersion1,
        destConnectionId: dcid,
        srcConnectionId: scid,
        packetNumber: 0,
        packetNumberLen: 4,
      );

      final payload = Uint8List.fromList([
        10,
        20,
        30,
        40,
        50,
        60,
        70,
        80,
        90,
        100,
      ]);
      final packetBytes = cipher.seal(header: header, payload: payload);
      expect(packetBytes.length, greaterThan(payload.length + 16));
    });

    test('open()', () {
      final dcid = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final scid = Uint8List.fromList([8, 7, 6, 5, 4, 3, 2, 1]);
      final (clientSecret, _) = computeInitialSecrets(dcid);
      final (key, iv, hpKey) = computeKeyAndIv(clientSecret);

      final hp = AesHeaderProtector(hpKey);
      final cipher = QuicPacketCipher(key: key, iv: iv, hp: hp);

      final header = ExtendedHeader(
        isLongHeader: true,
        type: packetTypeInitial,
        version: quicVersion1,
        destConnectionId: dcid,
        srcConnectionId: scid,
        packetNumber: 0,
        packetNumberLen: 4,
      );

      final payload = Uint8List.fromList([
        10,
        20,
        30,
        40,
        50,
        60,
        70,
        80,
        90,
        100,
      ]);
      final packetBytes = cipher.seal(header: header, payload: payload);
      final (openedHeader, openedPayload) = cipher.open(packetBytes);
      expect(openedHeader.type, equals(packetTypeInitial));
      expect(openedHeader.packetNumber, equals(0));
      expect(openedPayload, orderedEquals(payload));
    });
  });

  group('DatagramFrame [Atomic Audit]', () {
    test('encode() - type 0x31 prefixes the payload with its length', () {
      // RFC 9221 s. 4: the low bit of the type says a Length field follows,
      // which is what lets other frames be packed after this one.
      final frame = DatagramFrame(Uint8List.fromList([1, 2, 3]));
      expect(frame.dataLenPresent, isTrue);
      expect(frame.encode(), orderedEquals([0x31, 0x03, 1, 2, 3]));
    });

    test('encode() - type 0x30 runs the payload to the end of the packet', () {
      final frame = DatagramFrame(
        Uint8List.fromList([9, 8]),
        dataLenPresent: false,
      );
      expect(frame.encode(), orderedEquals([0x30, 9, 8]));
    });

    test('encode() - an empty datagram is still a well-formed frame', () {
      expect(DatagramFrame(Uint8List(0)).encode(), orderedEquals([0x31, 0x00]));
    });

    test('parseFrame() - round-trips a length-prefixed DATAGRAM frame', () {
      final payload = Uint8List.fromList(List<int>.generate(64, (i) => i));
      final parsed = parseFrame(DatagramFrame(payload).encode());
      expect(parsed, isA<DatagramFrame>());
      final datagram = parsed as DatagramFrame;
      expect(datagram.dataLenPresent, isTrue);
      expect(datagram.data, orderedEquals(payload));
    });

    test('parseFrame() - a 0x30 frame takes every remaining byte', () {
      final parsed =
          parseFrame(Uint8List.fromList([0x30, 0xde, 0xad, 0xbe, 0xef]))
              as DatagramFrame;
      expect(parsed.dataLenPresent, isFalse);
      expect(parsed.data, orderedEquals([0xde, 0xad, 0xbe, 0xef]));
    });

    test('parseFrame() - rejects a DATAGRAM frame cut short of its length', () {
      expect(
        () => parseFrame(Uint8List.fromList([0x31, 0x08, 1, 2])),
        throwsA(isA<FormatException>()),
      );
    });

    test('maxDatagramSize - matches wire.MaxDatagramSize and fits a 2-byte '
        'varint', () {
      expect(maxDatagramSize, 16383);
      expect(appendVarInt(const [], maxDatagramSize), hasLength(2));
    });
  });
}
