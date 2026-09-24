// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `association.go` (github.com/pion/sctp): [Association], the SCTP
/// association state machine (RFC 4960), plus the top-level [client]/
/// [server] constructors.
///
/// `Association` is exported in Go (capitalized) and re-exported from
/// `transpiled_pion_sctp.dart`, along with the free functions `Client`
/// (ported as [client]) and `Server` (ported as [server]).
///
/// **Concurrency adaptation, applied throughout this file**: Go's
/// `Association` guards nearly every field with a `sync.RWMutex` because its
/// read loop, write loop and every public method run on separate goroutines
/// that can interleave at any machine instruction. Dart has no such
/// preemption: a single isolate only ever runs one synchronous stretch of
/// code at a time, switching tasks solely at `await` points. The read loop
/// and write loop are therefore ported as two independently-scheduled
/// `Future`-returning methods (started, not awaited, exactly like Go's `go
/// a.readLoop()`/`go a.writeLoop()`), and every section Go marks "the caller
/// must hold the lock" is ported as a plain synchronous method with no
/// internal `await` -- reproducing the same atomicity Go's mutex provided,
/// without the mutex itself, per `RULE_NO_ARTIFICIAL_CONCURRENCY`. Channel
/// fields (`acceptCh`, `awakeWriteLoopCh`, `closeWriteLoopCh`,
/// `handshakeCompletedCh`, `writeNotify`, `readLoopCloseCh`) are ported as
/// the closest `Future`/`Completer` equivalent for the exact
/// send/receive/close pattern each one is actually used for; each adaptation
/// is called out at its own declaration below rather than collapsed
/// silently. `context.Context` (used only for `Client`'s handshake
/// cancellation, always with `context.Background()` upstream since no
/// `ClientWithContext` is ever exported, and for `Stream.writeDeadline`
/// passed as the block-write wait's cancellation source) is not ported as a
/// general type: [sendPayloadData] takes the concrete `Deadline` (its only
/// real caller, `Stream.writeSctp`, already has one) and exposes exactly the
/// two members (`done`, `err`) `sendPayloadData` reads off it.
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:transpiled_pion_logging/transpiled_pion_logging.dart'
    show LeveledLogger;
import 'package:transpiled_pion_randutil/transpiled_pion_randutil.dart'
    show MathRandomGenerator;
import 'package:transpiled_pion_transport/transpiled_pion_transport.dart'
    show Deadline;
import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart'
    show NetConn;

import 'ack_timer.dart';
import 'chunk.dart';
import 'chunk_abort.dart';
import 'chunk_cookie_ack.dart';
import 'chunk_cookie_echo.dart';
import 'chunk_error.dart';
import 'chunk_forward_tsn.dart';
import 'chunk_heartbeat.dart';
import 'chunk_heartbeat_ack.dart';
import 'chunk_init.dart';
import 'chunk_init_ack.dart';
import 'chunk_init_common.dart';
import 'chunk_payload_data.dart';
import 'chunk_reconfig.dart';
import 'chunk_selective_ack.dart';
import 'chunk_shutdown.dart';
import 'chunk_shutdown_ack.dart';
import 'chunk_shutdown_complete.dart';
import 'chunktype.dart';
import 'config.dart';
import 'control_queue.dart';
import 'error_cause.dart';
import 'error_cause_unrecognized_chunk_type.dart';
import 'error_cause_user_initiated_abort.dart';
import 'packet.dart';
import 'param.dart';
import 'param_outgoing_reset_request.dart';
import 'param_reconfig_response.dart';
import 'param_state_cookie.dart';
import 'param_supported_extensions.dart';
import 'param_zero_checksum.dart';
import 'payload_queue.dart';
import 'pending_queue.dart';
import 'receive_payload_queue.dart';
import 'rtx_timer.dart';
import 'stream.dart';
import 'util.dart';

bool _sna32Lt(int i1, int i2) => sna32Lt(Golang.Uint32(i1), Golang.Uint32(i2));
bool _sna32Lte(int i1, int i2) =>
    sna32Lte(Golang.Uint32(i1), Golang.Uint32(i2));
bool _sna32Gt(int i1, int i2) => sna32Gt(Golang.Uint32(i1), Golang.Uint32(i2));
bool _sna32Gte(int i1, int i2) =>
    sna32Gte(Golang.Uint32(i1), Golang.Uint32(i2));
bool _sna16Lt(int i1, int i2) => sna16Lt(Golang.Uint16(i1), Golang.Uint16(i2));

/// Adds two values in the `uint32` domain, wrapping at 2^32 exactly like Go.
/// See this file's doc comment group on `uint32`-as-`int` for why a mask
/// (rather than boxing every arithmetic op in `Golang.Uint32`) is used.
int _u32(int v) => v & 0xFFFFFFFF;

/// Port 5000 shows up in examples for SDPs used by WebRTC. Since this
/// implementation assumes it will be used by DTLS over UDP, the port is
/// only meaningful for de-multiplexing but more-so verification. Port of
/// `defaultSCTPSrcDstPort` (association.go:27).
const int defaultSctpSrcDstPort = 5000;

final MathRandomGenerator _globalMathRandomGenerator = MathRandomGenerator();

/// Port of `ErrChunk` (association.go:34).
final class ChunkException implements Exception {
  const ChunkException(this.name, this.errors);
  final String name;
  final String errors;
  @override
  String toString() => '[$name] abort chunk, with following errors: $errors';
}

/// Port of `ErrShutdownNonEstablished` (association.go:35).
final class ShutdownNonEstablishedException implements Exception {
  const ShutdownNonEstablishedException(this.name);
  final String name;
  @override
  String toString() =>
      'shutdown called in non-established state: shutdown $name';
}

/// Port of `ErrAssociationClosedBeforeConn` (association.go:36).
final class AssociationClosedBeforeConnException implements Exception {
  const AssociationClosedBeforeConnException();
  @override
  String toString() => 'association closed before connecting';
}

/// Port of `ErrAssociationClosed` (association.go:37).
final class AssociationClosedException implements Exception {
  const AssociationClosedException();
  @override
  String toString() => 'association closed';
}

/// Port of `ErrInitNotStoredToSend` (association.go:39).
final class InitNotStoredToSendException implements Exception {
  const InitNotStoredToSendException();
  @override
  String toString() => 'the init not stored to send';
}

/// Port of `ErrCookieEchoNotStoredToSend` (association.go:40).
final class CookieEchoNotStoredToSendException implements Exception {
  const CookieEchoNotStoredToSendException();
  @override
  String toString() => 'cookieEcho not stored to send';
}

/// Port of `ErrSCTPPacketSourcePortZero` (association.go:41).
final class SctpPacketSourcePortZeroException implements Exception {
  const SctpPacketSourcePortZeroException();
  @override
  String toString() => 'sctp packet must not have a source port of 0';
}

/// Port of `ErrSCTPPacketDestinationPortZero` (association.go:42).
final class SctpPacketDestinationPortZeroException implements Exception {
  const SctpPacketDestinationPortZeroException();
  @override
  String toString() => 'sctp packet must not have a destination port of 0';
}

/// Port of `ErrInitChunkBundled` (association.go:43).
final class InitChunkBundledException implements Exception {
  const InitChunkBundledException();
  @override
  String toString() => 'init chunk must not be bundled with any other chunk';
}

/// Port of `ErrInitChunkVerifyTagNotZero` (association.go:44-46).
final class InitChunkVerifyTagNotZeroException implements Exception {
  const InitChunkVerifyTagNotZeroException();
  @override
  String toString() =>
      'init chunk expects a verification tag of 0 on the packet when '
      'out-of-the-blue';
}

/// Port of `ErrHandleInitState` (association.go:47).
final class HandleInitStateException implements Exception {
  const HandleInitStateException(this.state);
  final String state;
  @override
  String toString() => 'todo: handle Init when in state: $state';
}

/// Port of `ErrInitAckNoCookie` (association.go:48).
final class InitAckNoCookieException implements Exception {
  const InitAckNoCookieException();
  @override
  String toString() => 'no cookie in InitAck';
}

/// Port of `ErrInflightQueueTSNPop` (association.go:49).
final class InflightQueueTsnPopException implements Exception {
  const InflightQueueTsnPopException(this.tsn);
  final int tsn;
  @override
  String toString() => 'unable to be popped from inflight queue TSN: $tsn';
}

/// Port of `ErrTSNRequestNotExist` (association.go:50).
final class TsnRequestNotExistException implements Exception {
  const TsnRequestNotExistException(this.tsn);
  final int tsn;
  @override
  String toString() => 'requested non-existent TSN: $tsn';
}

/// Port of `ErrResetPacketInStateNotExist` (association.go:51).
final class ResetPacketInStateNotExistException implements Exception {
  const ResetPacketInStateNotExistException(this.state);
  final String state;
  @override
  String toString() =>
      'sending reset packet in non-established state: state=$state';
}

/// Port of `ErrParamterType` (association.go:52). The Go identifier's own
/// "Paramter" typo (not "Parameter") is preserved verbatim, per this
/// project's convention of keeping upstream typos in ported identifiers
/// (e.g. `pendingQueue`'s "Chuck").
final class ParamterTypeException implements Exception {
  const ParamterTypeException(this.actual);
  final Object? actual;
  @override
  String toString() => 'unexpected parameter type: $actual';
}

/// Port of `ErrPayloadDataStateNotExist` (association.go:53).
final class PayloadDataStateNotExistException implements Exception {
  const PayloadDataStateNotExistException(this.state);
  final String state;
  @override
  String toString() =>
      'sending payload data in non-established state: state=$state';
}

/// Port of `ErrChunkTypeUnhandled` (association.go:54).
final class ChunkTypeUnhandledException implements Exception {
  const ChunkTypeUnhandledException();
  @override
  String toString() => 'unhandled chunk type';
}

/// Port of `ErrHandshakeInitAck` (association.go:55).
final class HandshakeInitAckException implements Exception {
  const HandshakeInitAckException();
  @override
  String toString() => 'handshake failed (INIT ACK)';
}

/// Port of `ErrHandshakeCookieEcho` (association.go:56).
final class HandshakeCookieEchoException implements Exception {
  const HandshakeCookieEchoException();
  @override
  String toString() => 'handshake failed (COOKIE ECHO)';
}

/// Port of `ErrTooManyReconfigRequests` (association.go:57).
final class TooManyReconfigRequestsException implements Exception {
  const TooManyReconfigRequestsException(this.count);
  final int count;
  @override
  String toString() => 'too many outstanding reconfig requests: $count';
}

const int _receiveMtu = 8192;
const int _initialMtu = 1228;
const int _initialRecvBufSize = 1024 * 1024;
const int _commonHeaderSize = 12;
const int _dataChunkHeaderSize = 16;
const int _defaultMaxMessageSize = 65536;

// association state enums. Port of association.go:70-79.
const int _stateClosed = 0;
const int _stateCookieWait = 1;
const int _stateCookieEchoed = 2;
const int _stateEstablished = 3;
const int _stateShutdownAckSent = 4;
const int _stateShutdownPending = 5;
const int _stateShutdownReceived = 6;
const int _stateShutdownSent = 7;

// retransmission timer IDs. Port of association.go:82-88.
const int _timerT1Init = 0;
const int _timerT1Cookie = 1;
const int _timerT2Shutdown = 2;
const int _timerT3Rtx = 3;
const int _timerReconfig = 4;

// ack mode (for testing). Port of association.go:91-95.
const int ackModeNormal = 0;
const int ackModeNoDelay = 1;
const int ackModeAlwaysDelay = 2;

// ack transmission state. Port of association.go:98-102.
const int _ackStateIdle = 0;
const int _ackStateImmediate = 1;
const int _ackStateDelay = 2;

// other constants. Port of association.go:105-120.
const int _acceptChSize = 16;
const int _avgChunkSize = 500;
const int _minTsnOffset = 2000;
const int _maxTsnOffset = 40000;
const int _maxReconfigRequests = 1000;

/// Port of `getAssociationStateString` (association.go:122-143).
String _getAssociationStateString(int assoc) {
  switch (assoc) {
    case _stateClosed:
      return 'Closed';
    case _stateCookieWait:
      return 'CookieWait';
    case _stateCookieEchoed:
      return 'CookieEchoed';
    case _stateEstablished:
      return 'Established';
    case _stateShutdownPending:
      return 'ShutdownPending';
    case _stateShutdownSent:
      return 'ShutdownSent';
    case _stateShutdownReceived:
      return 'ShutdownReceived';
    case _stateShutdownAckSent:
      return 'ShutdownAckSent';
    default:
      return 'Invalid association state $assoc';
  }
}

int _min16(int a, int b) => a < b ? a : b;
int _max32(int a, int b) => a > b ? a : b;
int _min32(int a, int b) => a < b ? a : b;

/// Port of `getMaxTSNOffset` (association.go:1206-1220): the maximum offset
/// over the current cumulative TSN this association is willing to enqueue,
/// keeping the bytes utilized in the receive buffer within a small multiple
/// of the user-provided max receive buffer size.
int _getMaxTsnOffset(int maxReceiveBufferSize) {
  var offset = (maxReceiveBufferSize * 4) ~/ _avgChunkSize;
  if (offset < _minTsnOffset) {
    offset = _minTsnOffset;
  }
  if (offset > _maxTsnOffset) {
    offset = _maxTsnOffset;
  }
  return offset;
}

/// Port of `setSupportedExtensions` (association.go:1222-1231).
void _setSupportedExtensions(ChunkInitCommon init) {
  init.params.add(
    ParamSupportedExtensions(
      chunkTypes: [ChunkType.reconfig, ChunkType.forwardTsn],
    ),
  );
}

/// Port of `chunkMandatoryChecksum` (association.go:721-730).
bool _chunkMandatoryChecksum(List<Chunk> cc) {
  for (final c in cc) {
    if (c is ChunkInit || c is ChunkCookieEcho) {
      return true;
    }
  }
  return false;
}

/// Port of `checkPacket` (association.go:1077-1117).
void _checkPacket(Packet pkt) {
  if (pkt.sourcePort == 0) {
    throw const SctpPacketSourcePortZeroException();
  }
  if (pkt.destinationPort == 0) {
    throw const SctpPacketDestinationPortZeroException();
  }

  for (final c in pkt.chunks) {
    if (c is ChunkInit) {
      if (pkt.chunks.length != 1) {
        throw const InitChunkBundledException();
      }
      if (pkt.verificationTag != 0) {
        throw const InitChunkVerifyTagNotZeroException();
      }
    }
  }
}

/// Port of `pack` (association.go:2655-2657).
List<Packet> _pack(Packet p) => [p];

/// Port of `Association` (association.go:160-263). See this file's doc
/// comment for the concurrency adaptation applied throughout.
final class Association implements RtxTimerObserver, AckTimerObserver {
  /// Port of `createAssociation` (association.go:331-416).
  Association(this.config)
    : maxReceiveBufferSize = config.maxReceiveBufferSize == 0
          ? _initialRecvBufSize
          : config.maxReceiveBufferSize,
      maxMessageSize = config.maxMessageSize == 0
          ? _defaultMaxMessageSize
          : config.maxMessageSize,
      minCwnd = config.minCwnd,
      fastRtxWnd = config.fastRtxWnd,
      cwndCaStep = config.cwndCaStep,
      mtu = config.mtu == 0 ? _initialMtu : config.mtu,
      _netConn = config.netConn,
      myMaxNumOutboundStreams = 0xFFFF,
      myMaxNumInboundStreams = 0xFFFF,
      recvZeroChecksum = config.enableZeroChecksum,
      blockWrite = config.blockWrite,
      log = config.loggerFactory.newLogger('sctp'),
      name = config.name {
    payloadQueue = ReceivePayloadQueue(_getMaxTsnOffset(maxReceiveBufferSize));
    inflightQueue = PayloadQueue();
    pendingQueue = PendingQueue();
    controlQueue = ControlQueue();
    maxPayloadSize = mtu - (_commonHeaderSize + _dataChunkHeaderSize);
    myVerificationTag = _globalMathRandomGenerator.uint32();
    final tsn = _globalMathRandomGenerator.uint32();
    initialTsn = tsn;
    myNextTsn = tsn;
    myNextRsn = tsn;
    minTsn2MeasureRtt = tsn;
    cumulativeTsnAckPoint = _u32(tsn - 1);
    advancedPeerTsnAckPoint = _u32(tsn - 1);
    rtoMgr = RtoManager(config.rtoMax);
    if (name.isEmpty) {
      name = identityHashCode(this).toString();
    }

    // RFC 4690 Sec 7.2.1: the initial cwnd before DATA transmission or after
    // a sufficiently long idle period MUST be set to
    // min(4*MTU, max(2*MTU, 4380 bytes)).
    _setCwnd(_min32(4 * getMtu(), _max32(2 * getMtu(), 4380)));

    t1Init = RtxTimer(_timerT1Init, this, maxInitRetrans, config.rtoMax);
    t1Cookie = RtxTimer(_timerT1Cookie, this, maxInitRetrans, config.rtoMax);
    t2Shutdown = RtxTimer(_timerT2Shutdown, this, noMaxRetrans, config.rtoMax);
    t3Rtx = RtxTimer(_timerT3Rtx, this, noMaxRetrans, config.rtoMax);
    tReconfig = RtxTimer(_timerReconfig, this, noMaxRetrans, config.rtoMax);
    ackTimer = AckTimer(this);
  }

  /// Port of `Association.config` -- not itself a Go field (Go stores the
  /// individual `Config` values inline), kept here so [Association] can
  /// reach `config.loggerFactory`/etc. without re-declaring every value Go
  /// copies into its own struct fields, several of which (`name`, `mtu`,
  /// `maxReceiveBufferSize`, ...) are ported below as the real
  /// `Association` fields Go actually reads from thereafter.
  final Config config;

  int bytesReceived = 0;
  int bytesSent = 0;

  final NetConn? _netConn;

  int peerVerificationTag = 0;
  int myVerificationTag = 0;
  int state = _stateClosed;
  late final int initialTsn;
  late int myNextTsn;
  late int minTsn2MeasureRtt;
  bool willSendForwardTsn = false;
  bool willRetransmitFast = false;
  bool willRetransmitReconfig = false;

  bool willSendShutdown = false;
  bool willSendShutdownAck = false;
  bool willSendShutdownComplete = false;

  bool willSendAbort = false;
  ErrorCause? willSendAbortCause;

  late int myNextRsn;
  final Map<int, ChunkReconfig> reconfigs = {};
  final Map<int, ParamOutgoingResetRequest> reconfigRequests = {};

  int sourcePort = 0;
  int destinationPort = 0;
  int myMaxNumInboundStreams;
  int myMaxNumOutboundStreams;
  ParamStateCookie? myCookie;
  late final ReceivePayloadQueue payloadQueue;
  late final PayloadQueue inflightQueue;
  late final PendingQueue pendingQueue;
  late final ControlQueue controlQueue;
  final int mtu;
  late final int maxPayloadSize;
  double srtt = 0;
  late int cumulativeTsnAckPoint;
  late int advancedPeerTsnAckPoint;
  bool useForwardTsn = false;
  bool sendZeroChecksum = false;
  bool recvZeroChecksum;

  final int maxReceiveBufferSize;
  int maxMessageSize;
  int cwnd = 0;
  int rwnd = 0;
  int ssthresh = 0;
  int partialBytesAcked = 0;
  bool inFastRecovery = false;
  int fastRecoverExitPoint = 0;
  final int minCwnd;
  final int fastRtxWnd;
  final int cwndCaStep;

  late final RtoManager rtoMgr;
  late final RtxTimer t1Init;
  late final RtxTimer t1Cookie;
  late final RtxTimer t2Shutdown;
  late final RtxTimer t3Rtx;
  late final RtxTimer tReconfig;
  late final AckTimer ackTimer;

  ChunkInit? storedInit;
  ChunkCookieEcho? storedCookieEcho;

  final Map<int, Stream> streams = {};
  final _AcceptChannel _acceptCh = _AcceptChannel(_acceptChSize);
  final Completer<void> _readLoopCloseCh = Completer<void>();
  Completer<void> _awakeWriteLoopCh = Completer<void>();
  final Completer<void> _closeWriteLoopCh = Completer<void>();
  final Completer<Object?> _handshakeCompletedCh = Completer<Object?>();

  bool _closeWriteLoopOnceDone = false;

  /// Port of `Association.silentError` (association.go:245): stored for
  /// structural parity, but -- as upstream -- never read anywhere in this
  /// call graph.
  final Object silentError = const _SilentlyDiscardException();

  int ackState = _ackStateIdle;
  int ackMode = ackModeNormal;

  final AssociationStats stats = AssociationStats();

  bool delayedAckTriggered = false;
  bool immediateAckTriggered = false;

  final bool blockWrite;
  bool writePending = false;
  Completer<void> _writeNotify = Completer<void>();

  String name;
  final LeveledLogger log;

  // ---------------------------------------------------------------------
  // Public API (Go-exported members)
  // ---------------------------------------------------------------------

  /// Port of `Association.Shutdown` (association.go:499-528): initiates the
  /// shutdown sequence. Completes once the shutdown sequence has finished
  /// and the connection is closed.
  Future<void> shutdown() async {
    log.debugf('[%s] closing association..', [name]);

    final currentState = getState();
    if (currentState != _stateEstablished) {
      throw ShutdownNonEstablishedException(name);
    }

    // Attempt a graceful shutdown.
    _setState(_stateShutdownPending);

    if (inflightQueue.size() == 0) {
      // No more outstanding, send shutdown.
      willSendShutdown = true;
      _awakeWriteLoop();
      _setState(_stateShutdownSent);
    }

    await _closeWriteLoopCh.future;
  }

  /// Port of `Association.Close` (association.go:531-550): ends the SCTP
  /// association and cleans up any state.
  Future<void> close() async {
    log.debugf('[%s] closing association..', [name]);

    await _closeInternal();

    // Wait for readLoop to end
    await _readLoopCloseCh.future;

    log.debugf('[%s] association closed', [name]);
  }

  Future<void> _closeInternal() async {
    log.debugf('[%s] closing association..', [name]);

    _setState(_stateClosed);

    await _netConn?.close();

    _closeAllTimers();

    _closeWriteLoopOnce();
  }

  /// Port of `Association.Abort` (association.go:569-585): sends the abort
  /// packet with a user-initiated abort cause and immediately closes the
  /// connection.
  Future<void> abort(String reason) async {
    log.debugf('[%s] aborting association: %s', [name, reason]);

    willSendAbort = true;
    willSendAbortCause = ErrorCauseUserInitiatedAbort(
      upperLayerAbortReason: Uint8List.fromList(reason.codeUnits),
    );

    _awakeWriteLoop();

    // Wait for readLoop to end
    await _readLoopCloseCh.future;
  }

  /// Port of `Association.OpenStream` (association.go:1596-1609).
  Stream? openStream(
    int streamIdentifier,
    PayloadProtocolIdentifier defaultPayloadType,
  ) {
    switch (getState()) {
      case _stateShutdownAckSent:
      case _stateShutdownPending:
      case _stateShutdownReceived:
      case _stateShutdownSent:
      case _stateClosed:
        throw const AssociationClosedException();
    }

    return _getOrCreateStream(streamIdentifier, false, defaultPayloadType);
  }

  /// Port of `Association.AcceptStream` (association.go:1612-1619). Throws
  /// [EofException] where Go returns `io.EOF` (no more incoming streams).
  Future<Stream> acceptStream() async {
    final s = await _acceptCh.receive();
    if (s == null) {
      throw const EofException();
    }
    return s;
  }

  /// Port of `Association.BytesSent` (association.go:1165-1168).
  int getBytesSent() => bytesSent;

  /// Port of `Association.BytesReceived` (association.go:1170-1173).
  int getBytesReceived() => bytesReceived;

  /// Port of `Association.MTU` (association.go:1175-1178).
  int getMtu() => mtu;

  /// Port of `Association.CWND` (association.go:1180-1183).
  int getCwnd() => cwnd;

  void _setCwnd(int newCwnd) {
    cwnd = newCwnd < minCwnd ? minCwnd : newCwnd;
  }

  /// Port of `Association.RWND` (association.go:1192-1195).
  int getRwnd() => rwnd;

  void _setRwnd(int newRwnd) {
    rwnd = newRwnd;
  }

  /// Port of `Association.SRTT` (association.go:1201-1204).
  double getSrtt() => srtt;

  /// Port of `Association.BufferedAmount` (association.go:2930-2935): total
  /// amount, in bytes, of currently buffered user data.
  int getBufferedAmount() =>
      pendingQueue.getNumBytes() + inflightQueue.getNumBytes();

  /// Port of `Association.MaxMessageSize` (association.go:2937-2940).
  int maxMessageSize_() => maxMessageSize;

  /// Port of `Association.SetMaxMessageSize` (association.go:2943-2945).
  void setMaxMessageSize(int maxMsgSize) {
    maxMessageSize = maxMsgSize;
  }

  // ---------------------------------------------------------------------
  // Internal machinery: init, read loop, write loop
  // ---------------------------------------------------------------------

  /// Port of `Association.init` (association.go:418-452).
  void _initAssociation(bool isClient) {
    unawaited(_readLoop());
    unawaited(_writeLoop());

    if (isClient) {
      final init = ChunkInit(
        common: ChunkInitCommon(
          initialTsn: myNextTsn,
          numOutboundStreams: myMaxNumOutboundStreams,
          numInboundStreams: myMaxNumInboundStreams,
          initiateTag: myVerificationTag,
          advertisedReceiverWindowCredit: maxReceiveBufferSize,
        ),
      );
      _setSupportedExtensions(init.common);

      if (recvZeroChecksum) {
        init.common.params.add(
          ParamZeroChecksumAcceptable(edmid: dtlsErrorDetectionMethod),
        );
      }

      storedInit = init;

      try {
        _sendInit();
      } on Object catch (e) {
        log.errorf('[%s] failed to send init: %s', [name, e]);
      }

      // After sending the INIT chunk, "A" starts the T1-init timer and
      // enters the COOKIE-WAIT state.
      _setState(_stateCookieWait);
      t1Init.start(rtoMgr.getRTO());
    }
  }

  /// Port of `Association.sendInit` (association.go:454-474): the caller
  /// must hold the lock (moot here, see this file's doc comment).
  void _sendInit() {
    log.debugf('[%s] sending INIT', [name]);
    final init = storedInit;
    if (init == null) {
      throw const InitNotStoredToSendException();
    }

    sourcePort = defaultSctpSrcDstPort;
    destinationPort = defaultSctpSrcDstPort;
    final outbound = Packet(
      sourcePort: sourcePort,
      destinationPort: destinationPort,
      verificationTag: 0,
      chunks: [init],
    );

    controlQueue.push(outbound);
    _awakeWriteLoop();
  }

  /// Port of `Association.sendCookieEcho` (association.go:477-494).
  void _sendCookieEcho() {
    final echo = storedCookieEcho;
    if (echo == null) {
      throw const CookieEchoNotStoredToSendException();
    }

    log.debugf('[%s] sending COOKIE-ECHO', [name]);

    final outbound = Packet(
      sourcePort: sourcePort,
      destinationPort: destinationPort,
      verificationTag: peerVerificationTag,
      chunks: [echo],
    );

    controlQueue.push(outbound);
    _awakeWriteLoop();
  }

  void _closeAllTimers() {
    t1Init.close();
    t1Cookie.close();
    t2Shutdown.close();
    t3Rtx.close();
    tReconfig.close();
    ackTimer.close();
  }

  void _closeWriteLoopOnce() {
    if (!_closeWriteLoopOnceDone) {
      _closeWriteLoopOnceDone = true;
      if (!_closeWriteLoopCh.isCompleted) {
        _closeWriteLoopCh.complete();
      }
    }
  }

  /// Port of `Association.readLoop` (association.go:597-646).
  Future<void> _readLoop() async {
    Object? closeErr;

    log.debugf('[%s] readLoop entered', [name]);

    try {
      while (true) {
        final conn = _netConn;
        if (conn == null) {
          break;
        }
        final buffer = Uint8List(_receiveMtu);
        final int n;
        try {
          n = await conn.read(buffer);
        } on Object catch (e) {
          closeErr = e;
          break;
        }
        if (n <= 0) {
          break;
        }
        final inbound = Uint8List.sublistView(buffer, 0, n);
        bytesReceived += n;
        try {
          await _handleInbound(inbound);
        } on Object catch (e) {
          closeErr = e;
          break;
        }
      }
    } finally {
      // also stop writeLoop, otherwise writeLoop can be leaked if the
      // connection is lost when there is no writing packet.
      _closeWriteLoopOnce();

      _setState(_stateClosed);
      for (final s in streams.values) {
        _unregisterStream(s, closeErr);
      }
      _acceptCh.close();
      if (!_readLoopCloseCh.isCompleted) {
        _readLoopCloseCh.complete();
      }

      log.debugf('[%s] readLoop exited %s', [name, closeErr]);
    }
  }

  /// Port of `Association.writeLoop` (association.go:648-687).
  Future<void> _writeLoop() async {
    log.debugf('[%s] writeLoop entered', [name]);

    loop:
    while (true) {
      final (rawPackets, ok) = _gatherOutbound();

      final conn = _netConn;
      for (final raw in rawPackets) {
        if (conn == null) {
          break loop;
        }
        try {
          await conn.write(raw);
        } on Object catch (e) {
          log.warnf('[%s] failed to write packets on netConn: %s', [name, e]);
          break loop;
        }
        bytesSent += raw.length;
        stats.incPacketsSent();
      }

      if (!ok) {
        await _closeInternal();
        return;
      }

      final awake = _awakeWriteLoopCh.future;
      final closed = _closeWriteLoopCh.future;
      final result = await Future.any([
        awake.then((_) => 0),
        closed.then((_) => 1),
      ]);
      if (result == 1) {
        break loop;
      }
    }

    _setState(_stateClosed);
    _closeAllTimers();
    log.debugf('[%s] writeLoop exited', [name]);
  }

  void _awakeWriteLoop() {
    if (!_awakeWriteLoopCh.isCompleted) {
      _awakeWriteLoopCh.complete();
    }
  }

  /// Port of `Association.isBlockWrite` (association.go:696-698).
  bool isBlockWrite() => blockWrite;

  /// Port of `Association.notifyBlockWritable` (association.go:700-708):
  /// marks the association writable and unblocks the waiting write.
  void _notifyBlockWritable() {
    writePending = false;
    final old = _writeNotify;
    _writeNotify = Completer<void>();
    if (!old.isCompleted) {
      old.complete();
    }
  }

  /// Port of `Association.unregisterStream` (association.go:710-719):
  /// un-registers a stream from the association.
  void _unregisterStream(Stream s, Object? err) {
    streams.remove(s.streamIdentifier);
    s.readErr = err;
    s._notifyReaders();
  }

  /// Port of `Association.marshalPacket` (association.go:732-734).
  Uint8List _marshalPacket(Packet p) =>
      p.marshal(!sendZeroChecksum || _chunkMandatoryChecksum(p.chunks));

  /// Port of `Association.unmarshalPacket` (association.go:736-743).
  Packet _unmarshalPacket(Uint8List raw) {
    final p = Packet();
    p.unmarshal(!recvZeroChecksum, raw);
    return p;
  }

  /// Port of `Association.handleInbound` (association.go:745-771): parses
  /// incoming raw packets.
  Future<void> _handleInbound(Uint8List raw) async {
    final Packet pkt;
    try {
      pkt = _unmarshalPacket(raw);
    } on Object catch (e) {
      log.warnf('[%s] unable to parse SCTP packet %s', [name, e]);
      return;
    }

    try {
      _checkPacket(pkt);
    } on Object catch (e) {
      log.warnf('[%s] failed validating packet %s', [name, e]);
      return;
    }

    _handleChunksStart();

    for (final c in pkt.chunks) {
      await _handleChunk(pkt, c);
    }

    _handleChunksEnd();
  }

  /// Port of `Association.gatherDataPacketsToRetransmit`
  /// (association.go:774-786): the caller should hold the lock.
  List<Uint8List> _gatherDataPacketsToRetransmit(List<Uint8List> rawPackets) {
    for (final p in _getDataPacketsToRetransmit()) {
      try {
        rawPackets.add(_marshalPacket(p));
      } on Object {
        log.warnf(
          '[%s] failed to serialize a DATA packet to be retransmitted',
          [name],
        );
      }
    }
    return rawPackets;
  }

  /// Port of `Association.gatherOutboundDataAndReconfigPackets`
  /// (association.go:791-853).
  List<Uint8List> _gatherOutboundDataAndReconfigPackets(
    List<Uint8List> rawPackets,
  ) {
    final (chunks, sisToReset) = _popPendingDataChunksToSend();
    if (chunks.isNotEmpty) {
      t3Rtx.start(rtoMgr.getRTO());
      for (final p in _bundleDataChunksIntoPackets(chunks)) {
        try {
          rawPackets.add(_marshalPacket(p));
        } on Object {
          log.warnf('[%s] failed to serialize a DATA packet', [name]);
        }
      }
    }

    if (sisToReset.isNotEmpty || willRetransmitReconfig) {
      if (willRetransmitReconfig) {
        willRetransmitReconfig = false;
        for (final c in reconfigs.values) {
          final p = _createPacket([c]);
          try {
            rawPackets.add(_marshalPacket(p));
          } on Object {
            log.warnf(
              '[%s] failed to serialize a RECONFIG packet to be retransmitted',
              [name],
            );
          }
        }
      }

      if (sisToReset.isNotEmpty) {
        final rsn = _generateNextRsn();
        final tsn = _u32(myNextTsn - 1);
        final c = ChunkReconfig(
          paramA: ParamOutgoingResetRequest(
            reconfigRequestSequenceNumber: rsn,
            senderLastTsn: tsn,
            streamIdentifiers: sisToReset,
          ),
        );
        reconfigs[rsn] = c;
        final p = _createPacket([c]);
        try {
          rawPackets.add(_marshalPacket(p));
        } on Object {
          log.warnf(
            '[%s] failed to serialize a RECONFIG packet to be transmitted',
            [name],
          );
        }
      }

      if (reconfigs.isNotEmpty) {
        tReconfig.start(rtoMgr.getRTO());
      }
    }

    return rawPackets;
  }

  /// Port of `Association.gatherOutboundFastRetransmissionPackets`
  /// (association.go:858-921).
  List<Uint8List> _gatherOutboundFastRetransmissionPackets(
    List<Uint8List> rawPackets,
  ) {
    if (willRetransmitFast) {
      willRetransmitFast = false;

      final toFastRetrans = <ChunkPayloadData>[];
      var fastRetransSize = _commonHeaderSize;

      var fastRetransWnd = getMtu();
      if (fastRetransWnd < fastRtxWnd) {
        fastRetransWnd = fastRtxWnd;
      }
      for (var i = 0; ; i++) {
        final chunkPayload = inflightQueue.get(
          _u32(cumulativeTsnAckPoint + i + 1),
        );
        if (chunkPayload == null) {
          break;
        }

        if (chunkPayload.acked || chunkPayload.abandoned()) {
          continue;
        }

        if (chunkPayload.nSent > 1 || chunkPayload.missIndicator < 3) {
          continue;
        }

        final dataChunkSize =
            _dataChunkHeaderSize + chunkPayload.userData.length;
        if (fastRetransWnd < fastRetransSize + dataChunkSize) {
          break;
        }

        fastRetransSize += dataChunkSize;
        stats.incFastRetrans();
        chunkPayload.nSent++;

        _checkPartialReliabilityStatus(chunkPayload);
        toFastRetrans.add(chunkPayload);
      }

      if (toFastRetrans.isNotEmpty) {
        for (final p in _bundleDataChunksIntoPackets(toFastRetrans)) {
          try {
            rawPackets.add(_marshalPacket(p));
          } on Object {
            log.warnf(
              '[%s] failed to serialize a DATA packet to be fast-retransmitted',
              [name],
            );
          }
        }
      }
    }

    return rawPackets;
  }

  /// Port of `Association.gatherOutboundSackPackets`
  /// (association.go:924-939).
  List<Uint8List> _gatherOutboundSackPackets(List<Uint8List> rawPackets) {
    if (ackState == _ackStateImmediate) {
      ackState = _ackStateIdle;
      final sack = _createSelectiveAckChunk();
      stats.incSacksSent();
      try {
        rawPackets.add(_marshalPacket(_createPacket([sack])));
      } on Object {
        log.warnf('[%s] failed to serialize a SACK packet', [name]);
      }
    }
    return rawPackets;
  }

  /// Port of `Association.gatherOutboundForwardTSNPackets`
  /// (association.go:942-957).
  List<Uint8List> _gatherOutboundForwardTsnPackets(List<Uint8List> rawPackets) {
    if (willSendForwardTsn) {
      willSendForwardTsn = false;
      if (_sna32Gt(advancedPeerTsnAckPoint, cumulativeTsnAckPoint)) {
        final fwdtsn = _createForwardTsn();
        try {
          rawPackets.add(_marshalPacket(_createPacket([fwdtsn])));
        } on Object {
          log.warnf('[%s] failed to serialize a Forward TSN packet', [name]);
        }
      }
    }
    return rawPackets;
  }

  /// Port of `Association.gatherOutboundShutdownPackets`
  /// (association.go:959-1004).
  (List<Uint8List>, bool) _gatherOutboundShutdownPackets(
    List<Uint8List> rawPackets,
  ) {
    var ok = true;

    if (willSendShutdown) {
      willSendShutdown = false;
      final shutdown = ChunkShutdown(cumulativeTsnAck: cumulativeTsnAckPoint);
      try {
        rawPackets.add(_marshalPacket(_createPacket([shutdown])));
        t2Shutdown.start(rtoMgr.getRTO());
      } on Object {
        log.warnf('[%s] failed to serialize a Shutdown packet', [name]);
      }
    } else if (willSendShutdownAck) {
      willSendShutdownAck = false;
      final shutdownAck = ChunkShutdownAck();
      try {
        rawPackets.add(_marshalPacket(_createPacket([shutdownAck])));
        t2Shutdown.start(rtoMgr.getRTO());
      } on Object {
        log.warnf('[%s] failed to serialize a ShutdownAck packet', [name]);
      }
    } else if (willSendShutdownComplete) {
      willSendShutdownComplete = false;
      final shutdownComplete = ChunkShutdownComplete();
      try {
        rawPackets.add(_marshalPacket(_createPacket([shutdownComplete])));
        ok = false;
      } on Object {
        log.warnf('[%s] failed to serialize a ShutdownComplete packet', [name]);
      }
    }

    return (rawPackets, ok);
  }

  /// Port of `Association.gatherAbortPacket` (association.go:1006-1021).
  Uint8List _gatherAbortPacket() {
    final cause = willSendAbortCause;

    willSendAbort = false;
    willSendAbortCause = null;

    final abort = ChunkAbort(errorCauses: cause != null ? [cause] : []);

    return _marshalPacket(_createPacket([abort]));
  }

  /// Port of `Association.gatherOutbound` (association.go:1025-1075):
  /// gathers outgoing packets. The returned bool set to `false` means the
  /// association should be closed down after the final send.
  (List<Uint8List>, bool) _gatherOutbound() {
    if (willSendAbort) {
      final Uint8List pkt;
      try {
        pkt = _gatherAbortPacket();
      } on Object {
        log.warnf('[%s] failed to serialize an abort packet', [name]);
        return (<Uint8List>[], false);
      }
      return ([pkt], false);
    }

    var rawPackets = <Uint8List>[];

    if (controlQueue.size() > 0) {
      for (final p in controlQueue.popAll()) {
        try {
          rawPackets.add(_marshalPacket(p));
        } on Object {
          log.warnf('[%s] failed to serialize a control packet', [name]);
        }
      }
    }

    final currentState = getState();
    var ok = true;

    switch (currentState) {
      case _stateEstablished:
        rawPackets = _gatherDataPacketsToRetransmit(rawPackets);
        rawPackets = _gatherOutboundDataAndReconfigPackets(rawPackets);
        rawPackets = _gatherOutboundFastRetransmissionPackets(rawPackets);
        rawPackets = _gatherOutboundSackPackets(rawPackets);
        rawPackets = _gatherOutboundForwardTsnPackets(rawPackets);
      case _stateShutdownPending:
      case _stateShutdownSent:
      case _stateShutdownReceived:
        rawPackets = _gatherDataPacketsToRetransmit(rawPackets);
        rawPackets = _gatherOutboundFastRetransmissionPackets(rawPackets);
        rawPackets = _gatherOutboundSackPackets(rawPackets);
        final (p2, ok2) = _gatherOutboundShutdownPackets(rawPackets);
        rawPackets = p2;
        ok = ok2;
      case _stateShutdownAckSent:
        final (p2, ok2) = _gatherOutboundShutdownPackets(rawPackets);
        rawPackets = p2;
        ok = ok2;
    }

    return (rawPackets, ok);
  }

  /// Port of `Association.peerLastTSN` (association.go:1143-1146).
  int _peerLastTsn() => payloadQueue.getcumulativeTSN();

  /// Port of `Association.setState` (association.go:1148-1158).
  void _setState(int newState) {
    final oldState = state;
    state = newState;
    if (newState != oldState) {
      log.debugf('[%s] state change: %s => %s', [
        name,
        _getAssociationStateString(oldState),
        _getAssociationStateString(newState),
      ]);
    }
  }

  /// Port of `Association.getState` (association.go:1161-1163).
  int getState() => state;

  /// Port of `Association.handleInit` (association.go:1236-1325): the
  /// caller should hold the lock.
  List<Packet>? _handleInit(Packet pkt, ChunkInit initChunk) {
    final currentState = getState();

    if (currentState != _stateClosed &&
        currentState != _stateCookieWait &&
        currentState != _stateCookieEchoed) {
      throw HandleInitStateException(_getAssociationStateString(currentState));
    }

    myMaxNumInboundStreams = _min16(
      initChunk.common.numInboundStreams,
      myMaxNumInboundStreams,
    );
    myMaxNumOutboundStreams = _min16(
      initChunk.common.numOutboundStreams,
      myMaxNumOutboundStreams,
    );
    peerVerificationTag = initChunk.common.initiateTag;
    sourcePort = pkt.destinationPort;
    destinationPort = pkt.sourcePort;

    payloadQueue.init(_u32(initChunk.common.initialTsn - 1));

    _setRwnd(initChunk.common.advertisedReceiverWindowCredit);

    for (final param in initChunk.common.params) {
      if (param is ParamSupportedExtensions) {
        for (final t in param.chunkTypes) {
          if (t == ChunkType.forwardTsn) {
            useForwardTsn = true;
          }
        }
      } else if (param is ParamZeroChecksumAcceptable) {
        sendZeroChecksum = param.edmid == dtlsErrorDetectionMethod;
      }
    }

    final outbound = Packet(
      sourcePort: sourcePort,
      destinationPort: destinationPort,
      verificationTag: peerVerificationTag,
    );

    final initAck = ChunkInitAck(
      common: ChunkInitCommon(
        initialTsn: myNextTsn,
        numOutboundStreams: myMaxNumOutboundStreams,
        numInboundStreams: myMaxNumInboundStreams,
        initiateTag: myVerificationTag,
        advertisedReceiverWindowCredit: maxReceiveBufferSize,
      ),
    );

    myCookie ??= ParamStateCookie.random();

    initAck.common.params = [myCookie!];

    if (recvZeroChecksum) {
      initAck.common.params.add(
        ParamZeroChecksumAcceptable(edmid: dtlsErrorDetectionMethod),
      );
    }

    _setSupportedExtensions(initAck.common);

    outbound.chunks = [initAck];

    return _pack(outbound);
  }

  /// Port of `Association.handleInitAck` (association.go:1328-1404): the
  /// caller should hold the lock.
  void _handleInitAck(Packet pkt, ChunkInitAck initChunkAck) {
    final currentState = getState();
    if (currentState != _stateCookieWait) {
      // RFC 4960 5.2.3: an unexpected INIT ACK is silently discarded.
      return;
    }

    myMaxNumInboundStreams = _min16(
      initChunkAck.common.numInboundStreams,
      myMaxNumInboundStreams,
    );
    myMaxNumOutboundStreams = _min16(
      initChunkAck.common.numOutboundStreams,
      myMaxNumOutboundStreams,
    );
    peerVerificationTag = initChunkAck.common.initiateTag;
    payloadQueue.init(_u32(initChunkAck.common.initialTsn - 1));
    if (sourcePort != pkt.destinationPort ||
        destinationPort != pkt.sourcePort) {
      log.warnf('[%s] handleInitAck: port mismatch', [name]);
      return;
    }

    _setRwnd(initChunkAck.common.advertisedReceiverWindowCredit);

    // RFC 4690 Sec 7.2.1: the initial value of ssthresh MAY be arbitrarily
    // high.
    ssthresh = getRwnd();

    t1Init.stop();
    storedInit = null;

    ParamStateCookie? cookieParam;
    for (final param in initChunkAck.common.params) {
      if (param is ParamStateCookie) {
        cookieParam = param;
      } else if (param is ParamSupportedExtensions) {
        for (final t in param.chunkTypes) {
          if (t == ChunkType.forwardTsn) {
            useForwardTsn = true;
          }
        }
      } else if (param is ParamZeroChecksumAcceptable) {
        sendZeroChecksum = param.edmid == dtlsErrorDetectionMethod;
      }
    }

    if (cookieParam == null) {
      throw const InitAckNoCookieException();
    }

    storedCookieEcho = ChunkCookieEcho(cookie: cookieParam.cookie);

    try {
      _sendCookieEcho();
    } on Object catch (e) {
      log.errorf('[%s] failed to send init: %s', [name, e]);
    }

    t1Cookie.start(rtoMgr.getRTO());
    _setState(_stateCookieEchoed);
  }

  /// Port of `Association.handleHeartbeat` (association.go:1407-1426): the
  /// caller should hold the lock.
  List<Packet> _handleHeartbeat(ChunkHeartbeat c) {
    final hbi = c.params.isNotEmpty ? c.params[0] : null;
    final info = hbi is ParamHeartbeatInfo ? hbi : null;
    if (info == null) {
      log.warnf('[%s] failed to handle Heartbeat, no ParamHeartbeatInfo', [
        name,
      ]);
    }

    return _pack(
      Packet(
        verificationTag: peerVerificationTag,
        sourcePort: sourcePort,
        destinationPort: destinationPort,
        chunks: [
          ChunkHeartbeatAck(
            params: [
              ParamHeartbeatInfo(
                heartbeatInformation: info?.heartbeatInformation,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Port of `Association.handleCookieEcho` (association.go:1429-1472): the
  /// caller should hold the lock.
  List<Packet>? _handleCookieEcho(ChunkCookieEcho cookieEcho) {
    final currentState = getState();

    final cookie = myCookie;
    if (cookie == null) {
      return null;
    }

    switch (currentState) {
      case _stateEstablished:
        if (!_bytesEqual(cookie.cookie, cookieEcho.cookie)) {
          return null;
        }
      case _stateClosed:
      case _stateCookieWait:
      case _stateCookieEchoed:
        if (!_bytesEqual(cookie.cookie, cookieEcho.cookie)) {
          return null;
        }

        // RFC-wise these do not seem to belong here, but removing them
        // breaks TestCookieEchoRetransmission.
        t1Init.stop();
        storedInit = null;

        t1Cookie.stop();
        storedCookieEcho = null;

        _setState(_stateEstablished);
        if (!_completeHandshake(null)) {
          return null;
        }
      default:
        return null;
    }

    final p = Packet(
      verificationTag: peerVerificationTag,
      sourcePort: sourcePort,
      destinationPort: destinationPort,
      chunks: [ChunkCookieAck()],
    );

    return _pack(p);
  }

  /// Port of `Association.handleCookieAck` (association.go:1475-1491): the
  /// caller should hold the lock.
  void _handleCookieAck() {
    final currentState = getState();
    if (currentState != _stateCookieEchoed) {
      // RFC 4960 5.2.5: silently discard a duplicate COOKIE ACK.
      return;
    }

    t1Cookie.stop();
    storedCookieEcho = null;

    _setState(_stateEstablished);
    _completeHandshake(null);
  }

  /// Port of `Association.handleData` (association.go:1494-1534): the
  /// caller should hold the lock.
  List<Packet>? _handleData(ChunkPayloadData chunkPayload) {
    stats.incDatas();

    final canPush = payloadQueue.canPush(chunkPayload.tsn);
    if (canPush) {
      final stream = _getOrCreateStream(
        chunkPayload.streamIdentifier,
        true,
        PayloadProtocolIdentifier.unknown,
      );
      if (stream == null) {
        // silently discard the data. (sender will retry on T3-rtx timeout)
        return null;
      }

      if (_getMyReceiverWindowCredit() > 0) {
        payloadQueue.push(chunkPayload.tsn);
        stream.handleData(chunkPayload);
      } else {
        final lastTsn = payloadQueue.getLastTSNReceived();
        if (lastTsn != null && _sna32Lt(chunkPayload.tsn, lastTsn)) {
          payloadQueue.push(chunkPayload.tsn);
          stream.handleData(chunkPayload);
        }
      }
    }

    return _handlePeerLastTsnAndAcknowledgement(chunkPayload.immediateSack);
  }

  /// Port of `Association.handlePeerLastTSNAndAcknowledgement`
  /// (association.go:1538-1579): common routine for handleData and
  /// handleForwardTSN. The caller should hold the lock.
  List<Packet>? _handlePeerLastTsnAndAcknowledgement(bool sackImmediately) {
    List<Packet>? reply;

    // Try to advance peerLastTSN. From RFC 3758 Sec 3.6: advance the
    // cumulative TSN point locally as far as possible.
    while (payloadQueue.pop(false)) {
      for (final rstReq in reconfigRequests.values) {
        final resp = _resetStreamsIfAny(rstReq);
        if (resp != null) {
          (reply ??= []).add(resp);
        }
      }
    }

    final hasPacketLoss = payloadQueue.size() > 0;

    if ((ackState != _ackStateImmediate &&
            !sackImmediately &&
            !hasPacketLoss &&
            ackMode == ackModeNormal) ||
        ackMode == ackModeAlwaysDelay) {
      if (ackState == _ackStateIdle) {
        delayedAckTriggered = true;
      } else {
        immediateAckTriggered = true;
      }
    } else {
      immediateAckTriggered = true;
    }

    return reply;
  }

  /// Port of `Association.getMyReceiverWindowCredit`
  /// (association.go:1582-1593): the caller should hold the lock.
  int _getMyReceiverWindowCredit() {
    var bytesQueued = 0;
    for (final s in streams.values) {
      bytesQueued += s.getNumBytesInReassemblyQueue();
    }

    if (bytesQueued >= maxReceiveBufferSize) {
      return 0;
    }

    return maxReceiveBufferSize - bytesQueued;
  }

  /// Port of `Association.createStream` (association.go:1621-1651): the
  /// caller should hold the lock and check no stream exists for this id.
  Stream? _createStream(int streamIdentifier, bool accept) {
    final stream = Stream(
      association: this,
      streamIdentifier: streamIdentifier,
      name: '$streamIdentifier:$name',
    );

    if (accept) {
      if (_acceptCh.trySend(stream)) {
        streams[streamIdentifier] = stream;
      } else {
        return null;
      }
    } else {
      streams[streamIdentifier] = stream;
    }

    return stream;
  }

  /// Port of `Association.getOrCreateStream` (association.go:1654-1671): the
  /// caller should hold the lock.
  Stream? _getOrCreateStream(
    int streamIdentifier,
    bool accept,
    PayloadProtocolIdentifier defaultPayloadType,
  ) {
    final existing = streams[streamIdentifier];
    if (existing != null) {
      existing.setDefaultPayloadType(defaultPayloadType);
      return existing;
    }

    final s = _createStream(streamIdentifier, accept);
    s?.setDefaultPayloadType(defaultPayloadType);
    return s;
  }

  /// Port of `Association.processSelectiveAck` (association.go:1676-1773):
  /// the caller should hold the lock. Returns
  /// `(bytesAckedPerStream, htna)`.
  (Map<int, int>, int) _processSelectiveAck(
    ChunkSelectiveAck selectiveAckChunk,
  ) {
    final bytesAckedPerStream = <int, int>{};

    for (
      var i = _u32(cumulativeTsnAckPoint + 1);
      _sna32Lte(i, selectiveAckChunk.cumulativeTsnAck);
      i = _u32(i + 1)
    ) {
      final chunkPayload = inflightQueue.pop(i);
      if (chunkPayload == null) {
        throw InflightQueueTsnPopException(i);
      }

      if (!chunkPayload.acked) {
        if (i == _u32(cumulativeTsnAckPoint + 1)) {
          t3Rtx.stop();
        }

        final nBytesAcked = chunkPayload.userData.length;

        bytesAckedPerStream[chunkPayload.streamIdentifier] =
            (bytesAckedPerStream[chunkPayload.streamIdentifier] ?? 0) +
            nBytesAcked;

        if (chunkPayload.nSent == 1 &&
            _sna32Gte(chunkPayload.tsn, minTsn2MeasureRtt)) {
          minTsn2MeasureRtt = myNextTsn;
          final rtt =
              DateTime.now().difference(chunkPayload.since!).inMicroseconds /
              1000.0;
          srtt = rtoMgr.setNewRTT(rtt);
        }
      }

      if (inFastRecovery && chunkPayload.tsn == fastRecoverExitPoint) {
        inFastRecovery = false;
      }
    }

    var htna = selectiveAckChunk.cumulativeTsnAck;

    for (final g in selectiveAckChunk.gapAckBlocks) {
      for (var i = g.start; i <= g.end; i++) {
        final tsn = _u32(selectiveAckChunk.cumulativeTsnAck + i);
        final chunkPayload = inflightQueue.get(tsn);
        if (chunkPayload == null) {
          throw TsnRequestNotExistException(tsn);
        }

        if (!chunkPayload.acked) {
          final nBytesAcked = inflightQueue.markAsAcked(tsn);

          bytesAckedPerStream[chunkPayload.streamIdentifier] =
              (bytesAckedPerStream[chunkPayload.streamIdentifier] ?? 0) +
              nBytesAcked;

          if (chunkPayload.nSent == 1) {
            minTsn2MeasureRtt = myNextTsn;
            final rtt =
                DateTime.now().difference(chunkPayload.since!).inMicroseconds /
                1000.0;
            srtt = rtoMgr.setNewRTT(rtt);
          }

          if (_sna32Lt(htna, tsn)) {
            htna = tsn;
          }
        }
      }
    }

    return (bytesAckedPerStream, htna);
  }

  /// Port of `Association.onCumulativeTSNAckPointAdvanced`
  /// (association.go:1776-1836): the caller should hold the lock.
  void _onCumulativeTsnAckPointAdvanced(int totalBytesAcked) {
    if (inflightQueue.size() == 0) {
      t3Rtx.stop();
    } else {
      t3Rtx.start(rtoMgr.getRTO());
    }

    if (getCwnd() <= ssthresh) {
      if (!inFastRecovery && pendingQueue.size() > 0) {
        _setCwnd(getCwnd() + _min32(totalBytesAcked, getCwnd()));
      }
    } else {
      partialBytesAcked = _u32(partialBytesAcked + totalBytesAcked);

      if (partialBytesAcked >= getCwnd() && pendingQueue.size() > 0) {
        partialBytesAcked = _u32(partialBytesAcked - getCwnd());
        var step = getMtu();
        if (step < cwndCaStep) {
          step = cwndCaStep;
        }
        _setCwnd(getCwnd() + step);
      }
    }
  }

  /// Port of `Association.processFastRetransmission`
  /// (association.go:1841-1903): the caller should hold the lock.
  void _processFastRetransmission(
    int cumTsnAckPoint,
    List<GapAckBlock> gapAckBlocks,
    int htna,
    bool cumTsnAckPointAdvanced,
  ) {
    if (!inFastRecovery || (inFastRecovery && cumTsnAckPointAdvanced)) {
      int maxTsn;
      if (!inFastRecovery) {
        maxTsn = htna;
      } else {
        maxTsn = cumTsnAckPoint;
        if (gapAckBlocks.isNotEmpty) {
          maxTsn = _u32(maxTsn + gapAckBlocks.last.end);
        }
      }

      for (
        var tsn = _u32(cumTsnAckPoint + 1);
        _sna32Lt(tsn, maxTsn);
        tsn = _u32(tsn + 1)
      ) {
        final c = inflightQueue.get(tsn);
        if (c == null) {
          throw TsnRequestNotExistException(tsn);
        }
        if (!c.acked && !c.abandoned() && c.missIndicator < 3) {
          c.missIndicator++;
          if (c.missIndicator == 3) {
            if (!inFastRecovery) {
              inFastRecovery = true;
              fastRecoverExitPoint = htna;
              ssthresh = _max32(getCwnd() ~/ 2, 4 * getMtu());
              _setCwnd(ssthresh);
              partialBytesAcked = 0;
              willRetransmitFast = true;
            }
          }
        }
      }
    }

    if (inFastRecovery && cumTsnAckPointAdvanced) {
      willRetransmitFast = true;
    }
  }

  /// Port of `Association.handleSack` (association.go:1908-2018): the
  /// caller should hold the lock.
  void _handleSack(ChunkSelectiveAck selectiveAckChunk) {
    final currentState = getState();
    if (currentState != _stateEstablished &&
        currentState != _stateShutdownPending &&
        currentState != _stateShutdownReceived) {
      return;
    }

    stats.incSacksReceived();

    if (_sna32Gt(cumulativeTsnAckPoint, selectiveAckChunk.cumulativeTsnAck)) {
      // Out-of-order SACK; drop.
      return;
    }

    final (bytesAckedPerStream, htna) = _processSelectiveAck(selectiveAckChunk);

    var totalBytesAcked = 0;
    for (final nBytesAcked in bytesAckedPerStream.values) {
      totalBytesAcked += nBytesAcked;
    }

    var cumTsnAckPointAdvanced = false;
    if (_sna32Lt(cumulativeTsnAckPoint, selectiveAckChunk.cumulativeTsnAck)) {
      cumulativeTsnAckPoint = selectiveAckChunk.cumulativeTsnAck;
      cumTsnAckPointAdvanced = true;
      _onCumulativeTsnAckPointAdvanced(totalBytesAcked);
    }

    for (final entry in bytesAckedPerStream.entries) {
      final s = streams[entry.key];
      if (s != null) {
        s.onBufferReleased(entry.value);
      }
    }

    final bytesOutstanding = inflightQueue.getNumBytes();
    if (bytesOutstanding >= selectiveAckChunk.advertisedReceiverWindowCredit) {
      _setRwnd(0);
    } else {
      _setRwnd(
        selectiveAckChunk.advertisedReceiverWindowCredit - bytesOutstanding,
      );
    }

    _processFastRetransmission(
      selectiveAckChunk.cumulativeTsnAck,
      selectiveAckChunk.gapAckBlocks,
      htna,
      cumTsnAckPointAdvanced,
    );

    if (useForwardTsn) {
      if (_sna32Lt(advancedPeerTsnAckPoint, cumulativeTsnAckPoint)) {
        advancedPeerTsnAckPoint = cumulativeTsnAckPoint;
      }

      for (var i = _u32(advancedPeerTsnAckPoint + 1); ; i = _u32(i + 1)) {
        final c = inflightQueue.get(i);
        if (c == null || !c.abandoned()) {
          break;
        }
        advancedPeerTsnAckPoint = i;
      }

      if (_sna32Gt(advancedPeerTsnAckPoint, cumulativeTsnAckPoint)) {
        willSendForwardTsn = true;
      }
      _awakeWriteLoop();
    }

    _postprocessSack(currentState, cumTsnAckPointAdvanced);
  }

  /// Port of `Association.postprocessSack` (association.go:2022-2043).
  void _postprocessSack(int currentState, bool shouldAwakeWriteLoopArg) {
    var shouldAwakeWriteLoop = shouldAwakeWriteLoopArg;
    if (inflightQueue.size() > 0) {
      t3Rtx.start(rtoMgr.getRTO());
    } else if (currentState == _stateShutdownPending) {
      shouldAwakeWriteLoop = true;
      willSendShutdown = true;
      _setState(_stateShutdownSent);
    } else if (currentState == _stateShutdownReceived) {
      shouldAwakeWriteLoop = true;
      willSendShutdownAck = true;
      _setState(_stateShutdownAckSent);
    }

    if (shouldAwakeWriteLoop) {
      _awakeWriteLoop();
    }
  }

  /// Port of `Association.handleShutdown` (association.go:2046-2068): the
  /// caller should hold the lock.
  void _handleShutdown(ChunkShutdown _) {
    final currentState = getState();

    if (currentState == _stateEstablished) {
      if (inflightQueue.size() > 0) {
        _setState(_stateShutdownReceived);
      } else {
        willSendShutdownAck = true;
        _setState(_stateShutdownAckSent);
        _awakeWriteLoop();
      }
    } else if (currentState == _stateShutdownSent) {
      willSendShutdownAck = true;
      _setState(_stateShutdownAckSent);
      _awakeWriteLoop();
    }
  }

  /// Port of `Association.handleShutdownAck` (association.go:2071-2079).
  void _handleShutdownAck(ChunkShutdownAck _) {
    final currentState = getState();
    if (currentState == _stateShutdownSent ||
        currentState == _stateShutdownAckSent) {
      t2Shutdown.stop();
      willSendShutdownComplete = true;
      _awakeWriteLoop();
    }
  }

  /// Port of `Association.handleShutdownComplete`
  /// (association.go:2081-2090).
  Future<void> _handleShutdownComplete(ChunkShutdownComplete _) async {
    final currentState = getState();
    if (currentState == _stateShutdownAckSent) {
      t2Shutdown.stop();
      await _closeInternal();
    }
  }

  /// Port of `Association.handleAbort` (association.go:2092-2101).
  Future<void> _handleAbort(ChunkAbort c) async {
    var errStr = '';
    for (final e in c.errorCauses) {
      errStr += '($e)';
    }

    await _closeInternal();

    throw ChunkException(name, errStr);
  }

  /// Port of `Association.createForwardTSN` (association.go:2106-2143): the
  /// caller should hold the lock.
  ChunkForwardTsn _createForwardTsn() {
    final streamMap = <int, int>{};
    for (
      var i = _u32(cumulativeTsnAckPoint + 1);
      _sna32Lte(i, advancedPeerTsnAckPoint);
      i = _u32(i + 1)
    ) {
      final c = inflightQueue.get(i);
      if (c == null) {
        break;
      }

      final ssn = streamMap[c.streamIdentifier];
      if (ssn == null) {
        streamMap[c.streamIdentifier] = c.streamSequenceNumber;
      } else if (_sna16Lt(ssn, c.streamSequenceNumber)) {
        streamMap[c.streamIdentifier] = c.streamSequenceNumber;
      }
    }

    final fwdtsn = ChunkForwardTsn(newCumulativeTsn: advancedPeerTsnAckPoint);
    for (final entry in streamMap.entries) {
      fwdtsn.streams.add(
        ChunkForwardTsnStream(identifier: entry.key, sequence: entry.value),
      );
    }

    return fwdtsn;
  }

  /// Port of `Association.createPacket` (association.go:2147-2154): wraps
  /// chunks in a packet. The caller should hold the read lock.
  Packet _createPacket(List<Chunk> cs) => Packet(
    verificationTag: peerVerificationTag,
    sourcePort: sourcePort,
    destinationPort: destinationPort,
    chunks: cs,
  );

  /// Port of `Association.handleReconfig` (association.go:2157-2181): the
  /// caller should hold the lock.
  List<Packet> _handleReconfig(ChunkReconfig reconfigChunk) {
    final pp = <Packet>[];

    final pkt = _handleReconfigParam(reconfigChunk.paramA!);
    if (pkt != null) {
      pp.add(pkt);
    }

    final paramB = reconfigChunk.paramB;
    if (paramB != null) {
      final pkt2 = _handleReconfigParam(paramB);
      if (pkt2 != null) {
        pp.add(pkt2);
      }
    }

    return pp;
  }

  /// Port of `Association.handleForwardTSN` (association.go:2184-2255): the
  /// caller should hold the lock.
  List<Packet>? _handleForwardTsn(ChunkForwardTsn chunkTsn) {
    if (!useForwardTsn) {
      final cerr = ChunkError(errorCauses: [ErrorCauseUnrecognizedChunkType()]);
      return [
        Packet(
          verificationTag: peerVerificationTag,
          sourcePort: sourcePort,
          destinationPort: destinationPort,
          chunks: [cerr],
        ),
      ];
    }

    // From RFC 3758 Sec 3.6: an out-of-date FORWARD TSN is not applied, but
    // still triggers a SACK.
    if (_sna32Lte(chunkTsn.newCumulativeTsn, _peerLastTsn())) {
      ackState = _ackStateImmediate;
      ackTimer.stop();
      _awakeWriteLoop();
      return null;
    }

    // Advance peerLastTSN
    while (_sna32Lt(_peerLastTsn(), chunkTsn.newCumulativeTsn)) {
      payloadQueue.pop(true);
    }

    for (final forwarded in chunkTsn.streams) {
      final s = streams[forwarded.identifier];
      s?.handleForwardTsnForOrdered(forwarded.sequence);
    }

    // Unordered chunks may be forwarded too; ForwardTSN does not report
    // which stream identifier it skipped for those, so broadcast to all.
    for (final s in streams.values) {
      s.handleForwardTsnForUnordered(chunkTsn.newCumulativeTsn);
    }

    return _handlePeerLastTsnAndAcknowledgement(false);
  }

  /// Port of `Association.sendResetRequest` (association.go:2257-2280).
  Future<void> sendResetRequest(int streamIdentifier) async {
    final currentState = getState();
    if (currentState != _stateEstablished) {
      throw ResetPacketInStateNotExistException(
        _getAssociationStateString(currentState),
      );
    }

    // Create a DATA chunk with only a valid stream identifier and no
    // userData, used as an end-of-stream signal.
    final c = ChunkPayloadData(
      streamIdentifier: streamIdentifier,
      beginningFragment: true,
      endingFragment: true,
    );

    pendingQueue.push(c);
    _awakeWriteLoop();
  }

  /// Port of `Association.handleReconfigParam` (association.go:2283-2332):
  /// the caller should hold the lock.
  Packet? _handleReconfigParam(Param raw) {
    if (raw is ParamOutgoingResetRequest) {
      if (_peerLastTsn() < raw.senderLastTsn &&
          reconfigRequests.length >= _maxReconfigRequests) {
        throw TooManyReconfigRequestsException(reconfigRequests.length);
      }
      reconfigRequests[raw.reconfigRequestSequenceNumber] = raw;
      return _resetStreamsIfAny(raw);
    } else if (raw is ParamReconfigResponse) {
      if (raw.result == ReconfigResult.inProgress) {
        if (reconfigs.containsKey(raw.reconfigResponseSequenceNumber)) {
          tReconfig.stop();
          tReconfig.start(rtoMgr.getRTO());
        }
        return null;
      }
      reconfigs.remove(raw.reconfigResponseSequenceNumber);
      if (reconfigs.isEmpty) {
        tReconfig.stop();
      }
      return null;
    }
    throw ParamterTypeException(raw);
  }

  /// Port of `Association.resetStreamsIfAny` (association.go:2335-2364): the
  /// caller should hold the lock.
  Packet _resetStreamsIfAny(ParamOutgoingResetRequest resetRequest) {
    var result = ReconfigResult.successPerformed;
    if (_sna32Lte(resetRequest.senderLastTsn, _peerLastTsn())) {
      for (final id in resetRequest.streamIdentifiers) {
        final s = streams[id];
        if (s == null) {
          continue;
        }
        s.onInboundStreamReset();
        streams.remove(s.streamIdentifier);
      }
      reconfigRequests.remove(resetRequest.reconfigRequestSequenceNumber);
    } else {
      result = ReconfigResult.inProgress;
    }

    return _createPacket([
      ChunkReconfig(
        paramA: ParamReconfigResponse(
          reconfigResponseSequenceNumber:
              resetRequest.reconfigRequestSequenceNumber,
          result: result,
        ),
      ),
    ]);
  }

  /// Port of `Association.movePendingDataChunkToInflightQueue`
  /// (association.go:2368-2399): moves the chunk peeked with
  /// `pendingQueue.peek()` to the inflight queue. The caller should hold the
  /// lock.
  void _movePendingDataChunkToInflightQueue(ChunkPayloadData chunkPayload) {
    pendingQueue.pop(chunkPayload);

    if (chunkPayload.endingFragment) {
      chunkPayload.setAllInflight();
    }

    chunkPayload.tsn = _generateNextTsn();

    chunkPayload.since = DateTime.now();
    chunkPayload.nSent = 1;

    _checkPartialReliabilityStatus(chunkPayload);

    inflightQueue.pushNoCheck(chunkPayload);
  }

  /// Port of `Association.popPendingDataChunksToSend`
  /// (association.go:2406-2467): pops chunks from the pending queues as many
  /// as `cwnd`/`rwnd` allow. The caller should hold the lock.
  (List<ChunkPayloadData>, List<int>) _popPendingDataChunksToSend() {
    final chunks = <ChunkPayloadData>[];
    final sisToReset = <int>[];

    if (pendingQueue.size() > 0) {
      while (true) {
        final chunkPayload = pendingQueue.peek();
        if (chunkPayload == null) {
          break;
        }

        final dataLen = chunkPayload.userData.length;
        if (dataLen == 0) {
          sisToReset.add(chunkPayload.streamIdentifier);
          pendingQueue.pop(chunkPayload);
          continue;
        }

        if (inflightQueue.getNumBytes() + dataLen > getCwnd()) {
          break;
        }

        if (dataLen > getRwnd()) {
          break;
        }

        _setRwnd(getRwnd() - dataLen);

        _movePendingDataChunkToInflightQueue(chunkPayload);
        chunks.add(chunkPayload);
      }

      // The data sender can always have one DATA chunk in flight.
      if (chunks.isEmpty && inflightQueue.size() == 0) {
        final c = pendingQueue.peek();
        if (c != null) {
          _movePendingDataChunkToInflightQueue(c);
          chunks.add(c);
        }
      }
    }

    if (blockWrite && chunks.isNotEmpty && pendingQueue.size() == 0) {
      _notifyBlockWritable();
    }

    return (chunks, sisToReset);
  }

  /// Port of `Association.bundleDataChunksIntoPackets`
  /// (association.go:2473-2500): packs DATA chunks into packets, bundling as
  /// long as the resulting packet size does not exceed the path MTU. The
  /// caller should hold the lock.
  List<Packet> _bundleDataChunksIntoPackets(List<ChunkPayloadData> chunks) {
    final packets = <Packet>[];
    var chunksToSend = <Chunk>[];
    var bytesInPacket = _commonHeaderSize;

    for (final chunkPayload in chunks) {
      var chunkSizeInPacket =
          _dataChunkHeaderSize + chunkPayload.userData.length;
      chunkSizeInPacket += getPadding(chunkSizeInPacket);
      if (bytesInPacket + chunkSizeInPacket > getMtu()) {
        packets.add(_createPacket(chunksToSend));
        chunksToSend = <Chunk>[];
        bytesInPacket = _commonHeaderSize;
      }
      chunksToSend.add(chunkPayload);
      bytesInPacket += chunkSizeInPacket;
    }

    if (chunksToSend.isNotEmpty) {
      packets.add(_createPacket(chunksToSend));
    }

    return packets;
  }

  /// Port of `Association.sendPayloadData` (association.go:2503-2536): sends
  /// the data chunks. `ctx` is Go's `context.Context` parameter, narrowed to
  /// the concrete `Deadline` its only caller (`Stream.writeSctp`) passes --
  /// see this file's doc comment.
  Future<void> sendPayloadData(
    Deadline ctx,
    List<ChunkPayloadData> chunks,
  ) async {
    final currentState = getState();
    if (currentState != _stateEstablished) {
      throw PayloadDataStateNotExistException(
        _getAssociationStateString(currentState),
      );
    }

    if (blockWrite) {
      while (writePending) {
        final waitFuture = _writeNotify.future;
        final result = await Future.any([
          ctx.done.then((_) => 1),
          waitFuture.then((_) => 0),
        ]);
        if (result == 1) {
          throw ctx.err ?? const _DeadlineDoneException();
        }
      }
      writePending = true;
    }

    for (final c in chunks) {
      pendingQueue.push(c);
    }

    _awakeWriteLoop();
  }

  /// Port of `Association.checkPartialReliabilityStatus`
  /// (association.go:2539-2579): the caller should hold the lock.
  void _checkPartialReliabilityStatus(ChunkPayloadData chunkPayload) {
    if (!useForwardTsn) {
      return;
    }

    // draft-ietf-rtcweb-data-protocol-09 section 6: DCEP messages MUST use
    // ordered delivery and reliable transmission.
    if (chunkPayload.payloadType == PayloadProtocolIdentifier.webRtcDcep) {
      return;
    }

    final stream = streams[chunkPayload.streamIdentifier];
    if (stream != null) {
      if (stream.reliabilityType == reliabilityTypeRexmit) {
        if (chunkPayload.nSent >= stream.reliabilityValue) {
          chunkPayload.setAbandoned(true);
        }
      } else if (stream.reliabilityType == reliabilityTypeTimed) {
        final elapsed = DateTime.now()
            .difference(chunkPayload.since!)
            .inMilliseconds;
        if (elapsed >= stream.reliabilityValue) {
          chunkPayload.setAbandoned(true);
        }
      }
    }
  }

  /// Port of `Association.getDataPacketsToRetransmit`
  /// (association.go:2584-2625): called when T3-rtx times out; retransmits
  /// outstanding data chunks that are not acked or abandoned. The caller
  /// should hold the lock.
  List<Packet> _getDataPacketsToRetransmit() {
    final awnd = _min32(getCwnd(), getRwnd());
    final chunks = <ChunkPayloadData>[];
    var bytesToSend = 0;
    var done = false;

    for (var i = 0; !done; i++) {
      final chunkPayload = inflightQueue.get(
        _u32(cumulativeTsnAckPoint + i + 1),
      );
      if (chunkPayload == null) {
        break;
      }

      if (!chunkPayload.retransmit) {
        continue;
      }

      if (i == 0 && getRwnd() < chunkPayload.userData.length) {
        done = true;
      } else if (bytesToSend + chunkPayload.userData.length > awnd) {
        break;
      }

      chunkPayload.retransmit = false;
      bytesToSend += chunkPayload.userData.length;

      chunkPayload.nSent++;

      _checkPartialReliabilityStatus(chunkPayload);

      chunks.add(chunkPayload);
    }

    return _bundleDataChunksIntoPackets(chunks);
  }

  /// Port of `Association.generateNextTSN` (association.go:2629-2634): the
  /// caller should hold the lock.
  int _generateNextTsn() {
    final tsn = myNextTsn;
    myNextTsn = _u32(myNextTsn + 1);
    return tsn;
  }

  /// Port of `Association.generateNextRSN` (association.go:2638-2643): the
  /// caller should hold the lock.
  int _generateNextRsn() {
    final rsn = myNextRsn;
    myNextRsn = _u32(myNextRsn + 1);
    return rsn;
  }

  /// Port of `Association.createSelectiveAckChunk`
  /// (association.go:2645-2653).
  ChunkSelectiveAck _createSelectiveAckChunk() => ChunkSelectiveAck(
    cumulativeTsnAck: _peerLastTsn(),
    advertisedReceiverWindowCredit: _getMyReceiverWindowCredit(),
    duplicateTsn: payloadQueue.popDuplicates(),
    gapAckBlocks: payloadQueue.getGapAckBlocks(),
  );

  /// Port of `Association.handleChunksStart` (association.go:2659-2667).
  void _handleChunksStart() {
    stats.incPacketsReceived();
    delayedAckTriggered = false;
    immediateAckTriggered = false;
  }

  /// Port of `Association.handleChunksEnd` (association.go:2669-2682).
  void _handleChunksEnd() {
    if (immediateAckTriggered) {
      ackState = _ackStateImmediate;
      ackTimer.stop();
      _awakeWriteLoop();
    } else if (delayedAckTriggered) {
      ackState = _ackStateDelay;
      ackTimer.start();
    }
  }

  /// Port of `Association.handleChunk` (association.go:2684-2772).
  Future<void> _handleChunk(Packet receivedPacket, Chunk receivedChunk) async {
    try {
      receivedChunk.check();
    } on Object catch (e) {
      log.errorf('[%s] failed validating chunk: %s ', [name, e]);
      return;
    }

    var isAbort = false;
    List<Packet>? packets;
    Object? err;

    try {
      if (receivedChunk is ChunkInit) {
        packets = _handleInit(receivedPacket, receivedChunk);
      } else if (receivedChunk is ChunkInitAck) {
        _handleInitAck(receivedPacket, receivedChunk);
      } else if (receivedChunk is ChunkAbort) {
        isAbort = true;
        await _handleAbort(receivedChunk);
      } else if (receivedChunk is ChunkError) {
        var errStr = '';
        for (final e in receivedChunk.errorCauses) {
          errStr += '($e)';
        }
        log.debugf('[%s] Error chunk, with following errors: %s', [
          name,
          errStr,
        ]);
      } else if (receivedChunk is ChunkHeartbeat) {
        packets = _handleHeartbeat(receivedChunk);
      } else if (receivedChunk is ChunkCookieEcho) {
        packets = _handleCookieEcho(receivedChunk);
      } else if (receivedChunk is ChunkCookieAck) {
        _handleCookieAck();
      } else if (receivedChunk is ChunkPayloadData) {
        packets = _handleData(receivedChunk);
      } else if (receivedChunk is ChunkSelectiveAck) {
        _handleSack(receivedChunk);
      } else if (receivedChunk is ChunkReconfig) {
        packets = _handleReconfig(receivedChunk);
      } else if (receivedChunk is ChunkForwardTsn) {
        packets = _handleForwardTsn(receivedChunk);
      } else if (receivedChunk is ChunkShutdown) {
        _handleShutdown(receivedChunk);
      } else if (receivedChunk is ChunkShutdownAck) {
        _handleShutdownAck(receivedChunk);
      } else if (receivedChunk is ChunkShutdownComplete) {
        await _handleShutdownComplete(receivedChunk);
      } else {
        throw const ChunkTypeUnhandledException();
      }
    } on Object catch (e) {
      err = e;
    }

    if (err != null) {
      if (isAbort) {
        throw err;
      }
      log.errorf('Failed to handle chunk: %s', [err]);
      return;
    }

    if (packets != null && packets.isNotEmpty) {
      controlQueue.pushAll(packets);
      _awakeWriteLoop();
    }
  }

  /// Port of `Association.onRetransmissionTimeout` (association.go:2774-2881).
  @override
  void onRetransmissionTimeout(int id, int nRtos) {
    // TSN hasn't been incremented in 3 attempts. Speculatively toggle
    // ZeroChecksum because old Pion versions had a broken implementation.
    if (_u32(cumulativeTsnAckPoint + 1) == initialTsn && nRtos % 3 == 0) {
      sendZeroChecksum = !sendZeroChecksum;
    }

    if (id == _timerT1Init) {
      try {
        _sendInit();
      } on Object {
        // retransmission attempt; ignore.
      }
      return;
    }

    if (id == _timerT1Cookie) {
      try {
        _sendCookieEcho();
      } on Object {
        // retransmission attempt; ignore.
      }
      return;
    }

    if (id == _timerT2Shutdown) {
      final currentState = getState();
      if (currentState == _stateShutdownSent) {
        willSendShutdown = true;
        _awakeWriteLoop();
      } else if (currentState == _stateShutdownAckSent) {
        willSendShutdownAck = true;
        _awakeWriteLoop();
      }
    }

    if (id == _timerT3Rtx) {
      stats.incT3Timeouts();

      // RFC 4960 sec 6.3.3/7.2.3: slow start on T3-rtx expiration.
      ssthresh = _max32(getCwnd() ~/ 2, 4 * getMtu());
      _setCwnd(getMtu());

      if (useForwardTsn) {
        for (var i = _u32(advancedPeerTsnAckPoint + 1); ; i = _u32(i + 1)) {
          final c = inflightQueue.get(i);
          if (c == null || !c.abandoned()) {
            break;
          }
          advancedPeerTsnAckPoint = i;
        }

        if (_sna32Gt(advancedPeerTsnAckPoint, cumulativeTsnAckPoint)) {
          willSendForwardTsn = true;
        }
      }

      inflightQueue.markAllToRetrasmit();
      _awakeWriteLoop();

      return;
    }

    if (id == _timerReconfig) {
      willRetransmitReconfig = true;
      _awakeWriteLoop();
    }
  }

  /// Port of `Association.onRetransmissionFailure` (association.go:2883-2916).
  @override
  void onRetransmissionFailure(int id) {
    if (id == _timerT1Init) {
      log.errorf('[%s] retransmission failure: T1-init', [name]);
      _completeHandshake(const HandshakeInitAckException());
      return;
    }

    if (id == _timerT1Cookie) {
      log.errorf('[%s] retransmission failure: T1-cookie', [name]);
      _completeHandshake(const HandshakeCookieEchoException());
      return;
    }

    if (id == _timerT2Shutdown) {
      log.errorf('[%s] retransmission failure: T2-shutdown', [name]);
      return;
    }

    if (id == _timerT3Rtx) {
      // T3-rtx timer will not fail by design.
      log.errorf('[%s] retransmission failure: T3-rtx (DATA)', [name]);
      return;
    }
  }

  /// Port of `Association.onAckTimeout` (association.go:2918-2927).
  @override
  void onAckTimeout() {
    stats.incAckTimeouts();
    ackState = _ackStateImmediate;
    _awakeWriteLoop();
  }

  /// Port of `Association.completeHandshake` (association.go:2950-2960):
  /// sends the given error to the handshake-completed signal unless the
  /// association's read/write side closed first. Returns whether it managed
  /// to signal.
  bool _completeHandshake(Object? handshakeErr) {
    if (!_handshakeCompletedCh.isCompleted) {
      _handshakeCompletedCh.complete(handshakeErr);
      return true;
    }
    return false;
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

/// Port of `Server` (association.go:288-303).
Future<Association> server(Config config) async {
  final a = Association(config);
  a._initAssociation(false);

  final result = await Future.any([
    a._handshakeCompletedCh.future.then((err) => (0, err)),
    a._readLoopCloseCh.future.then((_) => (1, null)),
  ]);
  final (which, err) = result;
  if (which == 1) {
    throw const AssociationClosedBeforeConnException();
  }
  if (err != null) {
    throw err;
  }
  return a;
}

/// Port of `Client` (association.go:305-308), folding in
/// `createClientWithContext` (association.go:310-329): the only real caller
/// upstream always passes `context.Background()` (no exported
/// `ClientWithContext`), so the cancellation-context parameter is not
/// ported -- see this file's doc comment.
Future<Association> client(Config config) async {
  final a = Association(config);
  a._initAssociation(true);

  final result = await Future.any([
    a._handshakeCompletedCh.future.then((err) => (0, err)),
    a._readLoopCloseCh.future.then((_) => (1, null)),
  ]);
  final (which, err) = result;
  if (which == 1) {
    throw const AssociationClosedBeforeConnException();
  }
  if (err != null) {
    throw err;
  }
  return a;
}

/// Bounded-capacity, closeable single-producer-multi-consumer FIFO. Port of
/// the `chan *Stream` semantics `Association.acceptCh` relies on: a
/// non-blocking, drop-on-full send (`Association.createStream`'s
/// `select {case a.acceptCh <- stream: ... default: ...}`), a blocking
/// receive (`AcceptStream`'s `<-a.acceptCh`), and a `close` after which
/// pending and future receives return `nil`/`ok=false`
/// (`Association.readLoop`'s deferred `close(a.acceptCh)`). No Go symbol
/// corresponds to this helper class itself (only the field it backs does),
/// so it is private per this project's auxiliary-symbol convention.
final class _AcceptChannel {
  _AcceptChannel(this._capacity);

  final int _capacity;
  final List<Stream> _buffer = [];
  final List<Completer<Stream?>> _waiters = [];
  bool _closed = false;

  bool trySend(Stream s) {
    if (_closed) {
      return false;
    }
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete(s);
      return true;
    }
    if (_buffer.length >= _capacity) {
      return false;
    }
    _buffer.add(s);
    return true;
  }

  Future<Stream?> receive() {
    if (_buffer.isNotEmpty) {
      return Future.value(_buffer.removeAt(0));
    }
    if (_closed) {
      return Future.value(null);
    }
    final c = Completer<Stream?>();
    _waiters.add(c);
    return c.future;
  }

  void close() {
    _closed = true;
    for (final w in _waiters) {
      if (!w.isCompleted) {
        w.complete(null);
      }
    }
    _waiters.clear();
  }
}

/// Port of `ErrSilentlyDiscard` (association.go:38). See
/// `Association.silentError`'s doc comment: stored for structural parity
/// only, never read by this call graph (matching upstream).
final class _SilentlyDiscardException implements Exception {
  const _SilentlyDiscardException();
  @override
  String toString() => 'silently discard';
}

/// Stand-in for a `Deadline` whose `err` getter is unexpectedly `null` when
/// its `done` future completes -- defensive only; `Deadline.err` is always
/// non-null once `done` completes in practice (see `Deadline.set`).
final class _DeadlineDoneException implements Exception {
  const _DeadlineDoneException();
  @override
  String toString() => 'deadline done';
}
