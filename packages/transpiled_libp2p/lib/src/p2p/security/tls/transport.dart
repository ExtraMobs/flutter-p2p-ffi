// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto_pkg;
import 'package:pointycastle/asn1.dart';
import 'package:transpiled_crypto_tls/transpiled_crypto_tls.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/crypto/ecdsa_key.dart';
import '../../../core/crypto/key_types.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/peer_id.dart';
import '../../../core/sec/security.dart';
import '../../../core/transport/transport.dart';
import 'crypto.dart';

/// Multistream protocol ID for TLS 1.3 security.
const String id = '/tls/1.0.0';

/// Multistream protocol ID for TLS 1.3 security.
const String tlsProtocolId = id;

/// `CurveID` for X25519 (`common.go`, RFC 8446 Section 4.2.7).
const int _x25519Group = 0x001d;

/// `pskModeDHE` (`common.go`): PSK with (EC)DHE key establishment.
const int _pskModeDhe = 1;

/// TLS configuration for an identity.
class IdentityConfig {
  IdentityConfig({this.certTemplate, this.keyLogWriter});

  dynamic certTemplate;
  dynamic keyLogWriter;
}

typedef IdentityOption = void Function(IdentityConfig config);

/// WithCertTemplate specifies the template to use when generating a new certificate.
IdentityOption withCertTemplate(dynamic template) {
  return (IdentityConfig config) {
    config.certTemplate = template;
  };
}

/// WithKeyLogWriter optionally specifies a destination for TLS master secrets.
IdentityOption withKeyLogWriter(dynamic writer) {
  return (IdentityConfig config) {
    config.keyLogWriter = writer;
  };
}

/// Identity is used to secure connections with TLS 1.3.
class Identity {
  Identity({required this.privKey, this.config});

  final PrivKey privKey;
  final IdentityConfig? config;
  ({Uint8List certificateDer, EcdsaPrivateKey privateKey})? _cert;

  /// Creates a new identity with the given private key and options.
  static Future<Identity> newIdentity(
    PrivKey privKey, [
    List<IdentityOption>? options,
  ]) async {
    final cfg = IdentityConfig();
    if (options != null) {
      for (final opt in options) {
        opt(cfg);
      }
    }
    final id = Identity(privKey: privKey, config: cfg);
    await id.getCertificate();
    return id;
  }

  /// Returns the cached certificate or generates a new one.
  Future<({Uint8List certificateDer, EcdsaPrivateKey privateKey})>
  getCertificate() async {
    return _cert ??= await keyToCertificate(privKey);
  }

  /// Configures single-use TLS verification for [remote].
  PeerId configForPeer(PeerId remote) => remote;
}

/// TLS 1.3 security transport for libp2p.
class TlsTransport implements SecureTransport {
  TlsTransport({
    required this.privKey,
    this.muxers = const ['/yamux/1.0.0'],
    this.protocolId = tlsProtocolId,
    Identity? identity,
  }) : localPeer = PeerId.fromPubKey(privKey.getPublic()),
       _identity = identity ?? Identity(privKey: privKey);

  final PrivKey privKey;
  final PeerId localPeer;
  final List<String> muxers;
  final String protocolId;
  final Identity _identity;

  @override
  String id() => protocolId;

  @override
  Future<SecureConn> secureOutbound(RawConn insecure, PeerId peer) async {
    return _handshake(insecure, peer, isClient: true);
  }

  @override
  Future<SecureConn> secureInbound(RawConn insecure, PeerId peer) async {
    return _handshake(insecure, peer, isClient: false);
  }

  Future<SecureConn> _handshake(
    RawConn insecure,
    PeerId peer, {
    required bool isClient,
  }) async {
    final cert = await _identity.getCertificate();
    final recordReader = _TlsRecordReader(insecure);
    final x25519 = crypto_pkg.X25519();
    final rng = Random.secure();

    if (isClient) {
      // 1. Client creates and sends ClientHello
      final clientKeyPair = await x25519.newKeyPair();
      final clientPub = await clientKeyPair.extractPublicKey();
      final clientPubBytes = Uint8List.fromList(clientPub.bytes);

      final clientRandom = Uint8List(32);
      final sessionId = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        clientRandom[i] = rng.nextInt(256);
        sessionId[i] = rng.nextInt(256);
      }

      final ch = ClientHelloMsg(
        vers: versionTls12,
        random: clientRandom,
        sessionId: sessionId,
        cipherSuites: const [
          tlsAes128GcmSha256,
          tlsChacha20Poly1305Sha256,
          tlsAes256GcmSha384,
        ],
        compressionMethods: Uint8List.fromList(const [0]),
        keyShares: [KeyShare(group: _x25519Group, data: clientPubBytes)],
        // supported_groups is mandatory alongside key_share: Go's
        // `negotiateGroup` intersects it with the server preferences and
        // aborts with alertHandshakeFailure when the client sends none.
        supportedCurves: const [_x25519Group],
        pskModes: Uint8List.fromList(const [_pskModeDhe]),
        supportedVersions: const [versionTls13],
        supportedSignatureAlgorithms: const [0x0403, 0x0807, 0x0804],
        alpnProtocols: [for (final m in muxers) m, 'libp2p'],
      );
      final chBytes = ch.marshal();

      final clientOutUnprotected = HalfConn();
      final chRecords = writeTls13Records(
        clientOutUnprotected,
        recordTypeHandshake,
        chBytes,
        version: versionTls10,
      );
      for (final r in chRecords) {
        await insecure.write(r);
      }

      // 2. Client receives ServerHello
      final shRecord = await recordReader.readRecord();
      final shDecoded = readTls13Record(
        clientOutUnprotected,
        shRecord,
        expectedVersion: null,
      );
      _throwIfAlert(shDecoded.recordType, shDecoded.data);
      if (shDecoded.recordType != recordTypeHandshake) {
        throw FormatException(
          'expected handshake record for ServerHello, got ${shDecoded.recordType}',
        );
      }
      final sh = ServerHelloMsg.unmarshal(shDecoded.data);
      final suite =
          cipherSuiteTls13ById(sh.cipherSuite) ?? cipherSuitesTls13[0];

      // 3. Compute shared secret and key schedule
      final serverShare = sh.serverShare;
      if (serverShare == null) {
        throw const FormatException('missing server key share');
      }
      final sharedSecret = await x25519.sharedSecretKey(
        keyPair: clientKeyPair,
        remotePublicKey: crypto_pkg.SimplePublicKey(
          serverShare.data,
          type: crypto_pkg.KeyPairType.x25519,
        ),
      );
      final sharedSecretBytes = Uint8List.fromList(
        await sharedSecret.extractBytes(),
      );

      final transcript = HandshakeTranscript(suite.hash);
      transcript.write(chBytes);
      // The transcript hash is over the bytes actually on the wire. Hashing a
      // re-serialization of the parsed ServerHello silently diverges whenever
      // the peer ordered or included extensions differently, and the first
      // symptom is an undecryptable handshake record.
      transcript.write(shDecoded.data);

      final earlySecret = EarlySecret(suite.hash, null);
      final handshakeSecret = earlySecret.handshakeSecret(sharedSecretBytes);
      final clientHsSecret = handshakeSecret.clientHandshakeTrafficSecret(
        transcript,
      );
      final serverHsSecret = handshakeSecret.serverHandshakeTrafficSecret(
        transcript,
      );

      final clientHsIn = HalfConn()
        ..version = versionTls13
        ..setTrafficSecret(suite, serverHsSecret);
      final clientHsOut = HalfConn()
        ..version = versionTls13
        ..setTrafficSecret(suite, clientHsSecret);

      // 4. Client reads Server Flight: EncryptedExtensions, CertificateRequest, Certificate, CertificateVerify, Finished
      final hsReader = _HandshakeReader(recordReader, clientHsIn);

      // EncryptedExtensions
      final eeBytes = await hsReader.readMessage();
      final ee = EncryptedExtensionsMsg.unmarshal(eeBytes);
      transcript.write(eeBytes);

      // CertificateRequest
      final crBytes = await hsReader.readMessage();
      transcript.write(crBytes);

      // Certificate
      final scBytes = await hsReader.readMessage();
      final serverCertMsg = CertificateMsgTls13.unmarshal(scBytes);
      transcript.write(scBytes);

      if (serverCertMsg.certificateChain.isEmpty) {
        throw const FormatException('server sent empty certificate chain');
      }
      final serverPubKey = await pubKeyFromCertChain(
        serverCertMsg.certificateChain,
      );
      if (peer.value.isNotEmpty && !peer.matchesPublicKey(serverPubKey)) {
        final actualPeer = PeerId.fromPubKey(serverPubKey);
        throw PeerIdMismatchException(expected: peer, actual: actualPeer);
      }

      // CertificateVerify
      final scvBytes = await hsReader.readMessage();
      final serverCv = CertificateVerifyMsg.unmarshal(scvBytes);
      final serverVerifyPayload = Uint8List.fromList([
        ...List.filled(64, 0x20),
        ...utf8.encode('TLS 1.3, server CertificateVerify'),
        0x00,
        ...transcript.sum(),
      ]);
      final serverEcdsaPub = _extractEcdsaPubFromCert(
        serverCertMsg.certificateChain.first,
      );
      final serverSigValid = await serverEcdsaPub.verify(
        serverVerifyPayload,
        serverCv.signature,
      );
      if (!serverSigValid) {
        throw const FormatException(
          'server CertificateVerify signature invalid',
        );
      }
      transcript.write(scvBytes);

      // Finished
      final sfBytes = await hsReader.readMessage();
      final serverFinished = FinishedMsg.unmarshal(sfBytes);
      final expectedServerVerifyData = suite.finishedHash(
        serverHsSecret,
        transcript,
      );
      if (!_bytesEqual(serverFinished.verifyData, expectedServerVerifyData)) {
        throw const FormatException('server Finished verify_data mismatch');
      }
      transcript.write(sfBytes);

      // RFC 8446 Section 7.1: the application traffic secrets are derived from
      // the transcript "ClientHello..server Finished". Deriving them after the
      // client flight has been appended produces keys the peer never computes,
      // and the handshake still completes -- the first application record is
      // what fails, as a bad record MAC.
      final masterSecret = handshakeSecret.masterSecret();
      final clientAppSecret = masterSecret.clientApplicationTrafficSecret(
        transcript,
      );
      final serverAppSecret = masterSecret.serverApplicationTrafficSecret(
        transcript,
      );

      // 5. Client sends Client Flight: Certificate, CertificateVerify, Finished
      final clientCertMsg = CertificateMsgTls13(
        certificateChain: [cert.certificateDer],
      );
      final ccBytes = clientCertMsg.marshal();
      transcript.write(ccBytes);

      final clientVerifyPayload = Uint8List.fromList([
        ...List.filled(64, 0x20),
        ...utf8.encode('TLS 1.3, client CertificateVerify'),
        0x00,
        ...transcript.sum(),
      ]);
      final clientSig = await cert.privateKey.sign(clientVerifyPayload);
      final clientCv = CertificateVerifyMsg(
        hasSignatureAlgorithm: true,
        signatureAlgorithm: 0x0403,
        signature: clientSig,
      );
      final ccvBytes = clientCv.marshal();
      transcript.write(ccvBytes);

      final clientVerifyData = suite.finishedHash(clientHsSecret, transcript);
      final clientFinished = FinishedMsg(verifyData: clientVerifyData);
      final cfBytes = clientFinished.marshal();
      transcript.write(cfBytes);

      final clientFlight = Uint8List.fromList([
        ...ccBytes,
        ...ccvBytes,
        ...cfBytes,
      ]);
      final clientEncryptedRecords = writeTls13Records(
        clientHsOut,
        recordTypeHandshake,
        clientFlight,
        version: versionTls13,
      );
      for (final r in clientEncryptedRecords) {
        await insecure.write(r);
      }

      // 6. Transition to Application Secrets
      final clientAppIn = HalfConn()
        ..version = versionTls13
        ..setTrafficSecret(suite, serverAppSecret);
      final clientAppOut = HalfConn()
        ..version = versionTls13
        ..setTrafficSecret(suite, clientAppSecret);

      final negotiatedMuxer =
          ee.alpnProtocol.isNotEmpty && ee.alpnProtocol != 'libp2p'
          ? ee.alpnProtocol
          : (muxers.isNotEmpty ? muxers.first : '/yamux/1.0.0');

      return _TlsConn(
        rawConn: insecure,
        localPeer: localPeer,
        remotePeer: PeerId.fromPubKey(serverPubKey),
        remotePubKey: serverPubKey,
        connectionState: ConnectionState(
          streamMultiplexer: negotiatedMuxer,
          security: protocolId,
          transport: 'tcp',
          usedEarlyMuxerNegotiation:
              ee.alpnProtocol.isNotEmpty && ee.alpnProtocol != 'libp2p',
        ),
        inHalfConn: clientAppIn,
        outHalfConn: clientAppOut,
        recordReader: recordReader,
      );
    } else {
      // 1. Server receives ClientHello
      final chRecord = await recordReader.readRecord();
      final chDecoded = readTls13Record(
        HalfConn(),
        chRecord,
        expectedVersion: null,
      );
      _throwIfAlert(chDecoded.recordType, chDecoded.data);
      if (chDecoded.recordType != recordTypeHandshake) {
        throw FormatException(
          'expected handshake record for ClientHello, got ${chDecoded.recordType}',
        );
      }
      final ch = ClientHelloMsg.unmarshal(chDecoded.data);

      CipherSuiteTls13? chosenSuite;
      for (final sId in ch.cipherSuites) {
        final candidate = cipherSuiteTls13ById(sId);
        if (candidate != null) {
          chosenSuite = candidate;
          break;
        }
      }
      final suite = chosenSuite ?? cipherSuitesTls13[0];

      // ALPN selection: prefer client preference that matches server muxers
      var negotiatedAlpn = 'libp2p';
      for (final proto in ch.alpnProtocols) {
        if (muxers.contains(proto)) {
          negotiatedAlpn = proto;
          break;
        }
      }

      // 2. Server generates ephemeral key and ServerHello
      final serverKeyPair = await x25519.newKeyPair();
      final serverPub = await serverKeyPair.extractPublicKey();
      final serverPubBytes = Uint8List.fromList(serverPub.bytes);

      final serverRandom = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        serverRandom[i] = rng.nextInt(256);
      }

      final sh = ServerHelloMsg(
        vers: versionTls12,
        random: serverRandom,
        sessionId: ch.sessionId,
        cipherSuite: suite.id,
        supportedVersion: versionTls13,
        serverShare: KeyShare(group: _x25519Group, data: serverPubBytes),
      );
      final shBytes = sh.marshal();

      final serverOutUnprotected = HalfConn();
      final shRecords = writeTls13Records(
        serverOutUnprotected,
        recordTypeHandshake,
        shBytes,
        version: versionTls12,
      );
      for (final r in shRecords) {
        await insecure.write(r);
      }

      // 3. Compute shared secret and key schedule
      KeyShare? clientShare;
      for (final ks in ch.keyShares) {
        if (ks.group == _x25519Group) {
          clientShare = ks;
          break;
        }
      }
      if (clientShare == null) {
        throw const FormatException('client did not provide X25519 key share');
      }
      final sharedSecret = await x25519.sharedSecretKey(
        keyPair: serverKeyPair,
        remotePublicKey: crypto_pkg.SimplePublicKey(
          clientShare.data,
          type: crypto_pkg.KeyPairType.x25519,
        ),
      );
      final sharedSecretBytes = Uint8List.fromList(
        await sharedSecret.extractBytes(),
      );

      final transcript = HandshakeTranscript(suite.hash);
      transcript.write(chDecoded.data);
      transcript.write(shBytes);

      final earlySecret = EarlySecret(suite.hash, null);
      final handshakeSecret = earlySecret.handshakeSecret(sharedSecretBytes);
      final clientHsSecret = handshakeSecret.clientHandshakeTrafficSecret(
        transcript,
      );
      final serverHsSecret = handshakeSecret.serverHandshakeTrafficSecret(
        transcript,
      );

      final serverHsOut = HalfConn()
        ..version = versionTls13
        ..setTrafficSecret(suite, serverHsSecret);
      final serverHsIn = HalfConn()
        ..version = versionTls13
        ..setTrafficSecret(suite, clientHsSecret);

      // 4. Server sends Server Flight: EncryptedExtensions, CertificateRequest, Certificate, CertificateVerify, Finished
      final ee = EncryptedExtensionsMsg(alpnProtocol: negotiatedAlpn);
      final eeBytes = ee.marshal();
      transcript.write(eeBytes);

      final cr = CertificateRequestMsgTls13(
        supportedSignatureAlgorithms: const [0x0403, 0x0807, 0x0804],
      );
      final crBytes = cr.marshal();
      transcript.write(crBytes);

      final serverCertMsg = CertificateMsgTls13(
        certificateChain: [cert.certificateDer],
      );
      final scBytes = serverCertMsg.marshal();
      transcript.write(scBytes);

      final serverVerifyPayload = Uint8List.fromList([
        ...List.filled(64, 0x20),
        ...utf8.encode('TLS 1.3, server CertificateVerify'),
        0x00,
        ...transcript.sum(),
      ]);
      final serverSig = await cert.privateKey.sign(serverVerifyPayload);
      final serverCv = CertificateVerifyMsg(
        hasSignatureAlgorithm: true,
        signatureAlgorithm: 0x0403,
        signature: serverSig,
      );
      final scvBytes = serverCv.marshal();
      transcript.write(scvBytes);

      final serverVerifyData = suite.finishedHash(serverHsSecret, transcript);
      final serverFinished = FinishedMsg(verifyData: serverVerifyData);
      final sfBytes = serverFinished.marshal();
      transcript.write(sfBytes);

      // Same RFC 8446 Section 7.1 boundary as on the client: the transcript
      // stops at the server Finished, before the client flight arrives.
      final masterSecret = handshakeSecret.masterSecret();
      final clientAppSecret = masterSecret.clientApplicationTrafficSecret(
        transcript,
      );
      final serverAppSecret = masterSecret.serverApplicationTrafficSecret(
        transcript,
      );

      final serverFlight = Uint8List.fromList([
        ...eeBytes,
        ...crBytes,
        ...scBytes,
        ...scvBytes,
        ...sfBytes,
      ]);
      final serverEncryptedRecords = writeTls13Records(
        serverHsOut,
        recordTypeHandshake,
        serverFlight,
        version: versionTls13,
      );
      for (final r in serverEncryptedRecords) {
        await insecure.write(r);
      }

      // 5. Server receives Client Flight: Certificate, CertificateVerify, Finished
      final hsReader = _HandshakeReader(recordReader, serverHsIn);

      // Client Certificate
      final ccBytes = await hsReader.readMessage();
      final clientCertMsg = CertificateMsgTls13.unmarshal(ccBytes);
      transcript.write(ccBytes);

      if (clientCertMsg.certificateChain.isEmpty) {
        throw const FormatException('client sent empty certificate chain');
      }
      final clientPubKey = await pubKeyFromCertChain(
        clientCertMsg.certificateChain,
      );
      if (peer.value.isNotEmpty && !peer.matchesPublicKey(clientPubKey)) {
        final actualPeer = PeerId.fromPubKey(clientPubKey);
        throw PeerIdMismatchException(expected: peer, actual: actualPeer);
      }

      // Client CertificateVerify
      final ccvBytes = await hsReader.readMessage();
      final clientCv = CertificateVerifyMsg.unmarshal(ccvBytes);
      final clientVerifyPayload = Uint8List.fromList([
        ...List.filled(64, 0x20),
        ...utf8.encode('TLS 1.3, client CertificateVerify'),
        0x00,
        ...transcript.sum(),
      ]);
      final clientEcdsaPub = _extractEcdsaPubFromCert(
        clientCertMsg.certificateChain.first,
      );
      final clientSigValid = await clientEcdsaPub.verify(
        clientVerifyPayload,
        clientCv.signature,
      );
      if (!clientSigValid) {
        throw const FormatException(
          'client CertificateVerify signature invalid',
        );
      }
      transcript.write(ccvBytes);

      // Client Finished
      final cfBytes = await hsReader.readMessage();
      final clientFinished = FinishedMsg.unmarshal(cfBytes);
      final expectedClientVerifyData = suite.finishedHash(
        clientHsSecret,
        transcript,
      );
      if (!_bytesEqual(clientFinished.verifyData, expectedClientVerifyData)) {
        throw const FormatException('client Finished verify_data mismatch');
      }
      transcript.write(cfBytes);

      // 6. Transition to Application Secrets
      final serverAppIn = HalfConn()
        ..version = versionTls13
        ..setTrafficSecret(suite, clientAppSecret);
      final serverAppOut = HalfConn()
        ..version = versionTls13
        ..setTrafficSecret(suite, serverAppSecret);

      return _TlsConn(
        rawConn: insecure,
        localPeer: localPeer,
        remotePeer: PeerId.fromPubKey(clientPubKey),
        remotePubKey: clientPubKey,
        connectionState: ConnectionState(
          streamMultiplexer: negotiatedAlpn != 'libp2p'
              ? negotiatedAlpn
              : (muxers.isNotEmpty ? muxers.first : '/yamux/1.0.0'),
          security: protocolId,
          transport: 'tcp',
          usedEarlyMuxerNegotiation: negotiatedAlpn != 'libp2p',
        ),
        inHalfConn: serverAppIn,
        outHalfConn: serverAppOut,
        recordReader: recordReader,
      );
    }
  }
}

/// Raises the peer's alert instead of a record-type complaint.
///
/// Go's `Conn.readRecord` turns an incoming alert record into the alert
/// itself (`conn.go`, `recordTypeAlert` branch); reporting only "unexpected
/// record type 21" hides the one byte that says why the peer refused.
void _throwIfAlert(int recordType, Uint8List data) {
  if (recordType != recordTypeAlert) return;
  throw AlertException(data.length >= 2 ? data[1] : alertInternalError);
}

class _TlsRecordReader {
  _TlsRecordReader(this._conn);
  final RawConn _conn;
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  Future<Uint8List> readRecord() async {
    while (_buffer.length < 5) {
      final chunk = await _conn.read();
      if (chunk.isEmpty)
        throw StateError('EOF while reading TLS record header');
      _buffer.add(chunk);
    }
    final bytes = _buffer.toBytes();
    final length = (bytes[3] << 8) | bytes[4];
    final totalRecordLen = 5 + length;
    while (_buffer.length < totalRecordLen) {
      final chunk = await _conn.read();
      if (chunk.isEmpty)
        throw StateError('EOF while reading TLS record payload');
      _buffer.add(chunk);
    }
    final fullBuf = _buffer.takeBytes();
    final record = Uint8List.sublistView(fullBuf, 0, totalRecordLen);
    if (fullBuf.length > totalRecordLen) {
      _buffer.add(Uint8List.sublistView(fullBuf, totalRecordLen));
    }
    return record;
  }
}

class _HandshakeReader {
  _HandshakeReader(this._recordReader, this._halfConn);
  final _TlsRecordReader _recordReader;
  final HalfConn _halfConn;
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  Future<Uint8List> readMessage() async {
    while (_buffer.length < 4 || _buffer.length < (4 + _peekMsgLen())) {
      final record = await _recordReader.readRecord();
      // Go's `Conn.readRecord` inspects the OUTER content type and drops a
      // middlebox-compatibility ChangeCipherSpec before any decryption
      // (`conn.go`, recordTypeChangeCipherSpec branch). Feeding that cleartext
      // record to the AEAD instead fails it as a bad record MAC, which is what
      // a real go-libp2p peer's flight triggers right after ServerHello.
      if (record.isNotEmpty && record[0] == recordTypeChangeCipherSpec) {
        continue;
      }
      final decrypted = readTls13Record(
        _halfConn,
        record,
        expectedVersion: _halfConn.version == 0 ? null : versionTls13,
      );
      if (decrypted.recordType == recordTypeChangeCipherSpec) {
        continue;
      }
      _throwIfAlert(decrypted.recordType, decrypted.data);
      if (decrypted.recordType != recordTypeHandshake) {
        throw FormatException(
          'unexpected TLS record type: ${decrypted.recordType}',
        );
      }
      _buffer.add(decrypted.data);
    }
    final msgLen = _peekMsgLen();
    final totalLen = 4 + msgLen;
    final allBytes = _buffer.takeBytes();
    final msgBytes = Uint8List.sublistView(allBytes, 0, totalLen);
    if (allBytes.length > totalLen) {
      _buffer.add(Uint8List.sublistView(allBytes, totalLen));
    }
    return msgBytes;
  }

  int _peekMsgLen() {
    final b = _buffer.toBytes();
    return (b[1] << 16) | (b[2] << 8) | b[3];
  }
}

EcdsaPublicKey _extractEcdsaPubFromCert(Uint8List certDer) {
  final certSeq = ASN1Sequence.fromBytes(certDer);
  final certElements = certSeq.elements!;
  final tbsElements = (certElements[0] as ASN1Sequence).elements!;
  var idx = 0;
  if (tbsElements.isNotEmpty && tbsElements[0].tag == 0xA0) {
    idx = 1;
  }
  final subjectPublicKeyInfoElement = tbsElements[idx + 5];
  return unmarshalEcdsaPublicKey(subjectPublicKeyInfoElement.encode());
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _TlsConn implements SecureConn {
  _TlsConn({
    required RawConn rawConn,
    required PeerId localPeer,
    required PeerId remotePeer,
    required PubKey remotePubKey,
    required ConnectionState connectionState,
    required HalfConn inHalfConn,
    required HalfConn outHalfConn,
    required _TlsRecordReader recordReader,
  }) : _rawConn = rawConn,
       _localPeer = localPeer,
       _remotePeer = remotePeer,
       _remotePubKey = remotePubKey,
       _connectionState = connectionState,
       _inHalfConn = inHalfConn,
       _outHalfConn = outHalfConn,
       _recordReader = recordReader;

  final RawConn _rawConn;
  final PeerId _localPeer;
  final PeerId _remotePeer;
  final PubKey _remotePubKey;
  final ConnectionState _connectionState;
  final HalfConn _inHalfConn;
  final HalfConn _outHalfConn;
  final _TlsRecordReader _recordReader;
  final BytesBuilder _readBuffer = BytesBuilder(copy: false);
  bool _closed = false;

  @override
  PeerId localPeer() => _localPeer;

  @override
  PeerId remotePeer() => _remotePeer;

  @override
  PubKey remotePublicKey() => _remotePubKey;

  @override
  ConnectionState connState() => _connectionState;

  @override
  Transport transport() => _rawConn.transport();

  @override
  Multiaddr localMultiaddr() => _rawConn.localMultiaddr();

  @override
  Multiaddr remoteMultiaddr() => _rawConn.remoteMultiaddr();

  @override
  bool get isClosed => _closed || _rawConn.isClosed;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _rawConn.close();
  }

  @override
  Future<void> write(Uint8List data) async {
    if (_closed) throw StateError('connection is closed');
    final records = writeTls13Records(
      _outHalfConn,
      recordTypeApplicationData,
      data,
      version: versionTls13,
    );
    for (final rec in records) {
      await _rawConn.write(rec);
    }
  }

  @override
  Future<Uint8List> read([int? maxLength]) async {
    if (_closed) return Uint8List(0);
    while (_readBuffer.isEmpty) {
      final record = await _recordReader.readRecord();
      final decrypted = readTls13Record(
        _inHalfConn,
        record,
        expectedVersion: versionTls13,
      );
      if (decrypted.recordType == recordTypeAlert) {
        await close();
        return Uint8List(0);
      }
      if (decrypted.recordType == recordTypeApplicationData) {
        _readBuffer.add(decrypted.data);
      }
    }
    final all = _readBuffer.takeBytes();
    if (maxLength == null || all.length <= maxLength) {
      return all;
    }
    final chunk = Uint8List.sublistView(all, 0, maxLength);
    _readBuffer.add(Uint8List.sublistView(all, maxLength));
    return chunk;
  }
}
