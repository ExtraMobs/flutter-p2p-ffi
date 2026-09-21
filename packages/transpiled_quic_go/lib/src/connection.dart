// Port of the reusable connection and stream layer of
// `github.com/quic-go/quic-go` (v0.60.0, revision
// 7612ad1036957cde45d672bebb8b9ec9c2e9b2a7): `connection.go`'s established
// (1-RTT) phase, `streams_map.go`'s stream-number arithmetic, and
// `frame_sorter.go`'s offset-ordered reassembly.
//
// Only the established phase lives here. Producing the 1-RTT keys is the
// handshake's job (`client_handshake.dart`); this file takes those keys and
// drives packets and streams over them, so every transport built on QUIC --
// libp2p's `/quic-v1` and the HTTP/3 stack that `/quic-v1/webtransport` needs
// -- shares one implementation instead of one per transport.
import 'dart:async';
import 'dart:collection';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';

import 'frames.dart';
import 'header.dart';
import 'initial_aead.dart';
import 'varint.dart';

/// Which side of the connection a peer is on, per quic-go's
/// `internal/protocol.Perspective`.
enum Perspective {
  /// The peer that initiated the connection.
  client,

  /// The peer that accepted the connection.
  server,
}

/// Thrown when an operation is attempted on a QUIC connection that has been
/// closed, locally or by the peer.
class ConnectionClosedException implements Exception {
  /// Creates a [ConnectionClosedException] with an optional [message].
  const ConnectionClosedException([this.message = 'QUIC connection is closed']);

  /// A human readable description of why the connection is gone.
  final String message;

  @override
  String toString() => 'ConnectionClosedException: $message';
}

/// Thrown when the peer resets a stream, per RFC 9000 section 19.4.
class StreamResetException implements Exception {
  /// Creates a [StreamResetException] for [streamId] with [errorCode].
  const StreamResetException(this.streamId, this.errorCode);

  /// The stream the peer reset.
  final int streamId;

  /// The application error code the peer sent.
  final int errorCode;

  @override
  String toString() =>
      'StreamResetException: stream $streamId reset with code $errorCode';
}

/// An established QUIC connection in its 1-RTT phase, per quic-go's `Conn`.
///
/// The connection owns the datagram flow for one peer: it unprotects incoming
/// packets with [receiveCipher], protects outgoing ones with [sendCipher],
/// acknowledges what it receives and routes STREAM frames to the [QuicStream]
/// they belong to.
class QuicConn {
  /// Wraps an already-handshaked QUIC connection.
  ///
  /// [socket] carries the datagrams, [remoteAddress] and [remotePort] name the
  /// peer, and [destConnectionId] is the connection ID the peer asked us to
  /// put on outgoing packets. When [socketSubscription] is given, this
  /// connection takes it over rather than subscribing again, so a handshake
  /// that was already reading the socket can hand it off without losing
  /// datagrams.
  QuicConn({
    required RawDatagramSocket socket,
    required InternetAddress remoteAddress,
    required int remotePort,
    required Uint8List destConnectionId,
    required Uint8List srcConnectionId,
    required QuicPacketCipher sendCipher,
    required QuicPacketCipher receiveCipher,
    required this.perspective,
    List<Uint8List> peerCertificates = const [],
    this.negotiatedProtocol,
    StreamSubscription<RawSocketEvent>? socketSubscription,
    this.ownsSocket = true,
  }) : peerCertificates = List<Uint8List>.unmodifiable(peerCertificates),
       _socket = socket,
       _remoteAddress = remoteAddress,
       _remotePort = remotePort,
       _destConnectionId = destConnectionId,
       _srcConnectionId = srcConnectionId,
       _sendCipher = sendCipher,
       _receiveCipher = receiveCipher {
    if (socketSubscription != null) {
      _subscription = socketSubscription..onData(_onSocketEvent);
    } else if (ownsSocket) {
      _subscription = _socket.listen(_onSocketEvent, onError: (Object _) {});
    }
    // A connection that does not own its socket is fed by whoever does --
    // a listener demultiplexing one shared socket across every connection it
    // accepted, calling [handleDatagram]. Subscribing here would be a second
    // listener on a single-subscription stream, which throws.
  }

  /// Whether this endpoint initiated the connection.
  final Perspective perspective;

  /// The peer's DER certificate chain, as TLS presented it during the
  /// handshake, per Go's `tls.ConnectionState.PeerCertificates`.
  final List<Uint8List> peerCertificates;

  /// The ALPN protocol the handshake settled on, per Go's
  /// `tls.ConnectionState.NegotiatedProtocol`.
  final String? negotiatedProtocol;

  /// Whether closing this connection also closes the underlying socket.
  ///
  /// A client owns its socket; a server listener shares one socket across
  /// every connection it accepted and keeps ownership of it.
  final bool ownsSocket;

  final RawDatagramSocket _socket;
  final InternetAddress _remoteAddress;
  final int _remotePort;
  final QuicPacketCipher _sendCipher;
  final QuicPacketCipher _receiveCipher;
  Uint8List _destConnectionId;
  final Uint8List _srcConnectionId;

  StreamSubscription<RawSocketEvent>? _subscription;
  bool _closed = false;
  String? _closeReason;
  int _nextPacketNumber = 0;

  final Map<int, QuicStream> _streams = {};
  final Queue<QuicStream> _pendingBidi = Queue<QuicStream>();
  final Queue<QuicStream> _pendingUni = Queue<QuicStream>();
  final Queue<Completer<QuicStream>> _bidiWaiters =
      Queue<Completer<QuicStream>>();
  final Queue<Completer<QuicStream>> _uniWaiters =
      Queue<Completer<QuicStream>>();

  int _nextBidiNum = 0;
  int _nextUniNum = 0;

  /// The connection ID this endpoint puts on outgoing packets.
  Uint8List get destConnectionId => Uint8List.fromList(_destConnectionId);

  /// The connection ID this endpoint asked the peer to use.
  Uint8List get srcConnectionId => Uint8List.fromList(_srcConnectionId);

  /// The peer's address, per Go's `(*Conn).RemoteAddr`.
  InternetAddress get remoteAddress => _remoteAddress;

  /// The peer's UDP port, the other half of Go's `(*Conn).RemoteAddr`.
  int get remotePort => _remotePort;

  /// Whether the connection has been closed.
  bool get isClosed => _closed;

  /// Why the peer closed the connection, or `null` when this side closed it
  /// or it is still open. Carries the CONNECTION_CLOSE error code, frame type
  /// and reason phrase, which is the only diagnosis a peer ever gives.
  String? get closeReason => _closeReason;

  ConnectionClosedException get _closedException =>
      ConnectionClosedException(_closeReason ?? 'QUIC connection is closed');

  /// How many streams are currently open on this connection.
  int get openStreamCount => _streams.length;

  /// Computes a stream ID from its stream number, per RFC 9000 section 2.1.
  ///
  /// The two low bits encode the initiator (bit 0: 0 client, 1 server) and the
  /// directionality (bit 1: 0 bidirectional, 1 unidirectional).
  static int streamIdFor({
    required int streamNumber,
    required Perspective initiator,
    required bool unidirectional,
  }) {
    final initiatorBit = initiator == Perspective.client ? 0 : 1;
    final directionBit = unidirectional ? 2 : 0;
    return (streamNumber * 4) | initiatorBit | directionBit;
  }

  /// Whether [streamId] names a unidirectional stream, per RFC 9000 section 2.1.
  static bool isUnidirectional(int streamId) => (streamId & 0x2) != 0;

  /// Which endpoint opened [streamId], per RFC 9000 section 2.1.
  static Perspective initiatorOf(int streamId) =>
      (streamId & 0x1) == 0 ? Perspective.client : Perspective.server;

  /// Opens a new bidirectional stream initiated by this endpoint.
  QuicStream openStream() => _openLocal(unidirectional: false);

  /// Opens a new unidirectional stream initiated by this endpoint.
  ///
  /// HTTP/3 needs these for its control stream and its two QPACK streams.
  QuicStream openUniStream() => _openLocal(unidirectional: true);

  QuicStream _openLocal({required bool unidirectional}) {
    if (_closed) throw _closedException;
    final number = unidirectional ? _nextUniNum++ : _nextBidiNum++;
    final id = streamIdFor(
      streamNumber: number,
      initiator: perspective,
      unidirectional: unidirectional,
    );
    final stream = QuicStream._(
      conn: this,
      id: id,
      writable: true,
      readable: !unidirectional,
    );
    _streams[id] = stream;
    return stream;
  }

  /// Waits for the peer to open a bidirectional stream.
  Future<QuicStream> acceptStream() {
    if (_closed) throw _closedException;
    if (_pendingBidi.isNotEmpty)
      return Future.value(_pendingBidi.removeFirst());
    final completer = Completer<QuicStream>();
    _bidiWaiters.add(completer);
    return completer.future;
  }

  /// Waits for the peer to open a unidirectional stream.
  Future<QuicStream> acceptUniStream() {
    if (_closed) throw _closedException;
    if (_pendingUni.isNotEmpty) return Future.value(_pendingUni.removeFirst());
    final completer = Completer<QuicStream>();
    _uniWaiters.add(completer);
    return completer.future;
  }

  void _onSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _closed) return;
    final datagram = _socket.receive();
    if (datagram == null || datagram.data.isEmpty) return;
    handleDatagram(datagram.data);
  }

  /// Processes one received datagram, unprotecting every packet coalesced in it.
  ///
  /// A listener that demultiplexes datagrams by connection ID before routing
  /// them calls this directly instead of letting the connection read the
  /// shared socket itself.
  void handleDatagram(Uint8List bytes) {
    var offset = 0;
    while (offset < bytes.length && !_closed) {
      final firstByte = bytes[offset];
      final remaining = Uint8List.sublistView(bytes, offset);

      if ((firstByte & 0x80) == 0) {
        // Short header: a 1-RTT packet, which is all this phase carries.
        try {
          final (header, payload) = _receiveCipher.open(
            remaining,
            destConnIdLen: _srcConnectionId.length,
          );
          _sendAck(header.packetNumber);
          _handleFrames(parseFrames(payload));
        } catch (_) {
          // A packet we cannot unprotect is discarded, per RFC 9000 s. 12.2.
        }
        return;
      }

      // A coalesced long-header packet belongs to an earlier encryption
      // level; skip past it to reach the 1-RTT packet behind it.
      final skipped = _longHeaderPacketLength(bytes, offset);
      if (skipped <= 0) return;
      offset += skipped;
    }
  }

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

  void _handleFrames(List<QuicFrame> frames) {
    for (final frame in frames) {
      if (frame is StreamFrame) {
        _streamFor(
          frame.streamId,
        )._receive(frame.offset, frame.data, frame.fin);
      } else if (frame is ResetStreamFrame) {
        _streams[frame.streamId]?._remoteReset(frame.applicationErrorCode);
      } else if (frame is NewConnectionIdFrame) {
        _destConnectionId = frame.connectionId;
      } else if (frame is ConnectionCloseFrame) {
        _closeReason =
            'peer closed the connection: '
            '${frame.isApplicationError ? 'application' : 'transport'} '
            'error 0x${frame.errorCode.toRadixString(16)} '
            'on frame type 0x${frame.frameType.toRadixString(16)}: '
            '"${frame.reasonPhrase}"';
        dev.log(_closeReason!, name: 'quic');
        close();
        return;
      }
    }
  }

  QuicStream _streamFor(int streamId) {
    final existing = _streams[streamId];
    if (existing != null) return existing;

    final unidirectional = isUnidirectional(streamId);
    final stream = QuicStream._(
      conn: this,
      id: streamId,
      writable: !unidirectional,
      readable: true,
    );
    _streams[streamId] = stream;

    final waiters = unidirectional ? _uniWaiters : _bidiWaiters;
    if (waiters.isNotEmpty) {
      waiters.removeFirst().complete(stream);
    } else {
      (unidirectional ? _pendingUni : _pendingBidi).add(stream);
    }
    return stream;
  }

  /// Protects [frames] into a single 1-RTT packet and sends it to the peer.
  void sendFrames(List<QuicFrame> frames) {
    if (_closed || frames.isEmpty) return;
    final payload = BytesBuilder(copy: false);
    for (final frame in frames) {
      payload.add(frame.encode());
    }
    final header = ExtendedHeader(
      isLongHeader: false,
      destConnectionId: _destConnectionId,
      packetNumber: _nextPacketNumber++,
      packetNumberLen: 4,
    );
    _socket.send(
      _sendCipher.seal(header: header, payload: payload.toBytes()),
      _remoteAddress,
      _remotePort,
    );
  }

  void _sendAck(int largestAcked) {
    sendFrames([AckFrame(largestAcked: largestAcked, firstAckRange: 0)]);
  }

  /// Closes the connection, telling the peer with a CONNECTION_CLOSE frame.
  Future<void> close([int errorCode = 0]) async {
    if (_closed) return;
    try {
      sendFrames([
        ConnectionCloseFrame(
          isApplicationError: true,
          errorCode: errorCode,
          frameType: 0,
          reasonPhrase: '',
        ),
      ]);
    } catch (_) {
      // A close that cannot be delivered still closes this side.
    }
    _closed = true;

    for (final stream in _streams.values) {
      stream._connectionClosed();
    }
    _streams.clear();
    for (final waiter in [..._bidiWaiters, ..._uniWaiters]) {
      if (!waiter.isCompleted) {
        waiter.completeError(_closedException);
      }
    }
    _bidiWaiters.clear();
    _uniWaiters.clear();
    _pendingBidi.clear();
    _pendingUni.clear();

    if (ownsSocket) {
      await _subscription?.cancel();
      _socket.close();
    }
    _subscription = null;
  }
}

/// One QUIC stream, per quic-go's `Stream`.
///
/// Reads are reassembled in offset order, so data that arrives out of order
/// is held back until the gap before it is filled rather than being delivered
/// scrambled.
class QuicStream {
  QuicStream._({
    required QuicConn conn,
    required this.id,
    required this.writable,
    required this.readable,
  }) : _conn = conn;

  /// The stream ID, per RFC 9000 section 2.1.
  final int id;

  /// Whether this endpoint may send on this stream.
  final bool writable;

  /// Whether this endpoint may receive on this stream.
  final bool readable;

  final QuicConn _conn;
  final SplayTreeMap<int, Uint8List> _outOfOrder =
      SplayTreeMap<int, Uint8List>();
  final BytesBuilder _readable = BytesBuilder(copy: false);
  final Queue<Completer<Uint8List>> _readers = Queue<Completer<Uint8List>>();

  int _readOffset = 0;
  int _writeOffset = 0;
  int? _finOffset;
  bool _finDelivered = false;
  bool _writeClosed = false;
  Object? _error;

  /// Whether the peer has finished sending and all its data was delivered.
  bool get isFinished => _finDelivered && _readable.isEmpty;

  /// How many bytes this endpoint has sent on this stream.
  int get writeOffset => _writeOffset;

  /// How many bytes have been reassembled in order from the peer.
  int get readOffset => _readOffset;

  void _receive(int offset, Uint8List data, bool fin) {
    if (_error != null) return;
    if (fin) _finOffset = offset + data.length;

    if (data.isNotEmpty) {
      if (offset + data.length <= _readOffset) {
        // Wholly retransmitted data that was already delivered.
      } else if (offset <= _readOffset) {
        _readable.add(Uint8List.sublistView(data, _readOffset - offset));
        _readOffset = offset + data.length;
        _drainOutOfOrder();
      } else {
        _outOfOrder[offset] = data;
      }
    }
    _deliver();
  }

  void _drainOutOfOrder() {
    while (_outOfOrder.isNotEmpty) {
      final first = _outOfOrder.firstKey()!;
      if (first > _readOffset) return;
      final buffered = _outOfOrder.remove(first)!;
      if (first + buffered.length <= _readOffset) continue;
      _readable.add(Uint8List.sublistView(buffered, _readOffset - first));
      _readOffset = first + buffered.length;
    }
  }

  void _deliver() {
    while (_readers.isNotEmpty) {
      if (_readable.isNotEmpty) {
        _readers.removeFirst().complete(_readable.takeBytes());
        continue;
      }
      if (_finOffset != null && _readOffset >= _finOffset!) {
        _finDelivered = true;
        _readers.removeFirst().complete(Uint8List(0));
        continue;
      }
      return;
    }
    if (_readable.isEmpty && _finOffset != null && _readOffset >= _finOffset!) {
      _finDelivered = true;
    }
  }

  void _remoteReset(int errorCode) {
    _fail(StreamResetException(id, errorCode));
  }

  void _connectionClosed() {
    _fail(_conn._closedException);
  }

  void _fail(Object error) {
    if (_error != null) return;
    _error = error;
    while (_readers.isNotEmpty) {
      final reader = _readers.removeFirst();
      if (!reader.isCompleted) reader.completeError(error);
    }
  }

  /// Reads the next chunk of stream data, or an empty list once the peer has
  /// finished sending.
  Future<Uint8List> read() {
    if (!readable) {
      throw StateError('stream $id is send-only and cannot be read');
    }
    if (_readable.isNotEmpty) return Future.value(_readable.takeBytes());
    if (_error != null) return Future.error(_error!);
    if (_finOffset != null && _readOffset >= _finOffset!) {
      _finDelivered = true;
      return Future.value(Uint8List(0));
    }
    final completer = Completer<Uint8List>();
    _readers.add(completer);
    return completer.future;
  }

  /// Reads exactly [length] bytes, or throws if the peer finishes first.
  Future<Uint8List> readExactly(int length) async {
    final out = BytesBuilder(copy: false);
    while (out.length < length) {
      final chunk = await read();
      if (chunk.isEmpty) {
        throw StateError(
          'stream $id ended after ${out.length} of $length bytes',
        );
      }
      out.add(chunk);
    }
    final bytes = out.takeBytes();
    if (bytes.length > length) {
      // Put the surplus back at the head of the readable buffer.
      final surplus = Uint8List.sublistView(bytes, length);
      final head = _readable.takeBytes();
      _readable
        ..add(surplus)
        ..add(head);
      return Uint8List.sublistView(bytes, 0, length);
    }
    return bytes;
  }

  /// Sends [data] on this stream, optionally marking it as the last write.
  void write(Uint8List data, {bool fin = false}) {
    if (!writable) {
      throw StateError('stream $id is receive-only and cannot be written');
    }
    if (_writeClosed)
      throw StateError('stream $id is already closed for writing');
    if (_conn.isClosed) throw _conn._closedException;

    // ponytail: one STREAM frame per write, capped below the 1200-byte
    // minimum datagram so a packet never needs fragmenting. Coalescing and
    // MTU discovery only matter for bulk transfer, which this layer does not
    // carry yet.
    const maxChunk = 1000;
    var sent = 0;
    do {
      final end = (sent + maxChunk < data.length)
          ? sent + maxChunk
          : data.length;
      final isLast = end >= data.length;
      _conn.sendFrames([
        StreamFrame(
          streamId: id,
          offset: _writeOffset,
          data: Uint8List.sublistView(data, sent, end),
          fin: fin && isLast,
        ),
      ]);
      _writeOffset += end - sent;
      sent = end;
    } while (sent < data.length);

    if (data.isEmpty && fin) {
      _conn.sendFrames([
        StreamFrame(
          streamId: id,
          offset: _writeOffset,
          data: Uint8List(0),
          fin: true,
        ),
      ]);
    }
    if (fin) _writeClosed = true;
  }

  /// Finishes sending on this stream, per RFC 9000 section 3.1.
  void closeWrite() {
    if (_writeClosed || !writable) return;
    write(Uint8List(0), fin: true);
  }

  /// Abandons this stream, telling the peer with a RESET_STREAM frame.
  void reset([int errorCode = 0]) {
    if (_error != null) return;
    if (writable && !_conn.isClosed) {
      _conn.sendFrames([
        ResetStreamFrame(
          streamId: id,
          applicationErrorCode: errorCode,
          finalSize: _writeOffset,
        ),
      ]);
    }
    _writeClosed = true;
    _fail(StreamResetException(id, errorCode));
  }
}
