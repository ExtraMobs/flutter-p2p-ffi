// Port of the client half of `github.com/quic-go/quic-go`'s handshake
// (v0.60.0, revision 7612ad1036957cde45d672bebb8b9ec9c2e9b2a7):
// `client.go`'s `Dial`, the Initial/Handshake packet exchange in
// `connection.go`, and the TLS 1.3 drive in `internal/handshake`.
//
// The QUIC handshake *is* a TLS 1.3 handshake carried in CRYPTO frames, and
// the keys it derives are the keys that protect the packets (RFC 9001). What
// varies between the transports built on it is only the TLS configuration:
// libp2p's `/quic-v1` negotiates ALPN `libp2p` and authenticates the peer from
// a libp2p certificate extension, while `/quic-v1/webtransport` negotiates
// ALPN `h3` and authenticates the server by matching the SHA-256 of its leaf
// certificate against the multiaddr's `certhash` components. Both are
// expressed here as a [QuicTlsConfig], mirroring how Go passes a `tls.Config`.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto_pkg;
import 'package:transpiled_crypto_tls/transpiled_crypto_tls.dart';

import 'connection.dart';
import 'frames.dart';
import 'header.dart';
import 'initial_aead.dart';
import 'transport_parameters.dart';
import 'varint.dart';

/// Thrown when a QUIC handshake cannot be completed.
class HandshakeException implements Exception {
  /// Creates a [HandshakeException] describing why the handshake failed.
  const HandshakeException(this.message);

  /// A human readable description of the failure.
  final String message;

  @override
  String toString() => 'HandshakeException: $message';
}

/// The client certificate and signer offered when a server requests one,
/// mirroring one entry of Go's `tls.Config.Certificates`.
class QuicClientCertificate {
  /// Creates a [QuicClientCertificate] from its DER encoding and a signer.
  const QuicClientCertificate({
    required this.der,
    required this.sign,
    this.signatureAlgorithm = 0x0403,
  });

  /// The DER encoding of the leaf certificate.
  final Uint8List der;

  /// Produces the CertificateVerify signature over the handshake transcript.
  final Future<Uint8List> Function(Uint8List message) sign;

  /// The TLS `SignatureScheme` the signature uses; ECDSA P-256 with SHA-256
  /// (`ecdsa_secp256r1_sha256`) by default.
  final int signatureAlgorithm;
}

/// The TLS configuration for a QUIC client handshake, mirroring the subset of
/// Go's `tls.Config` that quic-go actually consumes.
class QuicTlsConfig {
  /// Creates a [QuicTlsConfig].
  ///
  /// [nextProtos] is the ALPN list; the handshake fails if the server selects
  /// something outside it. [verifyPeerCertificate] receives the server's DER
  /// certificate chain and must throw to reject it -- this is how a caller
  /// pins `certhash` values instead of trusting a CA. [certificate] is offered
  /// only if the server sends a CertificateRequest.
  const QuicTlsConfig({
    required this.nextProtos,
    this.verifyPeerCertificate,
    this.certificate,
    this.serverName,
  });

  /// The ALPN protocols to offer, most preferred first.
  final List<String> nextProtos;

  /// Validates the server's DER certificate chain, throwing to reject it.
  final Future<void> Function(List<Uint8List> derChain)? verifyPeerCertificate;

  /// The certificate to present if the server asks for client authentication.
  final QuicClientCertificate? certificate;

  /// The SNI server name to send, when the peer is addressed by name.
  final String? serverName;
}

/// Dials a QUIC server over [socket] and completes the handshake, returning an
/// established connection, per quic-go's `Dial`.
///
/// The socket is not closed on success -- the returned [QuicConn] owns it. On
/// failure the subscription this function created is cancelled but the socket
/// is left to the caller, matching Go's behaviour of not closing a
/// `net.PacketConn` it did not create.
Future<QuicConn> dial({
  required RawDatagramSocket socket,
  required InternetAddress remoteAddress,
  required int remotePort,
  required QuicTlsConfig tlsConfig,
  TransportParameters? transportParameters,
  bool enableDatagrams = false,
  Duration handshakeTimeout = const Duration(seconds: 10),
}) async {
  final rng = math.Random.secure();
  final destConnectionId = _randomBytes(rng, 8);
  final srcConnectionId = _randomBytes(rng, 8);

  final parameters =
      transportParameters ??
      TransportParameters(
        initialMaxData: 10485760,
        initialMaxStreamDataBidiLocal: 2097152,
        initialMaxStreamDataBidiRemote: 2097152,
        initialMaxStreamDataUni: 2097152,
        initialMaxStreamsBidi: 100,
        initialMaxStreamsUni: 100,
        maxIdleTimeout: const Duration(seconds: 30),
      );
  // RFC 9000 s. 7.3: the server aborts the handshake unless this matches the
  // Source Connection ID of the client's Initial, so it is stamped here
  // rather than left to a caller that cannot know the value.
  parameters.initialSourceConnectionId = srcConnectionId;
  if (enableDatagrams) {
    // Go: `connection.go`'s `params.MaxDatagramFrameSize = wire.MaxDatagramSize`
    // when `Config.EnableDatagrams` is set. Its mere presence is what tells the
    // peer datagrams are supported -- an HTTP/3 server refuses a WebTransport
    // session whose client did not.
    parameters.maxDatagramFrameSize = maxDatagramSize;
  }

  final x25519 = crypto_pkg.X25519();
  final clientKeyPair = await x25519.newKeyPair();
  final clientPublicKey = await clientKeyPair.extractPublicKey();

  final clientHello = ClientHelloMsg(
    vers: versionTls12,
    random: _randomBytes(rng, 32),
    sessionId: _randomBytes(rng, 32),
    cipherSuites: const [
      tlsAes128GcmSha256,
      tlsChacha20Poly1305Sha256,
      tlsAes256GcmSha384,
    ],
    compressionMethods: Uint8List.fromList(const [0]),
    keyShares: [
      KeyShare(group: 0x001d, data: Uint8List.fromList(clientPublicKey.bytes)),
    ],
    supportedCurves: const [0x001d],
    pskModes: Uint8List.fromList(const [1]),
    supportedVersions: const [versionTls13],
    supportedSignatureAlgorithms: const [0x0403, 0x0807, 0x0804],
    alpnProtocols: tlsConfig.nextProtos,
    quicTransportParameters: parameters.marshal(),
    serverName: tlsConfig.serverName ?? '',
  );
  final clientHelloBytes = clientHello.marshal();

  final (initialClientSecret, initialServerSecret) = computeInitialSecrets(
    destConnectionId,
  );
  final clientInitialCipher = _cipherFor(initialClientSecret);
  final serverInitialCipher = _cipherFor(initialServerSecret);

  final incoming = StreamController<Uint8List>();
  final subscription = socket.listen((event) {
    if (event == RawSocketEvent.read) {
      final datagram = socket.receive();
      if (datagram != null) incoming.add(datagram.data);
    }
  }, onError: (Object _) {});

  try {
    socket.send(
      clientInitialCipher.seal(
        header: ExtendedHeader(
          isLongHeader: true,
          type: packetTypeInitial,
          destConnectionId: destConnectionId,
          srcConnectionId: srcConnectionId,
          version: quicVersion1,
          packetNumber: 0,
          packetNumberLen: 4,
          token: Uint8List(0),
        ),
        payload: _padToInitialSize(CryptoFrame(0, clientHelloBytes).encode()),
      ),
      remoteAddress,
      remotePort,
    );

    // The server answers with a datagram coalescing its Initial (ServerHello)
    // and its Handshake packets. Both must be unprotected with different keys,
    // so the flight is reassembled across datagrams until the server's
    // Finished has been read.
    final flight = _ServerFlight(
      serverInitialCipher: serverInitialCipher,
      clientHelloBytes: clientHelloBytes,
      x25519: x25519,
      clientKeyPair: clientKeyPair,
    );

    await for (final datagram in incoming.stream.timeout(
      handshakeTimeout,
      onTimeout: (sink) => sink.addError(
        TimeoutException('QUIC handshake timed out', handshakeTimeout),
      ),
    )) {
      await flight.consume(datagram);
      if (flight.isComplete) break;
    }
    if (!flight.isComplete) {
      throw const HandshakeException('server closed before Finished');
    }

    final negotiated = flight.negotiatedProtocol;
    if (negotiated != null && !tlsConfig.nextProtos.contains(negotiated)) {
      throw HandshakeException(
        'server selected ALPN "$negotiated", which was not offered',
      );
    }
    final verify = tlsConfig.verifyPeerCertificate;
    if (verify != null) await verify(flight.peerCertificates);

    await _sendClientFlight(
      socket: socket,
      remoteAddress: remoteAddress,
      remotePort: remotePort,
      srcConnectionId: srcConnectionId,
      flight: flight,
      certificate: tlsConfig.certificate,
    );

    return QuicConn(
      socket: socket,
      remoteAddress: remoteAddress,
      remotePort: remotePort,
      destConnectionId: flight.serverConnectionId,
      srcConnectionId: srcConnectionId,
      sendCipher: _cipherFor(flight.clientApplicationSecret),
      receiveCipher: _cipherFor(flight.serverApplicationSecret),
      perspective: Perspective.client,
      peerCertificates: flight.peerCertificates,
      negotiatedProtocol: negotiated,
      socketSubscription: subscription,
    );
  } catch (_) {
    await subscription.cancel();
    rethrow;
  } finally {
    await incoming.close();
  }
}

Future<void> _sendClientFlight({
  required RawDatagramSocket socket,
  required InternetAddress remoteAddress,
  required int remotePort,
  required Uint8List srcConnectionId,
  required _ServerFlight flight,
  required QuicClientCertificate? certificate,
}) async {
  final transcript = flight.transcript;
  final messages = BytesBuilder(copy: false);

  // Only answer with a Certificate when the server actually asked for one:
  // an HTTP/3 server authenticates the client above TLS, not inside it.
  if (flight.certificateRequested) {
    final certificateMsg = CertificateMsgTls13(
      certificateChain: [certificate?.der ?? Uint8List(0)],
    );
    final certificateBytes = certificateMsg.marshal();
    transcript.write(certificateBytes);
    messages.add(certificateBytes);

    if (certificate != null) {
      final signature = await certificate.sign(
        Uint8List.fromList([
          ...List.filled(64, 0x20),
          ...utf8.encode('TLS 1.3, client CertificateVerify'),
          0x00,
          ...transcript.sum(),
        ]),
      );
      final verifyBytes = CertificateVerifyMsg(
        hasSignatureAlgorithm: true,
        signatureAlgorithm: certificate.signatureAlgorithm,
        signature: signature,
      ).marshal();
      transcript.write(verifyBytes);
      messages.add(verifyBytes);
    }
  }

  final finishedBytes = FinishedMsg(
    verifyData: flight.suite.finishedHash(
      flight.clientHandshakeSecret,
      transcript,
    ),
  ).marshal();
  transcript.write(finishedBytes);
  messages.add(finishedBytes);

  final payload = BytesBuilder(copy: false)
    ..add(
      AckFrame(
        largestAcked: flight.largestHandshakePacketNumber,
        delayTimeMicros: 0,
        firstAckRange: 0,
      ).encode(),
    )
    ..add(CryptoFrame(0, messages.toBytes()).encode());

  socket.send(
    _cipherFor(flight.clientHandshakeSecret).seal(
      header: ExtendedHeader(
        isLongHeader: true,
        type: packetTypeHandshake,
        destConnectionId: flight.serverConnectionId,
        srcConnectionId: srcConnectionId,
        version: quicVersion1,
        packetNumber: 0,
        packetNumberLen: 4,
      ),
      payload: payload.toBytes(),
    ),
    remoteAddress,
    remotePort,
  );
}

/// Accumulates the server's handshake flight across datagrams and derives the
/// key schedule from it.
class _ServerFlight {
  _ServerFlight({
    required QuicPacketCipher serverInitialCipher,
    required Uint8List clientHelloBytes,
    required crypto_pkg.X25519 x25519,
    required crypto_pkg.KeyPair clientKeyPair,
  }) : _serverInitialCipher = serverInitialCipher,
       _clientHelloBytes = clientHelloBytes,
       _x25519 = x25519,
       _clientKeyPair = clientKeyPair;

  final QuicPacketCipher _serverInitialCipher;
  final Uint8List _clientHelloBytes;
  final crypto_pkg.X25519 _x25519;
  final crypto_pkg.KeyPair _clientKeyPair;

  final BytesBuilder _cryptoStream = BytesBuilder(copy: false);
  final List<Uint8List> peerCertificates = [];

  late CipherSuiteTls13 suite;
  late HandshakeTranscript transcript;
  late HandshakeSecret _handshakeSecret;
  late Uint8List clientHandshakeSecret;
  late Uint8List _serverHandshakeSecret;
  late Uint8List clientApplicationSecret;
  late Uint8List serverApplicationSecret;
  late QuicPacketCipher _serverHandshakeCipher;

  Uint8List serverConnectionId = Uint8List(0);
  String? negotiatedProtocol;
  bool certificateRequested = false;
  bool isComplete = false;
  int largestHandshakePacketNumber = 0;

  bool _sawServerHello = false;

  /// Unprotects every packet coalesced in [datagram] and feeds their CRYPTO
  /// frames to the TLS state machine.
  Future<void> consume(Uint8List datagram) async {
    var offset = 0;
    while (offset < datagram.length && !isComplete) {
      final firstByte = datagram[offset];
      if ((firstByte & 0x80) == 0) return; // 1-RTT arrives only after Finished
      final packetType = (firstByte >> 4) & 0x03;
      final length = _packetLength(datagram, offset);
      if (length <= 0) return;
      final packet = Uint8List.sublistView(datagram, offset, offset + length);
      offset += length;

      if (packetType == packetTypeInitial) {
        if (_sawServerHello) continue;
        final (header, payload) = _serverInitialCipher.open(packet);
        serverConnectionId = header.srcConnectionId;
        await _handleServerHello(payload);
      } else if (packetType == packetTypeHandshake && _sawServerHello) {
        final (header, payload) = _serverHandshakeCipher.open(packet);
        if (header.packetNumber > largestHandshakePacketNumber) {
          largestHandshakePacketNumber = header.packetNumber;
        }
        await _handleHandshakeMessages(payload);
      }
    }
  }

  Future<void> _handleServerHello(Uint8List payload) async {
    ServerHelloMsg? serverHello;
    Uint8List? serverHelloBytes;
    for (final frame in parseFrames(payload)) {
      if (frame is CryptoFrame) {
        serverHelloBytes = frame.data;
        serverHello = ServerHelloMsg.unmarshal(frame.data);
        break;
      }
    }
    if (serverHello == null || serverHelloBytes == null) {
      throw const HandshakeException('server Initial carried no ServerHello');
    }
    final serverShare = serverHello.serverShare;
    if (serverShare == null) {
      throw const HandshakeException('ServerHello carried no key share');
    }

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: _clientKeyPair,
      remotePublicKey: crypto_pkg.SimplePublicKey(
        serverShare.data,
        type: crypto_pkg.KeyPairType.x25519,
      ),
    );

    suite =
        cipherSuiteTls13ById(serverHello.cipherSuite) ?? cipherSuitesTls13[0];
    transcript = HandshakeTranscript(suite.hash)
      ..write(_clientHelloBytes)
      ..write(serverHelloBytes);

    _handshakeSecret = EarlySecret(
      suite.hash,
      null,
    ).handshakeSecret(Uint8List.fromList(await sharedSecret.extractBytes()));
    clientHandshakeSecret = _handshakeSecret.clientHandshakeTrafficSecret(
      transcript,
    );
    _serverHandshakeSecret = _handshakeSecret.serverHandshakeTrafficSecret(
      transcript,
    );
    _serverHandshakeCipher = _cipherFor(_serverHandshakeSecret);
    _sawServerHello = true;
  }

  Future<void> _handleHandshakeMessages(Uint8List payload) async {
    for (final frame in parseFrames(payload)) {
      if (frame is CryptoFrame) _cryptoStream.add(frame.data);
    }
    var buffered = _cryptoStream.takeBytes();
    var cursor = 0;

    while (cursor + 4 <= buffered.length) {
      final messageType = buffered[cursor];
      final messageLength =
          (buffered[cursor + 1] << 16) |
          (buffered[cursor + 2] << 8) |
          buffered[cursor + 3];
      if (cursor + 4 + messageLength > buffered.length) break;
      final message = Uint8List.sublistView(
        buffered,
        cursor,
        cursor + 4 + messageLength,
      );
      cursor += 4 + messageLength;

      switch (messageType) {
        case _encryptedExtensions:
          negotiatedProtocol = _alpnFrom(message);
          transcript.write(message);
        case _certificateRequest:
          certificateRequested = true;
          transcript.write(message);
        case _certificate:
          peerCertificates
            ..clear()
            ..addAll(CertificateMsgTls13.unmarshal(message).certificateChain);
          transcript.write(message);
        case _finished:
          final expected = suite.finishedHash(
            _serverHandshakeSecret,
            transcript,
          );
          final received = FinishedMsg.unmarshal(message).verifyData;
          if (!_constantTimeEquals(received, expected)) {
            throw const HandshakeException(
              'server Finished verify_data mismatch',
            );
          }
          transcript.write(message);
          final masterSecret = _handshakeSecret.masterSecret();
          clientApplicationSecret = masterSecret.clientApplicationTrafficSecret(
            transcript,
          );
          serverApplicationSecret = masterSecret.serverApplicationTrafficSecret(
            transcript,
          );
          isComplete = true;
        default:
          transcript.write(message);
      }
    }

    if (cursor < buffered.length) {
      _cryptoStream.add(Uint8List.sublistView(buffered, cursor));
    }
  }

  static const int _encryptedExtensions = 8;
  static const int _certificateRequest = 13;
  static const int _certificate = 11;
  static const int _finished = 20;
}

/// Reads the ALPN protocol the server selected out of an EncryptedExtensions
/// message, per RFC 8446 section 4.3.1 and RFC 7301 section 3.1.
String? _alpnFrom(Uint8List encryptedExtensions) {
  // 4 bytes of handshake header, then a 2-byte extensions block length.
  var cursor = 6;
  while (cursor + 4 <= encryptedExtensions.length) {
    final extensionType =
        (encryptedExtensions[cursor] << 8) | encryptedExtensions[cursor + 1];
    final extensionLength =
        (encryptedExtensions[cursor + 2] << 8) |
        encryptedExtensions[cursor + 3];
    cursor += 4;
    if (cursor + extensionLength > encryptedExtensions.length) return null;
    if (extensionType == 16 && extensionLength >= 3) {
      final nameLength = encryptedExtensions[cursor + 2];
      if (cursor + 3 + nameLength > encryptedExtensions.length) return null;
      return utf8.decode(
        Uint8List.sublistView(
          encryptedExtensions,
          cursor + 3,
          cursor + 3 + nameLength,
        ),
      );
    }
    cursor += extensionLength;
  }
  return null;
}

int _packetLength(Uint8List bytes, int offset) {
  try {
    final firstByte = bytes[offset];
    var cursor = 5;
    final destLength = bytes[offset + cursor++];
    cursor += destLength;
    final sourceLength = bytes[offset + cursor++];
    cursor += sourceLength;
    if (((firstByte >> 4) & 0x03) == packetTypeInitial) {
      final (tokenLength, tokenLengthSize) = parseVarInt(
        bytes,
        offset + cursor,
      );
      cursor += tokenLengthSize + tokenLength;
    }
    final (payloadLength, payloadLengthSize) = parseVarInt(
      bytes,
      offset + cursor,
    );
    cursor += payloadLengthSize;
    final total = cursor + payloadLength;
    if (total <= 0 || offset + total > bytes.length) return -1;
    return total;
  } catch (_) {
    return -1;
  }
}

QuicPacketCipher _cipherFor(Uint8List secret) {
  final (key, iv, headerProtectionKey) = computeKeyAndIv(secret);
  return QuicPacketCipher(
    key: key,
    iv: iv,
    hp: AesHeaderProtector(headerProtectionKey),
  );
}

/// Pads an Initial packet payload so the datagram reaches the 1200-byte
/// minimum RFC 9000 section 14.1 requires of a client's first flight.
Uint8List _padToInitialSize(Uint8List payload) {
  const minimumPayload = 1200 - 29 - 16;
  if (payload.length >= minimumPayload) return payload;
  final padded = Uint8List(minimumPayload)..setAll(0, payload);
  return padded;
}

Uint8List _randomBytes(math.Random rng, int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = rng.nextInt(256);
  }
  return bytes;
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}
