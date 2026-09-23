// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// The Go package exposes a broad net.Conn surface; this port intentionally
// keeps the transport adapter small and documents the behavior at its boundary.
// ignore_for_file: duplicate_ignore, public_member_api_docs, curly_braces_in_flow_control_structures,
// ignore_for_file: prefer_initializing_formals, prefer_null_aware_operators

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

const int yamuxHeaderSize = 12;
const int yamuxProtocolVersion = 0;
const int yamuxInitialStreamWindow = 256 * 1024;
const int yamuxMaxStreamWindow = 16 * 1024 * 1024;

enum YamuxMessageType { data, windowUpdate, ping, goAway }

const int yamuxSyn = 1;
const int yamuxAck = 2;
const int yamuxFin = 4;
const int yamuxRst = 8;

/// A Yamux frame. Only data frames carry [payload]; the length field in all
/// other frame types is represented by [length].
final class YamuxFrame {
  YamuxFrame({
    required this.type,
    this.flags = 0,
    this.streamId = 0,
    this.length = 0,
    this.version = yamuxProtocolVersion,
    List<int>? payload,
  }) : payload = Uint8List.fromList(payload ?? const <int>[]) {
    if (version != yamuxProtocolVersion) {
      throw YamuxProtocolException('invalid protocol version: $version');
    }
    if (flags < 0 || flags > 0xffff || streamId < 0 || streamId > 0xffffffff) {
      throw RangeError('invalid frame flags or stream id');
    }
    if (type == YamuxMessageType.data) {
      if (this.payload.length > 0xffffffff) {
        throw RangeError('payload too large');
      }
    } else if (this.payload.isNotEmpty) {
      throw ArgumentError('only data frames may contain a payload');
    }
  }

  final int version;
  final YamuxMessageType type;
  final int flags;
  final int streamId;
  final int length;
  final Uint8List payload;

  int get wireLength => type == YamuxMessageType.data ? payload.length : length;

  Uint8List encode() {
    final bytes = Uint8List(
      yamuxHeaderSize + (type == YamuxMessageType.data ? payload.length : 0),
    );
    final data = ByteData.sublistView(bytes);
    data.setUint8(0, version);
    data.setUint8(1, type.index);
    data.setUint16(2, flags, Endian.big);
    data.setUint32(4, streamId, Endian.big);
    data.setUint32(8, wireLength, Endian.big);
    if (payload.isNotEmpty)
      bytes.setRange(yamuxHeaderSize, bytes.length, payload);
    return bytes;
  }

  static YamuxFrame decode(Uint8List bytes) {
    if (bytes.length < yamuxHeaderSize) {
      throw const YamuxProtocolException('truncated Yamux header');
    }
    final d = ByteData.sublistView(bytes);
    final version = d.getUint8(0);
    if (version != yamuxProtocolVersion) {
      throw YamuxProtocolException('invalid protocol version: $version');
    }
    final typeValue = d.getUint8(1);
    if (typeValue > YamuxMessageType.goAway.index) {
      throw YamuxProtocolException('invalid message type: $typeValue');
    }
    final type = YamuxMessageType.values[typeValue];
    final length = d.getUint32(8, Endian.big);
    if (type == YamuxMessageType.data &&
        bytes.length != yamuxHeaderSize + length) {
      throw const YamuxProtocolException('truncated data frame');
    }
    return YamuxFrame(
      version: version,
      type: type,
      flags: d.getUint16(2, Endian.big),
      streamId: d.getUint32(4, Endian.big),
      length: length,
      payload: type == YamuxMessageType.data
          ? Uint8List.sublistView(bytes, yamuxHeaderSize)
          : Uint8List(0),
    );
  }

  @override
  String toString() =>
      'YamuxFrame(type: $type, flags: $flags, streamId: $streamId, length: $wireLength)';
}

/// Incremental decoder for the streaming Yamux transport.
final class YamuxFrameDecoder {
  YamuxFrameDecoder({this.maxDataLength});

  final int? maxDataLength;
  final Queue<Uint8List> _chunks = Queue<Uint8List>();
  int _headOffset = 0;
  int _buffered = 0;

  Uint8List _peek(int length) {
    final result = Uint8List(length);
    var out = 0;
    for (final chunk in _chunks) {
      final start = chunk == _chunks.first ? _headOffset : 0;
      final count = (chunk.length - start) < length - out
          ? chunk.length - start
          : length - out;
      if (count > 0) {
        result.setRange(out, out + count, chunk, start);
        out += count;
      }
      if (out == length) break;
    }
    return result;
  }

  Uint8List _consume(int length) {
    final result = Uint8List(length);
    var out = 0;
    while (out < length) {
      final chunk = _chunks.first;
      final count = (chunk.length - _headOffset) < length - out
          ? chunk.length - _headOffset
          : length - out;
      result.setRange(out, out + count, chunk, _headOffset);
      out += count;
      _headOffset += count;
      _buffered -= count;
      if (_headOffset == chunk.length) {
        _chunks.removeFirst();
        _headOffset = 0;
      }
    }
    return result;
  }

  void _checkLength(int type, int length) {
    if (type == YamuxMessageType.data.index &&
        maxDataLength != null &&
        length > maxDataLength!) {
      throw YamuxProtocolException(
        'data frame exceeds maximum length: $length > $maxDataLength',
      );
    }
  }

  void _checkHeader(Uint8List header) {
    final d = ByteData.sublistView(header);
    final version = d.getUint8(0);
    if (version != yamuxProtocolVersion) {
      throw YamuxProtocolException('invalid protocol version: $version');
    }
    final type = d.getUint8(1);
    if (type > YamuxMessageType.goAway.index) {
      throw YamuxProtocolException('invalid message type: $type');
    }
    _checkLength(type, d.getUint32(8, Endian.big));
  }

  List<YamuxFrame> add(List<int> chunk) {
    if (chunk.isNotEmpty) {
      // Check a header completed by this fragment before retaining its body.
      if (_buffered >= yamuxHeaderSize) {
        final header = _peek(yamuxHeaderSize);
        _checkHeader(header);
      } else if (_buffered + chunk.length >= yamuxHeaderSize) {
        final header = Uint8List(yamuxHeaderSize);
        final old = _peek(_buffered);
        header.setRange(0, _buffered, old);
        header.setRange(
          _buffered,
          yamuxHeaderSize,
          chunk.sublist(0, yamuxHeaderSize - _buffered),
        );
        _checkHeader(header);
      }
      _chunks.add(Uint8List.fromList(chunk));
      _buffered += chunk.length;
    }
    final result = <YamuxFrame>[];
    while (_buffered >= yamuxHeaderSize) {
      final header = _peek(yamuxHeaderSize);
      final d = ByteData.sublistView(header);
      final version = d.getUint8(0);
      if (version != yamuxProtocolVersion) {
        throw YamuxProtocolException('invalid protocol version: $version');
      }
      final type = d.getUint8(1);
      if (type > YamuxMessageType.goAway.index) {
        throw YamuxProtocolException('invalid message type: $type');
      }
      final length = d.getUint32(8, Endian.big);
      _checkLength(type, length);
      final total =
          yamuxHeaderSize + (type == YamuxMessageType.data.index ? length : 0);
      if (_buffered < total) break;
      _consume(yamuxHeaderSize);
      result.add(
        YamuxFrame(
          version: header[0],
          type: YamuxMessageType.values[type],
          flags: d.getUint16(2, Endian.big),
          streamId: d.getUint32(4, Endian.big),
          length: length,
          payload: type == YamuxMessageType.data.index
              ? _consume(length)
              : Uint8List(0),
        ),
      );
    }
    return result;
  }
}

final class YamuxConfig {
  const YamuxConfig({
    this.acceptBacklog = 256,
    this.pingBacklog = 32,
    this.enableKeepAlive = true,
    this.keepAliveInterval = const Duration(seconds: 30),
    this.measureRttInterval = const Duration(seconds: 30),
    this.connectionWriteTimeout = const Duration(seconds: 10),
    this.maxIncomingStreams = 1000,
    this.initialStreamWindowSize = yamuxInitialStreamWindow,
    this.maxStreamWindowSize = yamuxMaxStreamWindow,
    this.readBufferSize = 4096,
    this.writeCoalesceDelay = const Duration(microseconds: 100),
    this.maxMessageSize = 64 * 1024,
  });

  final int acceptBacklog;
  final int pingBacklog;
  final bool enableKeepAlive;
  final Duration keepAliveInterval;
  final Duration measureRttInterval;
  final Duration connectionWriteTimeout;
  final int maxIncomingStreams;
  final int initialStreamWindowSize;
  final int maxStreamWindowSize;
  final int readBufferSize;
  final Duration writeCoalesceDelay;
  final int maxMessageSize;

  static const YamuxConfig defaults = YamuxConfig();

  void verify() {
    if (acceptBacklog <= 0)
      throw YamuxConfigException('backlog must be positive');
    if (enableKeepAlive && keepAliveInterval <= Duration.zero) {
      throw YamuxConfigException('keep-alive interval must be positive');
    }
    if (measureRttInterval == Duration.zero) {
      throw YamuxConfigException('measure-rtt interval must be positive');
    }
    if (initialStreamWindowSize < yamuxInitialStreamWindow) {
      throw YamuxConfigException(
        'InitialStreamWindowSize must be larger or equal 256 kB',
      );
    }
    if (maxStreamWindowSize < initialStreamWindowSize) {
      throw YamuxConfigException(
        'MaxStreamWindowSize must be larger than the InitialStreamWindowSize',
      );
    }
    if (maxMessageSize < 1024) {
      throw YamuxConfigException(
        'MaxMessageSize must be greater than a kilobyte',
      );
    }
    if (writeCoalesceDelay < Duration.zero || pingBacklog < 1) {
      throw YamuxConfigException(
        'invalid write coalesce delay or ping backlog',
      );
    }
  }
}

final class YamuxConfigException implements Exception {
  YamuxConfigException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum YamuxStreamState {
  init,
  synSent,
  synReceived,
  established,
  finished,
}

enum YamuxHalfStreamState {
  open,
  closed,
  reset,
}

abstract class YamuxException implements Exception {
  const YamuxException(this.message, {this.isTimeout = false, this.isTemporary = false});
  final String message;
  final bool isTimeout;
  final bool isTemporary;

  @override
  String toString() => message;
}

class YamuxSessionClosedException extends YamuxException {
  const YamuxSessionClosedException([super.message = 'session shutdown']);
}

class YamuxProtocolException extends YamuxException {
  const YamuxProtocolException(super.message);
}

class YamuxGoAwayException extends YamuxSessionClosedException {
  const YamuxGoAwayException({required this.errorCode, required this.remote})
      : super(remote ? 'remote sent go away, code: $errorCode' : 'sent go away, code: $errorCode');
  final int errorCode;
  final bool remote;
}

class YamuxStreamResetException extends YamuxException {
  const YamuxStreamResetException({this.remote = false, this.errorCode = 0})
      : super('stream reset (${remote ? 'remote' : 'local'}), error code: $errorCode');
  final bool remote;
  final int errorCode;
}

class YamuxStreamErrorException extends YamuxStreamResetException {
  const YamuxStreamErrorException({required super.errorCode, required super.remote});
}

class YamuxStreamClosedException extends YamuxSessionClosedException {
  const YamuxStreamClosedException([super.message = 'stream closed']);
}

class YamuxSessionShutdownException extends YamuxGoAwayException {
  const YamuxSessionShutdownException([int errorCode = 0]) : super(errorCode: errorCode, remote: false);
}

class YamuxRemoteGoAwayException extends YamuxGoAwayException {
  const YamuxRemoteGoAwayException([int errorCode = 0]) : super(errorCode: errorCode, remote: true);
}

class YamuxTimeoutException extends YamuxException {
  const YamuxTimeoutException([super.message = 'i/o deadline reached'])
      : super(isTimeout: true, isTemporary: true);
}

class YamuxConnectionWriteTimeoutException extends YamuxException {
  const YamuxConnectionWriteTimeoutException([super.message = 'connection write timeout'])
      : super(isTimeout: true);
}

class YamuxKeepAliveTimeoutException extends YamuxException {
  const YamuxKeepAliveTimeoutException([super.message = 'keepalive timeout'])
      : super(isTimeout: true);
}

class YamuxDuplicateStreamException extends YamuxProtocolException {
  const YamuxDuplicateStreamException([super.message = 'duplicate stream initiated']);
}

class YamuxRecvWindowExceededException extends YamuxProtocolException {
  const YamuxRecvWindowExceededException([super.message = 'recv window exceeded']);
}

class YamuxStreamsExhaustedException extends YamuxException {
  const YamuxStreamsExhaustedException([super.message = 'streams exhausted']);
}

/// The small transport contract needed by Yamux. TCP/Noise adapters can wrap
/// their byte stream without making this package depend on dart:io.
abstract interface class YamuxTransport {
  Stream<List<int>> get input;
  Future<void> write(Uint8List bytes);
  Future<void> close();
}

final class YamuxSession {
  YamuxSession(
    this.transport, {
    YamuxConfig config = YamuxConfig.defaults,
    required this.isClient,
  }) : config = config {
    this.config.verify();
    _decoder = YamuxFrameDecoder(
      maxDataLength: config.maxMessageSize - yamuxHeaderSize,
    );
    _nextStreamId = isClient ? 1 : 2;
    _subscription = transport.input.listen(
      _onInput,
      onError: (Object error, StackTrace stack) => close(reason: error),
      onDone: () =>
          close(reason: const YamuxSessionClosedException('transport closed')),
      cancelOnError: true,
    );
    _startKeepalive();
  }

  factory YamuxSession.client(
    YamuxTransport transport, {
    YamuxConfig config = YamuxConfig.defaults,
  }) => YamuxSession(transport, config: config, isClient: true);

  factory YamuxSession.server(
    YamuxTransport transport, {
    YamuxConfig config = YamuxConfig.defaults,
  }) => YamuxSession(transport, config: config, isClient: false);

  final YamuxTransport transport;
  final YamuxConfig config;
  final bool isClient;
  late final YamuxFrameDecoder _decoder;
  final Map<int, YamuxStream> _streams = <int, YamuxStream>{};
  final Queue<YamuxStream> _acceptQueue = Queue<YamuxStream>();
  final Queue<Completer<YamuxStream>> _acceptWaiters =
      Queue<Completer<YamuxStream>>();
  final Completer<void> _closed = Completer<void>();
  Future<void>? _closeFuture;
  late final StreamSubscription<List<int>> _subscription;
  Future<void> _writeTail = Future<void>.value();
  Object? _shutdownErr;
  int _nextStreamId = 1;
  int _incomingCount = 0;
  final Set<int> _inflight = <int>{};
  bool _goAway = false;

  bool get isClosed => _closed.isCompleted;
  Future<void> get closeFuture => _closed.future;
  int get numStreams => _streams.length;
  int get numIncomingStreams => _incomingCount;

  Object get _closedError => _shutdownErr ?? const YamuxSessionShutdownException();

  Future<YamuxStream> openStream({Duration? timeout}) async {
    if (isClosed || _goAway) throw _closedError;
    final end = timeout == null ? null : DateTime.now().add(timeout);
    while (_inflight.length >= config.acceptBacklog) {
      if (isClosed) throw _closedError;
      final remaining = end == null ? null : end.difference(DateTime.now());
      if (remaining != null && remaining <= Duration.zero) {
        throw const YamuxTimeoutException('opening Yamux stream timed out');
      }
      await Future.any<void>([
        _closed.future,
        Future<void>.delayed(remaining ?? const Duration(milliseconds: 10)),
      ]);
    }
    if (_nextStreamId >= 0xfffffffe) throw const YamuxStreamsExhaustedException();
    final id = _nextStreamId;
    _nextStreamId += 2;
    final stream = YamuxStream._(this, id, YamuxStreamState.init);
    _streams[id] = stream;
    _inflight.add(id);
    await stream._sendWindowUpdate(syn: true);
    return stream;
  }

  Future<YamuxStream> acceptStream() async {
    while (true) {
      if (isClosed) throw _closedError;

      final YamuxStream stream;
      if (_acceptQueue.isNotEmpty) {
        stream = _acceptQueue.removeFirst();
      } else {
        final waiter = Completer<YamuxStream>();
        _acceptWaiters.add(waiter);
        try {
          stream = await waiter.future;
        } on Object {
          if (isClosed) throw _closedError;
          continue;
        }
      }

      if (stream.isClosed) continue;

      // Paridade com go-yamux (session.go:265-279):
      // if err := stream.sendWindowUpdate(nil); err != nil {
      //   // don't return accept errors.
      //   s.logger.Printf("[WARN] error sending window update before accepting: %s", err)
      //   continue
      // }
      try {
        await stream._sendWindowUpdate(ack: true);
        return stream;
      } catch (error) {
        stream._forceClose(error);
        if (isClosed) throw _closedError;
        continue;
      }
    }
  }

  Future<YamuxStream> open() => openStream();

  Future<YamuxStream> accept() => acceptStream();

  Future<void> goAway() {
    _goAway = true;
    return _sendFrame(YamuxFrame(type: YamuxMessageType.goAway));
  }

  /// Sends a non-normal GoAway and closes the underlying transport.
  Future<void> closeWithError(int errorCode) async {
    if (isClosed) return;
    _goAway = true;
    await _sendFrame(
      YamuxFrame(type: YamuxMessageType.goAway, length: errorCode),
    );
    await close(
      reason: YamuxGoAwayException(errorCode: errorCode, remote: false),
    );
  }

  Future<void> close({Object? reason}) => _closeFuture ??= _close(reason);

  Future<void> _close(Object? reason) async {
    _stopKeepalive();
    _shutdownErr = reason ?? const YamuxSessionShutdownException();
    _goAway = true;
    _closed.complete();
    await _subscription.cancel();

    for (final stream in List<YamuxStream>.from(_streams.values)) {
      stream._forceClose(_shutdownErr!);
    }
    _streams.clear();
    while (_acceptWaiters.isNotEmpty) {
      _acceptWaiters.removeFirst().completeError(_closedError);
    }
    // Paridade com go-yamux (session.go): `<-s.sendDoneCh` antes de
    // `s.conn.Close()`, para não fechar por cima de um quadro escrito pela
    // metade. `connectionWriteTimeout` é a válvula de segurança do upstream;
    // sem ela um transporte já morto travaria o shutdown para sempre.
    try {
      await _writeTail.timeout(config.connectionWriteTimeout);
    } catch (_) {}
    await transport.close();
  }

  /// Pings still waiting for their pong, keyed by the opaque value carried in
  /// the frame's length field.
  final Map<int, Completer<void>> _pings = {};
  int _nextPingId = 0;
  Timer? _keepaliveTimer;

  /// Sends a ping and waits for its pong, reporting the round trip.
  ///
  /// Go: `Ping` (`go-yamux/session.go`), which puts one
  /// [YamuxConfig.connectionWriteTimeout] over both halves -- getting the
  /// ping out, and hearing the answer.
  Future<Duration> ping() async {
    if (isClosed) throw _closedError;
    final id = _nextPingId++;
    final pong = Completer<void>();
    _pings[id] = pong;
    final elapsed = Stopwatch()..start();
    try {
      await _sendFrame(
        YamuxFrame(type: YamuxMessageType.ping, flags: yamuxSyn, length: id),
      ).timeout(config.connectionWriteTimeout);
      await pong.future.timeout(config.connectionWriteTimeout);
    } finally {
      _pings.remove(id);
    }
    return elapsed.elapsed;
  }

  /// Arms the next keepalive ping.
  ///
  /// Go: `startKeepalive` (`go-yamux/session.go:446-473`) -- a timer that
  /// pings, reschedules itself, and closes the session with
  /// `ErrKeepAliveTimeout` when the ping fails.
  void _startKeepalive() {
    if (!config.enableKeepAlive || isClosed) return;
    _keepaliveTimer = Timer(config.keepAliveInterval, () async {
      if (isClosed) return;
      try {
        await ping();
      } catch (_) {
        unawaited(close(reason: const YamuxKeepAliveTimeoutException()));
        return;
      }
      _startKeepalive();
    });
  }

  /// Go: `stopKeepalive` (`go-yamux/session.go:476`).
  void _stopKeepalive() {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
  }

  /// Queues [frame] behind whatever is already being written.
  ///
  /// Paridade com go-yamux (session.go:516-567):
  /// sendLoop detecta erro no write do socket, registra shutdownErr e aciona close.
  Future<void> _sendFrame(YamuxFrame frame) {
    if (isClosed) return Future<void>.error(_closedError);
    final bytes = frame.encode();
    final sent = _writeTail.then((_) async {
      if (!isClosed) {
        await transport.write(bytes).timeout(config.connectionWriteTimeout);
      }
    });

    _writeTail = sent.then<void>(
      (_) {},
      onError: (Object error) => unawaited(close(reason: error)),
    );
    sent.ignore();
    return sent;
  }

  void _onInput(List<int> chunk) {
    if (isClosed) return;
    try {
      for (final frame in _decoder.add(chunk)) _handle(frame);
    } catch (error) {
      unawaited(close(reason: error));
    }
  }

  void _handle(YamuxFrame frame) {
    if (frame.type == YamuxMessageType.goAway) {
      _goAway = true;
      unawaited(
        close(
          reason: YamuxGoAwayException(
            errorCode: frame.length,
            remote: true,
          ),
        ),
      );
      return;
    }
    if (frame.type == YamuxMessageType.ping) {
      if ((frame.flags & yamuxSyn) != 0) {
        unawaited(
          _sendFrame(
            YamuxFrame(
              type: YamuxMessageType.ping,
              flags: yamuxAck,
              length: frame.length,
            ),
          ),
        );
      } else {
        final waiting = _pings.remove(frame.length);
        if (waiting != null && !waiting.isCompleted) waiting.complete();
      }
      return;
    }
    final incoming = (frame.flags & yamuxSyn) != 0;
    if (incoming) {
      if (_streams.containsKey(frame.streamId)) {
        throw const YamuxDuplicateStreamException();
      }
      _newIncoming(frame.streamId);
    }
    final stream = _streams[frame.streamId];
    if (stream == null) return;
    if (frame.type == YamuxMessageType.windowUpdate) {
      stream._sendWindow += frame.length;
      stream._signalWindowWaiters();
      stream._processFlags(frame.flags, frame.length);
    } else {
      if (frame.payload.length > stream._recvWindow) {
        unawaited(
          close(reason: const YamuxRecvWindowExceededException()),
        );
        return;
      }
      stream._recvWindow -= frame.payload.length;
      stream._enqueue(frame.payload);
      // DATA and FIN may share a frame. Deliver bytes before publishing EOF,
      // matching go-yamux's readData then processFlags ordering.
      stream._processFlags(frame.flags, frame.length);
    }
  }

  void _newIncoming(int id) {
    if (isClient == id.isOdd) {
      throw const YamuxProtocolException('both yamux endpoints are clients');
    }
    if (_goAway ||
        _incomingCount >= config.maxIncomingStreams ||
        _acceptQueue.length >= config.acceptBacklog) {
      unawaited(
        _sendFrame(
          YamuxFrame(
            type: YamuxMessageType.windowUpdate,
            flags: yamuxRst,
            streamId: id,
          ),
        ),
      );
      return;
    }
    final stream = YamuxStream._(this, id, YamuxStreamState.synReceived);
    _streams[id] = stream;
    _incomingCount++;
    if (_acceptWaiters.isNotEmpty) {
      final waiter = _acceptWaiters.removeFirst();
      waiter.complete(stream);
    } else {
      _acceptQueue.add(stream);
    }
  }

  void _ack(YamuxStream stream) {
    _inflight.remove(stream.id);
  }

  void _remove(YamuxStream stream) {
    if (_streams.remove(stream.id) == null) return;
    _acceptQueue.remove(stream);
    _inflight.remove(stream.id);
    if (stream.incoming && _incomingCount > 0) _incomingCount--;
  }
}

final class YamuxStream {
  YamuxStream._(this.session, this.id, this._state)
      : _recvWindow = session.config.initialStreamWindowSize,
        _sendWindow = yamuxInitialStreamWindow;

  final YamuxSession session;
  final int id;

  YamuxStreamState _state;
  YamuxHalfStreamState _readState = YamuxHalfStreamState.open;
  YamuxHalfStreamState _writeState = YamuxHalfStreamState.open;

  Object? _readErr;
  Object? _writeErr;

  int _sendWindow;
  int _recvWindow;
  final Queue<Uint8List> _received = Queue<Uint8List>();
  final Queue<({Completer<Uint8List?> completer, int maxBytes})> _readers =
      Queue<({Completer<Uint8List?> completer, int maxBytes})>();
  final Queue<Completer<void>> _windowWaiters = Queue<Completer<void>>();
  bool _cleaned = false;
  int _queuedBytes = 0;

  int get streamId => id;
  int get streamID => id;
  bool get incoming => id % 2 == (session.isClient ? 0 : 1);
  bool get isClosed =>
      _state == YamuxStreamState.finished ||
      (_readState != YamuxHalfStreamState.open &&
          _writeState != YamuxHalfStreamState.open);
  int get bufferedBytes => _queuedBytes;

  Future<int> write(Uint8List bytes) async {
    if (bytes.isEmpty) return 0;
    var offset = 0;
    while (offset < bytes.length) {
      _checkWritable();
      while (_sendWindow == 0) {
        final waiter = Completer<void>();
        _windowWaiters.add(waiter);
        if (_sendWindow != 0 ||
            _writeState != YamuxHalfStreamState.open ||
            session.isClosed) {
          if (!waiter.isCompleted) waiter.complete();
        }
        await waiter.future;
        _checkWritable();
      }
      final max = _sendWindow < session.config.maxMessageSize - yamuxHeaderSize
          ? _sendWindow
          : session.config.maxMessageSize - yamuxHeaderSize;
      final count = (bytes.length - offset) < max ? bytes.length - offset : max;
      final flags = _sendFlags();
      await session._sendFrame(
        YamuxFrame(
          type: YamuxMessageType.data,
          flags: flags,
          streamId: id,
          payload: Uint8List.sublistView(bytes, offset, offset + count),
        ),
      );
      _sendWindow -= count;
      offset += count;
    }
    return offset;
  }

  Future<Uint8List?> read([int maxBytes = 65536]) {
    if (maxBytes <= 0) throw RangeError('maxBytes must be positive');

    switch (_readState) {
      case YamuxHalfStreamState.open:
        break;
      case YamuxHalfStreamState.closed:
        if (_queuedBytes == 0) return Future<Uint8List?>.value(null);
        break;
      case YamuxHalfStreamState.reset:
        return Future<Uint8List?>.error(
          _readErr ?? const YamuxStreamResetException(),
        );
    }

    if (_received.isNotEmpty) {
      final out = _take(maxBytes);
      unawaited(_maybeSendWindowUpdate());
      return Future<Uint8List?>.value(out);
    }

    final c = Completer<Uint8List?>();
    _readers.add((completer: c, maxBytes: maxBytes));
    return c.future;
  }

  Future<int> readInto(Uint8List target) async {
    final data = await read(target.length);
    if (data == null) return -1;
    target.setRange(0, data.length, data);
    return data.length;
  }

  Future<void> closeWrite() async {
    if (_state == YamuxStreamState.finished ||
        _writeState == YamuxHalfStreamState.closed) {
      return;
    }
    if (_writeState == YamuxHalfStreamState.reset) {
      return;
    }
    _writeState = YamuxHalfStreamState.closed;
    final cleanup = _readState != YamuxHalfStreamState.open;
    if (cleanup) {
      _state = YamuxStreamState.finished;
    }
    _notifyWaiting();
    await session._sendFrame(
      YamuxFrame(
        type: YamuxMessageType.windowUpdate,
        flags: _sendFlags() | yamuxFin,
        streamId: id,
      ),
    );
    if (cleanup) {
      _cleanup();
    }
  }

  Future<void> closeRead() async {
    if (_state == YamuxStreamState.finished ||
        _readState != YamuxHalfStreamState.open) {
      return;
    }
    _readState = YamuxHalfStreamState.reset;
    _readErr = const YamuxStreamResetException(remote: false);
    final cleanup = _writeState != YamuxHalfStreamState.open;
    if (cleanup) {
      _state = YamuxStreamState.finished;
    }
    _notifyWaiting();
    if (cleanup) {
      _cleanup();
    }
  }

  Future<void> close() async {
    if (_state == YamuxStreamState.finished) return;
    await closeRead();
    await closeWrite();
  }

  Future<void> reset([int errorCode = 0]) async {
    if (_state == YamuxStreamState.finished) return;
    final sendReset = _state == YamuxStreamState.synSent ||
        _state == YamuxStreamState.synReceived ||
        _state == YamuxStreamState.established;

    final err = YamuxStreamErrorException(errorCode: errorCode, remote: false);
    if (_writeState == YamuxHalfStreamState.open) {
      _writeState = YamuxHalfStreamState.reset;
      _writeErr = err;
    }
    if (_readState == YamuxHalfStreamState.open) {
      _readState = YamuxHalfStreamState.reset;
      _readErr = err;
    }
    _state = YamuxStreamState.finished;
    _notifyWaiting();

    if (sendReset) {
      await session._sendFrame(
        YamuxFrame(
          type: YamuxMessageType.windowUpdate,
          flags: yamuxRst,
          streamId: id,
          length: errorCode,
        ),
      );
    }
    _cleanup();
  }

  Future<void> resetWithError(int errorCode) => reset(errorCode);

  int _sendFlags() {
    var flags = 0;
    switch (_state) {
      case YamuxStreamState.init:
        flags |= yamuxSyn;
        _state = YamuxStreamState.synSent;
        break;
      case YamuxStreamState.synReceived:
        flags |= yamuxAck;
        _state = YamuxStreamState.established;
        break;
      case YamuxStreamState.synSent:
      case YamuxStreamState.established:
      case YamuxStreamState.finished:
        break;
    }
    return flags;
  }

  Future<void> _sendWindowUpdate({bool syn = false, bool ack = false}) async {
    final delta =
        session.config.initialStreamWindowSize - yamuxInitialStreamWindow;
    var flags = _sendFlags();
    if (syn) flags |= yamuxSyn;
    if (ack) flags |= yamuxAck;
    _recvWindow += delta;
    await session._sendFrame(
      YamuxFrame(
        type: YamuxMessageType.windowUpdate,
        flags: flags,
        streamId: id,
        length: delta,
      ),
    );
  }

  void _processFlags(int flags, int errorCode) {
    var closeStream = false;

    if ((flags & yamuxAck) != 0) {
      if (_state == YamuxStreamState.synSent) {
        _state = YamuxStreamState.established;
      }
      session._ack(this);
    }

    if ((flags & yamuxFin) != 0) {
      if (_readState == YamuxHalfStreamState.open) {
        _readState = YamuxHalfStreamState.closed;
        if (_writeState != YamuxHalfStreamState.open) {
          closeStream = true;
          _state = YamuxStreamState.finished;
        }
        _notifyWaiting();
      }
    }

    if ((flags & yamuxRst) != 0) {
      final err = errorCode != 0
          ? YamuxStreamErrorException(errorCode: errorCode, remote: true)
          : const YamuxStreamResetException(remote: true);
      if (_readState == YamuxHalfStreamState.open) {
        _readState = YamuxHalfStreamState.reset;
        _readErr = err;
      }
      if (_writeState == YamuxHalfStreamState.open) {
        _writeState = YamuxHalfStreamState.reset;
        _writeErr = err;
      }
      _state = YamuxStreamState.finished;
      closeStream = true;
      _notifyWaiting();
    }

    if (closeStream) {
      _cleanup();
    }
  }

  void _enqueue(Uint8List bytes) {
    if (bytes.isEmpty) return;
    _received.add(bytes);
    _queuedBytes += bytes.length;
    while (_readers.isNotEmpty && _received.isNotEmpty) {
      final waiter = _readers.removeFirst();
      waiter.completer.complete(_take(waiter.maxBytes));
      unawaited(_maybeSendWindowUpdate());
    }
  }

  Uint8List _take(int maxBytes) {
    final out = Uint8List(maxBytes < _queuedBytes ? maxBytes : _queuedBytes);
    var offset = 0;
    while (offset < out.length) {
      final head = _received.first;
      final count = (head.length) < out.length - offset
          ? head.length
          : out.length - offset;
      out.setRange(offset, offset + count, head);
      offset += count;
      _queuedBytes -= count;
      if (count == head.length) {
        _received.removeFirst();
      } else {
        _received.removeFirst();
        _received.addFirst(Uint8List.sublistView(head, count));
      }
    }
    return out;
  }

  Future<void> _maybeSendWindowUpdate() async {
    final delta = session.config.initialStreamWindowSize - _recvWindow;
    if (delta > 0 &&
        _recvWindow < session.config.initialStreamWindowSize ~/ 2) {
      _recvWindow += delta;
      await session._sendFrame(
        YamuxFrame(
          type: YamuxMessageType.windowUpdate,
          streamId: id,
          length: delta,
        ),
      );
    }
  }

  void _forceClose(Object err) {
    if (_readState == YamuxHalfStreamState.open) {
      _readState = YamuxHalfStreamState.reset;
      _readErr = err;
    }
    if (_writeState == YamuxHalfStreamState.open) {
      _writeState = YamuxHalfStreamState.reset;
      _writeErr = err;
    }
    _state = YamuxStreamState.finished;
    _notifyWaiting();
  }

  void _cleanup() {
    if (!_cleaned) {
      _cleaned = true;
      session._remove(this);
    }
  }

  void _checkWritable() {
    if (session.isClosed) throw session._closedError;
    switch (_writeState) {
      case YamuxHalfStreamState.open:
        break;
      case YamuxHalfStreamState.closed:
        throw const YamuxStreamClosedException();
      case YamuxHalfStreamState.reset:
        throw _writeErr ?? const YamuxStreamResetException();
    }
  }

  void _signalWindowWaiters() {
    while (_windowWaiters.isNotEmpty) {
      final waiter = _windowWaiters.removeFirst();
      if (!waiter.isCompleted) waiter.complete();
    }
  }

  void _notifyWaiting() {
    _signalWindowWaiters();
    while (_readers.isNotEmpty) {
      final r = _readers.removeFirst();
      if (_readErr != null) {
        r.completer.completeError(_readErr!);
      } else {
        r.completer.complete(null);
      }
    }
  }
}

// Go's exported names are retained as aliases while the Dart names remain
// collision-free for callers importing dart:async.
typedef Config = YamuxConfig;
typedef Session = YamuxSession;

/// Go: `DefaultConfig` (`yamux/config.go:88`).
YamuxConfig defaultConfig() => YamuxConfig.defaults;
const DefaultConfig = defaultConfig;

/// Go: `VerifyConfig` (`yamux/config.go:107`).
void verifyConfig(YamuxConfig config) => config.verify();
const VerifyConfig = verifyConfig;

/// Go: `Server` (`yamux/session.go:83`).
YamuxSession server(YamuxTransport conn, [YamuxConfig? config]) {
  final cfg = config ?? YamuxConfig.defaults;
  cfg.verify();
  return YamuxSession(conn, isClient: false, config: cfg);
}
const Server = server;

/// Go: `Client` (`yamux/session.go:70`).
YamuxSession client(YamuxTransport conn, [YamuxConfig? config]) {
  final cfg = config ?? YamuxConfig.defaults;
  cfg.verify();
  return YamuxSession(conn, isClient: true, config: cfg);
}
const Client = client;
