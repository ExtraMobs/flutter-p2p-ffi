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
      throw YamuxProtocolException('truncated Yamux header');
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
      throw YamuxProtocolException('truncated data frame');
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

final class YamuxProtocolException implements Exception {
  YamuxProtocolException(this.message);
  final String message;
  @override
  String toString() => message;
}

final class YamuxStreamResetException implements Exception {
  YamuxStreamResetException({required this.remote, this.errorCode = 0});
  final bool remote;
  final int errorCode;
  @override
  String toString() =>
      'stream reset (${remote ? 'remote' : 'local'}), error code: $errorCode';
}

final class YamuxSessionClosedException implements Exception {
  YamuxSessionClosedException([this.reason = 'session shutdown']);
  final String reason;
  @override
  String toString() => reason;
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
          close(reason: YamuxSessionClosedException('transport closed')),
      cancelOnError: true,
    );
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
  Object? _shutdownReason;
  int _nextStreamId = 1;
  int _incomingCount = 0;
  int _inflight = 0;
  bool _goAway = false;

  bool get isClosed => _closed.isCompleted;
  Future<void> get closeFuture => _closed.future;
  int get numStreams => _streams.length;
  int get numIncomingStreams => _incomingCount;

  Future<YamuxStream> openStream({Duration? timeout}) async {
    if (isClosed || _goAway) throw _closedError;
    final end = timeout == null ? null : DateTime.now().add(timeout);
    while (_inflight >= config.acceptBacklog) {
      if (isClosed) throw _closedError;
      final remaining = end == null ? null : end.difference(DateTime.now());
      if (remaining != null && remaining <= Duration.zero) {
        throw TimeoutException('opening Yamux stream timed out');
      }
      await Future.any<void>([
        _closed.future,
        Future<void>.delayed(remaining ?? const Duration(milliseconds: 10)),
      ]);
    }
    if (_nextStreamId >= 0xfffffffe) throw YamuxStreamsExhaustedException();
    final id = _nextStreamId;
    _nextStreamId += 2;
    final stream = YamuxStream._(this, id, incoming: false);
    _streams[id] = stream;
    _inflight++;
    await stream._sendWindowUpdate(syn: true);
    return stream;
  }

  Future<YamuxStream> acceptStream() {
    if (_acceptQueue.isNotEmpty) return _acceptOne();
    if (isClosed) return Future<YamuxStream>.error(_closedError);
    final waiter = Completer<YamuxStream>();
    _acceptWaiters.add(waiter);
    return waiter.future;
  }

  Future<YamuxStream> open() => openStream();

  Future<YamuxStream> accept() => acceptStream();

  Future<YamuxStream> _acceptOne() async {
    final stream = _acceptQueue.removeFirst();
    if (!stream.isClosed) await stream._sendWindowUpdate(ack: true);
    return stream;
  }

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
      reason: YamuxSessionClosedException('sent go away, code: $errorCode'),
    );
  }

  Future<void> close({Object? reason}) => _closeFuture ??= _close(reason);

  Future<void> _close(Object? reason) async {
    _shutdownReason = reason ?? YamuxSessionClosedException();
    _goAway = true;
    _closed.complete();
    await _subscription.cancel();
    for (final stream in List<YamuxStream>.from(_streams.values)) {
      stream._forceClose(_shutdownReason!);
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

  Object get _closedError => _shutdownReason ?? YamuxSessionClosedException();

  Future<void> _sendFrame(YamuxFrame frame) {
    final bytes = frame.encode();
    _writeTail = _writeTail.then((_) async {
      if (!isClosed) await transport.write(bytes);
    });
    return _writeTail;
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
        close(reason: YamuxSessionClosedException('remote sent go away')),
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
      }
      return;
    }
    final incoming = (frame.flags & yamuxSyn) != 0;
    if (incoming) {
      if (_streams.containsKey(frame.streamId)) {
        throw YamuxProtocolException('duplicate stream initiated');
      }
      _newIncoming(frame.streamId);
    }
    final stream = _streams[frame.streamId];
    if (stream == null) return;
    if (frame.type == YamuxMessageType.windowUpdate) {
      stream._window += frame.length;
      stream._signalWindowWaiters();
      if ((frame.flags & yamuxAck) != 0) _ack(stream);
      stream._processFlags(frame.flags, frame.length);
    } else {
      if (frame.payload.length > stream._recvWindow) {
        unawaited(
          close(reason: YamuxProtocolException('receive window exceeded')),
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
      throw YamuxProtocolException('both yamux endpoints are clients');
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
    final stream = YamuxStream._(this, id, incoming: true);
    _streams[id] = stream;
    _incomingCount++;
    if (_acceptWaiters.isNotEmpty) {
      final waiter = _acceptWaiters.removeFirst();
      unawaited(
        stream
            ._sendWindowUpdate(ack: true)
            .then((_) => waiter.complete(stream)),
      );
    } else {
      _acceptQueue.add(stream);
    }
  }

  void _ack(YamuxStream stream) {
    if (stream._acked) return;
    stream._acked = true;
    if (_inflight > 0) _inflight--;
  }

  void _remove(YamuxStream stream) {
    if (_streams.remove(stream.id) == null) return;
    _acceptQueue.remove(stream);
    if (stream.incoming && _incomingCount > 0) _incomingCount--;
    if (!stream.incoming && _inflight > 0) _inflight--;
  }
}

final class YamuxStreamsExhaustedException implements Exception {
  @override
  String toString() => 'streams exhausted';
}

final class YamuxStream {
  YamuxStream._(this.session, this.id, {required this.incoming})
    : _recvWindow = yamuxInitialStreamWindow,
      _window = yamuxInitialStreamWindow;

  final YamuxSession session;
  final int id;
  final bool incoming;
  int _window;
  int _recvWindow;
  final Queue<Uint8List> _received = Queue<Uint8List>();
  final Queue<({Completer<Uint8List?> completer, int maxBytes})> _readers =
      Queue<({Completer<Uint8List?> completer, int maxBytes})>();
  final Queue<Completer<void>> _windowWaiters = Queue<Completer<void>>();
  bool _readClosed = false;
  bool _readReset = false;
  bool _resetRemote = false;
  int _resetCode = 0;
  bool _writeClosed = false;
  bool _reset = false;
  bool _acked = false;
  bool _synSent = false;
  bool _cleaned = false;
  int _queuedBytes = 0;

  int get streamId => id;
  int get streamID => id;
  bool get isClosed => _reset || (_readClosed && _writeClosed);
  int get bufferedBytes => _queuedBytes;

  Future<int> write(Uint8List bytes) async {
    if (bytes.isEmpty) return 0;
    var offset = 0;
    while (offset < bytes.length) {
      _checkWritable();
      while (_window == 0) {
        final waiter = Completer<void>();
        _windowWaiters.add(waiter);
        if (_window != 0 || _reset || _writeClosed || session.isClosed) {
          waiter.complete();
        }
        await waiter.future;
        _checkWritable();
      }
      final max = _window < session.config.maxMessageSize - yamuxHeaderSize
          ? _window
          : session.config.maxMessageSize - yamuxHeaderSize;
      final count = (bytes.length - offset) < max ? bytes.length - offset : max;
      var flags = _sendFlags();
      await session._sendFrame(
        YamuxFrame(
          type: YamuxMessageType.data,
          flags: flags,
          streamId: id,
          payload: Uint8List.sublistView(bytes, offset, offset + count),
        ),
      );
      _window -= count;
      offset += count;
    }
    return offset;
  }

  Future<Uint8List?> read([int maxBytes = 65536]) {
    if (maxBytes <= 0) throw RangeError('maxBytes must be positive');
    if (_readReset) {
      return Future<Uint8List?>.error(
        YamuxStreamResetException(remote: _resetRemote, errorCode: _resetCode),
      );
    }
    if (_received.isNotEmpty) return Future.value(_take(maxBytes));
    if (_reset)
      return Future<Uint8List?>.error(YamuxStreamResetException(remote: true));
    if (_readClosed) return Future<Uint8List?>.value(null);
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
    if (_writeClosed) return;
    if (_reset) return;
    _writeClosed = true;
    _signalWindowWaiters();
    await session._sendFrame(
      YamuxFrame(
        type: YamuxMessageType.windowUpdate,
        flags: _sendFlags() | yamuxFin,
        streamId: id,
      ),
    );
    _cleanupIfDone();
  }

  Future<void> closeRead() async {
    if (_readClosed) return;
    _readClosed = true;
    _readReset = true;
    _resetRemote = false;
    while (_readers.isNotEmpty) {
      _readers.removeFirst().completer.completeError(
        YamuxStreamResetException(remote: false),
      );
    }
    _cleanupIfDone();
  }

  Future<void> close() async {
    await closeRead();
    await closeWrite();
  }

  Future<void> reset([int errorCode = 0]) async {
    if (_reset || isClosed) return;
    _reset = true;
    _readClosed = true;
    _readReset = true;
    _resetRemote = false;
    _resetCode = errorCode;
    _writeClosed = true;
    while (_readers.isNotEmpty) {
      _readers.removeFirst().completer.completeError(
        YamuxStreamResetException(remote: false, errorCode: errorCode),
      );
    }
    if (incoming || _synSent) {
      await session._sendFrame(
        YamuxFrame(
          type: YamuxMessageType.windowUpdate,
          flags: yamuxRst,
          streamId: id,
          length: errorCode,
        ),
      );
    }
    _cleanupIfDone();
  }

  Future<void> resetWithError(int errorCode) => reset(errorCode);

  int _sendFlags() {
    if (!incoming && !_synSent) {
      _synSent = true;
      return yamuxSyn;
    }
    if (incoming && !_acked) {
      _acked = true;
      return yamuxAck;
    }
    return 0;
  }

  Future<void> _sendWindowUpdate({bool syn = false, bool ack = false}) async {
    final delta =
        session.config.initialStreamWindowSize - yamuxInitialStreamWindow;
    var flags = syn ? yamuxSyn : 0;
    if (syn) _synSent = true;
    if (ack) {
      flags |= yamuxAck;
      _acked = true;
    }
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
    if ((flags & yamuxAck) != 0) session._ack(this);
    if ((flags & yamuxFin) != 0) {
      _readClosed = true;
      while (_readers.isNotEmpty)
        _readers.removeFirst().completer.complete(null);
      _cleanupIfDone();
    }
    if ((flags & yamuxRst) != 0) {
      _reset = true;
      _readClosed = true;
      _readReset = true;
      _resetRemote = true;
      _resetCode = errorCode;
      _writeClosed = true;
      _signalWindowWaiters();
      while (_readers.isNotEmpty) {
        _readers.removeFirst().completer.completeError(
          YamuxStreamResetException(remote: true, errorCode: errorCode),
        );
      }
      _cleanupIfDone();
    }
  }

  void _enqueue(Uint8List bytes) {
    if (bytes.isEmpty) return;
    _received.add(bytes);
    _queuedBytes += bytes.length;
    while (_readers.isNotEmpty && _received.isNotEmpty) {
      final waiter = _readers.removeFirst();
      waiter.completer.complete(_take(waiter.maxBytes));
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
    final delta = session.config.initialStreamWindowSize - _recvWindow;
    if (delta > 0 &&
        _recvWindow < session.config.initialStreamWindowSize ~/ 2) {
      _recvWindow += delta;
      unawaited(
        session._sendFrame(
          YamuxFrame(
            type: YamuxMessageType.windowUpdate,
            streamId: id,
            length: delta,
          ),
        ),
      );
    }
    return out;
  }

  void _forceClose(Object reason) {
    _reset = true;
    _readClosed = true;
    _readReset = true;
    _resetRemote = false;
    _writeClosed = true;
    _signalWindowWaiters();
    while (_readers.isNotEmpty) {
      _readers.removeFirst().completer.completeError(reason);
    }
  }

  void _cleanupIfDone() {
    if (!_cleaned && isClosed) {
      _cleaned = true;
      session._remove(this);
    }
  }

  void _checkWritable() {
    if (session.isClosed) throw session._closedError;
    if (_reset) {
      throw YamuxStreamResetException(
        remote: _resetRemote,
        errorCode: _resetCode,
      );
    }
    if (_writeClosed) throw YamuxSessionClosedException('stream closed');
  }

  void _signalWindowWaiters() {
    while (_windowWaiters.isNotEmpty) {
      final waiter = _windowWaiters.removeFirst();
      if (!waiter.isCompleted) waiter.complete();
    }
  }
}

// Go's exported names are retained as aliases while the Dart names remain
// collision-free for callers importing dart:async.
typedef Config = YamuxConfig;
typedef Session = YamuxSession;
