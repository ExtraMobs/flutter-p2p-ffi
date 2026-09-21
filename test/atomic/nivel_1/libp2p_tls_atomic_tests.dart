import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:test/test.dart';
import 'package:transpiled_libp2p/src/core/crypto/ecdsa_key.dart';
import 'package:transpiled_libp2p/src/core/crypto/ed25519_key.dart';
import 'package:transpiled_libp2p/src/core/crypto/key_codec.dart';
import 'package:transpiled_libp2p/src/core/crypto/key_types.dart';
import 'package:transpiled_libp2p/src/core/peer/peer_id.dart';
import 'package:transpiled_libp2p/src/core/transport/transport.dart';
import 'package:transpiled_libp2p/src/p2p/security/tls/crypto.dart';
import 'package:transpiled_libp2p/src/p2p/security/tls/extension.dart';
import 'package:transpiled_libp2p/src/p2p/security/tls/transport.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

// Upstream: go-libp2p (revision pinned in doc/transpilation/UPSTREAM_LOCK.md),
// p2p/security/tls/extension.go and p2p/security/tls/crypto.go. Vectors
// below are copied verbatim from extension_test.go's
// TestExtensionGenerating/TestExtensionComparison and crypto_test.go's
// TestVectors, so this port's negative case ("Invalid certificate") and
// three positive cases (Ed25519/ECDSA/secp256k1 peer IDs) are exactly the
// certificates go-libp2p itself uses to test PubKeyFromCertChain.
void main() {
  group('getPrefixedExtensionId [Atomic Audit]', () {
    test(
      'getPrefixedExtensionId() - matches the upstream TestExtensionGenerating vector',
      () {
        expect(getPrefixedExtensionId(const [13, 37]), [
          1,
          3,
          6,
          1,
          4,
          1,
          53594,
          13,
          37,
        ]);
      },
    );

    test(
      'getPrefixedExtensionId() - suffix [1, 1] matches the libp2p TLS extension id',
      () {
        expect(getPrefixedExtensionId(const [1, 1]), extensionId);
      },
    );
  });

  group('extensionIdEqual [Atomic Audit]', () {
    test(
      'extensionIdEqual() - matches the upstream TestExtensionComparison vectors',
      () {
        expect(extensionIdEqual([1, 2, 3, 4], [1, 2, 3, 4]), isTrue);
        expect(extensionIdEqual([1, 2, 3, 4], [1, 2, 3]), isFalse);
        expect(extensionIdEqual([1, 2, 3], [1, 2, 3, 4]), isFalse);
        expect(extensionIdEqual([1, 2, 3, 4], [4, 3, 2, 1]), isFalse);
      },
    );
  });

  group('generateSignedExtension [Atomic Audit]', () {
    test(
      'generateSignedExtension() - embeds the identity public key and signs certPublicKeySpkiDer',
      () async {
        final identityKey = await generateEd25519KeyPair();
        final certKey = generateEcdsaKeyPair();
        final certSpki = certKey.getPublic().raw();

        final ext = await generateSignedExtension(identityKey, certSpki);

        expect(ext.id, extensionId);
        expect(ext.critical, isFalse);

        final signedKeySeq = ASN1Sequence.fromBytes(ext.value);
        final embeddedPubKeyBytes =
            (signedKeySeq.elements![0] as ASN1OctetString).octets!;
        final signatureBytes =
            (signedKeySeq.elements![1] as ASN1OctetString).octets!;

        expect(embeddedPubKeyBytes, marshalPublicKey(identityKey.getPublic()));

        final toVerify = Uint8List.fromList([
          ...utf8.encode('libp2p-tls-handshake:'),
          ...certSpki,
        ]);
        expect(
          await identityKey.getPublic().verify(toVerify, signatureBytes),
          isTrue,
        );
      },
    );
  });

  group('keyToCertificate [Atomic Audit]', () {
    test(
      'keyToCertificate() - produces a v3 self-signed certificate with an ECDSA P-256 ephemeral key',
      () async {
        final identityKey = await generateEd25519KeyPair();
        final result = await keyToCertificate(identityKey);

        final tbs =
            (ASN1Sequence.fromBytes(result.certificateDer).elements![0]
                    as ASN1Sequence)
                .elements!;
        expect(
          tbs[0].tag,
          0xA0,
          reason: 'explicit [0] version tag must be present',
        );
        expect(
          ASN1Integer.fromBytes(tbs[0].valueBytes!).integer,
          BigInt.two,
          reason: 'version must be v3',
        );
        expect(
          tbs.any((e) => e.tag == 0xA3),
          isTrue,
          reason: 'extensions [3] tag must be present',
        );

        expect(result.privateKey.type, KeyType.ecdsa);
      },
    );

    test(
      'keyToCertificate() -> pubKeyFromCertChain() round-trips back to the same PeerId',
      () async {
        final identityKey = await generateEd25519KeyPair();
        final expectedPeerId = PeerId.fromPubKey(identityKey.getPublic());

        final result = await keyToCertificate(identityKey);
        final recoveredPubKey = await pubKeyFromCertChain([
          result.certificateDer,
        ]);

        expect(PeerId.fromPubKey(recoveredPubKey), expectedPeerId);
      },
    );
  });

  group('pubKeyFromCertChain [Atomic Audit]', () {
    test(
      'pubKeyFromCertChain() - crypto_test.go "ED25519 Peer ID" vector',
      () async {
        final pubKey = await pubKeyFromCertChain([
          _hexToBytes(_ed25519VectorHex),
        ]);
        expect(pubKey.type, KeyType.ed25519);
        expect(
          PeerId.fromPubKey(pubKey),
          PeerId.decode('12D3KooWM6CgA9iBFZmcYAHA6A2qvbAxqfkmrYiRQuz3XEsk4Ksv'),
        );
      },
    );

    test(
      'pubKeyFromCertChain() - crypto_test.go "ECDSA Peer ID" vector',
      () async {
        final pubKey = await pubKeyFromCertChain([
          _hexToBytes(_ecdsaVectorHex),
        ]);
        expect(pubKey.type, KeyType.ecdsa);
        expect(
          PeerId.fromPubKey(pubKey),
          PeerId.decode('QmfXbAwNjJLXfesgztEHe8HwgVDCMMpZ9Eax1HYq6hn9uE'),
        );
      },
    );

    test(
      'pubKeyFromCertChain() - crypto_test.go "secp256k1 Peer ID" vector',
      () async {
        final pubKey = await pubKeyFromCertChain([
          _hexToBytes(_secp256k1VectorHex),
        ]);
        expect(pubKey.type, KeyType.secp256k1);
        expect(
          PeerId.fromPubKey(pubKey),
          PeerId.decode(
            '16Uiu2HAkutTMoTzDw1tCvSRtu6YoixJwS46S1ZFxW8hSx9fWHiPs',
          ),
        );
      },
    );

    test(
      'pubKeyFromCertChain() - throws FormatException("signature invalid") for crypto_test.go '
      '"Invalid certificate" vector',
      () async {
        await expectLater(
          () => pubKeyFromCertChain([_hexToBytes(_invalidSignatureVectorHex)]),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('signature invalid'),
            ),
          ),
        );
      },
    );

    test(
      'pubKeyFromCertChain() - throws FormatException when the chain is not exactly one certificate',
      () async {
        await expectLater(
          () => pubKeyFromCertChain([]),
          throwsA(isA<FormatException>()),
        );
        await expectLater(
          () => pubKeyFromCertChain([Uint8List(0), Uint8List(0)]),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'pubKeyFromCertChain() - throws FormatException when the libp2p extension is missing '
      '(OID tampered on the ED25519 vector)',
      () async {
        // The libp2p extension OID 1.3.6.1.4.1.53594.1.1 DER-encodes as
        // 2b0601040183a25a0101; flipping its last byte makes it no longer
        // match extensionId, so the scan in pubKeyFromCertChain finds no
        // libp2p extension at all -- same observable failure as a
        // certificate that never carried the extension.
        final tampered = _ed25519VectorHex.replaceFirst(
          '2b0601040183a25a0101',
          '2b0601040183a25a0102',
        );
        expect(tampered, isNot(_ed25519VectorHex));
        await expectLater(
          () => pubKeyFromCertChain([_hexToBytes(tampered)]),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('expected certificate to contain the key extension'),
            ),
          ),
        );
      },
    );

    test('pubKeyFromCertChain() - throws FormatException when the embedded public key was swapped '
        'for a different key (wrong key)', () async {
      final signerKey = await generateEd25519KeyPair();
      final otherKey = await generateEd25519KeyPair();
      final result = await keyToCertificate(signerKey);

      final signerKeyBytes = marshalPublicKey(signerKey.getPublic());
      final otherKeyBytes = marshalPublicKey(otherKey.getPublic());
      expect(
        otherKeyBytes.length,
        signerKeyBytes.length,
        reason:
            'both Ed25519 keys marshal to the same byte length, so the swap keeps the DER well-formed',
      );

      final tampered = Uint8List.fromList(result.certificateDer);
      final at = _indexOfBytes(tampered, signerKeyBytes);
      expect(
        at,
        isNonNegative,
        reason:
            'the signer\'s marshaled public key must appear in the certificate DER',
      );
      tampered.setRange(at, at + signerKeyBytes.length, otherKeyBytes);

      await expectLater(
        () => pubKeyFromCertChain([tampered]),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('signature invalid'),
          ),
        ),
      );
    });
  });

  group('withCertTemplate [Atomic Audit]', () {
    test('withCertTemplate() - configures certificate template option', () {
      final opt = withCertTemplate('test-template');
      final cfg = IdentityConfig();
      opt(cfg);
      expect(cfg.certTemplate, equals('test-template'));
    });
  });

  group('withKeyLogWriter [Atomic Audit]', () {
    test('withKeyLogWriter() - configures key log writer option', () {
      final opt = withKeyLogWriter('test-writer');
      final cfg = IdentityConfig();
      opt(cfg);
      expect(cfg.keyLogWriter, equals('test-writer'));
    });
  });

  group('Identity [Atomic Audit]', () {
    test('newIdentity() - creates an identity with options', () async {
      final idKey = await generateEd25519KeyPair();
      final identity = await Identity.newIdentity(idKey, [
        withCertTemplate('dummy-template'),
      ]);
      expect(identity.privKey, same(idKey));
      expect(identity.config?.certTemplate, equals('dummy-template'));
    });

    test(
      'getCertificate() - returns valid certificate and caches it',
      () async {
        final idKey = await generateEd25519KeyPair();
        final identity = await Identity.newIdentity(idKey);
        final cert1 = await identity.getCertificate();
        final cert2 = await identity.getCertificate();
        expect(cert1.certificateDer, isNotEmpty);
        expect(cert1.privateKey, isNotNull);
        expect(cert1, equals(cert2));
      },
    );

    test('configForPeer() - returns remote peer identifier', () async {
      final idKey = await generateEd25519KeyPair();
      final identity = await Identity.newIdentity(idKey);
      final peer = PeerId.fromPubKey(idKey.getPublic());
      expect(identity.configForPeer(peer), equals(peer));
    });
  });

  group('TlsTransport [Atomic Audit]', () {
    test('id() - returns standard tls protocol identifier', () async {
      final idKey = await generateEd25519KeyPair();
      final transport = TlsTransport(privKey: idKey);
      expect(transport.id(), equals('/tls/1.0.0'));
    });

    test('secureOutbound() - completes TLS handshake outbound', () async {
      final clientKey = await generateEd25519KeyPair();
      final serverKey = await generateEd25519KeyPair();
      final clientPeer = PeerId.fromPubKey(clientKey.getPublic());
      final serverPeer = PeerId.fromPubKey(serverKey.getPublic());

      final clientTransport = TlsTransport(privKey: clientKey);
      final serverTransport = TlsTransport(privKey: serverKey);

      final (clientRaw, serverRaw) = _createDuplexPipePair();

      final results = await Future.wait([
        clientTransport.secureOutbound(clientRaw, serverPeer),
        serverTransport.secureInbound(serverRaw, clientPeer),
      ]);

      final clientConn = results[0];
      final serverConn = results[1];

      expect(clientConn.localPeer(), equals(clientPeer));
      expect(clientConn.remotePeer(), equals(serverPeer));

      final clientMsg = utf8.encode('ping from client');
      await clientConn.write(Uint8List.fromList(clientMsg));
      final receivedByServer = await serverConn.read();
      expect(utf8.decode(receivedByServer), equals('ping from client'));

      await clientConn.close();
      await serverConn.close();
    });

    test('secureInbound() - completes TLS handshake inbound', () async {
      final clientKey = await generateEd25519KeyPair();
      final serverKey = await generateEd25519KeyPair();
      final clientPeer = PeerId.fromPubKey(clientKey.getPublic());
      final serverPeer = PeerId.fromPubKey(serverKey.getPublic());

      final clientTransport = TlsTransport(privKey: clientKey);
      final serverTransport = TlsTransport(privKey: serverKey);

      final (clientRaw, serverRaw) = _createDuplexPipePair();

      final results = await Future.wait([
        clientTransport.secureOutbound(clientRaw, serverPeer),
        serverTransport.secureInbound(serverRaw, clientPeer),
      ]);

      final clientConn = results[0];
      final serverConn = results[1];

      expect(serverConn.localPeer(), equals(serverPeer));
      expect(serverConn.remotePeer(), equals(clientPeer));

      final serverMsg = utf8.encode('pong from server');
      await serverConn.write(Uint8List.fromList(serverMsg));
      final receivedByClient = await clientConn.read();
      expect(utf8.decode(receivedByClient), equals('pong from server'));

      await clientConn.close();
      await serverConn.close();
    });
  });
}

Uint8List _hexToBytes(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

int _indexOfBytes(Uint8List haystack, Uint8List needle) {
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}

// go-libp2p p2p/security/tls/crypto_test.go's TestVectors, "ED25519 Peer ID".
const _ed25519VectorHex =
    '308201ae30820156a0030201020204499602d2300a06082a8648ce3d040302302031123010060355'
    '040a13096c69627032702e696f310a300806035504051301313020170d3735303130313133303030'
    '305a180f34303936303130313133303030305a302031123010060355040a13096c69627032702e69'
    '6f310a300806035504051301313059301306072a8648ce3d020106082a8648ce3d0301070342000'
    '40c901d423c831ca85e27c73c263ba132721bb9d7a84c4f0380b2a6756fd601331c8870234dec878'
    '504c174144fa4b14b66a651691606d8173e55bd37e381569ea37c307a3078060a2b0601040183a25'
    'a0101046a3068042408011220a77f1d92fedb59dddaea5a1c4abd1ac2fbde7d7b879ed364501809923'
    'd7c11b90440d90d2769db992d5e6195dbb08e706b6651e024fda6cfb8846694a435519941cac215a8'
    '207792e42849cccc6cd8136c6e4bde92a58c5e08cfd4206eb5fe0bf909300a06082a8648ce3d04030'
    '20346003043021f50f6b6c52711a881778718238f650c9fb48943ae6ee6d28427dc6071ae55e70220'
    '3625f116a7a454db9c56986c82a25682f7248ea1cb764d322ea983ed36a31b77';

// go-libp2p p2p/security/tls/crypto_test.go's TestVectors, "ECDSA Peer ID".
const _ecdsaVectorHex =
    '308201f63082019da0030201020204499602d2300a06082a8648ce3d040302302031123010060355'
    '040a13096c69627032702e696f310a300806035504051301313020170d3735303130313133303030'
    '305a180f34303936303130313133303030305a302031123010060355040a13096c69627032702e69'
    '6f310a300806035504051301313059301306072a8648ce3d020106082a8648ce3d0301070342000'
    '40c901d423c831ca85e27c73c263ba132721bb9d7a84c4f0380b2a6756fd601331c8870234dec878'
    '504c174144fa4b14b66a651691606d8173e55bd37e381569ea381c23081bf3081bc060a2b0601040'
    '183a25a01010481ad3081aa045f0803125b3059301306072a8648ce3d020106082a8648ce3d03010'
    '703420004bf30511f909414ebdd3242178fd290f093a551cf75c973155de0bb5a96fedf6cb5d52da'
    '7563e794b512f66e60c7f55ba8a3acf3dd72a801980d205e8a1ad29f2044730450220064ea812477'
    '4caf8f50e57f436aa62350ce652418c019df5d98a3ac666c9386a022100aa59d704a931b5f72fb92'
    '22cb6cc51f954d04a4e2e5450f8805fe8918f71eaae300a06082a8648ce3d04030203470030440220'
    '799395b0b6c1e940a7e4484705f610ab51ed376f19ff9d7c16757cfbf61b8d4302206205c03fbb0f9'
    '5205c779be86581d3e31c01871ad5d1f3435bcf375cb0e5088a';

// go-libp2p p2p/security/tls/crypto_test.go's TestVectors, "secp256k1 Peer ID".
const _secp256k1VectorHex =
    '308201ba3082015fa0030201020204499602d2300a06082a8648ce3d040302302031123010060355'
    '040a13096c69627032702e696f310a300806035504051301313020170d3735303130313133303030'
    '305a180f34303936303130313133303030305a302031123010060355040a13096c69627032702e69'
    '6f310a300806035504051301313059301306072a8648ce3d020106082a8648ce3d0301070342000'
    '40c901d423c831ca85e27c73c263ba132721bb9d7a84c4f0380b2a6756fd601331c8870234dec878'
    '504c174144fa4b14b66a651691606d8173e55bd37e381569ea38184308181307f060a2b060104018'
    '3a25a01010471306f0425080212210206dc6968726765b820f050263ececf7f71e4955892776c097'
    '0542efd689d2382044630440220145e15a991961f0d08cd15425bb95ec93f6ffa03c5a385eedc34e'
    'cf464c7a8ab022026b3109b8a3f40ef833169777eb2aa337cfb6282f188de0666d1bcec2a4690dd3'
    '00a06082a8648ce3d0403020349003046022100e1a217eeef9ec9204b3f774a08b70849646b6a1e6'
    'b8b27f93dc00ed58545d9fe022100b00dafa549d0f03547878338c7b15e7502888f6d45db387e5ae'
    '6b5d46899cef0';

// go-libp2p p2p/security/tls/crypto_test.go's TestVectors, "Invalid certificate"
// (same shape as the ECDSA vector, but its extension signature was tampered).
const _invalidSignatureVectorHex =
    '308201f73082019da0030201020204499602d2300a06082a8648ce3d040302302031123010060355'
    '040a13096c69627032702e696f310a300806035504051301313020170d3735303130313133303030'
    '305a180f34303936303130313133303030305a302031123010060355040a13096c69627032702e69'
    '6f310a300806035504051301313059301306072a8648ce3d020106082a8648ce3d0301070342000'
    '40c901d423c831ca85e27c73c263ba132721bb9d7a84c4f0380b2a6756fd601331c8870234dec878'
    '504c174144fa4b14b66a651691606d8173e55bd37e381569ea381c23081bf3081bc060a2b0601040'
    '183a25a01010481ad3081aa045f0803125b3059301306072a8648ce3d020106082a8648ce3d03010'
    '703420004bf30511f909414ebdd3242178fd290f093a551cf75c973155de0bb5a96fedf6cb5d52da'
    '7563e794b512f66e60c7f55ba8a3acf3dd72a801980d205e8a1ad29f204473045022100bb6e03577'
    'b7cc7a3cd1558df0da2b117dfdcc0399bc2504ebe7de6f65cade72802206de96e2a5be9b6202adba2'
    '4ee0362e490641ac45c240db71fe955f2c5cf8df6e300a06082a8648ce3d0403020348003045022100'
    'e847f267f43717358f850355bdcabbefb2cfbf8a3c043b203a14788a092fe8db022027c1d04a2d41f'
    'd6b57a7e8b3989e470325de4406e52e084e34a3fd56eef0d0df';

class _DuplexPipeConn implements RawConn {
  _DuplexPipeConn({required this.localAddr, required this.remoteAddr});

  final Multiaddr localAddr;
  final Multiaddr remoteAddr;
  late final _DuplexPipeConn other;

  final List<int> _incoming = [];
  Completer<void>? _readCompleter;
  bool _closed = false;

  void _receive(Uint8List bytes) {
    if (_closed) return;
    _incoming.addAll(bytes);
    if (_readCompleter != null && !_readCompleter!.isCompleted) {
      _readCompleter!.complete();
    }
  }

  @override
  Multiaddr localMultiaddr() => localAddr;

  @override
  Multiaddr remoteMultiaddr() => remoteAddr;

  @override
  Transport transport() => throw UnimplementedError();

  @override
  bool get isClosed => _closed;

  @override
  Future<void> close() async {
    _closed = true;
    if (_readCompleter != null && !_readCompleter!.isCompleted) {
      _readCompleter!.complete();
    }
  }

  @override
  Future<Uint8List> read([int? maxLength]) async {
    while (_incoming.isEmpty) {
      if (_closed) return Uint8List(0);
      _readCompleter = Completer<void>();
      await _readCompleter!.future;
    }
    final len = maxLength != null
        ? math.min(maxLength, _incoming.length)
        : _incoming.length;
    final res = Uint8List.fromList(_incoming.sublist(0, len));
    _incoming.removeRange(0, len);
    return res;
  }

  @override
  Future<void> write(Uint8List data) async {
    if (_closed) throw StateError('closed');
    other._receive(data);
  }
}

(RawConn, RawConn) _createDuplexPipePair() {
  final a1 = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
  final a2 = Multiaddr.parse('/ip4/127.0.0.1/tcp/4002');
  final c1 = _DuplexPipeConn(localAddr: a1, remoteAddr: a2);
  final c2 = _DuplexPipeConn(localAddr: a2, remoteAddr: a1);
  c1.other = c2;
  c2.other = c1;
  return (c1, c2);
}
