// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:transpiled_quic_go/transpiled_quic_go.dart' as quicgo;

import '../../../core/connmgr/gater.dart';
import '../../../core/crypto/key_types.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/peer_id.dart';
import '../../../core/protocol/protocol.dart';
import '../../../core/transport/transport.dart';
import '../../security/tls/crypto.dart';
import '../../security/tls/transport.dart' show Identity, tlsProtocolId;

/// QUIC transport order for listener priority.
const int listenOrder = 1;

/// The ALPN protocol libp2p negotiates over QUIC, per go-libp2p's
/// `p2p/transport/quic`.
const String alpnLibp2p = 'libp2p';

/// Extracts host and UDP port from a QUIC multiaddr (/ip4/.../udp/.../quic-v1).
(String, int)? _extractQuicEndpoint(Multiaddr addr) {
  final comps = addr.components;
  if (comps.length < 3) return null;
  String? host;
  int? port;
  var hasQuicV1 = false;
  for (final c in comps) {
    if (c.protocol.code == Protocols.ip4 ||
        c.protocol.code == Protocols.ip6 ||
        c.protocol.code == Protocols.dns ||
        c.protocol.code == Protocols.dns4 ||
        c.protocol.code == Protocols.dns6) {
      host = c.value;
    } else if (c.protocol.code == Protocols.udp) {
      port = int.tryParse(c.value);
    } else if (c.protocol.code == Protocols.quicV1 ||
        c.protocol.name == 'quic-v1') {
      hasQuicV1 = true;
    } else if (c.protocol.code == Protocols.webtransport ||
        c.protocol.name == 'webtransport' ||
        c.protocol.code == Protocols.certhash ||
        c.protocol.name == 'certhash') {
      return null;
    }
  }
  if (host != null && port != null && hasQuicV1) {
    return (host, port);
  }
  return null;
}

/// QUIC transport implementation for libp2p.
class QuicTransport implements Transport {
  QuicTransport({
    required this.privKey,
    this.rcmgr = const NullResourceManager(),
    this.gater,
    Identity? identity,
  }) : localPeer = PeerId.fromPubKey(privKey.getPublic()),
       identity = identity ?? Identity(privKey: privKey);

  final PrivKey privKey;
  final PeerId localPeer;
  final Identity identity;
  final ResourceManager rcmgr;
  final ConnectionGater? gater;
  final List<Listener> _listeners = [];
  bool _closed = false;

  @override
  bool canDial(Multiaddr addr) => _extractQuicEndpoint(addr) != null;

  @override
  List<int> protocols() => const [
    Protocols.ip4,
    Protocols.ip6,
    Protocols.udp,
    Protocols.quicV1,
  ];

  @override
  bool proxy() => false;

  @override
  Future<Listener> listen(Multiaddr addr) async {
    if (_closed) throw StateError('QuicTransport is closed');
    final endpoint = _extractQuicEndpoint(addr);
    if (endpoint == null) {
      throw ArgumentError('Address $addr is not a valid QUIC multiaddr');
    }

    final (host, port) = endpoint;
    final socket = await RawDatagramSocket.bind(
      host == '0.0.0.0' ? InternetAddress.anyIPv4 : host,
      port,
    );

    final cert = await identity.getCertificate();
    final quicServer = quicgo.QuicServer(
      socket: socket,
      certificate: quicgo.QuicServerCertificate(
        der: cert.certificateDer,
        sign: cert.privateKey.sign,
      ),
      nextProtos: const [alpnLibp2p],
      requestClientCertificate: true,
    );

    final listener = _QuicListener(
      transport: this,
      socket: socket,
      localPeer: localPeer,
      quicServer: quicServer,
      listenAddr: addr,
    );
    _listeners.add(listener);
    return listener;
  }

  @override
  Future<CapableConn> dial(Multiaddr addr, PeerId peer) async {
    if (_closed) throw StateError('QuicTransport is closed');
    final endpoint = _extractQuicEndpoint(addr);
    if (endpoint == null) {
      throw ArgumentError('Address $addr is not a valid QUIC multiaddr');
    }

    final (host, port) = endpoint;
    final remoteAddress =
        InternetAddress.tryParse(host) ??
        (await InternetAddress.lookup(host)).first;

    final isIPv6 = remoteAddress.type == InternetAddressType.IPv6;
    final socket = await RawDatagramSocket.bind(
      isIPv6
          ? (remoteAddress.isLoopback
                ? InternetAddress.loopbackIPv6
                : InternetAddress.anyIPv6)
          : (remoteAddress.isLoopback
                ? InternetAddress.loopbackIPv4
                : InternetAddress.anyIPv4),
      0,
    );
    final localAddr = Multiaddr.parse(
      '/${isIPv6 ? 'ip6' : 'ip4'}/${socket.address.address}'
      '/udp/${socket.port}/quic-v1',
    );

    final certificate = await identity.getCertificate();
    PeerId? authenticatedPeer;
    PubKey? remotePubKey;

    try {
      final session = await quicgo.dial(
        socket: socket,
        remoteAddress: remoteAddress,
        remotePort: port,
        tlsConfig: quicgo.QuicTlsConfig(
          nextProtos: const [alpnLibp2p],
          certificate: quicgo.QuicClientCertificate(
            der: certificate.certificateDer,
            sign: certificate.privateKey.sign,
          ),
          verifyPeerCertificate: (chain) async {
            // libp2p authenticates the peer from the certificate's libp2p
            // extension rather than from a CA chain: the identity key in the
            // extension signs the certificate's own public key, and the
            // PeerId it derives to is the peer.
            final publicKey = await pubKeyFromCertChain(chain);
            final certPeer = PeerId.fromPubKey(publicKey);
            if (peer.value.isNotEmpty && certPeer != peer) {
              throw StateError(
                'Authenticated peer ID mismatch: expected $peer, got $certPeer',
              );
            }
            remotePubKey = publicKey;
            authenticatedPeer = certPeer;
          },
        ),
      );

      final certPeer = authenticatedPeer;
      final certKey = remotePubKey;
      if (certPeer == null || certKey == null) {
        await session.close();
        throw const FormatException('Handshake missing server certificate');
      }

      return _QuicConn(
        transport: this,
        session: session,
        localPeer: localPeer,
        remotePeer: certPeer,
        remotePubKey: certKey,
        localMultiaddr: localAddr,
        remoteMultiaddr: addr,
        direction: Direction.outbound,
      );
    } catch (_) {
      socket.close();
      rethrow;
    }
  }

  void _removeListener(Listener l) {
    _listeners.remove(l);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final l in _listeners.toList()) {
      await l.close();
    }
    _listeners.clear();
  }
}

/// A libp2p QUIC listener.
///
/// All handshake and packet-demultiplexing logic now lives in
/// `transpiled_quic_go`'s `QuicServer`, whose Go counterpart is
/// `quic-go`'s server-side `Transport`/`Listener` pair; this class keeps only
/// what is libp2p's own business, matching how go-libp2p's
/// `p2p/transport/quic/listener.go` wraps quic-go's `Listener.Accept`: owning
/// the socket subscription, feeding every datagram to the [quicServer], and
/// authenticating each accepted connection's peer from its TLS certificate
/// chain before handing out a [CapableConn].
class _QuicListener implements Listener {
  _QuicListener({
    required this.transport,
    required this.socket,
    required this.localPeer,
    required this.quicServer,
    required this.listenAddr,
  }) {
    _subscription = socket.listen(_onSocketEvent, onError: (Object _) {});
    unawaited(_acceptLoop());
  }

  final QuicTransport transport;
  final RawDatagramSocket socket;
  final PeerId localPeer;
  final quicgo.QuicServer quicServer;
  final Multiaddr listenAddr;

  late final StreamSubscription<RawSocketEvent> _subscription;
  final List<Completer<CapableConn>> _acceptQueue = [];
  final List<CapableConn> _pendingConns = [];
  bool _closed = false;

  void _onSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _closed) return;
    final datagram = socket.receive();
    if (datagram == null || datagram.data.isEmpty) return;
    quicServer.handleDatagram(datagram);
  }

  /// Wraps every connection [quicServer] accepts into a libp2p [CapableConn],
  /// deriving the remote peer from the certificate chain TLS authenticated --
  /// exactly what `pubKeyFromCertChain` checks on the dialling side. A
  /// connection whose chain does not carry a valid libp2p identity is closed
  /// and never surfaced, matching go-libp2p's own transport-level check on
  /// top of quic-go's generic `Accept`.
  Future<void> _acceptLoop() async {
    while (true) {
      quicgo.QuicConn conn;
      try {
        conn = await quicServer.accept();
      } on quicgo.QuicServerClosedException {
        return;
      }
      try {
        final remotePubKey = await pubKeyFromCertChain(conn.peerCertificates);
        final remotePeer = PeerId.fromPubKey(remotePubKey);
        final wrapped = _QuicConn(
          transport: transport,
          session: conn,
          localPeer: localPeer,
          remotePeer: remotePeer,
          remotePubKey: remotePubKey,
          localMultiaddr: multiaddr(),
          remoteMultiaddr: Multiaddr.parse(
            '/${conn.remoteAddress.type == InternetAddressType.IPv6 ? 'ip6' : 'ip4'}'
            '/${conn.remoteAddress.address}/udp/${conn.remotePort}/quic-v1',
          ),
          direction: Direction.inbound,
        );
        if (_acceptQueue.isNotEmpty) {
          _acceptQueue.removeAt(0).complete(wrapped);
        } else {
          _pendingConns.add(wrapped);
        }
      } catch (e, st) {
        dev.log(
          'inbound QUIC connection failed libp2p authentication',
          name: 'quic',
          error: e,
          stackTrace: st,
        );
        await conn.close();
      }
    }
  }

  @override
  Future<CapableConn> accept() async {
    if (_closed) throw const ListenerClosedException();
    if (_pendingConns.isNotEmpty) {
      return _pendingConns.removeAt(0);
    }
    final completer = Completer<CapableConn>();
    _acceptQueue.add(completer);
    return completer.future;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription.cancel();
    await quicServer.close();
    socket.close();
    for (final c in _acceptQueue) {
      c.completeError(const ListenerClosedException());
    }
    _acceptQueue.clear();
    for (final conn in _pendingConns) {
      await conn.close();
    }
    _pendingConns.clear();
    transport._removeListener(this);
  }

  @override
  Multiaddr multiaddr() {
    return Multiaddr.parse(
      '/ip4/${socket.address.address}/udp/${socket.port}/quic-v1',
    );
  }
}

class _QuicConn implements CapableConn {
  _QuicConn({
    required Transport transport,
    required quicgo.QuicConn session,
    required PeerId localPeer,
    required PeerId remotePeer,
    required PubKey remotePubKey,
    required Multiaddr localMultiaddr,
    required Multiaddr remoteMultiaddr,
    required Direction direction,
  }) : _transport = transport,
       _session = session,
       _localPeer = localPeer,
       _remotePeer = remotePeer,
       _remotePubKey = remotePubKey,
       _localMultiaddr = localMultiaddr,
       _remoteMultiaddr = remoteMultiaddr,
       _direction = direction,
       _opened = DateTime.now();

  final Transport _transport;
  final quicgo.QuicConn _session;
  final PeerId _localPeer;
  final PeerId _remotePeer;
  final PubKey _remotePubKey;
  final Multiaddr _localMultiaddr;
  final Multiaddr _remoteMultiaddr;
  final Direction _direction;
  final DateTime _opened;

  /// Feeds this connection a datagram that a shared listener socket
  /// demultiplexed to this peer.
  void handleDatagram(Uint8List bytes) => _session.handleDatagram(bytes);

  @override
  Transport transport() => _transport;

  @override
  PeerId localPeer() => _localPeer;

  @override
  PeerId remotePeer() => _remotePeer;

  @override
  PubKey remotePublicKey() => _remotePubKey;

  @override
  Multiaddr localMultiaddr() => _localMultiaddr;

  @override
  Multiaddr remoteMultiaddr() => _remoteMultiaddr;

  @override
  bool get isClosed => _session.isClosed;

  @override
  ConnectionState connState() => const ConnectionState(
    streamMultiplexer: 'quic',
    security: tlsProtocolId,
    transport: 'quic-v1',
  );

  @override
  ConnStats stat() => ConnStats(
    direction: _direction,
    opened: _opened,
    numStreams: _session.openStreamCount,
  );

  @override
  ConnScope scope() => const NullScope();

  @override
  Future<NetworkStream> openStream() async =>
      _QuicStream(conn: this, stream: _session.openStream());

  @override
  Future<NetworkStream> acceptStream() async =>
      _QuicStream(conn: this, stream: await _session.acceptStream());

  @override
  Future<void> close() => _session.close();
}

/// Adapts a QUIC stream to libp2p's [NetworkStream].
///
/// QUIC multiplexes natively, so a libp2p stream *is* a QUIC stream: no yamux
/// frame sits in between, and this adapter only maps the two APIs onto each
/// other.
class _QuicStream implements NetworkStream {
  _QuicStream({required _QuicConn conn, required quicgo.QuicStream stream})
    : _conn = conn,
      _stream = stream,
      _opened = DateTime.now();

  final _QuicConn _conn;
  final quicgo.QuicStream _stream;
  final DateTime _opened;
  final BytesBuilder _surplus = BytesBuilder(copy: false);
  ProtocolId _protocol = '';
  bool _closed = false;

  @override
  String get id => _stream.id.toString();

  @override
  ProtocolId protocol() => _protocol;

  @override
  Future<void> setProtocol(ProtocolId id) async {
    _protocol = id;
  }

  @override
  Conn conn() => _conn;

  @override
  StreamScope scope() => const NullScope();

  @override
  Stats stat() => Stats(direction: _conn.stat().direction, opened: _opened);

  @override
  bool get isClosed => _closed;

  @override
  Future<Uint8List> read([int? maxLength]) async {
    if (_surplus.isEmpty) {
      if (_closed) return Uint8List(0);
      try {
        _surplus.add(await _stream.read());
      } on quicgo.ConnectionClosedException {
        return Uint8List(0);
      } on quicgo.StreamResetException {
        return Uint8List(0);
      }
    }
    final available = _surplus.takeBytes();
    if (maxLength == null || available.length <= maxLength) return available;
    _surplus.add(Uint8List.sublistView(available, maxLength));
    return Uint8List.sublistView(available, 0, maxLength);
  }

  @override
  Future<void> write(Uint8List data) async {
    if (_closed) throw StateError('Stream is closed');
    _stream.write(data);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _stream.closeWrite();
  }

  @override
  Future<void> reset() async {
    _closed = true;
    _stream.reset();
  }

  @override
  Future<void> closeRead() async {}

  @override
  Future<void> closeWrite() async {
    _stream.closeWrite();
  }

  @override
  Future<void> resetWithError(StreamErrorCode errorCode) async {
    _closed = true;
    _stream.reset(errorCode);
  }

  @override
  Future<void> setDeadline(DateTime? time) async {}

  @override
  Future<void> setReadDeadline(DateTime? time) async {}

  @override
  Future<void> setWriteDeadline(DateTime? time) async {}
}
