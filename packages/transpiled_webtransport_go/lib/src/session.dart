// Port of `github.com/quic-go/webtransport-go`'s `session.go` and `stream.go`
// (v0.11.1, revision d03fbc34952e05e833ab2a3810ab55aeefe2bf30).
//
// A WebTransport session multiplexes its streams straight onto the QUIC
// streams of the connection that carries its HTTP/3 CONNECT request. What
// distinguishes one session's streams from another's -- and from ordinary
// HTTP/3 request streams -- is a header at the very start of each stream: a
// signal varint (`webTransportFrameType` for bidirectional streams,
// `webTransportUniStreamType` for unidirectional ones) followed by the
// session ID, which is the stream ID of that CONNECT request.
import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:transpiled_quic_go/transpiled_quic_go.dart' as quic_go;
import 'package:transpiled_quic_go/transpiled_quic_go.dart'
    show appendVarInt, parseVarInt;

import 'protocol.dart';

/// Thrown when a WebTransport session is closed, locally or by the peer.
class SessionClosedException implements Exception {
  /// Creates a [SessionClosedException] with an optional [message].
  const SessionClosedException([this.message = 'WebTransport session closed']);

  /// A human readable description of why the session is gone.
  final String message;

  @override
  String toString() => 'SessionClosedException: $message';
}

/// An established WebTransport session, per Go's `webtransport.Session`.
class Session {
  /// Wraps the QUIC connection [conn] as the session established by the
  /// CONNECT request that travelled on stream [sessionId].
  Session({
    required quic_go.QuicConn conn,
    required this.sessionId,
    required quic_go.QuicStream requestStream,
    this.applicationProtocol = '',
  }) : _conn = conn,
       _requestStream = requestStream,
       _streamHeader = Uint8List.fromList(
         appendVarInt(appendVarInt(const [], webTransportFrameType), sessionId),
       ),
       _uniStreamHeader = Uint8List.fromList(
         appendVarInt(
           appendVarInt(const [], webTransportUniStreamType),
           sessionId,
         ),
       );

  /// The session ID, which is the stream ID of its CONNECT request.
  final int sessionId;

  /// The application protocol the server selected, empty when none was.
  final String applicationProtocol;

  final quic_go.QuicConn _conn;
  final quic_go.QuicStream _requestStream;
  final Uint8List _streamHeader;
  final Uint8List _uniStreamHeader;

  final Queue<SessionStream> _pendingBidi = Queue<SessionStream>();
  final Queue<Completer<SessionStream>> _bidiWaiters =
      Queue<Completer<SessionStream>>();
  bool _closed = false;
  bool _accepting = false;

  /// Whether the session has been closed.
  bool get isClosed => _closed || _conn.isClosed;

  /// The QUIC connection carrying this session.
  quic_go.QuicConn get conn => _conn;

  /// Opens a bidirectional stream inside this session.
  ///
  /// Go: `(*Session).OpenStream`. The session header is written immediately
  /// rather than lazily on first write; the difference is not observable on
  /// the wire beyond when the stream first appears.
  SessionStream openStream() {
    if (isClosed) throw const SessionClosedException();
    final stream = _conn.openStream();
    stream.write(_streamHeader);
    return SessionStream._(stream);
  }

  /// Opens a unidirectional stream inside this session.
  ///
  /// Go: `(*Session).OpenUniStream`.
  SessionStream openUniStream() {
    if (isClosed) throw const SessionClosedException();
    final stream = _conn.openUniStream();
    stream.write(_uniStreamHeader);
    return SessionStream._(stream);
  }

  /// Waits for the peer to open a bidirectional stream in this session.
  ///
  /// Go: `(*Session).AcceptStream`.
  Future<SessionStream> acceptStream() {
    if (isClosed) throw const SessionClosedException();
    if (_pendingBidi.isNotEmpty) {
      return Future.value(_pendingBidi.removeFirst());
    }
    final completer = Completer<SessionStream>();
    _bidiWaiters.add(completer);
    _pumpAccepts();
    return completer.future;
  }

  /// Continuously accepts QUIC streams and routes the ones tagged for this
  /// session, discarding streams that carry another session's header.
  ///
  /// Go runs this as the goroutine started by the client's `handleConn`.
  void _pumpAccepts() {
    if (_accepting) return;
    _accepting = true;
    unawaited(() async {
      while (!isClosed) {
        final quic_go.QuicStream stream;
        try {
          stream = await _conn.acceptStream();
        } catch (_) {
          return;
        }
        try {
          final signal = await _readVarIntFrom(stream);
          final id = await _readVarIntFrom(stream);
          if (signal != webTransportFrameType || id != sessionId) {
            stream.reset();
            continue;
          }
          final sessionStream = SessionStream._(stream);
          if (_bidiWaiters.isNotEmpty) {
            _bidiWaiters.removeFirst().complete(sessionStream);
          } else {
            _pendingBidi.add(sessionStream);
          }
        } catch (_) {
          stream.reset();
        }
      }
    }());
  }

  /// Closes the session and the QUIC connection carrying it.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final waiter in _bidiWaiters) {
      if (!waiter.isCompleted) {
        waiter.completeError(const SessionClosedException());
      }
    }
    _bidiWaiters.clear();
    _pendingBidi.clear();
    _requestStream.reset();
    await _conn.close();
  }
}

/// A stream inside a WebTransport session, per Go's `webtransport.Stream`.
///
/// The session header has already been consumed (on an accepted stream) or
/// written (on an opened one), so reads and writes here carry only
/// application bytes.
class SessionStream {
  SessionStream._(this._stream);

  final quic_go.QuicStream _stream;
  final BytesBuilder _surplus = BytesBuilder(copy: false);

  /// The QUIC stream ID this stream runs on.
  int get id => _stream.id;

  /// Reads the next chunk of application data, empty once the peer is done.
  Future<Uint8List> read() async {
    if (_surplus.isNotEmpty) return _surplus.takeBytes();
    return _stream.read();
  }

  /// Reads exactly [length] bytes of application data.
  Future<Uint8List> readExactly(int length) async {
    final out = BytesBuilder(copy: false);
    if (_surplus.isNotEmpty) out.add(_surplus.takeBytes());
    while (out.length < length) {
      final chunk = await _stream.read();
      if (chunk.isEmpty) {
        throw const SessionClosedException(
          'stream ended before the requested bytes arrived',
        );
      }
      out.add(chunk);
    }
    final bytes = out.takeBytes();
    if (bytes.length > length) {
      _surplus.add(Uint8List.sublistView(bytes, length));
      return Uint8List.sublistView(bytes, 0, length);
    }
    return bytes;
  }

  /// Sends [data] on this stream.
  void write(Uint8List data) => _stream.write(data);

  /// Finishes sending on this stream.
  void closeWrite() => _stream.closeWrite();

  /// Abandons this stream.
  void reset([int errorCode = 0]) => _stream.reset(errorCode);
}

/// Reads one QUIC varint from the head of [stream], one byte at a time.
///
/// The first byte's two most significant bits give the encoded length, per
/// RFC 9000 section 16, so exactly the right number of bytes is consumed and
/// nothing that follows the varint is swallowed.
Future<int> _readVarIntFrom(quic_go.QuicStream stream) async {
  final first = await stream.readExactly(1);
  final length = 1 << (first[0] >> 6);
  if (length == 1) return first[0] & 0x3f;
  final rest = await stream.readExactly(length - 1);
  final buffer = Uint8List(length)
    ..[0] = first[0]
    ..setAll(1, rest);
  return parseVarInt(buffer).$1;
}
