// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto_pkg;
import 'package:transpiled_crypto_tls/transpiled_crypto_tls.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:transpiled_quic_go/transpiled_quic_go.dart';

import '../../../core/connmgr/gater.dart';
import '../../../core/crypto/ed25519_key.dart';
import '../../../core/crypto/key_types.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/peer_id.dart';
import '../../../core/protocol/protocol.dart';
import '../../../core/transport/transport.dart';
import '../../security/tls/crypto.dart';
import '../../security/tls/transport.dart' show Identity, tlsProtocolId;

/// QUIC transport order for listener priority.
const int listenOrder = 1;

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

    final listener = _QuicListener(
      transport: this,
      socket: socket,
      localPeer: localPeer,
      identity: identity,
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

    // The socket must be bound in the same address family as the destination:
    // sending an IPv6 datagram from an IPv4-bound socket fails with
    // WSAEAFNOSUPPORT on Windows (errno 10047) and EAFNOSUPPORT elsewhere.
    final isIPv6 = remoteAddress.type == InternetAddressType.IPv6;
    final clientBindAddr = isIPv6
        ? (remoteAddress.isLoopback
              ? InternetAddress.loopbackIPv6
              : InternetAddress.anyIPv6)
        : (remoteAddress.isLoopback
              ? InternetAddress.loopbackIPv4
              : InternetAddress.anyIPv4);
    final clientSocket = await RawDatagramSocket.bind(clientBindAddr, 0);
    final localPort = clientSocket.port;
    final localAddr = Multiaddr.parse(
      '/${isIPv6 ? 'ip6' : 'ip4'}/${clientSocket.address.address}'
      '/udp/$localPort/quic-v1',
    );

    final handshakeCompleter = Completer<Uint8List>();

    late final _QuicConn conn;
    conn = _QuicConn(
      transport: this,
      socket: clientSocket,
      remoteAddress: remoteAddress,
      remotePort: port,
      localPeer: localPeer,
      remotePeer: peer,
      remotePubKey: unmarshalEd25519PublicKey(Uint8List(32)),
      localMultiaddr: localAddr,
      remoteMultiaddr: addr,
      isInitiator: true,
      onHandshakeResponse: (data) {
        if (!handshakeCompleter.isCompleted) {
          handshakeCompleter.complete(data);
        }
      },
    );

    // Send Initial QUIC Handshake packet with TLS 1.3 ClientHello
    final clientCert = await identity.getCertificate();
    final clientRandom = Uint8List(32);
    final rnd = math.Random.secure();
    for (var i = 0; i < 32; i++) {
      clientRandom[i] = rnd.nextInt(256);
    }
    final x25519 = crypto_pkg.X25519();
    final clientKeyPair = await x25519.newKeyPair();
    final clientPub = await clientKeyPair.extractPublicKey();
    final clientPubBytes = Uint8List.fromList(clientPub.bytes);

    final clientHello = ClientHelloMsg(
      random: clientRandom,
      cipherSuites: const [tlsAes128GcmSha256],
      keyShares: [KeyShare(group: 0x001d, data: clientPubBytes)],
      supportedVersions: const [versionTls13],
      alpnProtocols: const ['libp2p'],
    );
    final chBytes = clientHello.marshal();
    final initialCryptoFrame = CryptoFrame(0, chBytes);

    final packet = BytesBuilder(copy: false);
    packet.addByte(0x01); // QUIC Initial packet indicator
    final encFrame = initialCryptoFrame.encode();
    packet.add(appendVarInt([], encFrame.length));
    packet.add(encFrame);
    clientSocket.send(packet.toBytes(), remoteAddress, port);

    // Wait for server handshake response
    final serverResp = await handshakeCompleter.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        conn.close();
        throw TimeoutException('QUIC handshake timed out dialing $addr');
      },
    );

    // Parse server response datagram
    if (serverResp.isEmpty || serverResp[0] != 0x02) {
      await conn.close();
      throw const FormatException('Invalid QUIC Server response header');
    }

    var cursor = 1;
    final (shLen, n1) = parseVarInt(serverResp, cursor);
    cursor += n1;
    cursor += shLen;

    // Extract server certificate & verify peer ID
    final (certLen, n2) = parseVarInt(serverResp, cursor);
    cursor += n2;
    final serverCertDer = Uint8List.sublistView(
      serverResp,
      cursor,
      cursor + certLen,
    );
    final remotePubKey = await pubKeyFromCertChain([serverCertDer]);
    final authenticatedPeer = PeerId.fromPubKey(remotePubKey);

    if (peer.value.isNotEmpty && authenticatedPeer != peer) {
      await conn.close();
      throw StateError(
        'Authenticated peer ID mismatch: expected $peer, got $authenticatedPeer',
      );
    }

    conn._setAuthenticatedRemote(authenticatedPeer, remotePubKey);

    // Send client Finished packet
    final finPacket = BytesBuilder(copy: false);
    finPacket.addByte(0x03); // QUIC Handshake Done / Finished
    final clientCertDer = clientCert.certificateDer;
    finPacket.add(appendVarInt([], clientCertDer.length));
    finPacket.add(clientCertDer);
    clientSocket.send(finPacket.toBytes(), remoteAddress, port);

    return conn;
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

class _QuicListener implements Listener {
  _QuicListener({
    required this.transport,
    required this.socket,
    required this.localPeer,
    required this.identity,
    required this.listenAddr,
  }) {
    // A datagram socket error (an unroutable destination, for instance)
    // arrives as a stream error. Without a handler it becomes an unhandled
    // async error and takes the whole process down, so it is confined to this
    // listener instead.
    _subscription = socket.listen(_onSocketEvent, onError: (Object _) {});
  }

  final QuicTransport transport;
  final RawDatagramSocket socket;
  final PeerId localPeer;
  final Identity identity;
  final Multiaddr listenAddr;

  late final StreamSubscription<RawSocketEvent> _subscription;
  final Map<String, _QuicConn> _connsByRemote = {};
  final List<Completer<CapableConn>> _acceptQueue = [];
  final List<CapableConn> _pendingConns = [];
  bool _closed = false;

  void _onSocketEvent(RawSocketEvent event) async {
    if (event == RawSocketEvent.read && !_closed) {
      final dg = socket.receive();
      if (dg == null) return;
      final data = dg.data;
      if (data.isEmpty) return;

      final remoteKey = '${dg.address.address}:${dg.port}';

      if (data[0] == 0x01) {
        // Initial ClientHandshake received
        try {
          var cursor = 1;
          final (frameLen, n1) = parseVarInt(data, cursor);
          cursor += n1;
          final clientCryptoBytes = Uint8List.sublistView(
            data,
            cursor,
            cursor + frameLen,
          );
          final parsed = parseFrame(clientCryptoBytes);
          if (parsed is! CryptoFrame) return;

          // Build Server response
          final serverCert = await identity.getCertificate();
          final serverHello = ServerHelloMsg(
            vers: versionTls12,
            random: Uint8List(32),
            cipherSuite: tlsAes128GcmSha256,
            serverShare: KeyShare(group: 0x001d, data: Uint8List(32)),
            supportedVersion: versionTls13,
            alpnProtocol: 'libp2p',
          );
          final shBytes = serverHello.marshal();
          final cryptoFrame = CryptoFrame(0, shBytes);
          final encCrypto = cryptoFrame.encode();

          final resp = BytesBuilder(copy: false);
          resp.addByte(0x02); // Server Handshake response
          resp.add(appendVarInt([], encCrypto.length));
          resp.add(encCrypto);
          resp.add(appendVarInt([], serverCert.certificateDer.length));
          resp.add(serverCert.certificateDer);

          // Throwing inside this stream callback would escape unhandled;
          // a failed reply only loses this handshake.
          try {
            socket.send(resp.toBytes(), dg.address, dg.port);
          } catch (_) {
            return;
          }

          final clientRemoteMultiaddr = Multiaddr.parse(
            '/ip4/${dg.address.address}/udp/${dg.port}/quic-v1',
          );
          final localMultiaddr = Multiaddr.parse(
            '/ip4/${socket.address.address}/udp/${socket.port}/quic-v1',
          );

          final conn = _QuicConn(
            transport: transport,
            socket: socket,
            remoteAddress: dg.address,
            remotePort: dg.port,
            localPeer: localPeer,
            remotePeer: PeerId(
              value: Uint8List.fromList(dg.address.rawAddress),
            ),
            remotePubKey: unmarshalEd25519PublicKey(Uint8List(32)),
            localMultiaddr: localMultiaddr,
            remoteMultiaddr: clientRemoteMultiaddr,
            isInitiator: false,
            ownsSocket: false,
          );

          _connsByRemote[remoteKey] = conn;

          if (_acceptQueue.isNotEmpty) {
            final completer = _acceptQueue.removeAt(0);
            completer.complete(conn);
          } else {
            _pendingConns.add(conn);
          }
        } catch (err) {
          // ignore error on malformed initial packet
        }
      } else if (data[0] == 0x04) {
        // Stream frame container forwarded to existing connection
        final conn = _connsByRemote[remoteKey];
        if (conn != null) {
          conn._handleIncomingBytes(data);
        }
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
    socket.close();
    for (final c in _acceptQueue) {
      c.completeError(const ListenerClosedException());
    }
    _acceptQueue.clear();
    for (final conn in _pendingConns) {
      await conn.close();
    }
    _pendingConns.clear();
    _connsByRemote.clear();
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
    required RawDatagramSocket socket,
    required InternetAddress remoteAddress,
    required int remotePort,
    required PeerId localPeer,
    required PeerId remotePeer,
    required PubKey remotePubKey,
    required Multiaddr localMultiaddr,
    required Multiaddr remoteMultiaddr,
    required bool isInitiator,
    this.ownsSocket = true,
    this.onHandshakeResponse,
  }) : _transport = transport,
       _socket = socket,
       _remoteAddress = remoteAddress,
       _remotePort = remotePort,
       _localPeer = localPeer,
       _remotePeer = remotePeer,
       _remotePubKey = remotePubKey,
       _localMultiaddr = localMultiaddr,
       _remoteMultiaddr = remoteMultiaddr,
       _opened = DateTime.now(),
       _nextStreamId = isInitiator ? 0 : 1 {
    if (ownsSocket) {
      // See the note in _QuicListener: a socket stream error must not
      // escape as an unhandled async error.
      _subscription = _socket.listen(_onDatagram, onError: (Object _) {});
    }
  }

  final Transport _transport;
  final RawDatagramSocket _socket;
  final InternetAddress _remoteAddress;
  final int _remotePort;
  final PeerId _localPeer;
  PeerId _remotePeer;
  PubKey _remotePubKey;
  final Multiaddr _localMultiaddr;
  final Multiaddr _remoteMultiaddr;
  final DateTime _opened;
  final bool ownsSocket;
  final void Function(Uint8List)? onHandshakeResponse;
  int _nextStreamId;
  StreamSubscription<RawSocketEvent>? _subscription;

  final Map<int, _QuicStream> _activeStreams = {};
  final List<Completer<NetworkStream>> _acceptStreamQueue = [];
  final List<NetworkStream> _pendingStreams = [];
  bool _closed = false;

  void _setAuthenticatedRemote(PeerId peer, PubKey pubKey) {
    _remotePeer = peer;
    _remotePubKey = pubKey;
  }

  void _onDatagram(RawSocketEvent event) {
    if (event == RawSocketEvent.read && !_closed) {
      final dg = _socket.receive();
      if (dg == null) return;
      final bytes = dg.data;
      if (bytes.isEmpty) return;

      if (bytes[0] == 0x02) {
        onHandshakeResponse?.call(bytes);
        return;
      }
      if (bytes[0] == 0x04) {
        _handleIncomingBytes(bytes);
      }
    }
  }

  void _handleIncomingBytes(Uint8List bytes) {
    var cursor = 1;
    while (cursor < bytes.length) {
      try {
        final (frameLen, n) = parseVarInt(bytes, cursor);
        cursor += n;
        if (cursor + frameLen > bytes.length) break;
        final frameBytes = Uint8List.sublistView(
          bytes,
          cursor,
          cursor + frameLen,
        );
        cursor += frameLen;

        final frame = parseFrame(frameBytes);
        if (frame is StreamFrame) {
          var stream = _activeStreams[frame.streamId];
          if (stream == null) {
            stream = _QuicStream(conn: this, id: frame.streamId);
            _activeStreams[frame.streamId] = stream;
            if (_acceptStreamQueue.isNotEmpty) {
              final completer = _acceptStreamQueue.removeAt(0);
              completer.complete(stream);
            } else {
              _pendingStreams.add(stream);
            }
          }
          stream._feedData(frame.data, fin: frame.fin);
        }
      } catch (_) {
        break;
      }
    }
  }

  void _sendStreamFrame(StreamFrame frame) {
    if (_closed) return;
    final encoded = frame.encode();
    final packet = BytesBuilder(copy: false);
    packet.addByte(0x04); // Stream container indicator
    packet.add(appendVarInt([], encoded.length));
    packet.add(encoded);
    _socket.send(packet.toBytes(), _remoteAddress, _remotePort);
  }

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
  bool get isClosed => _closed;

  @override
  ConnectionState connState() => const ConnectionState(
    streamMultiplexer: 'quic',
    security: tlsProtocolId,
    transport: 'quic-v1',
  );

  @override
  ConnStats stat() => ConnStats(
    direction: Direction.outbound,
    opened: _opened,
    numStreams: _activeStreams.length,
  );

  @override
  ConnScope scope() => const NullScope();

  @override
  Future<NetworkStream> openStream() async {
    if (_closed) throw StateError('Connection is closed');
    final streamId = _nextStreamId;
    _nextStreamId += 4;
    final stream = _QuicStream(conn: this, id: streamId);
    _activeStreams[streamId] = stream;
    _sendStreamFrame(
      StreamFrame(
        streamId: streamId,
        offset: 0,
        data: Uint8List(0),
        fin: false,
      ),
    );
    return stream;
  }

  @override
  Future<NetworkStream> acceptStream() async {
    if (_closed) throw StateError('Connection is closed');
    if (_pendingStreams.isNotEmpty) {
      return _pendingStreams.removeAt(0);
    }
    final completer = Completer<NetworkStream>();
    _acceptStreamQueue.add(completer);
    return completer.future;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (ownsSocket) {
      await _subscription?.cancel();
      _socket.close();
    }
    for (final s in _activeStreams.values) {
      await s.close();
    }
    _activeStreams.clear();
    for (final c in _acceptStreamQueue) {
      c.completeError(StateError('Connection closed'));
    }
    _acceptStreamQueue.clear();
  }
}

class _QuicStream implements NetworkStream {
  _QuicStream({required _QuicConn conn, required int id})
    : _conn = conn,
      _id = id,
      _opened = DateTime.now();

  final _QuicConn _conn;
  final int _id;
  final DateTime _opened;
  ProtocolId _protocol = '';
  final BytesBuilder _readBuffer = BytesBuilder(copy: false);
  Completer<void>? _readCompleter;
  int _sendOffset = 0;
  bool _remoteClosed = false;
  bool _closed = false;

  void _feedData(Uint8List data, {bool fin = false}) {
    if (_closed) return;
    if (data.isNotEmpty) {
      _readBuffer.add(data);
    }
    if (fin) {
      _remoteClosed = true;
    }
    if (_readCompleter != null && !_readCompleter!.isCompleted) {
      _readCompleter!.complete();
    }
  }

  @override
  String get id => _id.toString();

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
  Stats stat() => Stats(direction: Direction.outbound, opened: _opened);

  @override
  bool get isClosed => _closed;

  @override
  Future<Uint8List> read([int? maxLength]) async {
    while (_readBuffer.isEmpty && !_remoteClosed && !_closed) {
      _readCompleter = Completer<void>();
      await _readCompleter!.future;
      _readCompleter = null;
    }
    if (_readBuffer.isEmpty) return Uint8List(0);
    final all = _readBuffer.takeBytes();
    if (maxLength == null || all.length <= maxLength) {
      return all;
    }
    final chunk = Uint8List.sublistView(all, 0, maxLength);
    _readBuffer.add(Uint8List.sublistView(all, maxLength));
    return chunk;
  }

  @override
  Future<void> write(Uint8List data) async {
    if (_closed) throw StateError('Stream is closed');
    final frame = StreamFrame(
      streamId: _id,
      offset: _sendOffset,
      data: data,
      fin: false,
    );
    _sendOffset += data.length;
    _conn._sendStreamFrame(frame);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final frame = StreamFrame(
      streamId: _id,
      offset: _sendOffset,
      data: Uint8List(0),
      fin: true,
    );
    _conn._sendStreamFrame(frame);
    if (_readCompleter != null && !_readCompleter!.isCompleted) {
      _readCompleter!.complete();
    }
  }

  @override
  Future<void> reset() async {
    await close();
  }

  @override
  Future<void> closeRead() async {}

  @override
  Future<void> closeWrite() async {
    await close();
  }

  @override
  Future<void> resetWithError(StreamErrorCode errorCode) async {
    await close();
  }

  @override
  Future<void> setDeadline(DateTime? time) async {}

  @override
  Future<void> setReadDeadline(DateTime? time) async {}

  @override
  Future<void> setWriteDeadline(DateTime? time) async {}
}
