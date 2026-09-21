// Port of github.com/pion/transport/v4/netctx/packetconn.go (revision fixed
// in doc/transpilation/UPSTREAM_LOCK.md) -- PARTIAL, by design.
//
// Upstream's `netctx` package declares two wrappers: `Conn` (conn.go, wraps
// a stream `net.Conn`) and `PacketConn` (packetconn.go, wraps a packet
// `net.PacketConn`). Only `PacketConn` has a real caller in this project's
// locked revisions: `pion-dtls/conn.go:65,222` declares a field
// `nextConn netctx.PacketConn` and constructs it via
// `netctx.NewPacketConn(nextConn)`. `netctx.Conn`, `netctx.Pipe`, and the
// `Reader`/`Writer`/`ReadWriter` interfaces from conn.go have zero call
// sites in `pion/stun` or `pion/dtls` and are not ported (confirmed via
// `grep -rn 'netctx\.' go-ipfs-reference/pion-stun go-ipfs-reference/pion-dtls
// --include=*.go | grep -v _test.go`, which returns only
// `netctx.PacketConn`/`netctx.NewPacketConn`).
//
// [PacketConn.conn] (Go's `Conn() net.PacketConn`, packetconn.go:179) is also
// not ported: no call site in either module ever calls it.
import 'dart:async';
import 'dart:typed_data';

import 'deadline.dart' show DeadlineExceededException;
import 'net.dart' show NetAddr, UdpConn;

/// Thrown by [PacketConn.readFromContext] or [PacketConn.writeToContext]
/// after [PacketConn.close] has been called. Port of the Go sentinel
/// `ErrClosing` (packetconn.go's package `netctx`, declared in conn.go:19)
/// used on a closed write, and of the Go stdlib sentinel `net.ErrClosed`
/// used on a closed read (packetconn.go:67). Both upstream sentinels carry
/// the identical message `"use of closed network connection"` and neither is
/// ever distinguished by identity (`errors.Is`) in this port's scope, so
/// they are consolidated into one exception type here instead of two
/// otherwise-identical classes.
class ClosingException implements Exception {
  @override
  String toString() => 'ClosingException: use of closed network connection';
}

/// Wraps a packet-oriented connection so reads and writes can be cancelled.
/// Port of `netctx.PacketConn` (packetconn.go:26-32).
///
/// Go's `ReadFromContext`/`WriteToContext` accept a `context.Context` and,
/// on cancellation, force-unblock an in-flight blocking `ReadFrom`/`WriteTo`
/// by pushing the wrapped `net.PacketConn`'s deadline into the past
/// (packetconn.go:61-158) -- a trick needed only because Go's blocking
/// socket calls have no other way to be interrupted. This port's [UdpConn]
/// (net.dart) is already `Future`-based and non-blocking at the Dart layer,
/// so there is nothing to force-unblock: cancellation below is a plain
/// `Future` race between the read/write and [cancellation], with no
/// deadline manipulation involved. [cancellation] plays the role Go's
/// `context.Context` parameter plays; this project has no general
/// `context.Context` port (AGENTS.md: adapt only when behavior requires it),
/// and every real producer of such a signal in this codebase is
/// `Deadline.done` (deadline.dart), so a plain `Future<void>` is the natural
/// fit, and [DeadlineExceededException] (the same exception `Deadline.err`
/// reports) is what a firing [cancellation] throws.
abstract interface class PacketConn {
  /// Wraps [conn]. Port of `NewPacketConn` (packetconn.go:43-50).
  factory PacketConn(UdpConn conn) = _PacketConn;

  /// Reads a packet from the connection into [buffer], returning the number
  /// of bytes copied and the source address. Unlike [UdpConn.readFrom],
  /// throws [DeadlineExceededException] if [cancellation] completes first,
  /// or [ClosingException] if the connection is already closed. Port of
  /// `ReadFromContext` (packetconn.go:61-108).
  Future<(int, NetAddr)> readFromContext(
    Future<void> cancellation,
    Uint8List buffer,
  );

  /// Writes [buffer] to [addr]. Unlike [UdpConn.writeTo], throws
  /// [DeadlineExceededException] if [cancellation] completes first, or
  /// [ClosingException] if the connection is already closed. Port of
  /// `WriteToContext` (packetconn.go:111-157).
  Future<int> writeToContext(
    Future<void> cancellation,
    Uint8List buffer,
    NetAddr addr,
  );

  /// Closes the connection. Any blocked [readFromContext] or
  /// [writeToContext] call is unblocked and throws. Port of `Close`
  /// (packetconn.go:160-171).
  Future<void> close();

  /// Port of `LocalAddr` (packetconn.go:174-176).
  NetAddr get localAddr;
}

class _PacketConn implements PacketConn {
  _PacketConn(this._next);

  final UdpConn _next;
  bool _closed = false;

  Future<T> _raceCancellation<T>(
    Future<T> operation,
    Future<void> cancellation,
  ) {
    final result = Completer<T>();
    unawaited(
      operation.then(
        (value) {
          if (!result.isCompleted) result.complete(value);
        },
        onError: (Object e, StackTrace st) {
          if (!result.isCompleted) result.completeError(e, st);
        },
      ),
    );
    unawaited(
      cancellation.then((_) {
        if (!result.isCompleted)
          result.completeError(DeadlineExceededException());
      }),
    );
    return result.future;
  }

  @override
  Future<(int, NetAddr)> readFromContext(
    Future<void> cancellation,
    Uint8List buffer,
  ) {
    if (_closed) throw ClosingException();
    return _raceCancellation(_next.readFrom(buffer), cancellation);
  }

  @override
  Future<int> writeToContext(
    Future<void> cancellation,
    Uint8List buffer,
    NetAddr addr,
  ) {
    if (_closed) throw ClosingException();
    return _raceCancellation(_next.writeTo(buffer, addr), cancellation);
  }

  @override
  Future<void> close() async {
    await _next.close();
    _closed = true;
  }

  @override
  NetAddr get localAddr => _next.localAddr;
}
