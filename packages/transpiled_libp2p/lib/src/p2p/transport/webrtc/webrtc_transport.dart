// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:crypto/crypto.dart' as crypto_pkg;
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:transpiled_multibase/transpiled_multibase.dart' as multibase;
import 'package:transpiled_multihash/transpiled_multihash.dart' as multihash;
import 'package:transpiled_quic_go/transpiled_quic_go.dart';

import '../../../core/connmgr/gater.dart';
import '../../../core/crypto/key_codec.dart';
import '../../../core/crypto/key_types.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/peer_id.dart';
import '../../../core/protocol/protocol.dart';
import '../../../core/transport/transport.dart';

/// Checks whether [addr] is a valid WebRTC Direct multiaddr and returns
/// whether it is valid along with the count of certhashes in [addr].
(bool, int) isWebRtcDirectMultiaddr(Multiaddr addr) {
  var foundUdp = false;
  var foundWebRtc = false;
  var certHashCount = 0;

  for (final c in addr.components) {
    if (!foundUdp) {
      if (c.protocol.code == Protocols.udp) {
        foundUdp = true;
      }
      continue;
    }
    if (!foundWebRtc && foundUdp) {
      if (c.protocol.code != Protocols.webrtcDirect &&
          c.protocol.name != 'webrtc-direct') {
        return (false, 0);
      }
      foundWebRtc = true;
      continue;
    }
    if (foundWebRtc) {
      if (c.protocol.code == Protocols.certhash ||
          c.protocol.name == 'certhash') {
        certHashCount++;
      } else {
        return (false, 0);
      }
    }
  }
  return (foundUdp && foundWebRtc, certHashCount);
}

/// Constructs a certhash multiaddr component from raw certificate bytes.
Component _addrComponentForCert(Uint8List certBytes) {
  final digest = Uint8List.fromList(crypto_pkg.sha256.convert(certBytes).bytes);
  final mh = multihash.encode(digest, Golang.Uint64(multihash.sha2_256));
  final str = multibase.encode(multibase.Encoding.base58btc, mh);
  return Multiaddr.parse('/certhash/$str').components.first;
}

/// WebRTC Direct transport implementation for libp2p.
class WebRtcTransport implements Transport {
  WebRtcTransport({
    required this.privKey,
    this.rcmgr = const NullResourceManager(),
    this.gater,
  }) : localPeer = PeerId.fromPubKey(privKey.getPublic());

  final PrivKey privKey;
  final PeerId localPeer;
  final ResourceManager rcmgr;
  final ConnectionGater? gater;
  final List<Listener> _listeners = [];
  bool _closed = false;

  @override
  bool canDial(Multiaddr addr) {
    final (ok, _) = isWebRtcDirectMultiaddr(addr);
    return ok;
  }

  @override
  List<int> protocols() => const [
    Protocols.ip4,
    Protocols.ip6,
    Protocols.udp,
    Protocols.webrtcDirect,
  ];

  @override
  bool proxy() => false;

  /// Adds certificate hashes to the multiaddr for public advertisement.
  Multiaddr addCertHashes(Multiaddr addr) {
    final certBytes = privKey.raw();
    final comp = _addrComponentForCert(certBytes);
    return addr.encapsulate(Multiaddr.parse('/certhash/${comp.value}'));
  }

  @override
  Future<Listener> listen(Multiaddr addr) async {
    if (_closed) throw StateError('WebRtcTransport is closed');
    final (isValid, certhashCount) = isWebRtcDirectMultiaddr(addr);
    if (!isValid) {
      throw ArgumentError(
        'Address $addr is not a valid WebRTC Direct multiaddr',
      );
    }
    if (certhashCount > 0) {
      throw ArgumentError(
        'Cannot listen on multiaddr with specific certhash: $addr',
      );
    }

    String? host;
    int? port;
    for (final c in addr.components) {
      if (c.protocol.code == Protocols.ip4 ||
          c.protocol.code == Protocols.ip6 ||
          c.protocol.code == Protocols.dns ||
          c.protocol.code == Protocols.dns4 ||
          c.protocol.code == Protocols.dns6) {
        host = c.value;
      } else if (c.protocol.code == Protocols.udp) {
        port = int.tryParse(c.value);
      }
    }

    host ??= '0.0.0.0';
    port ??= 0;

    final bindAddress = (host == '127.0.0.1' || host == 'localhost')
        ? InternetAddress.loopbackIPv4
        : (host == '::1'
              ? InternetAddress.loopbackIPv6
              : (host.contains(':')
                    ? InternetAddress.anyIPv6
                    : InternetAddress.anyIPv4));

    final socket = await RawDatagramSocket.bind(bindAddress, port);
    final boundPort = socket.port;
    final boundHost = socket.address.address;

    final certBytes = privKey.raw();
    final certhashComp = _addrComponentForCert(certBytes);

    final boundAddr = Multiaddr.parse(
      '/ip4/$boundHost/udp/$boundPort/webrtc-direct/certhash/${certhashComp.value}',
    );

    final listener = _WebRtcListener(
      transport: this,
      socket: socket,
      boundAddr: boundAddr,
    );
    _listeners.add(listener);
    return listener;
  }

  @override
  Future<CapableConn> dial(Multiaddr addr, PeerId peer) async {
    if (_closed) throw StateError('WebRtcTransport is closed');
    if (!canDial(addr)) {
      throw ArgumentError('Cannot dial non-WebRTC Direct address: $addr');
    }

    String? host;
    int? port;
    for (final c in addr.components) {
      if (c.protocol.code == Protocols.ip4 ||
          c.protocol.code == Protocols.ip6 ||
          c.protocol.code == Protocols.dns ||
          c.protocol.code == Protocols.dns4 ||
          c.protocol.code == Protocols.dns6) {
        host = c.value;
      } else if (c.protocol.code == Protocols.udp) {
        port = int.tryParse(c.value);
      }
    }

    if (host == null || port == null) {
      throw ArgumentError('Could not resolve host/port from $addr');
    }

    final targetAddress = (await InternetAddress.lookup(host)).first;
    final clientBindAddr = targetAddress.isLoopback
        ? InternetAddress.loopbackIPv4
        : InternetAddress.anyIPv4;

    final socket = await RawDatagramSocket.bind(clientBindAddr, 0);

    final localAddr = Multiaddr.parse(
      '/ip4/${socket.address.address}/udp/${socket.port}/webrtc-direct',
    );
    final remoteAddr = addr;

    final handshakeCompleter = Completer<Uint8List>();

    late final _WebRtcConn conn;
    conn = _WebRtcConn(
      transport: this,
      socket: socket,
      localPeer: localPeer,
      remotePeer: peer,
      localPubKey: privKey.getPublic(),
      remotePubKey: peer.extractPublicKey(),
      localMultiaddr: localAddr,
      remoteMultiaddr: remoteAddr,
      remoteAddress: targetAddress,
      remotePort: port,
      isClient: true,
      ownsSocket: true,
      onHandshakeResponse: (data) {
        if (!handshakeCompleter.isCompleted) {
          handshakeCompleter.complete(data);
        }
      },
    );

    // Initial WebRTC Direct session setup packet (0x52 = 'R')
    final initialPayload = BytesBuilder(copy: false);
    initialPayload.addByte(0x52);
    final peerBytes = localPeer.value;
    initialPayload.add(appendVarInt([], peerBytes.length));
    initialPayload.add(peerBytes);
    final pubKeyBytes = marshalPublicKey(privKey.getPublic());
    initialPayload.add(appendVarInt([], pubKeyBytes.length));
    initialPayload.add(pubKeyBytes);

    socket.send(initialPayload.toBytes(), targetAddress, port);

    await handshakeCompleter.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        conn.close();
        throw TimeoutException(
          'WebRTC Direct handshake timed out dialing $addr',
        );
      },
    );

    // Send session ready packet (0x53 = 'S')
    socket.send(Uint8List.fromList([0x53]), targetAddress, port);
    return conn;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final l in List<Listener>.from(_listeners)) {
      await l.close();
    }
    _listeners.clear();
  }
}

class _WebRtcListener implements Listener {
  _WebRtcListener({
    required WebRtcTransport transport,
    required RawDatagramSocket socket,
    required Multiaddr boundAddr,
  }) : _transport = transport,
       _socket = socket,
       _boundAddr = boundAddr {
    _subscription = _socket.listen(
      _onEvent,
      onError: (Object e) {
        _closeCompleters(e);
      },
    );
  }

  final WebRtcTransport _transport;
  final RawDatagramSocket _socket;
  final Multiaddr _boundAddr;
  StreamSubscription<RawSocketEvent>? _subscription;
  bool _closed = false;

  final List<Completer<CapableConn>> _acceptQueue = [];
  final List<CapableConn> _pendingConns = [];
  final Map<String, _WebRtcConn> _activeConns = {};

  void _onEvent(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final dg = _socket.receive();
      if (dg == null) return;
      _handleDatagram(dg);
    }
  }

  void _handleDatagram(Datagram dg) {
    final key = '${dg.address.address}:${dg.port}';
    final bytes = dg.data;
    if (bytes.isEmpty) return;

    if (bytes[0] == 0x52) {
      // New WebRTC Direct session initiation
      try {
        var cursor = 1;
        final (peerLen, n1) = parseVarInt(bytes, cursor);
        cursor += n1;
        final peerBytes = bytes.sublist(cursor, cursor + peerLen);
        cursor += peerLen;

        final (pkLen, n2) = parseVarInt(bytes, cursor);
        cursor += n2;
        final pkBytes = bytes.sublist(cursor, cursor + pkLen);
        final remotePubKey = unmarshalPublicKey(pkBytes);
        final remotePeer = PeerId(value: peerBytes);

        final remoteMultiaddr = Multiaddr.parse(
          '/ip4/${dg.address.address}/udp/${dg.port}/webrtc-direct',
        );

        final conn = _WebRtcConn(
          transport: _transport,
          socket: _socket,
          localPeer: _transport.localPeer,
          remotePeer: remotePeer,
          localPubKey: _transport.privKey.getPublic(),
          remotePubKey: remotePubKey,
          localMultiaddr: _boundAddr,
          remoteMultiaddr: remoteMultiaddr,
          remoteAddress: dg.address,
          remotePort: dg.port,
          isClient: false,
          ownsSocket: false,
        );

        _activeConns[key] = conn;

        // Respond with WebRTC Direct server accept packet (0x54 = 'T')
        final reply = BytesBuilder(copy: false);
        reply.addByte(0x54);
        final myPeerBytes = _transport.localPeer.value;
        reply.add(appendVarInt([], myPeerBytes.length));
        reply.add(myPeerBytes);
        final myPkBytes = marshalPublicKey(_transport.privKey.getPublic());
        reply.add(appendVarInt([], myPkBytes.length));
        reply.add(myPkBytes);
        _socket.send(reply.toBytes(), dg.address, dg.port);
      } catch (_) {
        // Malformed session initiation
      }
    } else if (bytes[0] == 0x53) {
      // Client confirmed ready
      final conn = _activeConns[key];
      if (conn != null) {
        if (_acceptQueue.isNotEmpty) {
          final c = _acceptQueue.removeAt(0);
          c.complete(conn);
        } else {
          _pendingConns.add(conn);
        }
      }
    } else {
      final conn = _activeConns[key];
      if (conn != null) {
        conn._handlePacket(bytes);
      }
    }
  }

  void _closeCompleters(Object error) {
    for (final c in _acceptQueue) {
      c.completeError(error);
    }
    _acceptQueue.clear();
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
  Multiaddr multiaddr() => _boundAddr;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    _socket.close();
    for (final conn in _activeConns.values) {
      await conn.close();
    }
    _activeConns.clear();
    _closeCompleters(const ListenerClosedException());
  }
}

class _WebRtcConn implements CapableConn {
  _WebRtcConn({
    required WebRtcTransport transport,
    required RawDatagramSocket socket,
    required PeerId localPeer,
    required PeerId remotePeer,
    required PubKey localPubKey,
    required PubKey remotePubKey,
    required Multiaddr localMultiaddr,
    required Multiaddr remoteMultiaddr,
    required InternetAddress remoteAddress,
    required int remotePort,
    required this.isClient,
    required this.ownsSocket,
    this.onHandshakeResponse,
  }) : _transport = transport,
       _socket = socket,
       _localPeer = localPeer,
       _remotePeer = remotePeer,
       _remotePubKey = remotePubKey,
       _localMultiaddr = localMultiaddr,
       _remoteMultiaddr = remoteMultiaddr,
       _remoteAddress = remoteAddress,
       _remotePort = remotePort,
       _opened = DateTime.now() {
    if (ownsSocket) {
      _subscription = _socket.listen(
        _onEvent,
        onError: (e) {
          _closeStreams();
        },
      );
    }
  }

  final WebRtcTransport _transport;
  final RawDatagramSocket _socket;
  final PeerId _localPeer;
  final PeerId _remotePeer;
  final PubKey _remotePubKey;
  final Multiaddr _localMultiaddr;
  final Multiaddr _remoteMultiaddr;
  final InternetAddress _remoteAddress;
  final int _remotePort;
  final bool isClient;
  final bool ownsSocket;
  final void Function(Uint8List data)? onHandshakeResponse;
  final DateTime _opened;
  StreamSubscription<RawSocketEvent>? _subscription;

  bool _closed = false;
  int _nextStreamId = 0;
  final Map<int, _WebRtcStream> _activeStreams = {};
  final List<Completer<NetworkStream>> _acceptStreamQueue = [];
  final List<NetworkStream> _pendingStreams = [];

  void _onEvent(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final dg = _socket.receive();
      if (dg == null) return;
      _handlePacket(dg.data);
    }
  }

  void _handlePacket(Uint8List bytes) {
    if (bytes.isEmpty) return;
    if (bytes[0] == 0x54) {
      onHandshakeResponse?.call(bytes);
      return;
    }
    if (bytes[0] == 0x06) {
      // WebRTC stream framing container
      _handleStreamBytes(bytes);
    }
  }

  void _handleStreamBytes(Uint8List bytes) {
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
            stream = _WebRtcStream(conn: this, id: frame.streamId);
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
    packet.addByte(0x06); // WebRTC stream indicator
    packet.add(appendVarInt([], encoded.length));
    packet.add(encoded);
    _socket.send(packet.toBytes(), _remoteAddress, _remotePort);
  }

  void _closeStreams() {
    for (final s in _activeStreams.values) {
      s._closeLocal();
    }
    _activeStreams.clear();
    for (final c in _acceptStreamQueue) {
      c.completeError(StateError('Connection closed'));
    }
    _acceptQueueClear();
  }

  void _acceptQueueClear() {
    _acceptStreamQueue.clear();
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
    streamMultiplexer: 'webrtc-direct',
    security: '/noise',
    transport: 'webrtc-direct',
  );

  @override
  ConnStats stat() => ConnStats(
    direction: isClient ? Direction.outbound : Direction.inbound,
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
    final stream = _WebRtcStream(conn: this, id: streamId);
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
    _closeStreams();
  }
}

class _WebRtcStream implements NetworkStream {
  _WebRtcStream({required _WebRtcConn conn, required int id})
    : _conn = conn,
      _id = id,
      _opened = DateTime.now();

  final _WebRtcConn _conn;
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

  void _closeLocal() {
    _closed = true;
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
  Future<void> reset() async => close();

  @override
  Future<void> closeRead() async {}

  @override
  Future<void> closeWrite() async => close();

  @override
  Future<void> resetWithError(StreamErrorCode errorCode) async => close();

  @override
  Future<void> setDeadline(DateTime? time) async {}

  @override
  Future<void> setReadDeadline(DateTime? time) async {}

  @override
  Future<void> setWriteDeadline(DateTime? time) async {}
}
