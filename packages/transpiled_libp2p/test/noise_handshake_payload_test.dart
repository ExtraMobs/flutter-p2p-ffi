// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// test/transport/noise/noise_handshake_payload_test.dart
//
// Parity test for lib/src/transport/noise/noise_handshake_payload.dart
// against a real payload built with go-libp2p's own core/crypto,
// core/peer, and p2p/security/noise/pb (real protoc-generated code, not
// hand-rolled) -- go-ipfs-reference/go-libp2p/dartipfs_vectors/main.go,
// self-verified in Go before being copied here. Proves the hand-rolled
// 2-field protobuf decoder reads the real wire format correctly, and
// that verifyNoiseHandshakePayload's signature check + PeerId derivation
// match go-libp2p exactly.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

Uint8List _fromHex(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

const _identityPubkeyMarshaledHex =
    '080112204046afe32dff2b06ebf7bcfc5e470c9891fab603953c0581cd45d15aaf47cf51';

const _noiseStaticPubkeyHex =
    'a4291817255988bde015a1763f5143b9ca2ac9b422bc5b15ac33f75265980f94';

const _payloadHex =
    '0a24080112204046afe32dff2b06ebf7bcfc5e470c9891fab603953c0581cd45d15aaf47c'
    'f5112405c3080e24fa41075c2c4b06578a0f803ab9664ee186d663549c52ce382c0f50545'
    '389fba28635ec9cf32c0a0b2b53a520827158dc7b9288042d759b905c18109';

const _expectedPeerId = '12D3KooWE9Gn3dipZhrnrhCVPoeDhdmK3svuy8q9PAqDGgYb8c3S';

void main() {
  group('Noise handshake payload -- real go-libp2p-generated vector', () {
    test('verifies a real payload and derives the correct PeerId', () async {
      final identity = await verifyNoiseHandshakePayload(
        _fromHex(_payloadHex),
        _fromHex(_noiseStaticPubkeyHex),
      );
      expect(identity.peerId.toString(), equals(_expectedPeerId));
      expect(identity.publicKey.raw(), equals(_fromHex(_identityPubkeyMarshaledHex).sublist(4)));
    });

    test('honors an expectedRemoteId that matches', () async {
      final expected = PeerId.fromBase58(_expectedPeerId);
      final identity = await verifyNoiseHandshakePayload(
        _fromHex(_payloadHex),
        _fromHex(_noiseStaticPubkeyHex),
        expectedRemoteId: expected,
      );
      expect(identity.peerId, equals(expected));
    });

    test('rejects a mismatched expectedRemoteId', () async {
      final wrongId = PeerId.fromBase58('QmSoLnSGccFuZQJzRadHn95W2CrSFmZuTdDWP8HXaHca9z');
      await expectLater(
        verifyNoiseHandshakePayload(
          _fromHex(_payloadHex),
          _fromHex(_noiseStaticPubkeyHex),
          expectedRemoteId: wrongId,
        ),
        throwsA(isA<NoiseHandshakeAuthException>()),
      );
    });

    test('rejects the payload when checked against the wrong Noise static key', () async {
      final wrongStaticKey = Uint8List(32); // all-zero, definitely not the signed one
      await expectLater(
        verifyNoiseHandshakePayload(_fromHex(_payloadHex), wrongStaticKey),
        throwsA(isA<NoiseHandshakeAuthException>()),
      );
    });

    test('rejects a truncated payload', () async {
      final truncated = _fromHex(_payloadHex);
      await expectLater(
        verifyNoiseHandshakePayload(
          truncated.sublist(0, truncated.length - 5),
          _fromHex(_noiseStaticPubkeyHex),
        ),
        throwsFormatException,
      );
    });
  });

  group('Noise handshake payload -- generate/verify round trip', () {
    test('a freshly generated Ed25519 identity round-trips through generate+verify', () async {
      final identity = await unmarshalEd25519PrivateKey(
        (await generateEd25519KeyPair()).raw(),
      );
      final noiseStaticKey = Uint8List.fromList(List<int>.generate(32, (i) => i));

      final payload = await generateNoiseHandshakePayload(
        localIdentityKey: identity,
        localNoiseStaticPublicKey: noiseStaticKey,
      );

      final remote = await verifyNoiseHandshakePayload(payload, noiseStaticKey);
      expect(remote.peerId, equals(PeerId.fromPublicKey(identity.getPublic().raw(), type: 'ed25519')));
    });

    test('rejects a payload verified against a different Noise static key', () async {
      final identity = await generateEd25519KeyPair();
      final payload = await generateNoiseHandshakePayload(
        localIdentityKey: identity,
        localNoiseStaticPublicKey: Uint8List.fromList(List<int>.generate(32, (i) => i)),
      );
      await expectLater(
        verifyNoiseHandshakePayload(payload, Uint8List.fromList(List<int>.generate(32, (i) => i + 1))),
        throwsA(isA<NoiseHandshakeAuthException>()),
      );
    });
  });
}
