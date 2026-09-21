import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';

import '../../../packages/transpiled_quic_go/lib/transpiled_quic_go.dart';

// Byte vectors below are cross-checked against
// `go-ipfs-reference/quic-go/http3/frames_test.go` (module
// `github.com/quic-go/quic-go`) where upstream provides an equivalent case.

void main() {
  group('Top-Level Functions [Atomic Audit]', () {
    test('parseHttp3Frame() - round trips a DATA frame via append()', () {
      const original = Http3DataFrame(0x1337);
      final encoded = original.append(const []);
      final (frame, bytesRead) = parseHttp3Frame(encoded);
      expect(frame, isA<Http3DataFrame>());
      expect((frame as Http3DataFrame).length, 0x1337);
      expect(bytesRead, encoded.length);
    });

    test('parseHttp3Frame() - round trips a HEADERS frame via append()', () {
      const original = Http3HeadersFrame(0x1337);
      final encoded = original.append(const []);
      final (frame, bytesRead) = parseHttp3Frame(encoded);
      expect(frame, isA<Http3HeadersFrame>());
      expect((frame as Http3HeadersFrame).length, 0x1337);
      expect(bytesRead, encoded.length);
    });

    test(
      'parseHttp3Frame() - round trips a SETTINGS frame with Other entries via append()',
      () {
        const original = Http3SettingsFrame(other: {13: 37, 0xdead: 0xbeef});
        final encoded = original.append(const []);
        final (frame, bytesRead) = parseHttp3Frame(encoded);
        expect(frame, isA<Http3SettingsFrame>());
        final sf = frame as Http3SettingsFrame;
        expect(sf.other, {13: 37, 0xdead: 0xbeef});
        expect(sf.maxFieldSectionSize, -1);
        expect(sf.datagram, isFalse);
        expect(sf.extendedConnect, isFalse);
        expect(bytesRead, encoded.length);
      },
    );

    test('parseHttp3Frame() - round trips a GOAWAY frame via append()', () {
      const original = Http3GoAwayFrame(100);
      final encoded = original.append(const []);
      final (frame, bytesRead) = parseHttp3Frame(encoded);
      expect(frame, isA<Http3GoAwayFrame>());
      expect((frame as Http3GoAwayFrame).streamId, 100);
      expect(bytesRead, encoded.length);
    });

    test(
      'parseHttp3Frame() - skips an unknown frame type and returns the next known frame',
      () {
        // Mirrors TestParserUnknownFrameType: an unrecognized type 0xdead
        // carrying a 6-byte payload ("foobar") must be skipped transparently,
        // leaving the following HEADERS frame's own 3-byte payload ("foo")
        // unconsumed for the caller.
        final data = Uint8List.fromList([
          ...appendVarInt(const [], 0xdead),
          ...appendVarInt(const [], 6),
          ...utf8.encode('foobar'),
          ...const Http3HeadersFrame(3).append(const []),
          ...utf8.encode('foo'),
        ]);

        final (frame, bytesRead) = parseHttp3Frame(data);
        expect(frame, isA<Http3HeadersFrame>());
        expect((frame as Http3HeadersFrame).length, 3);
        expect(utf8.decode(data.sublist(bytesRead, bytesRead + 3)), 'foo');
      },
    );

    test(
      'parseHttp3Frame() - skips CANCEL_PUSH, PUSH_PROMISE and MAX_PUSH_ID as unsupported-but-benign',
      () {
        // Mirrors TestParserUnsupportedFrameTypes.
        for (final ft in [0x3, 0x5, 0xd]) {
          final data = Uint8List.fromList([
            ...appendVarInt(const [], ft),
            ...appendVarInt(const [], 6),
            ...utf8.encode('foobar'),
            ...const Http3DataFrame(3).append(const []),
            ...utf8.encode('foo'),
          ]);

          final (frame, bytesRead) = parseHttp3Frame(data);
          expect(
            frame,
            isA<Http3DataFrame>(),
            reason: 'frame type 0x${ft.toRadixString(16)}',
          );
          expect((frame as Http3DataFrame).length, 3);
          expect(utf8.decode(data.sublist(bytesRead, bytesRead + 3)), 'foo');
        }
      },
    );

    test(
      'parseHttp3Frame() - throws Http3ReservedFrameTypeException for reserved frame types',
      () {
        // Mirrors TestParserReservedFrameType: types 0x2, 0x6, 0x8, 0x9 are
        // RFC 9114 §7.2.8 grease code points reserved for HTTP/2 and MUST be
        // rejected as H3_FRAME_UNEXPECTED.
        for (final ft in [0x2, 0x6, 0x8, 0x9]) {
          final data = Uint8List.fromList([
            ...appendVarInt(const [], ft),
            ...appendVarInt(const [], 6),
            ...utf8.encode('foobar'),
          ]);

          expect(
            () => parseHttp3Frame(data),
            throwsA(
              isA<Http3ReservedFrameTypeException>()
                  .having((e) => e.frameType, 'frameType', ft)
                  .having(
                    (e) => e.errorCode,
                    'errorCode',
                    Http3ErrCode.frameUnexpected,
                  ),
            ),
            reason: 'frame type 0x${ft.toRadixString(16)}',
          );
        }
      },
    );

    test('parseHttp3Frame() - throws FormatException on empty input', () {
      expect(() => parseHttp3Frame(Uint8List(0)), throwsFormatException);
    });

    test(
      'parseHttp3Frame() - throws FormatException on a truncated frame header',
      () {
        // Mirrors testFrameParserEOF, applied to a DATA frame header.
        Uint8List data = appendVarInt(const [], 0x0);
        data = appendVarInt(data, 0x1337);
        for (var i = 1; i < data.length; i++) {
          expect(
            () => parseHttp3Frame(Uint8List.sublistView(data, 0, i)),
            throwsFormatException,
            reason: 'truncated to $i byte(s)',
          );
        }
      },
    );

    test(
      'parseHttp3Frame() - throws FormatException when a SETTINGS frame declares a length above 8 KiB',
      () {
        final data = Uint8List.fromList([
          ...appendVarInt(const [], 0x4),
          ...appendVarInt(const [], 8 * 1024 + 1),
        ]);
        expect(
          () => parseHttp3Frame(data),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'unexpected size for SETTINGS frame: 8193',
            ),
          ),
        );
      },
    );

    test(
      'parseHttp3Frame() - throws FormatException on a duplicate "other" SETTINGS entry',
      () {
        // Mirrors TestParserSettingsFrameDuplicateSettings ("other setting").
        final settings = [
          ...appendVarInt(const [], 13),
          ...appendVarInt(const [], 37),
          ...appendVarInt(const [], 13),
          ...appendVarInt(const [], 38),
        ];
        final data = Uint8List.fromList([
          ...appendVarInt(const [], 0x4),
          ...appendVarInt(const [], settings.length),
          ...settings,
        ]);
        expect(
          () => parseHttp3Frame(data),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'duplicate setting: 13',
            ),
          ),
        );
      },
    );

    test(
      'parseHttp3Frame() - throws FormatException on a duplicate SETTINGS_H3_DATAGRAM',
      () {
        // Mirrors TestParserSettingsFrameDuplicateSettings ("datagram").
        final settings = [
          ...appendVarInt(const [], 0x33),
          ...appendVarInt(const [], 1),
          ...appendVarInt(const [], 0x33),
          ...appendVarInt(const [], 0),
        ];
        final data = Uint8List.fromList([
          ...appendVarInt(const [], 0x4),
          ...appendVarInt(const [], settings.length),
          ...settings,
        ]);
        expect(
          () => parseHttp3Frame(data),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'duplicate setting: 51',
            ),
          ),
        );
      },
    );

    test(
      'parseHttp3Frame() - throws FormatException on an invalid SETTINGS_H3_DATAGRAM value',
      () {
        // Mirrors TestParserSettingsFrameDatagramInvalidValue.
        final settings = [
          ...appendVarInt(const [], 0x33),
          ...appendVarInt(const [], 1337),
        ];
        final data = Uint8List.fromList([
          ...appendVarInt(const [], 0x4),
          ...appendVarInt(const [], settings.length),
          ...settings,
        ]);
        expect(
          () => parseHttp3Frame(data),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'invalid value for SETTINGS_H3_DATAGRAM: 1337',
            ),
          ),
        );
      },
    );

    test(
      'parseHttp3Frame() - throws FormatException on an invalid SETTINGS_ENABLE_CONNECT_PROTOCOL value',
      () {
        // Mirrors TestParserSettingsFrameExtendedConnectInvalidValue.
        final settings = [
          ...appendVarInt(const [], 0x8),
          ...appendVarInt(const [], 1337),
        ];
        final data = Uint8List.fromList([
          ...appendVarInt(const [], 0x4),
          ...appendVarInt(const [], settings.length),
          ...settings,
        ]);
        expect(
          () => parseHttp3Frame(data),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'invalid value for SETTINGS_ENABLE_CONNECT_PROTOCOL: 1337',
            ),
          ),
        );
      },
    );

    test(
      'parseHttp3Frame() - throws FormatException on a GOAWAY frame with a mismatched declared length',
      () {
        // Mirrors the `r.NumRead-startLen != int(l)` check in Go's
        // parseGoAwayFrame: the declared length (5) does not match the
        // actual varint length of the encoded stream id (2, for value 100).
        final data = Uint8List.fromList([
          ...appendVarInt(const [], 0x7),
          ...appendVarInt(const [], 5),
          ...appendVarInt(const [], 100),
        ]);
        expect(
          () => parseHttp3Frame(data),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'GOAWAY frame: inconsistent length',
            ),
          ),
        );
      },
    );

    test("nextProtoH3 - matches Go's exported NextProtoH3 constant", () {
      expect(nextProtoH3, 'h3');
    });

    test(
      'http3StreamTypeControl, http3StreamTypePush, http3StreamTypeQpackEncoder, '
      "http3StreamTypeQpackDecoder - match Go's unexported streamType* constants",
      () {
        expect(http3StreamTypeControl, 0x00);
        expect(http3StreamTypePush, 0x01);
        expect(http3StreamTypeQpackEncoder, 0x02);
        expect(http3StreamTypeQpackDecoder, 0x03);
      },
    );
  });

  group('Http3DataFrame [Atomic Audit]', () {
    test('append() - encodes type 0x0 and the payload length as varints', () {
      final bytes = const Http3DataFrame(5).append(const []);
      expect(bytes, Uint8List.fromList([0x00, 0x05]));
    });

    test('append() - prepends to a non-empty prefix', () {
      final bytes = const Http3DataFrame(5).append([0xff]);
      expect(bytes, Uint8List.fromList([0xff, 0x00, 0x05]));
    });
  });

  group('Http3HeadersFrame [Atomic Audit]', () {
    test(
      'append() - encodes type 0x1 and the header block length as varints',
      () {
        final bytes = const Http3HeadersFrame(0x1337).append(const []);
        // type 0x1 (1 byte) + length 0x1337 (2-byte varint: 0x40 | 0x13, 0x37)
        expect(bytes, Uint8List.fromList([0x01, 0x53, 0x37]));
      },
    );
  });

  group('Http3SettingsFrame [Atomic Audit]', () {
    test(
      'append() - writes MaxFieldSectionSize, Datagram, ExtendedConnect then '
      'Other, in that order',
      () {
        const frame = Http3SettingsFrame(
          maxFieldSectionSize: 1337,
          datagram: true,
          extendedConnect: true,
        );
        final bytes = frame.append(const []);
        // type 0x4, length 7, then:
        //   id 0x6 (1B) + val 1337 (2B varint: 0x45, 0x39)
        //   id 0x33 (1B) + val 1 (1B)
        //   id 0x8 (1B) + val 1 (1B)
        expect(
          bytes,
          Uint8List.fromList([
            0x04,
            0x07,
            0x06,
            0x45,
            0x39,
            0x33,
            0x01,
            0x08,
            0x01,
          ]),
        );
      },
    );

    test(
      'append() - omits unset MaxFieldSectionSize and false flags entirely',
      () {
        const frame = Http3SettingsFrame();
        final bytes = frame.append(const []);
        expect(bytes, Uint8List.fromList([0x04, 0x00]));
      },
    );
  });

  group('Http3GoAwayFrame [Atomic Audit]', () {
    test('append() - encodes type 0x7, a length equal to the stream id varint '
        'length, then the stream id', () {
      final bytes = const Http3GoAwayFrame(100).append(const []);
      // type 0x7 (1B), length = varIntLength(100) = 2 (1B: 0x02),
      // then 100 as a 2-byte varint: 0x40, 0x64.
      expect(bytes, Uint8List.fromList([0x07, 0x02, 0x40, 0x64]));
    });
  });

  group('Http3ReservedFrameTypeException [Atomic Audit]', () {
    test('errorCode - always returns the frameUnexpected error code', () {
      const ex = Http3ReservedFrameTypeException(0x6);
      expect(ex.errorCode, Http3ErrCode.frameUnexpected);
    });

    test("toString() - matches Go's error message format", () {
      const ex = Http3ReservedFrameTypeException(0x6);
      expect(ex.toString(), 'http3: reserved frame type: 6');
    });
  });

  group('Http3ErrCode [Atomic Audit]', () {
    test(
      'toString() - returns the named H3_* wire identifier for known codes',
      () {
        expect(Http3ErrCode.frameUnexpected.toString(), 'H3_FRAME_UNEXPECTED');
        expect(Http3ErrCode.noError.toString(), 'H3_NO_ERROR');
        expect(
          Http3ErrCode.qpackDecompressionFailed.toString(),
          'QPACK_DECOMPRESSION_FAILED',
        );
      },
    );

    test(
      'toString() - falls back to a hex-formatted message for unknown codes',
      () {
        expect(
          const Http3ErrCode(0x999).toString(),
          'unknown error code: 0x999',
        );
      },
    );

    test('operator == - compares by value', () {
      expect(const Http3ErrCode(0x105) == const Http3ErrCode(0x105), isTrue);
      expect(const Http3ErrCode(0x105) == const Http3ErrCode(0x106), isFalse);
      expect(const Http3ErrCode(0x105) == Http3ErrCode.frameUnexpected, isTrue);
    });

    test('hashCode - equal values share a hash code', () {
      expect(
        const Http3ErrCode(0x105).hashCode,
        const Http3ErrCode(0x105).hashCode,
      );
    });
  });
}
