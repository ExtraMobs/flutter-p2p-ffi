// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// test/transport/noise/noise_framing_test.dart
//
// Tests lib/src/transport/noise/noise_framing.dart's chunking + 2-byte
// length-prefix framing against a real handshake-derived CipherState
// pair (built with the already vector-validated HandshakeState from
// noise_state_test.dart), rather than against a fixed Go vector: the
// underlying AEAD encrypt/decrypt is already proven correct there, so
// this only needs to prove the chunk-size and length-prefix logic on
// top of it round-trips, including at the chunk-boundary edge cases.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

Future<((CipherState, CipherState), (CipherState, CipherState))> _handshakeSplitPair() async {
  final aStatic = await generateNoiseKeyPair();
  final bStatic = await generateNoiseKeyPair();
  final a = await HandshakeState.initialize(initiator: true, staticKeyPair: aStatic);
  final b = await HandshakeState.initialize(initiator: false, staticKeyPair: bStatic);

  final (m0, _) = await a.writeMessage(Uint8List(0));
  await b.readMessage(m0);
  final (m1, _) = await b.writeMessage(Uint8List(0));
  await a.readMessage(m1);
  final (m2, aSplit) = await a.writeMessage(Uint8List(0));
  final (_, bSplit) = await b.readMessage(m2);

  return (aSplit!, bSplit!);
}

Uint8List _readLengthPrefix(Uint8List frame) {
  final bd = ByteData.sublistView(frame, 0, lengthPrefixLength);
  final len = bd.getUint16(0, Endian.big);
  return frame.sublist(lengthPrefixLength, lengthPrefixLength + len);
}

void main() {
  group('noise_framing', () {
    test('empty plaintext produces zero frames', () async {
      final (aSplit, _) = await _handshakeSplitPair();
      final frames = await encryptFrames(aSplit.$1, Uint8List(0));
      expect(frames, isEmpty);
    });

    test('small plaintext round-trips in exactly one frame', () async {
      final (aSplit, bSplit) = await _handshakeSplitPair();
      final plaintext = Uint8List.fromList('hello noise transport'.codeUnits);

      final frames = await encryptFrames(aSplit.$1, plaintext);
      expect(frames, hasLength(1));

      final ciphertext = _readLengthPrefix(frames.single);
      final decrypted = await decryptFrame(bSplit.$1, ciphertext);
      expect(decrypted, equals(plaintext));
    });

    test('length prefix matches the actual ciphertext length', () async {
      final (aSplit, _) = await _handshakeSplitPair();
      final plaintext = Uint8List.fromList(List<int>.generate(1000, (i) => i % 256));
      final frames = await encryptFrames(aSplit.$1, plaintext);
      final frame = frames.single;
      final bd = ByteData.sublistView(frame, 0, lengthPrefixLength);
      final declaredLen = bd.getUint16(0, Endian.big);
      expect(declaredLen, equals(frame.length - lengthPrefixLength));
      // ciphertext = plaintext + 16-byte Poly1305 tag.
      expect(declaredLen, equals(plaintext.length + 16));
    });

    test('plaintext larger than maxPlaintextLength is chunked across frames', () async {
      final (aSplit, bSplit) = await _handshakeSplitPair();
      final size = maxPlaintextLength * 2 + 137; // 2 full chunks + a remainder
      final plaintext = Uint8List.fromList(List<int>.generate(size, (i) => i % 256));

      final frames = await encryptFrames(aSplit.$1, plaintext);
      expect(frames, hasLength(3));
      for (final frame in frames.take(2)) {
        expect(frame.length - lengthPrefixLength, equals(maxPlaintextLength + 16));
      }
      expect(frames.last.length - lengthPrefixLength, equals(137 + 16));

      final decrypted = BytesBuilder();
      for (final frame in frames) {
        decrypted.add(await decryptFrame(bSplit.$1, _readLengthPrefix(frame)));
      }
      expect(decrypted.toBytes(), equals(plaintext));
    });

    test('a plaintext of exactly maxPlaintextLength stays in one frame', () async {
      final (aSplit, bSplit) = await _handshakeSplitPair();
      final plaintext = Uint8List.fromList(List<int>.generate(maxPlaintextLength, (i) => i % 256));

      final frames = await encryptFrames(aSplit.$1, plaintext);
      expect(frames, hasLength(1));

      final decrypted = await decryptFrame(bSplit.$1, _readLengthPrefix(frames.single));
      expect(decrypted, equals(plaintext));
    });

    test('decrypting with the wrong cipher state fails', () async {
      final (aSplit, bSplit) = await _handshakeSplitPair();
      final plaintext = Uint8List.fromList('secret'.codeUnits);
      final frames = await encryptFrames(aSplit.$1, plaintext);
      // bSplit.$2 is b's own encrypt-direction state, not the one paired
      // with a's cs1 -- decrypting with it must fail.
      await expectLater(
        decryptFrame(bSplit.$2, _readLengthPrefix(frames.single)),
        throwsA(anything),
      );
    });
  });
}
