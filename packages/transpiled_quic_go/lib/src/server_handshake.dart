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

  /// Per-peer Initial packet number space, keyed by remote endpoint: the
  /// ClientHello being reassembled, the packet numbers seen in that space,
  /// and the ciphers protecting it. It outlives the ClientHello because the
  /// client keeps retransmitting Initials until they are acknowledged.
  final Map<String, _InitialSpace> _initialSpaces = {};
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
        if (_connsByRemote.containsKey(remoteKey)) continue;
        if (_pending.containsKey(remoteKey)) {
          // Not a no-op: quic-go has no special case for a repeated Initial
          // either (`transport.go:584-587` hands it straight to the
          // connection, and `connection.go:1366-1383` drops it only when the
          // packet *number* repeats). Dropping it silently leaves the peer
          // retransmitting a packet this side never acknowledges.
          _acknowledgeInitial(dg, remoteKey, packet);
          continue;
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

      final space = _initialSpaces.putIfAbsent(remoteKey, () {
        final (clientSecret, serverSecret) = computeInitialSecrets(clientDcid);
        final (sKey, sIv, sHp) = computeKeyAndIv(serverSecret);
        final (cKey, cIv, cHp) = computeKeyAndIv(clientSecret);
        return _InitialSpace(
          clientCipher: QuicPacketCipher(
            key: cKey,
            iv: cIv,
            hp: AesHeaderProtector(cHp),
          ),
          serverCipher: QuicPacketCipher(
            key: sKey,
            iv: sIv,
            hp: AesHeaderProtector(sHp),
          ),
          clientConnectionId: Uint8List.fromList(clientScid),
          serverConnectionId: _randomBytes(8),
        );
      });
      final serverInitCipher = space.serverCipher;

      final (decHdr, decPayload) = space.clientCipher.open(data);
      space.tracker.receivedPacket(decHdr.packetNumber);
      final frames = parseFrames(decPayload);

      // A real client's ClientHello does not fit in one Initial packet: with
      // a post-quantum key share it runs past 1200 bytes, so it arrives split
      // across two or more packets, each carrying one CRYPTO frame at its own
      // offset (RFC 9000 s. 19.6). Parsing only the first frame therefore
      // fails with a truncated message and the client, hearing nothing, just
      // retransmits until it times out. Reassemble the CRYPTO stream by
      // offset and wait until a whole handshake message is there.
      for (final f in frames) {
        if (f is CryptoFrame) space.assembly.add(f.offset, f.data);
      }
      final helloBytes = space.assembly.completeMessage();
      if (helloBytes == null) {
        // Only part of the ClientHello is here. quic-go acknowledges an
        // ack-eliciting Initial the moment it arrives rather than waiting for
        // the flight it completes -- the `receivedPacketTracker` covering the
        // Initial and Handshake spaces says so in as many words, and the
        // `max_ack_delay` decimation applies only to Application Data
        // (`internal/ackhandler/received_packet_tracker.go:15-16, 30-49`
        // against `:78-134`).
        _sendInitialAck(dg, space);
        return;
      }
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

      final serverConnId = space.serverConnectionId;

      final tp = TransportParameters(
        initialSourceConnectionId: serverConnId,
        // RFC 9000 s. 7.3 makes this mandatory for a server: it echoes the
        // Destination Connection ID the client chose for its first Initial,
        // which is what lets the client detect an off-path attacker having
        // swapped connection IDs mid-handshake. quic-go sets it in
        // `connection.go`'s `newConnection`; omitting it makes a Go peer
        // abort with `TRANSPORT_PARAMETER_ERROR: missing
        // original_destination_connection_id`.
        originalDestinationConnectionId: Uint8List.fromList(clientDcid),
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
      // The transcript hashes the ClientHello *as a whole message*, which is
      // what `helloBytes` is: the CRYPTO stream reassembled by offset. Hashing
      // the first CRYPTO frame of the last Initial instead hashes a fragment,
      // and every secret derived from this transcript then differs from the
      // client's -- so the peer cannot unprotect the server's Handshake
      // packet, never sees EncryptedExtensions..Finished, and therefore never
      // sends its own second flight. Go hashes the assembled message too:
      // `crypto/tls`'s `readHandshake` returns one complete message and
      // `handshake_server_tls13.go:66-105` writes that into the transcript.
      final transcript = HandshakeTranscript(suite.hash)
        ..write(helloBytes)
        ..write(shBytes);
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
        packetNumber: space.nextPacketNumber++,
        packetNumberLen: 4,
      );
      // Every Initial received so far, as ACK ranges -- not just the one that
      // completed the ClientHello. A split ClientHello leaves the earlier
      // packets unacknowledged otherwise, and the peer retransmits them for
      // as long as it keeps its Initial keys.
      final ackInit = space.tracker.ackFrame()!;
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
        serverHandshakeCipher: serverHsCipher,
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
      final (handshakeHeader, payload) = pending.clientHandshakeCipher.open(
        packet,
      );
      var ackEliciting = false;
      for (final frame in parseFrames(payload)) {
        if (frame is CryptoFrame) {
          pending.cryptoStream.add(frame.data);
          ackEliciting = true;
        } else if (frame is! AckFrame && frame is! PaddingFrame) {
          // Go: `internal/ackhandler/ack_eliciting.go:5-16`
          // (`IsFrameTypeAckEliciting`) -- everything but ACK and PADDING
          // elicits an acknowledgement.
          ackEliciting = true;
        }
      }
      // The client's certificate and Finished travel here, and nothing
      // acknowledged them before: the peer kept retransmitting its whole
      // second flight until the handshake was confirmed some other way.
      if (pending.handshakeTracker.receivedPacket(
            handshakeHeader.packetNumber,
          ) &&
          ackEliciting) {
        _sendHandshakeAck(dg, pending);
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
    _initialSpaces.remove(remoteKey);
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
    // RFC 9001 s. 4.1.2: the server confirms the handshake by sending
    // HANDSHAKE_DONE, which is what lets the peer drop its Handshake keys and
    // stop retransmitting that flight. quic-go queues it from
    // `connection.go`'s `handleHandshakeComplete` on the server side.
    conn.sendFrames([const HandshakeDoneFrame()]);
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
    _initialSpaces.clear();
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

  /// Records a retransmitted Initial and acknowledges it.
  ///
  /// The client keeps its Initial keys, and keeps resending, until every
  /// Initial it sent has been acknowledged. Dropping the packet without a
  /// word -- which is what this server used to do once its flight had gone
  /// out -- leaves the peer retransmitting into silence.
  void _acknowledgeInitial(Datagram dg, String remoteKey, Uint8List packet) {
    final space = _initialSpaces[remoteKey];
    if (space == null) return;
    try {
      final (header, _) = space.clientCipher.open(packet);
      if (!space.tracker.receivedPacket(header.packetNumber)) return;
      _sendInitialAck(dg, space);
    } catch (e) {
      dev.log('dropping unreadable Initial retransmit', name: 'quic', error: e);
    }
  }

  /// Sends an ACK-only Initial packet covering everything [space] has seen.
  void _sendInitialAck(Datagram dg, _InitialSpace space) {
    final ack = space.tracker.ackFrame();
    if (ack == null) return;
    final header = ExtendedHeader(
      isLongHeader: true,
      type: packetTypeInitial,
      destConnectionId: space.clientConnectionId,
      srcConnectionId: space.serverConnectionId,
      version: 1,
      packetNumber: space.nextPacketNumber++,
      packetNumberLen: 4,
    );
    _socket.send(
      space.serverCipher.seal(header: header, payload: ack.encode()),
      dg.address,
      dg.port,
    );
  }

  /// Sends an ACK-only Handshake packet covering everything [pending] has
  /// seen in the Handshake packet number space.
  void _sendHandshakeAck(Datagram dg, _InboundHandshake pending) {
    final ack = pending.handshakeTracker.ackFrame();
    if (ack == null) return;
    final header = ExtendedHeader(
      isLongHeader: true,
      type: packetTypeHandshake,
      destConnectionId: pending.clientConnectionId,
      srcConnectionId: pending.serverConnectionId,
      version: 1,
      packetNumber: pending.nextHandshakePacketNumber++,
      packetNumberLen: 4,
    );
    _socket.send(
      pending.serverHandshakeCipher.seal(header: header, payload: ack.encode()),
      dg.address,
      dg.port,
    );
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
    required this.serverHandshakeCipher,
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

  /// Protects the ACK-only Handshake packets this server sends back.
  final QuicPacketCipher serverHandshakeCipher;
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

  /// Packet numbers seen in the Handshake packet number space.
  final _ReceivedPacketTracker handshakeTracker = _ReceivedPacketTracker();

  /// The next packet number this server uses in the Handshake space; 0
  /// carried the server's own flight.
  int nextHandshakePacketNumber = 1;

  /// The client's DER certificate chain, once its Certificate message landed
  /// (empty when [QuicServer.requestClientCertificate] never asked for one).
  List<Uint8List> certificateChain = const [];
}

/// One peer's Initial packet number space: the ClientHello being reassembled
/// from CRYPTO frames, the packet numbers acknowledged in that space, and the
/// Initial-level ciphers, which are derived from the client's first
/// Destination Connection ID and so are fixed for the whole space.
class _InitialSpace {
  _InitialSpace({
    required this.clientCipher,
    required this.serverCipher,
    required this.clientConnectionId,
    required this.serverConnectionId,
  });

  final QuicPacketCipher clientCipher;
  final QuicPacketCipher serverCipher;

  /// The connection ID the client chose for itself, used as the Destination
  /// Connection ID of every Initial this server sends back.
  final Uint8List clientConnectionId;

  /// The connection ID this server answers under, as the Source Connection
  /// ID of every packet it sends in this space.
  ///
  /// Chosen once, when the space is created, and never again: RFC 9000
  /// section 7.2 has the client adopt the Source Connection ID of the first
  /// Initial it receives from the server as its Destination Connection ID,
  /// and abandon the connection if a later one disagrees. Picking it only
  /// when the ClientHello completes therefore breaks any handshake in which
  /// an ACK went out first -- which is exactly what a split ClientHello
  /// causes. quic-go picks it in `transport.go`'s `handleInitialImpl`, before
  /// anything is sent.
  final Uint8List serverConnectionId;

  final _CryptoAssembly assembly = _CryptoAssembly();
  final _ReceivedPacketTracker tracker = _ReceivedPacketTracker();

  /// The next packet number this server uses in the Initial space.
  int nextPacketNumber = 0;
}

/// The packet numbers received in one packet number space, and the ACK frame
/// that reports them.
///
/// Go: `quic-go/internal/ackhandler/received_packet_tracker.go`'s
/// `receivedPacketTracker`, whose own comment (`:15-16`) states the rule this
/// server had been breaking -- for the Initial and Handshake spaces, "every
/// received packet is acknowledged immediately". The `max_ack_delay`
/// decimation that waits for a second packet or a timer belongs to the
/// Application Data space alone (`appDataReceivedPacketTracker`, `:78-134`).
///
/// Reduced to what an inbound handshake needs: no ECN counters, and no reuse
/// of one `wire.AckFrame` across calls, because this side sends few enough
/// ACKs for the allocation never to matter.
class _ReceivedPacketTracker {
  final Set<int> _received = {};

  /// Records [packetNumber], reporting whether it had not been seen before.
  ///
  /// Go's `ReceivedPacket` treats a duplicate as a caller bug, because the
  /// connection filters duplicates before calling it
  /// (`connection.go:1366-1383`); here this method *is* the duplicate check,
  /// so it answers rather than failing.
  bool receivedPacket(int packetNumber) => _received.add(packetNumber);

  /// The ACK frame covering every packet number received so far, or `null`
  /// when nothing has been received yet.
  ///
  /// RFC 9000 section 19.3 encodes the acknowledged set as ranges walking
  /// down from the largest: `largest_acknowledged` and `first_ack_range`,
  /// then one gap/length pair per further range. A gap counts the
  /// unacknowledged packets between two ranges, minus one (section 19.3.1).
  AckFrame? ackFrame() {
    if (_received.isEmpty) return null;
    final sorted = _received.toList()..sort();

    // Contiguous runs as (smallest, largest), ascending.
    final runs = <(int, int)>[];
    var start = sorted.first;
    var previous = sorted.first;
    for (final pn in sorted.skip(1)) {
      if (pn == previous + 1) {
        previous = pn;
        continue;
      }
      runs.add((start, previous));
      start = pn;
      previous = pn;
    }
    runs.add((start, previous));

    final descending = runs.reversed.toList();
    final largest = descending.first;
    final additional = <AckRange>[];
    var previousSmallest = largest.$1;
    for (final run in descending.skip(1)) {
      additional.add(
        AckRange(gap: previousSmallest - run.$2 - 2, length: run.$2 - run.$1),
      );
      previousSmallest = run.$1;
    }
    return AckFrame(
      largestAcked: largest.$2,
      firstAckRange: largest.$2 - largest.$1,
      additionalRanges: additional,
    );
  }
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
