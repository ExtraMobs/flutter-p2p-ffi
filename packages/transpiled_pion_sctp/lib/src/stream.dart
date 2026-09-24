// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

/// Port of `stream.go` (github.com/pion/sctp): [Stream], one bidirectional
/// SCTP stream multiplexed over an [Association], and [StreamState], its
/// state field. `StreamState` has no dedicated Go source file upstream --
/// it, and its `String` method, are declared directly in `stream.go`
/// (stream.go:28-50) -- so this port declares it in this same file rather
/// than inventing a `streamstate.go` counterpart, per the "one Dart file per
/// Go file" rule.
///
/// Both `Stream` and `StreamState` are exported in Go (capitalized); both
/// stay public here and are re-exported from `transpiled_pion_sctp.dart`.
///
/// **Blocking-to-async adaptation**: Go's `Stream.Read`/`ReadSCTP` block the
/// calling goroutine on `sync.Cond.Wait()` until the reassembly queue has
/// something to read or an error is set. Dart has no goroutines to block;
/// per AGENTS.md's guidance to use the closest Dart primitive "only when
/// behavior requires it", [readSctp] is `Future`-based instead: the
/// `sync.Cond` becomes a `Completer<void>` that is replaced and completed
/// every time Go would call `Signal`/`Broadcast` on the condition variable
/// (`_notifyReaders`), and the read loop `await`s it in place of
/// `Wait()`. Because this port never has more than one in-flight [readSctp]
/// per stream in practice, `Signal` (wake one waiter) and `Broadcast` (wake
/// all) collapse to the same operation here (complete the current
/// completer); this is documented rather than silently assumed.
///
/// `sync.RWMutex`/`sync.Mutex` guards on `Stream` fields protect against
/// concurrent access from the association's read/write loop goroutines and
/// the application goroutine calling public `Stream` methods. Dart's
/// single-threaded event loop makes concurrent field mutation impossible
/// within one isolate, so those mutexes are dropped, per
/// `RULE_NO_ARTIFICIAL_CONCURRENCY` and the same reasoning already applied
/// in `rtx_timer.dart`/`ack_timer.dart`.
///
/// Go's `readTimeoutCancel chan struct{}` exists only to let a fresh
/// `SetReadDeadline` call cancel a previously scheduled timeout goroutine;
/// Dart's `Timer.cancel()` does that directly, so no separate cancellation
/// channel is needed.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_pion_transport/transpiled_pion_transport.dart'
    show Deadline;

import 'association.dart';
import 'chunk_payload_data.dart';
import 'reassembly_queue.dart';

/// Port of `ReliabilityTypeReliable` (stream.go:21).
const int reliabilityTypeReliable = 0;

/// Port of `ReliabilityTypeRexmit` (stream.go:23).
const int reliabilityTypeRexmit = 1;

/// Port of `ReliabilityTypeTimed` (stream.go:25).
const int reliabilityTypeTimed = 2;

/// Port of `StreamState` (stream.go:30) and its constants (stream.go:33-37).
enum StreamState {
  /// Port of `StreamStateOpen` (stream.go:34): the state a [Stream] starts
  /// in.
  open,

  /// Port of `StreamStateClosing` (stream.go:35): outgoing stream is being
  /// reset.
  closing,

  /// Port of `StreamStateClosed` (stream.go:36).
  closed;

  /// Port of `StreamState.String` (stream.go:39-50).
  String string() {
    switch (this) {
      case StreamState.open:
        return 'open';
      case StreamState.closing:
        return 'closing';
      case StreamState.closed:
        return 'closed';
    }
  }

  @override
  String toString() => string();
}

/// Port of `ErrOutboundPacketTooLarge` (stream.go:54).
final class OutboundPacketTooLargeException implements Exception {
  const OutboundPacketTooLargeException(this.maxMessageSize);

  final int maxMessageSize;

  @override
  String toString() =>
      'outbound packet larger than maximum message size: $maxMessageSize';
}

/// Port of `ErrStreamClosed` (stream.go:55).
final class StreamClosedException implements Exception {
  const StreamClosedException();

  @override
  String toString() => 'stream closed';
}

/// Port of `ErrReadDeadlineExceeded` (stream.go:56), wrapping
/// `os.ErrDeadlineExceeded`.
final class ReadDeadlineExceededException implements Exception {
  const ReadDeadlineExceededException();

  @override
  String toString() => 'read deadline exceeded: i/o timeout';
}

/// Port of `io.EOF` as observed through `Stream.readErr` (set by
/// `onInboundStreamReset` and propagated by `Association.unregisterStream`
/// when the read loop ends cleanly).
final class EofException implements Exception {
  const EofException();

  @override
  String toString() => 'EOF';
}

/// Port of `Stream` (stream.go:60-81).
final class Stream {
  /// Constructs a stream. Port of the `&Stream{...}` literal in
  /// `Association.createStream` (association.go:1622-1631); the stream is
  /// registered into `Association.streams`/`acceptCh` by the caller, exactly
  /// as upstream, so no factory is exposed here beyond the plain
  /// constructor.
  Stream({
    required this.association,
    required this.streamIdentifier,
    required this.name,
    PayloadProtocolIdentifier defaultPayloadType =
        PayloadProtocolIdentifier.unknown,
  }) : _defaultPayloadType = defaultPayloadType,
       reassemblyQueue = ReassemblyQueue(streamIdentifier),
       writeDeadline = Deadline();

  /// Port of `Stream.association` (stream.go:61).
  final Association association;

  /// Port of `Stream.streamIdentifier` (stream.go:63).
  final int streamIdentifier;

  PayloadProtocolIdentifier _defaultPayloadType;

  /// Port of `Stream.reassemblyQueue` (stream.go:65).
  final ReassemblyQueue reassemblyQueue;

  /// Port of `Stream.sequenceNumber` (stream.go:66).
  int sequenceNumber = 0;

  Completer<void> _readNotify = Completer<void>();

  /// Port of `Stream.readErr` (stream.go:68).
  Object? readErr;

  Timer? _readTimeoutTimer;

  /// Port of `Stream.writeDeadline` (stream.go:70).
  final Deadline writeDeadline;

  /// Port of `Stream.unordered` (stream.go:72).
  bool unordered = false;

  /// Port of `Stream.reliabilityType` (stream.go:73).
  int reliabilityType = reliabilityTypeReliable;

  /// Port of `Stream.reliabilityValue` (stream.go:74).
  int reliabilityValue = 0;

  /// Port of `Stream.bufferedAmount` (stream.go:75).
  int bufferedAmount = 0;

  /// Port of `Stream.bufferedAmountLow` (stream.go:76).
  int bufferedAmountLow = 0;

  /// Port of `Stream.onBufferedAmountLow` (stream.go:77).
  void Function()? onBufferedAmountLowCallback;

  /// Port of `Stream.state` (stream.go:78).
  StreamState state = StreamState.open;

  /// Port of `Stream.name` (stream.go:80).
  final String name;

  void _notifyReaders() {
    final old = _readNotify;
    _readNotify = Completer<void>();
    if (!old.isCompleted) {
      old.complete();
    }
  }

  /// Port of `Stream.StreamIdentifier` (stream.go:84-89).
  int getStreamIdentifier() => streamIdentifier;

  /// Port of `Stream.SetDefaultPayloadType` (stream.go:92-94).
  void setDefaultPayloadType(PayloadProtocolIdentifier defaultPayloadType) {
    _defaultPayloadType = defaultPayloadType;
  }

  /// Port of `Stream.SetReliabilityParams` (stream.go:97-102).
  void setReliabilityParams(bool unorderedValue, int relType, int relVal) {
    _setReliabilityParams(unorderedValue, relType, relVal);
  }

  /// Port of `Stream.setReliabilityParams` (stream.go:106-112): the caller
  /// should hold the lock -- moot here, see this file's doc comment.
  void _setReliabilityParams(bool unorderedValue, int relType, int relVal) {
    unordered = unorderedValue;
    reliabilityType = relType;
    reliabilityValue = relVal;
  }

  /// Port of `Stream.Read` (stream.go:117-121): reads a packet of up to
  /// `p.length` bytes, dropping the Payload Protocol Identifier. Throws
  /// [EofException] when the stream is reset, or [readErr] otherwise, if
  /// the stream is closed.
  Future<int> read(Uint8List p) async {
    final (n, _) = await readSctp(p);
    return n;
  }

  /// Port of `Stream.ReadSCTP` (stream.go:127-151): reads a packet of up to
  /// `payload.length` bytes and returns the associated Payload Protocol
  /// Identifier. See this file's doc comment for the blocking-to-`Future`
  /// adaptation.
  Future<(int, PayloadProtocolIdentifier)> readSctp(Uint8List payload) async {
    try {
      while (true) {
        try {
          return reassemblyQueue.read(payload);
        } on ShortBufferException catch (e) {
          return (e.bytesWritten, e.payloadType);
        } on TryAgainException {
          if (readErr != null) {
            throw readErr!;
          }
          await _readNotify.future;
        }
      }
    } finally {
      // close readTimeoutCancel if the current read timeout routine is no
      // longer effective
      if (_readTimeoutTimer != null && readErr != null) {
        _readTimeoutTimer!.cancel();
        _readTimeoutTimer = null;
      }
    }
  }

  /// Port of `Stream.SetReadDeadline` (stream.go:154-199): sets the read
  /// deadline in an identical way to `net.Conn`.
  void setReadDeadline(DateTime? deadline) {
    _readTimeoutTimer?.cancel();
    _readTimeoutTimer = null;

    if (readErr != null) {
      if (readErr is! ReadDeadlineExceededException) {
        return;
      }
      readErr = null;
    }

    if (deadline != null) {
      var dur = deadline.difference(DateTime.now());
      if (dur.isNegative) {
        dur = Duration.zero;
      }
      _readTimeoutTimer = Timer(dur, () {
        readErr ??= const ReadDeadlineExceededException();
        _readTimeoutTimer = null;
        _notifyReaders();
      });
    }
  }

  /// Port of `Stream.handleData` (stream.go:201-215).
  void handleData(ChunkPayloadData pd) {
    if (reassemblyQueue.push(pd)) {
      final readable = reassemblyQueue.isReadable();
      if (readable) {
        _notifyReaders();
      }
    }
  }

  /// Port of `Stream.handleForwardTSNForOrdered` (stream.go:217-238).
  void handleForwardTsnForOrdered(int ssn) {
    if (unordered) {
      return; // unordered chunks are handled by handleForwardTsnForUnordered
    }

    // Remove all chunks older than or equal to the new TSN from the
    // reassemblyQueue.
    reassemblyQueue.forwardTsnForOrdered(ssn);
    final readable = reassemblyQueue.isReadable();

    // Notify the reader asynchronously if there's a data chunk to read.
    if (readable) {
      _notifyReaders();
    }
  }

  /// Port of `Stream.handleForwardTSNForUnordered` (stream.go:240-261).
  void handleForwardTsnForUnordered(int newCumulativeTsn) {
    if (!unordered) {
      return; // ordered chunks are handled by handleForwardTsnForOrdered
    }

    // Remove all chunks older than or equal to the new TSN from the
    // reassemblyQueue.
    reassemblyQueue.forwardTsnForUnordered(newCumulativeTsn);
    final readable = reassemblyQueue.isReadable();

    // Notify the reader asynchronously if there's a data chunk to read.
    if (readable) {
      _notifyReaders();
    }
  }

  /// Port of `Stream.Write` (stream.go:264-268): writes `payload` with the
  /// default Payload Protocol Identifier.
  Future<int> write(Uint8List payload) =>
      writeSctp(payload, _defaultPayloadType);

  /// Port of `Stream.WriteSCTP` (stream.go:271-304): writes `payload` to the
  /// underlying connection.
  Future<int> writeSctp(
    Uint8List payload,
    PayloadProtocolIdentifier ppi,
  ) async {
    final maxMessageSize = association.maxMessageSize();
    if (payload.length > maxMessageSize) {
      throw OutboundPacketTooLargeException(maxMessageSize);
    }

    if (state != StreamState.open) {
      throw const StreamClosedException();
    }

    // The send could fail if the association is blocked for writing
    // (timeout), it will leave a hole in the stream sequence number space,
    // so we decrement the sequence number in case of failure.
    final (chunks, unorderedSend) = _packetize(payload, ppi);
    var n = payload.length;
    try {
      await association.sendPayloadData(writeDeadline, chunks);
    } on Object {
      bufferedAmount -= n;
      if (!unorderedSend) {
        sequenceNumber--;
      }
      n = 0;
      rethrow;
    }

    return n;
  }

  /// Port of `Stream.SetWriteDeadline` (stream.go:307-312): only works for
  /// blocking writes.
  void setWriteDeadline(DateTime? deadline) {
    writeDeadline.set(deadline);
  }

  /// Port of `Stream.SetDeadline` (stream.go:315-321).
  void setDeadline(DateTime? t) {
    setReadDeadline(t);
    setWriteDeadline(t);
  }

  /// Port of `Stream.packetize` (stream.go:323-379).
  (List<ChunkPayloadData>, bool) _packetize(
    Uint8List raw,
    PayloadProtocolIdentifier ppi,
  ) {
    var offset = 0;
    var remaining = raw.length;

    // From draft-ietf-rtcweb-data-protocol-09, section 6: All Data Channel
    // Establishment Protocol messages MUST be sent using ordered delivery
    // and reliable transmission.
    final unorderedSend =
        ppi != PayloadProtocolIdentifier.webRtcDcep && unordered;

    final chunks = <ChunkPayloadData>[];
    ChunkPayloadData? head;
    while (remaining != 0) {
      final fragmentSize = association.maxPayloadSize < remaining
          ? association.maxPayloadSize
          : remaining;

      // Copy the userdata since we'll have to store it until acked and the
      // caller may re-use the buffer in the mean time.
      final userData = Uint8List(fragmentSize);
      userData.setRange(0, fragmentSize, raw, offset);

      final chunk = ChunkPayloadData(
        streamIdentifier: streamIdentifier,
        userData: userData,
        unordered: unorderedSend,
        beginningFragment: offset == 0,
        endingFragment: remaining - fragmentSize == 0,
        payloadType: ppi,
        streamSequenceNumber: sequenceNumber,
        head: head,
      );

      head ??= chunk;

      chunks.add(chunk);

      remaining -= fragmentSize;
      offset += fragmentSize;
    }

    // RFC 4960 Sec 6.6: When transmitting ordered and unordered data, an
    // endpoint does not increment its Stream Sequence Number when
    // transmitting a DATA chunk with U flag set to 1.
    if (!unorderedSend) {
      sequenceNumber = (sequenceNumber + 1) & 0xFFFF;
    }

    bufferedAmount += raw.length;

    return (chunks, unorderedSend);
  }

  /// Port of `Stream.Close` (stream.go:383-409): closes the write-direction
  /// of the stream. Future calls to [write]/[writeSctp] are not permitted
  /// after calling this.
  Future<void> close() async {
    final int sid;
    final bool resetOutbound;

    if (state == StreamState.open) {
      state = readErr == null ? StreamState.closing : StreamState.closed;
      sid = streamIdentifier;
      resetOutbound = true;
    } else {
      sid = streamIdentifier;
      resetOutbound = false;
    }

    if (resetOutbound) {
      // Reset the outgoing stream. https://tools.ietf.org/html/rfc6525
      await association.sendResetRequest(sid);
    }
  }

  /// Port of `Stream.BufferedAmount` (stream.go:412-417).
  int getBufferedAmount() => bufferedAmount;

  /// Port of `Stream.BufferedAmountLowThreshold` (stream.go:420-426).
  int getBufferedAmountLowThreshold() => bufferedAmountLow;

  /// Port of `Stream.SetBufferedAmountLowThreshold` (stream.go:429-435).
  void setBufferedAmountLowThreshold(int th) {
    bufferedAmountLow = th;
  }

  /// Port of `Stream.OnBufferedAmountLow` (stream.go:438-444).
  void onBufferedAmountLow(void Function() f) {
    onBufferedAmountLowCallback = f;
  }

  /// Port of `Stream.onBufferReleased` (stream.go:447-476): called by the
  /// association's read loop to notify this stream that the given amount of
  /// outgoing data has been delivered to the peer.
  void onBufferReleased(int nBytesReleased) {
    if (nBytesReleased <= 0) {
      return;
    }

    final fromAmount = bufferedAmount;

    if (bufferedAmount < nBytesReleased) {
      bufferedAmount = 0;
    } else {
      bufferedAmount -= nBytesReleased;
    }

    final callback = onBufferedAmountLowCallback;
    if (callback != null &&
        fromAmount > bufferedAmountLow &&
        bufferedAmount <= bufferedAmountLow) {
      callback();
    }
  }

  /// Port of `Stream.getNumBytesInReassemblyQueue` (stream.go:478-481).
  int getNumBytesInReassemblyQueue() => reassemblyQueue.getNumBytes();

  /// Port of `Stream.onInboundStreamReset` (stream.go:483-506).
  void onInboundStreamReset() {
    // No more inbound data to read. Unblock the read with EOF.
    //
    // See RFC 8831 section 6.7: if one side decides to close the data
    // channel, it resets the corresponding outgoing stream. When the peer
    // sees that an incoming stream was reset, it also resets its
    // corresponding outgoing stream. Once this is completed, the data
    // channel is closed.
    readErr = const EofException();
    _notifyReaders();

    if (state == StreamState.closing) {
      state = StreamState.closed;
    }
  }

  /// Port of `Stream.State` (stream.go:509-514).
  StreamState getState() => state;
}
