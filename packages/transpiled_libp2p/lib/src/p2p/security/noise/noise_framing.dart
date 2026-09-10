// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/transport/noise/noise_framing.dart
//
// Port of go-libp2p's p2p/security/noise post-handshake wire framing
// (rw.go): each post-handshake message is length-prefixed with a 2-byte
// big-endian length (`LengthPrefixLength`), and plaintext larger than
// `MaxPlaintextLength` is split across multiple frames. This is the
// pure encode/decode logic, deliberately kept separate from any actual
// socket I/O (see noise_session.dart) so it's unit-testable on its own.
import 'dart:typed_data';

import 'noise_state.dart';

/// The Noise-imposed maximum transport message length, inclusive of the
/// 16-byte Poly1305 MAC, per go-libp2p's `MaxTransportMsgLength`.
const int maxTransportMsgLength = 0xffff;

/// ChaCha20-Poly1305's authentication tag length.
const int _macOverhead = 16;

/// The maximum plaintext payload per frame; larger writes are chunked,
/// per go-libp2p's `MaxPlaintextLength`.
const int maxPlaintextLength = maxTransportMsgLength - _macOverhead;

/// The length of the frame's length prefix itself, per go-libp2p's
/// `LengthPrefixLength`.
const int lengthPrefixLength = 2;

/// Splits [plaintext] into `<= maxPlaintextLength`-byte chunks, encrypts
/// each with [cipherState], and returns the wire-ready frames (each
/// already prefixed with its 2-byte big-endian ciphertext length), per
/// go-libp2p's `secureSession.Write`.
Future<List<Uint8List>> encryptFrames(
  CipherState cipherState,
  Uint8List plaintext,
) async {
  final frames = <Uint8List>[];
  var written = 0;
  while (written < plaintext.length) {
    final end = (written + maxPlaintextLength < plaintext.length)
        ? written + maxPlaintextLength
        : plaintext.length;
    final ciphertext = await cipherState.encryptWithAd(
      Uint8List(0),
      plaintext.sublist(written, end),
    );
    frames.add(_withLengthPrefix(ciphertext));
    written = end;
  }
  // An empty write still produces one (empty) frame, matching Go's loop
  // running at least once would -- but Go's `for written < total` skips
  // entirely for `total == 0`, so mirror that: no frames for empty input.
  return frames;
}

/// Decrypts one already length-delimited ciphertext frame (i.e. the
/// bytes read after peeling off the 2-byte length prefix), per
/// go-libp2p's `secureSession.Read`.
Future<Uint8List> decryptFrame(CipherState cipherState, Uint8List frameCiphertext) {
  return cipherState.decryptWithAd(Uint8List(0), frameCiphertext);
}

Uint8List _withLengthPrefix(Uint8List ciphertext) {
  if (ciphertext.length > maxTransportMsgLength) {
    throw ArgumentError(
      'Noise frame ciphertext too large: ${ciphertext.length} > $maxTransportMsgLength',
    );
  }
  final out = ByteData(lengthPrefixLength + ciphertext.length);
  out.setUint16(0, ciphertext.length, Endian.big);
  final bytes = out.buffer.asUint8List();
  bytes.setRange(lengthPrefixLength, bytes.length, ciphertext);
  return bytes;
}
