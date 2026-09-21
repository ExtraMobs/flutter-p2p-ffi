// Port of the server half of `github.com/quic-go/quic-go`'s handshake
// (v0.60.0, revision 7612ad1036957cde45d672bebb8b9ec9c2e9b2a7): the server
// side of the Initial/Handshake exchange driven by `transport.go`'s
// `handleInitialImpl` and `server.go`'s `Listener`, running the TLS 1.3
// server flight through `internal/handshake`'s `cryptoSetupServer`.
//
// Mirrors `client_handshake.dart`: the QUIC handshake *is* a TLS 1.3
// handshake carried in CRYPTO frames, and what varies between the transports
// built on it is only the TLS configuration -- the ALPN offered, the
// certificate presented, and whether the peer must present one of its own.
// libp2p's `/quic-v1` negotiates ALPN `libp2p`, presents a libp2p identity
// certificate and requires the peer to present one too; `/quic-v1/webtransport`
// negotiates ALPN `h3`, presents a WebTransport certificate and requires no
// client certificate, because there the peer is authenticated by a Noise
// handshake carried inside the session instead of by TLS. Both are expressed
// here as parameters to [QuicServer], mirroring how Go configures a
// `tls.Config` per listener.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
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

/// TLS 1.3 handshake message type codes used by the inbound handshake
/// (RFC 8446 section 4). Go keeps these unexported in `crypto/tls`, so they
/// stay private here too.
const int _tlsCertificate = 11;
const int _tlsCertificateVerify = 15;
const int _tlsFinished = 20;

/// Compares two byte strings without an early exit, per Go's
/// `crypto/subtle.ConstantTimeCompare`, so a mismatching Finished cannot be
/// guessed byte by byte from timing.
bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Thrown by [QuicServer.accept] once the server has been closed, per
/// quic-go's `ErrServerClosed` sentinel (`server.go`).
class QuicServerClosedException implements Exception {
  /// Creates a [QuicServerClosedException].
  const QuicServerClosedException([this.message = 'QUIC server is closed']);

  /// A human readable description of why the server is gone.
  final String message;

  @override
  String toString() => 'QuicServerClosedException: $message';
}

/// The TLS `NamedGroup` identifier for X25519 (RFC 8446 s. 4.2.7), the only
/// key exchange this port implements. Go: `tls.X25519`.
const int _curveX25519 = 0x001d;

/// The certificate a QUIC server presents, and the signer that proves it
/// holds the private key. Server-side counterpart of `client_handshake.dart`'s
/// `QuicClientCertificate`.
class QuicServerCertificate {
  /// Creates a [QuicServerCertificate] from its DER encoding and a signer.
  const QuicServerCertificate({
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

/// Accepts QUIC connections on one shared [RawDatagramSocket], per quic-go's
/// server-side `Transport`/`Listener` pair (`transport.go`, `server.go`).
///
/// This does not subscribe to [socket] itself: the socket is used only to
/// send the server's handshake flight and is handed to each accepted
/// [QuicConn] for its own outbound writes (with `ownsSocket: false`). The
/// caller owns the socket subscription and feeds every received datagram to
/// [handleDatagram] -- which is what lets one socket be shared between a
/// `QuicServer` and whatever else needs it, exactly as go-libp2p's QUIC
/// transport shares one `net.PacketConn` between dialling and listening.
class QuicServer {
  /// Creates a [QuicServer] that answers handshakes arriving on [socket].
  ///
  /// [nextProtos] is the ALPN this server offers; only its first entry is
  /// ever sent, matching a single-purpose listener rather than a
  /// preference-ordered negotiation. [certificate] authenticates this
  /// server. [requestClientCertificate] sends a CertificateRequest and
  /// requires the peer to answer it with its own certificate; libp2p's
  /// `/quic-v1` needs this, `/quic-v1/webtransport` does not, because there
  /// the peer is authenticated inside the session instead.
  /// [enableDatagrams] advertises the QUIC DATAGRAM transport parameter
  /// (RFC 9221), which WebTransport requires and libp2p does not use.
  QuicServer({
    required RawDatagramSocket socket,
    required QuicServerCertificate certificate,
    required List<String> nextProtos,
    this.requestClientCertificate = false,
    this.enableDatagrams = false,
  }) : _socket = socket,
       _certificate = certificate,
       _alpn = nextProtos.first;

  /// Whether this server asks the peer to present a certificate.
  final bool requestClientCertificate;

  /// Whether this server advertises QUIC datagram support.
  final bool enableDatagrams;

  final RawDatagramSocket _socket;
  final QuicServerCertificate _certificate;
  final String _alpn;

  final Map<String, QuicConn> _connsByRemote = {};
  final Map<String, _InboundHandshake> _pending = {};

  /// Partially received ClientHellos, keyed by remote endpoint.
  final Map<String, _CryptoAssembly> _clientHellos = {};
  final List<Completer<QuicConn>> _acceptQueue = [];
  final List<QuicConn> _pendingConns = [];
  bool _closed = false;

  /// Completes with the next fully handshaked connection.
  Future<QuicConn> accept() {
    if (_closed) throw const QuicServerClosedException();
    if (_pendingConns.isNotEmpty) {
      return Future.value(_pendingConns.removeAt(0));
    }
    final completer = Completer<QuicConn>();
    _acceptQueue.add(completer);
    return completer.future;
  }

  /// Hands one received datagram to the right connection or handshake.
  ///
  /// RFC 9000 section 12.2 lets a peer coalesce packets of different
  /// encryption levels into one datagram, so every packet is walked rather
  /// than assuming the datagram holds a single one: a client's second flight
  /// arrives as an Initial carrying an ACK coalesced with the Handshake
  /// packet that carries its certificate.
  void handleDatagram(Datagram dg) {
    if (_closed || dg.data.isEmpty) return;
    unawaited(_dispatch(dg));
  }

  Future<void> _dispatch(Datagram dg) async {
    final data = dg.data;
    final remoteKey = '${dg.address.address}:${dg.port}';
    var offset = 0;
    while (offset < data.length) {
      final firstByte = data[offset];
      if ((firstByte & 0x80) == 0) {
        // Short header: a 1-RTT packet for a connection already established.
        _connsByRemote[remoteKey]?.handleDatagram(
          offset == 0 ? data : Uint8List.sublistView(data, offset),
        );
        return;
      }
      final length = _longHeaderPacketLength(data, offset);
      if (length <= 0) return;
      final packet = Uint8List.sublistView(data, offset, offset + length);
      offset += length;

      final type = (firstByte >> 4) & 0x03;
      if (type == packetTypeInitial) {
        if (_pending.containsKey(remoteKey) ||
            _connsByRemote.containsKey(remoteKey)) {
          continue; // A retransmit or a pure ACK; the flight already went out.
        }
        await _handleClientInitial(dg, remoteKey, packet);
      } else if (type == packetTypeHandshake) {
        await _handleClientHandshake(dg, remoteKey, packet);
      }
    }
  }

  /// Answers a client's Initial packet with the server's whole first flight.
  Future<void> _handleClientInitial(
    Datagram dg,
    String remoteKey,
    Uint8List data,
  ) async {
    try {
      var cursor = 5;
      final dcidLen = data[cursor++];
      final clientDcid = Uint8List.sublistView(data, cursor, cursor + dcidLen);
      cursor += dcidLen;
      final scidLen = data[cursor++];
      final clientScid = Uint8List.sublistView(data, cursor, cursor + scidLen);

      final (clientSecret, serverSecret) = computeInitialSecrets(clientDcid);
      final (sKey, sIv, sHp) = computeKeyAndIv(serverSecret);
      final (cKey, cIv, cHp) = computeKeyAndIv(clientSecret);

      final serverInitCipher = QuicPacketCipher(
        key: sKey,
        iv: sIv,
        hp: AesHeaderProtector(sHp),
      );
      final clientInitCipher = QuicPacketCipher(
        key: cKey,
        iv: cIv,
        hp: AesHeaderProtector(cHp),
      );

      final (decHdr, decPayload) = clientInitCipher.open(data);
      final frames = parseFrames(decPayload);

      // A real client's ClientHello does not fit in one Initial packet: with
      // a post-quantum key share it runs past 1200 bytes, so it arrives split
      // across two or more packets, each carrying one CRYPTO frame at its own
      // offset (RFC 9000 s. 19.6). Parsing only the first frame therefore
      // fails with a truncated message and the client, hearing nothing, just
      // retransmits until it times out. Reassemble the CRYPTO stream by
      // offset and wait until a whole handshake message is there.
      final assembly = _clientHellos.putIfAbsent(
        remoteKey,
        _CryptoAssembly.new,
      );
      for (final f in frames) {
        if (f is CryptoFrame) assembly.add(f.offset, f.data);
      }
      final helloBytes = assembly.completeMessage();
      if (helloBytes == null) return;
      _clientHellos.remove(remoteKey);
      final clientHello = ClientHelloMsg.unmarshal(helloBytes);

      // The client offers its key shares in preference order, and its first
      // preference is very often NOT X25519: Go 1.24 and later lead with the
      // hybrid post-quantum group X25519MLKEM768 (0x11ec), whose share is
      // over a kilobyte and is not an X25519 public key at all. Taking
      // `.first` and feeding it to X25519 produces a shared secret the client
      // cannot reproduce, so it decrypts nothing and simply retransmits its
      // Initial until it gives up -- a failure that looks exactly like the
      // server being unreachable. Pick the X25519 share by its group id.
      final clientShare = clientHello.keyShares
          .where((share) => share.group == _curveX25519)
          .firstOrNull;
      if (clientShare == null) {
        // RFC 8446 s. 4.1.4 says to answer with a HelloRetryRequest naming a
        // group this side supports. That message is not ported yet, so the
        // handshake is abandoned instead of being silently mis-negotiated.
        throw const FormatException(
          'client offered no X25519 key share, and HelloRetryRequest is not '
          'implemented',
        );
      }

      final x25519 = crypto_pkg.X25519();
      final serverKeyPair = await x25519.newKeyPair();
      final serverPub = await serverKeyPair.extractPublicKey();
      final serverPubBytes = Uint8List.fromList(serverPub.bytes);
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

      final serverConnId = _randomBytes(8);

      final tp = TransportParameters(
        initialSourceConnectionId: serverConnId,
        initialMaxData: 10485760,
        initialMaxStreamDataBidiLocal: 2097152,
        initialMaxStreamDataBidiRemote: 2097152,
        initialMaxStreamDataUni: 2097152,
        initialMaxStreamsBidi: 100,
        initialMaxStreamsUni: 100,
        maxIdleTimeout: const Duration(seconds: 30),
      );
      if (enableDatagrams) {
        // Go: `connection.go`'s `params.MaxDatagramFrameSize =
        // wire.MaxDatagramSize` when `Config.EnableDatagrams` is set. Its
        // mere presence is what tells the peer datagrams are supported.
        tp.maxDatagramFrameSize = maxDatagramSize;
      }

      final serverHello = ServerHelloMsg(
        vers: versionTls12,
        random: Uint8List(32),
        cipherSuite: tlsAes128GcmSha256,
        serverShare: KeyShare(group: _curveX25519, data: serverPubBytes),
        supportedVersion: versionTls13,
        // ALPN does NOT belong in a TLS 1.3 ServerHello: RFC 8446 s. 4.1.3
        // allows only `key_share`, `pre_shared_key` and `supported_versions`
        // there, and everything else moves to EncryptedExtensions, where this
        // handshake sends it. A Go peer rejects the connection outright with
        // "server sent a ServerHello extension forbidden in TLS 1.3".
      );
      final shBytes = serverHello.marshal();

      final suite =
          cipherSuiteTls13ById(serverHello.cipherSuite) ?? cipherSuitesTls13[0];
      final transcript = HandshakeTranscript(suite.hash);
      for (final f in frames) {
        if (f is CryptoFrame) {
          transcript.write(f.data);
          break;
        }
      }
      transcript.write(shBytes);
      final earlySecret = EarlySecret(suite.hash, null);
      final handshakeSecret = earlySecret.handshakeSecret(sharedSecretBytes);
      final serverHsSecret = handshakeSecret.serverHandshakeTrafficSecret(
        transcript,
      );
      // Derived at the same transcript point as the server's own secret --
      // right after ServerHello -- because that is where the client derives
      // it too (RFC 8446 s. 7.1). It is what unprotects the client's
      // Handshake packets, which carry the certificate this server
      // authenticates the peer from (when [requestClientCertificate] asked
      // for one).
      final clientHsSecret = handshakeSecret.clientHandshakeTrafficSecret(
        transcript,
      );

      final ee = EncryptedExtensionsMsg(
        alpnProtocol: _alpn,
        quicTransportParameters: tp.marshal(isServer: true),
      );
      final eeBytes = ee.marshal();
      transcript.write(eeBytes);

      // A CertificateRequest is written -- and hashed into the transcript --
      // only when this server actually wants a client certificate. Writing
      // it unconditionally would desync the transcript from what a client
      // that never answers it computes, and Finished would never verify.
      var crBytes = Uint8List(0);
      if (requestClientCertificate) {
        final cr = CertificateRequestMsgTls13(
          supportedSignatureAlgorithms: const [0x0403, 0x0807, 0x0804],
        );
        crBytes = cr.marshal();
        transcript.write(crBytes);
      }

      final sc = CertificateMsgTls13(certificateChain: [_certificate.der]);
      final scBytes = sc.marshal();
      transcript.write(scBytes);

      final serverVerifyPayload = Uint8List.fromList([
        ...List.filled(64, 0x20),
        ...utf8.encode('TLS 1.3, server CertificateVerify'),
        0x00,
        ...transcript.sum(),
      ]);
      final serverSig = await _certificate.sign(serverVerifyPayload);
      final scv = CertificateVerifyMsg(
        hasSignatureAlgorithm: true,
        signatureAlgorithm: _certificate.signatureAlgorithm,
        signature: serverSig,
      );
      final scvBytes = scv.marshal();
      transcript.write(scvBytes);

      final serverVerifyData = suite.finishedHash(serverHsSecret, transcript);
      final sf = FinishedMsg(verifyData: serverVerifyData);
      final sfBytes = sf.marshal();
      transcript.write(sfBytes);

      // Derive application secrets.
      final masterSecret = handshakeSecret.masterSecret();
      final clientAppSecret = masterSecret.clientApplicationTrafficSecret(
        transcript,
      );
      final serverAppSecret = masterSecret.serverApplicationTrafficSecret(
        transcript,
      );

      final (cAppKey, cAppIv, cAppHp) = computeKeyAndIv(clientAppSecret);
      final (sAppKey, sAppIv, sAppHp) = computeKeyAndIv(serverAppSecret);

      final clientAppCipher = QuicPacketCipher(
        key: cAppKey,
        iv: cAppIv,
        hp: AesHeaderProtector(cAppHp),
      );
      final serverAppCipher = QuicPacketCipher(
        key: sAppKey,
        iv: sAppIv,
        hp: AesHeaderProtector(sAppHp),
      );

      // Build Initial response packet.
      final initRespHeader = ExtendedHeader(
        isLongHeader: true,
        type: packetTypeInitial,
        destConnectionId: clientScid,
        srcConnectionId: serverConnId,
        version: 1,
        packetNumber: 0,
        packetNumberLen: 4,
      );
      final ackInit = AckFrame(
        largestAcked: decHdr.packetNumber,
        firstAckRange: 0,
      );
      final cryptoInit = CryptoFrame(0, shBytes);
      final initPayload = BytesBuilder(copy: false)
        ..add(ackInit.encode())
        ..add(cryptoInit.encode());
      final sealedInitResp = serverInitCipher.seal(
        header: initRespHeader,
        payload: initPayload.toBytes(),
      );

      // Build Handshake response packet.
      final (sHsKey, sHsIv, sHsHp) = computeKeyAndIv(serverHsSecret);
      final serverHsCipher = QuicPacketCipher(
        key: sHsKey,
        iv: sHsIv,
        hp: AesHeaderProtector(sHsHp),
      );

      final hsRespHeader = ExtendedHeader(
        isLongHeader: true,
        type: packetTypeHandshake,
        destConnectionId: clientScid,
        srcConnectionId: serverConnId,
        version: 1,
        packetNumber: 0,
        packetNumberLen: 4,
      );
      final serverFlight = Uint8List.fromList([
        ...eeBytes,
        ...crBytes,
        ...scBytes,
        ...scvBytes,
        ...sfBytes,
      ]);
      final cryptoHs = CryptoFrame(0, serverFlight);
      final sealedHsResp = serverHsCipher.seal(
        header: hsRespHeader,
        payload: cryptoHs.encode(),
      );

      final coalescedDatagram = BytesBuilder(copy: false)
        ..add(sealedInitResp)
        ..add(sealedHsResp);

      _socket.send(coalescedDatagram.toBytes(), dg.address, dg.port);

      final (cHsKey, cHsIv, cHsHp) = computeKeyAndIv(clientHsSecret);
      _pending[remoteKey] = _InboundHandshake(
        clientHandshakeCipher: QuicPacketCipher(
          key: cHsKey,
          iv: cHsIv,
          hp: AesHeaderProtector(cHsHp),
        ),
        clientHandshakeSecret: clientHsSecret,
        serverAppCipher: serverAppCipher,
        clientAppCipher: clientAppCipher,
        clientConnectionId: clientScid,
        serverConnectionId: serverConnId,
        suite: suite,
        transcript: transcript,
        remoteAddress: dg.address,
        remotePort: dg.port,
      );
    } catch (e, st) {
      // Swallowing this silently makes a failed inbound handshake
      // indistinguishable from a peer that never dialled: `accept()` simply
      // never completes. Log it and drop the datagram, which is what a QUIC
      // server must do with a packet it cannot process.
      dev.log(
        'inbound QUIC handshake failed',
        name: 'quic',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Consumes a Handshake packet from a client whose Initial was answered.
  ///
  /// This is where the server learns who dialled it, when
  /// [requestClientCertificate] asked for a certificate: the client's
  /// Certificate message and its Finished proves it holds the handshake
  /// keys. Until both arrive the connection does not exist, so [accept]
  /// cannot hand out a peer that was never authenticated.
  Future<void> _handleClientHandshake(
    Datagram dg,
    String remoteKey,
    Uint8List packet,
  ) async {
    final pending = _pending[remoteKey];
    if (pending == null) return;
    try {
      final (_, payload) = pending.clientHandshakeCipher.open(packet);
      for (final frame in parseFrames(payload)) {
        if (frame is CryptoFrame) pending.cryptoStream.add(frame.data);
      }

      var buffered = pending.cryptoStream.takeBytes();
      var cursor = 0;
      while (cursor + 4 <= buffered.length) {
        final messageLength =
            (buffered[cursor + 1] << 16) |
            (buffered[cursor + 2] << 8) |
            buffered[cursor + 3];
        if (cursor + 4 + messageLength > buffered.length) break;
        final messageType = buffered[cursor];
        final message = Uint8List.sublistView(
          buffered,
          cursor,
          cursor + 4 + messageLength,
        );
        cursor += 4 + messageLength;

        switch (messageType) {
          case _tlsCertificate:
            pending.certificateChain = CertificateMsgTls13.unmarshal(
              message,
            ).certificateChain;
            pending.transcript.write(message);
          case _tlsCertificateVerify:
            pending.transcript.write(message);
          case _tlsFinished:
            final expected = pending.suite.finishedHash(
              pending.clientHandshakeSecret,
              pending.transcript,
            );
            final received = FinishedMsg.unmarshal(message).verifyData;
            if (!_constantTimeEquals(received, expected)) {
              throw const FormatException(
                'client Finished verify_data mismatch',
              );
            }
            pending.transcript.write(message);
            await _completeInbound(dg, remoteKey, pending);
            return;
          default:
            pending.transcript.write(message);
        }
      }
      // Whatever is left is the tail of a message split across packets.
      if (cursor < buffered.length) {
        pending.cryptoStream.add(Uint8List.sublistView(buffered, cursor));
      }
    } catch (e, st) {
      _pending.remove(remoteKey);
      dev.log(
        'inbound QUIC client handshake rejected',
        name: 'quic',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Turns a finished handshake into an accepted connection.
  Future<void> _completeInbound(
    Datagram dg,
    String remoteKey,
    _InboundHandshake pending,
  ) async {
    _pending.remove(remoteKey);
    if (requestClientCertificate && pending.certificateChain.isEmpty) {
      throw const FormatException(
        'client completed the handshake without a certificate',
      );
    }

    final conn = QuicConn(
      socket: _socket,
      remoteAddress: pending.remoteAddress,
      remotePort: pending.remotePort,
      destConnectionId: pending.clientConnectionId,
      srcConnectionId: pending.serverConnectionId,
      sendCipher: pending.serverAppCipher,
      receiveCipher: pending.clientAppCipher,
      perspective: Perspective.server,
      peerCertificates: pending.certificateChain,
      negotiatedProtocol: _alpn,
      ownsSocket: false,
    );

    _connsByRemote[remoteKey] = conn;
    if (_acceptQueue.isNotEmpty) {
      _acceptQueue.removeAt(0).complete(conn);
    } else {
      _pendingConns.add(conn);
    }
  }

  /// Closes every connection this server accepted and fails any pending
  /// [accept]. The shared socket is left to whoever owns it.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _clientHellos.clear();
    for (final c in _acceptQueue) {
      c.completeError(const QuicServerClosedException());
    }
    _acceptQueue.clear();
    for (final conn in _pendingConns) {
      await conn.close();
    }
    _pendingConns.clear();
    for (final conn in _connsByRemote.values) {
      await conn.close();
    }
    _connsByRemote.clear();
    _pending.clear();
  }

  Uint8List _randomBytes(int length) {
    final rng = math.Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes;
  }
}

/// The bytes one long-header QUIC packet occupies inside a datagram, or -1
/// when the datagram is truncated or malformed.
///
/// RFC 9000 section 12.2 lets an endpoint coalesce packets of different
/// encryption levels into one datagram, so walking them means reading each
/// one's Length field rather than assuming the datagram holds a single packet.
int _longHeaderPacketLength(Uint8List bytes, int offset) {
  try {
    final firstByte = bytes[offset];
    var cursor = 5; // first byte + 4 version bytes
    final dcidLen = bytes[offset + cursor++];
    cursor += dcidLen;
    final scidLen = bytes[offset + cursor++];
    cursor += scidLen;
    if (((firstByte >> 4) & 0x03) == packetTypeInitial) {
      final (tokenLen, tokenLenSize) = parseVarInt(bytes, offset + cursor);
      cursor += tokenLenSize + tokenLen;
    }
    final (payloadLen, payloadLenSize) = parseVarInt(bytes, offset + cursor);
    cursor += payloadLenSize;
    final total = cursor + payloadLen;
    if (total <= 0 || offset + total > bytes.length) return -1;
    return total;
  } catch (_) {
    return -1;
  }
}

/// An inbound connection whose TLS handshake has not finished yet.
///
/// The server answers a client's Initial with its whole first flight, but it
/// cannot hand out the connection until the client's own Finished arrives in
/// a Handshake packet (and, when [QuicServer.requestClientCertificate] asked
/// for one, its Certificate too). Everything needed to unprotect and verify
/// that flight -- and to build the connection once it checks out -- waits
/// here in the meantime. Go keeps the equivalent state inside `quic-go`'s
/// `cryptoSetup`/`connection` pair, which this server stands in for.
class _InboundHandshake {
  _InboundHandshake({
    required this.clientHandshakeCipher,
    required this.clientHandshakeSecret,
    required this.serverAppCipher,
    required this.clientAppCipher,
    required this.clientConnectionId,
    required this.serverConnectionId,
    required this.suite,
    required this.transcript,
    required this.remoteAddress,
    required this.remotePort,
  });

  final QuicPacketCipher clientHandshakeCipher;
  final Uint8List clientHandshakeSecret;
  final QuicPacketCipher serverAppCipher;
  final QuicPacketCipher clientAppCipher;
  final Uint8List clientConnectionId;
  final Uint8List serverConnectionId;
  final CipherSuiteTls13 suite;
  final HandshakeTranscript transcript;
  final InternetAddress remoteAddress;
  final int remotePort;

  /// CRYPTO-stream bytes received so far, which need not arrive aligned to
  /// handshake-message boundaries.
  final BytesBuilder cryptoStream = BytesBuilder(copy: false);

  /// The client's DER certificate chain, once its Certificate message landed
  /// (empty when [QuicServer.requestClientCertificate] never asked for one).
  List<Uint8List> certificateChain = const [];
}

/// Offset-ordered reassembly of a TLS handshake message carried by CRYPTO
/// frames, which QUIC may deliver out of order and split across packets.
///
/// Go: `quic-go`'s `cryptoStreamImpl` (`crypto_stream.go`), reduced to what
/// the first flight needs -- there is no retransmission or flow control here,
/// because a client that hears nothing retransmits its whole Initial anyway.
class _CryptoAssembly {
  final Map<int, Uint8List> _chunks = {};

  /// Records [data] as the CRYPTO stream bytes at [offset], ignoring a
  /// retransmission of a chunk already held.
  void add(int offset, Uint8List data) {
    if (data.isEmpty) return;
    _chunks.putIfAbsent(offset, () => Uint8List.fromList(data));
  }

  /// The first complete handshake message, or `null` while the bytes from
  /// offset zero do not yet cover its declared length.
  Uint8List? completeMessage() {
    final contiguous = BytesBuilder(copy: false);
    var next = 0;
    while (true) {
      final chunk = _chunks[next];
      if (chunk == null) break;
      contiguous.add(chunk);
      next += chunk.length;
    }
    final bytes = contiguous.takeBytes();
    if (bytes.length < 4) return null;
    final length = (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
    if (bytes.length < 4 + length) return null;
    return Uint8List.sublistView(bytes, 0, 4 + length);
  }
}
