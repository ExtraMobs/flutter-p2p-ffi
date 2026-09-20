import 'dart:typed_data';

import 'package:test/test.dart';
import '../../../packages/transpiled_quic_go/lib/src/frames.dart';
import '../../../packages/transpiled_quic_go/lib/src/packet_number.dart';
import '../../../packages/transpiled_quic_go/lib/src/varint.dart';



void main() {
  group('Top-Level Functions [Atomic Audit]', () {
    test('decodePacketNumber() - recovers full packet numbers', () {
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

    test('varIntLength() - returns expected byte length based on integer threshold', () {
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

    test('appendVarInt() - appends varint bytes with correct length tags', () {
      expect(appendVarInt([], 25), Uint8List.fromList([25]));
      expect(appendVarInt([1, 2], 25), Uint8List.fromList([1, 2, 25]));
      final v2 = appendVarInt([], 494);
      expect(v2, Uint8List.fromList([0x40 | (494 >> 8), 494 & 0xff]));
    });

    test('parseVarInt() - parses varint and returns byte count', () {
      final (v1, n1) = parseVarInt(Uint8List.fromList([25]));
      expect(v1, 25);
      expect(n1, 1);

      final (v2, n2) = parseVarInt(appendVarInt([], 494));
      expect(v2, 494);
      expect(n2, 2);

      expect(() => parseVarInt(Uint8List(0)), throwsFormatException);
      expect(() => parseVarInt(Uint8List.fromList([0x40])), throwsFormatException);
    });

    test('parseFrame() - parses Ping, Crypto and Stream frames', () {
      final ping = parseFrame(const PingFrame().encode());
      expect(ping, isA<PingFrame>());

      final crypto = parseFrame(CryptoFrame(10, Uint8List.fromList([1, 2, 3])).encode());
      expect(crypto, isA<CryptoFrame>());
      final cf = crypto as CryptoFrame;
      expect(cf.offset, 10);
      expect(cf.data, Uint8List.fromList([1, 2, 3]));

      final stream = parseFrame(StreamFrame(streamId: 4, offset: 20, data: Uint8List.fromList([5, 6]), fin: true).encode());
      expect(stream, isA<StreamFrame>());
      final sf = stream as StreamFrame;
      expect(sf.streamId, 4);
      expect(sf.offset, 20);
      expect(sf.data, Uint8List.fromList([5, 6]));
      expect(sf.fin, isTrue);

      expect(() => parseFrame(Uint8List.fromList([0x00])), throwsFormatException);
    });
  });

  group('QuicFrame [Atomic Audit]', () {
    test('encode() - serializes frame to bytes', () {
      const QuicFrame frame = PingFrame();
      expect(frame.encode(), Uint8List.fromList([0x01]));
    });
  });

  group('PingFrame [Atomic Audit]', () {
    test('encode() - serializes Ping frame', () {
      const frame = PingFrame();
      expect(frame.encode(), Uint8List.fromList([0x01]));
    });
  });

  group('CryptoFrame [Atomic Audit]', () {
    test('encode() - serializes Crypto frame', () {
      final frame = CryptoFrame(0, Uint8List.fromList([10, 20]));
      final bytes = frame.encode();
      expect(bytes, isNotEmpty);
      expect(bytes.sublist(bytes.length - 2), Uint8List.fromList([10, 20]));
    });
  });

  group('StreamFrame [Atomic Audit]', () {
    test('encode() - serializes Stream frame', () {
      final frame = StreamFrame(streamId: 1, offset: 0, data: Uint8List.fromList([99]), fin: false);
      final bytes = frame.encode();
      expect(bytes, isNotEmpty);
      expect(bytes.last, 99);
    });
  });
}
