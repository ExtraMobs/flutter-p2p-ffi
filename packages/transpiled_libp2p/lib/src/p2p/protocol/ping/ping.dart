// SPDX-License-Identifier: MIT
//
// Ported from go-libp2p `p2p/protocol/ping/ping.go`.

// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';
import 'dart:typed_data';

import '../../../core/host/host.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/peer_id.dart';

/// Multistream protocol ID for the ping protocol.
///
/// Go: `ping.ID` (`ping.go:26`).
const String id = '/ipfs/ping/1.0.0';

/// Size in bytes of the ping payload.
///
/// Go: `ping.PingSize` (`ping.go:22`).
const int pingSize = 32;

/// Round-trip timeout: how long [PingService.pingHandler] waits, without a
/// completed request/response round trip, before closing the stream.
///
/// Go: `ping.pingTimeout` (`ping.go:23`), unexported upstream.
const Duration _pingTimeout = Duration(seconds: 10);

/// Hard lifetime deadline set on an inbound ping stream.
///
/// Go: `ping.pingDuration` (`ping.go:24`), unexported upstream.
const Duration _pingDuration = Duration(seconds: 30);

/// Resource manager service name ping streams are attached to.
///
/// Go: `ping.ServiceName` (`ping.go:28`).
const String serviceName = 'libp2p.ping';

/// Result of one ping attempt: either a round-trip time or an error.
///
/// Go: `ping.Result` (`ping.go:97-100`).
class Result {
  Result({this.rtt = Duration.zero, this.error});

  Duration rtt;
  Object? error;
}

/// Registers the ping protocol handler on a [Host] and issues outbound
/// pings.
///
/// Go: `ping.PingService` (`ping.go:32-34`).
class PingService {
  /// Constructs a [PingService] and registers [pingHandler] as the stream
  /// handler for [id] on `host`.
  ///
  /// Go: `NewPingService(h)` (`ping.go:36-40`).
  PingService(this.host) {
    host.setStreamHandler(id, pingHandler);
  }

  /// Go: `PingService.Host` (`ping.go:33`).
  final Host host;

  /// Handles an inbound `/ipfs/ping/1.0.0` stream: echoes back whatever the
  /// initiator sends until the stream idles for [_pingTimeout] or its
  /// [_pingDuration] lifetime deadline elapses.
  ///
  /// Go: `PingService.PingHandler` (`ping.go:42-89`).
  void pingHandler(NetworkStream stream) {
    unawaited(_pingHandler(stream));
  }

  /// Pings peer [p] until the returned stream's subscription is canceled,
  /// yielding one [Result] per round trip.
  ///
  /// Go: `PingService.Ping` (`ping.go:102-104`), which delegates to the
  /// top-level `Ping`. The delegation is mirrored here through the shared
  /// private `_pingStream`, rather than calling the top-level [ping]
  /// function by its bare name: inside an instance method, Dart resolves an
  /// unqualified `ping(...)` call to the instance member of the same name
  /// first, unlike Go, where methods and package-level functions are
  /// distinct namespaces. Both public entry points run the identical
  /// implementation.
  Stream<Result> ping(
    PeerId p, {
    NetworkContext context = NetworkContext.empty,
  }) => _pingStream(host, p, context);
}

/// Pings peer [p] over `h` until the returned stream's subscription is
/// canceled, yielding one [Result] per round trip.
///
/// Go: `Ping(ctx, h, p)` (`ping.go:112-155`).
Stream<Result> ping(
  Host h,
  PeerId p, {
  NetworkContext context = NetworkContext.empty,
}) => _pingStream(h, p, context);

/// Shared implementation behind both [ping] and [PingService.ping].
Stream<Result> _pingStream(Host h, PeerId p, NetworkContext context) {
  late final StreamController<Result> controller;
  NetworkStream? openStream;
  var canceled = false;

  Future<void> run() async {
    NetworkStream stream;
    try {
      stream = await h.newStream(p, [
        id,
      ], context: withAllowLimitedConn(context, 'ping'));
    } catch (e) {
      controller.add(Result(error: e));
      await controller.close();
      return;
    }
    openStream = stream;

    try {
      stream.scope().setService(serviceName);
    } catch (e) {
      dev.log('error attaching stream to ping service', name: 'ping', error: e);
      await stream.reset();
      controller.add(Result(error: e));
      await controller.close();
      return;
    }

    final ra = Random(_cryptoRandomSeed());

    try {
      while (!canceled) {
        final res = await _pingRoundTrip(stream, ra);

        if (canceled) return;

        if (res.error == null) {
          h.peerstore.recordLatency(p, res.rtt);
        }

        if (canceled) return;
        controller.add(res);
      }
    } finally {
      await controller.close();
    }
  }

  controller = StreamController<Result>(
    onListen: () {
      unawaited(run());
    },
    onCancel: () {
      canceled = true;
      // Go: `context.AfterFunc(ctx, func() { s.Reset() })` (`ping.go:150-153`)
      // -- forces any pending read/write to abort immediately.
      unawaited(openStream?.reset());
    },
  );

  return controller.stream;
}

/// Derives a `math`-style PRNG seed from cryptographically random bytes.
///
/// Go: the `mrand.New(mrand.NewSource(...))` construction in `Ping`
/// (`ping.go:129-133`), seeded by 8 bytes read from `crypto/rand`.
int _cryptoRandomSeed() {
  final secure = Random.secure();
  var seed = 0;
  for (var i = 0; i < 8; i++) {
    seed = ((seed << 8) | secure.nextInt(256)) & 0x7fffffffffffffff;
  }
  return seed;
}

/// Performs one ping request/response round trip on an already-open stream,
/// returning the measured RTT or the error that broke it.
///
/// Go: `ping(s network.Stream, randReader io.Reader) (time.Duration, error)`
/// (`ping.go:170-201`).
Future<Result> _pingRoundTrip(NetworkStream stream, Random ra) async {
  try {
    stream.scope().reserveMemory(2 * pingSize, reservationPriorityAlways);
  } catch (e) {
    dev.log('error reserving memory for ping stream', name: 'ping', error: e);
    await stream.reset();
    return Result(error: e);
  }

  try {
    final buf = Uint8List(pingSize);
    for (var i = 0; i < pingSize; i++) {
      buf[i] = ra.nextInt(256);
    }

    final before = DateTime.now();
    await stream.write(buf);

    final rbuf = await _readFull(stream, pingSize);

    if (!_bytesEqual(buf, rbuf)) {
      return Result(error: Exception('ping packet was incorrect'));
    }

    return Result(rtt: DateTime.now().difference(before));
  } catch (e) {
    return Result(error: e);
  } finally {
    stream.scope().releaseMemory(2 * pingSize);
  }
}

/// Handles one inbound ping stream: echoes [pingSize]-byte payloads back to
/// the initiator until the stream idles for [_pingTimeout] or the
/// [_pingDuration] lifetime deadline trips.
///
/// Go: `PingService.PingHandler` (`ping.go:42-89`).
Future<void> _pingHandler(NetworkStream stream) async {
  try {
    stream.scope().setService(serviceName);
  } catch (e) {
    dev.log('error attaching stream to ping service', name: 'ping', error: e);
    await stream.reset();
    return;
  }

  try {
    stream.scope().reserveMemory(pingSize, reservationPriorityAlways);
  } catch (e) {
    dev.log('error reserving memory for ping stream', name: 'ping', error: e);
    await stream.reset();
    return;
  }

  Timer? idleTimer;
  try {
    await stream.setDeadline(DateTime.now().add(_pingDuration));

    void armIdleTimer() {
      idleTimer?.cancel();
      idleTimer = Timer(_pingTimeout, () {
        dev.log('ping timeout', name: 'ping');
        unawaited(stream.close());
      });
    }

    armIdleTimer();

    while (true) {
      final buf = await _readFull(stream, pingSize);
      await stream.write(buf);
      armIdleTimer();
    }
  } catch (_) {
    await stream.close();
  } finally {
    idleTimer?.cancel();
    stream.scope().releaseMemory(pingSize);
  }
}

/// Reads exactly [n] bytes from [stream], mirroring Go's `io.ReadFull`.
///
/// Throws a [StateError] if the stream is exhausted before [n] bytes are
/// read.
Future<Uint8List> _readFull(NetworkStream stream, int n) async {
  final out = Uint8List(n);
  var offset = 0;
  while (offset < n) {
    final chunk = await stream.read(n - offset);
    if (chunk.isEmpty) {
      throw StateError('unexpected EOF reading ping stream');
    }
    out.setRange(offset, offset + chunk.length, chunk);
    offset += chunk.length;
  }
  return out;
}

/// Mirrors Go's `bytes.Equal` -- a plain (non constant-time) byte-slice
/// comparison, matching upstream's use of `bytes.Equal` rather than
/// `crypto/subtle` for this non-secret payload check.
bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
