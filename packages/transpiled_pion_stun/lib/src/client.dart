/// Port of `client.go` (pion/stun v3.1.1).
///
/// Scope cuts, per explicit project instruction:
///
/// - The STUN-over-DTLS branch of `DialURI` (`DTLSConfig` field, the
///   `github.com/pion/dtls/v3` import, and the `dtls.Client(...)` call for
///   `turns:` URIs resolving to UDP transport -- upstream client.go:19,40,
///   79-92) is NOT ported: `pion/dtls` is not ported into this codebase yet,
///   and porting it here would invert the intended module dependency order.
///   [DialUri] throws [DtlsNotSupportedException] for that case instead.
/// - The TLS branch (`stuns:`/`turns:` over TCP, upstream client.go:94-101,
///   `tls.Client(tcpConn, &tlsCfg)`) is also not ported, for an unrelated,
///   independently-discovered reason: `pion/transport/v4`'s `Net.dial`
///   (this codebase's `transpiled_pion_transport_v4` port) returns a
///   [NetConn] narrowed to `read`/`write`/`close` -- by design, since no
///   locked-revision caller needs more -- with no way to promote the
///   underlying connection to TLS (`dart:io`'s `SecureSocket` upgrades a
///   real `Socket`, not an arbitrary [NetConn]). Silently dialing a raw
///   `SecureSocket` here would bypass a caller's injected [Net] and
///   silently diverge from `DialConfig.net`'s documented contract, which is
///   worse than declaring the gap: [DialUri] throws
///   [TlsNotSupportedException] instead. Revisit once a consumer actually
///   needs `stuns:`/secure `turns:` client dialing.
///
/// Go's `sync.Pool`-based `clientTransactionPool`/`bufferPool`/
/// `callbackWaitHandlerPool` and `runtime.SetFinalizer` (client.go's own
/// `clientFinalizer`) are GC-pressure optimizations with no observable
/// effect on [Client]'s API and are not ported, matching this package's
/// `internal/hmac` pool omission (integrity.dart) and AGENTS.md's rule
/// against porting Go-specific concurrency/GC internals into public Dart
/// API. Go's blocking `Do` (a `sync.Cond` wait for a callback) becomes
/// [Client.doRequest], a `Future`-returning method built on a [Completer]
/// -- the idiomatic non-blocking Dart shape for "wait for the eventual
/// result of an async callback" (AGENTS.md: goroutines/channels map to
/// `Future`/`Stream`). Named `doRequest`, not `do`, because `do` is a Dart
/// reserved word.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart'
    as pion_transport_v4;

import 'agent.dart';
import 'message.dart';
import 'uri.dart';

/// Port of `ErrUnsupportedURI` (client.go:25).
final class UnsupportedUriException implements Exception {
  const UnsupportedUriException();

  @override
  String toString() => 'invalid schema or transport';
}

/// See file-level doc comment: the STUN-over-DTLS `DialUri` branch is not
/// ported because `pion/dtls` is not ported into this codebase yet.
final class DtlsNotSupportedException implements Exception {
  const DtlsNotSupportedException();

  @override
  String toString() =>
      'DTLS-secured STUN/TURN dialing is not supported: pion/dtls is not '
      'ported in this codebase yet';
}

/// See file-level doc comment: the TLS `DialUri` branch is not ported
/// because `transpiled_pion_transport_v4`'s [pion_transport_v4.NetConn] has no
/// upgrade-to-TLS primitive.
final class TlsNotSupportedException implements Exception {
  const TlsNotSupportedException();

  @override
  String toString() =>
      'TLS-secured STUN/TURN dialing is not supported: the injectable Net '
      'abstraction has no upgrade-to-TLS primitive';
}

/// Port of `ErrNoConnection` (client.go:112): `ClientOptions.Connection`
/// (here, the connection argument to [Client.new]) is missing.
final class NoConnectionException implements Exception {
  const NoConnectionException();

  @override
  String toString() => 'no connection provided';
}

/// Port of `ErrClientClosed` (client.go:481).
final class ClientClosedException implements Exception {
  const ClientClosedException();

  @override
  String toString() => 'client is closed';
}

/// Port of `StopErr` (client.go:383-389).
final class StopException implements Exception {
  const StopException({required this.err, required this.cause});

  final Object err;
  final Object cause;

  @override
  String toString() => 'error while stopping due to $cause: $err';
}

/// Port of `CloseErr` (client.go:394-398).
final class CloseException implements Exception {
  const CloseException({this.agentErr, this.connectionErr});

  final Object? agentErr;
  final Object? connectionErr;

  @override
  String toString() =>
      'failed to close: ${connectionErr ?? '<nil>'} (connection), '
      '${agentErr ?? '<nil>'} (agent)';
}

/// Port of `ClientAgent` (client.go:274-281): the subset of [Agent]'s API
/// [Client] drives. [Agent] satisfies this directly.
abstract interface class ClientAgent {
  void process(Message m);
  void close();
  void start(List<int> id, DateTime deadline);
  void stop(List<int> id);
  void collect(DateTime t);
  void setHandler(Handler h);
}

/// Port of `Clock` (client.go:349-351): abstracts the source of current
/// time.
abstract interface class Clock {
  DateTime now();
}

/// Port of `systemClockService` (client.go:353): private in Go, so private
/// here too (AGENTS.md, "Princípio do Menor Privilégio").
final class _SystemClock implements Clock {
  const _SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Port of `systemClock()` (client.go:359-361): also private in Go.
const Clock _systemClock = _SystemClock();

/// Port of `Collector` (client.go:601-605): calls a function with a
/// constant rate.
abstract interface class Collector {
  void start(Duration rate, void Function(DateTime now) f);
  void close();
}

/// Port of `tickerCollector` (client.go:596-599): private in Go, so private
/// here too.
final class _TickerCollector implements Collector {
  Timer? _timer;

  @override
  void start(Duration rate, void Function(DateTime now) f) {
    _timer = Timer.periodic(rate, (_) => f(DateTime.now()));
  }

  @override
  void close() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Port of `ClientOption` (client.go:117): a function type declared by
/// upstream Go itself (the typedef exception AGENTS.md carves out for
/// "type aliases declarados no próprio repositório upstream Go").
typedef ClientOption = void Function(Client c);

/// Port of `WithHandler` (client.go:120-126).
ClientOption withHandler(Handler h) =>
    (c) => c._handler = h;

/// Port of `WithRTO` (client.go:129-133).
ClientOption withRto(Duration rto) =>
    (c) => c._rto = rto;

/// Port of `WithClock` (client.go:136-141).
ClientOption withClock(Clock clock) =>
    (c) => c._clock = clock;

/// Port of `WithTimeoutRate` (client.go:144-148).
ClientOption withTimeoutRate(Duration d) =>
    (c) => c._rtoRate = d;

/// Port of `WithAgent` (client.go:151-156).
ClientOption withAgent(ClientAgent a) =>
    (c) => c._agent = a;

/// Port of `WithCollector` (client.go:159-164).
ClientOption withCollector(Collector coll) =>
    (c) => c._collector = coll;

/// Port of `WithNoConnClose` (client.go:167-171).
ClientOption withNoConnClose() =>
    (c) => c._closeConn = false;

const Duration _defaultTimeoutRate = Duration(milliseconds: 5);
const Duration _defaultRto = Duration(milliseconds: 300);
const int _defaultMaxAttempts = 7;

/// Port of `WithNoRetransmit` (client.go:174-181): disables retransmissions
/// and sets RTO so it is effectively a timeout if not otherwise set.
void withNoRetransmit(Client c) {
  c._maxAttempts = 0;
  if (c._rto == Duration.zero) {
    c._rto = _defaultRto * _defaultMaxAttempts;
  }
}

final class _ClientTransaction {
  _ClientTransaction();

  late List<int> id;
  int attempt = 0;
  int calls = 0;
  late Handler h;
  late DateTime start;
  late Duration rto;
  Uint8List raw = Uint8List(0);

  void handle(Event e) {
    calls++;
    if (calls == 1) h(e);
  }

  DateTime nextTimeout(DateTime now) => now.add(rto * (attempt + 1));
}

/// Port of `Client` (client.go:264-283): simulates a "connection" to a STUN
/// server.
final class Client {
  /// Port of `NewClient` (client.go:245-269). Throws
  /// [NoConnectionException] if [conn] is missing behavior this
  /// constructor needs (never -- [conn] is non-nullable in this port,
  /// unlike Go's nil-checked field, since Dart's type system already rules
  /// out the nil case at compile time).
  Client(this._conn, {List<ClientOption> options = const []})
    : _clock = _systemClock,
      _rto = _defaultRto,
      _rtoRate = _defaultTimeoutRate,
      _maxAttempts = _defaultMaxAttempts,
      _closeConn = true,
      _agent = Agent() {
    for (final o in options) {
      o(this);
    }
    _agent.setHandler(_handleAgentCallback);
    _collector.start(_rtoRate, (t) => _safeCollect(t));
    _readLoopDone = _readUntilClosed();
  }

  pion_transport_v4.NetConn _conn;
  Clock _clock;
  Duration _rto;
  Duration _rtoRate;
  int _maxAttempts;
  bool _closed = false;
  bool _closeConn;
  Handler? _handler;
  ClientAgent _agent;
  Collector _collector = _TickerCollector();
  final Map<String, _ClientTransaction> _t = {};
  late final Future<void> _readLoopDone;
  final Completer<void> _closeRequested = Completer<void>();

  static String _key(List<int> id) => id.join(',');

  void _safeCollect(DateTime t) {
    try {
      _agent.collect(t);
    } on AgentClosedException {
      // Matches `closedOrPanic` (client.go:436-441): ignore, agent already
      // closed.
    }
  }

  /// Port of `Dial` (client.go:27-35): connects over [network] to
  /// [address] using the real OS network stack, then wraps the connection
  /// in a [Client].
  static Future<Client> dial(
    String network,
    String address, {
    List<ClientOption> options = const [],
  }) async {
    final conn = await pion_transport_v4.StdNet().dial(network, address);
    return Client(conn, options: options);
  }

  /// Port of `DialURI`/`DialConfig` (client.go:38-101). See file-level doc
  /// comment for the DTLS/TLS scope cuts.
  static Future<Client> dialUri(
    StunUri uri, {
    pion_transport_v4.Net? net,
    List<ClientOption> options = const [],
  }) async {
    final nw = net ?? pion_transport_v4.StdNet();
    final addr = '${uri.host}:${uri.port}';

    switch (uri.scheme) {
      case SchemeType.stun:
        final conn = await nw.dial('udp', addr);
        return Client(conn, options: options);
      case SchemeType.turn:
        final network = uri.proto == ProtoType.tcp ? 'tcp' : 'udp';
        final conn = await nw.dial(network, addr);
        return Client(conn, options: options);
      case SchemeType.turns:
        if (uri.proto == ProtoType.udp) throw const DtlsNotSupportedException();
        throw const TlsNotSupportedException();
      case SchemeType.stuns:
        throw const TlsNotSupportedException();
      case SchemeType.unknown:
        throw const UnsupportedUriException();
    }
  }

  /// Port of `Client.readUntilClosed` (client.go:412-428).
  ///
  /// Races each `_conn.read()` against [_closeRequested] rather than
  /// awaiting it directly. Go's real `net.UDPConn.Close()` (called from
  /// [close] via `_conn.close()`) is guaranteed by the OS/Go stdlib to
  /// unblock any goroutine currently parked in a `Read()` on that same
  /// connection, which is exactly what lets Go's `c.wg.Wait()` in `Close`
  /// return promptly. `transpiled_pion_transport_v4`'s connected-UDP
  /// `NetConn` (`stdnet.dart`, `_ConnectedUdpNetConn`/`_DatagramQueue`) does
  /// not provide that guarantee: `close()` cancels the datagram
  /// subscription before the underlying socket's `onDone` can fire, so a
  /// `Completer` a pending `read()` is awaiting inside `_DatagramQueue.next`
  /// is never completed and the call hangs forever. Confirmed with an
  /// isolated repro (dial real loopback UDP, block on `conn.read()`, call
  /// `conn.close()`: `close()` itself returns in ~1ms, but the pending
  /// `read()` never resolves, even after a 3s wait) -- independent proof,
  /// not a guess, per this project's standing instruction not to blame the
  /// environment/a dependency without one. `transpiled_pion_transport_v4`
  /// is outside this pass's scope to fix, so [close] here works around it
  /// instead of hanging: it just stops *awaiting* the stuck `read()` (the
  /// orphaned Future is abandoned, not cancelled -- Dart has no way to
  /// cancel an in-flight `Future`) the moment [close] signals
  /// [_closeRequested], which is enough to make [close] itself return
  /// promptly like Go's does.
  Future<void> _readUntilClosed() async {
    final m = Message();
    while (true) {
      if (_closed) return;
      final buf = Uint8List(1024);
      int n;
      try {
        final outcome = await Future.any<Object>([
          _conn.read(buf),
          _closeRequested.future.then((_) => _closeRequested),
        ]);
        if (identical(outcome, _closeRequested)) return;
        n = outcome as int;
      } catch (_) {
        continue;
      }
      if (n <= 0) continue;
      m.raw = Uint8List.sublistView(buf, 0, n);
      try {
        m.decode();
      } catch (_) {
        continue;
      }
      try {
        _agent.process(m);
      } on AgentClosedException {
        return;
      }
    }
  }

  /// Port of `Client.Close` (client.go:483-505). Throws [CloseException] on
  /// partial failure, [ClientClosedException] if already closed.
  Future<void> close() async {
    if (_closed) throw const ClientClosedException();
    _closed = true;
    _collector.close();
    Object? agentErr;
    Object? connErr;
    try {
      _agent.close();
    } catch (e) {
      agentErr = e;
    }
    if (_closeConn) {
      try {
        await _conn.close();
      } catch (e) {
        connErr = e;
      }
    }
    // Wake up _readUntilClosed's Future.any race (see that method's doc
    // comment) so it can return even if the underlying `_conn.read()` call
    // it was awaiting is itself stuck forever.
    if (!_closeRequested.isCompleted) _closeRequested.complete();
    // Port of `c.wg.Wait()` (client.go:499): wait for the read loop, which
    // observes `_closed` and returns, to actually finish.
    await _readLoopDone;
    if (agentErr == null && connErr == null) return;
    throw CloseException(agentErr: agentErr, connectionErr: connErr);
  }

  /// Port of `Client.Indicate` (client.go:509-512): shorthand for [start]
  /// with no handler.
  Future<void> indicate(Message m) => start(m, null);

  /// Port of `Client.Do` (client.go:566-590+), adapted to a `Future`-based
  /// shape; see file-level doc comment.
  Future<Event> doRequest(Message m) {
    if (_closed) throw const ClientClosedException();
    final completer = Completer<Event>();
    unawaited(
      start(m, (e) {
        if (!completer.isCompleted) completer.complete(e);
      }).catchError((Object e) {
        if (!completer.isCompleted) completer.completeError(e);
      }),
    );
    return completer.future;
  }

  /// Port of `Client.delete` (client.go:592-598).
  void _delete(List<int> id) => _t.remove(_key(id));

  /// Port of `Client.start` (client.go:339-354).
  void _startTransaction(_ClientTransaction t) {
    if (_closed) throw const ClientClosedException();
    final key = _key(t.id);
    if (_t.containsKey(key)) throw const TransactionExistsException();
    _t[key] = t;
  }

  /// Port of `Client.Start` (client.go:703-745): starts a transaction (if
  /// [handler] is set) and writes [msg] to the server; [handler] is called
  /// asynchronously.
  Future<void> start(Message msg, Handler? handler) async {
    if (_closed) throw const ClientClosedException();
    if (handler != null) {
      final t = _ClientTransaction()
        ..id = msg.transactionId
        ..start = _clock.now()
        ..h = handler
        ..rto = _rto
        ..attempt = 0
        ..raw = Uint8List.fromList(msg.raw)
        ..calls = 0;
      final deadline = t.nextTimeout(t.start);
      _startTransaction(t);
      _agent.start(msg.transactionId, deadline);
    }
    try {
      await _conn.write(msg.raw);
    } catch (e) {
      if (handler != null) {
        _delete(msg.transactionId);
        try {
          _agent.stop(msg.transactionId);
        } catch (stopErr) {
          throw StopException(err: stopErr, cause: e);
        }
      }
      rethrow;
    }
  }

  /// Port of `Client.handleAgentCallback` (client.go:627-698).
  void _handleAgentCallback(Event event) {
    if (_closed) return;
    final key = _key(event.transactionId);
    final transaction = _t.remove(key);
    if (transaction == null) {
      if (_handler != null && event.error is! TransactionStoppedException) {
        _handler!(event);
      }
      return;
    }
    if (_maxAttempts <= transaction.attempt || event.error == null) {
      transaction.handle(event);
      return;
    }
    // Re-transmission.
    transaction.attempt++;
    final id = transaction.id;
    try {
      _startTransaction(transaction);
    } catch (startErr) {
      _delete(id);
      transaction.handle(Event(transactionId: id, error: startErr));
      return;
    }
    final now = _clock.now();
    final timeOut = transaction.nextTimeout(now);
    try {
      _agent.start(id, timeOut);
    } catch (startErr) {
      _delete(id);
      transaction.handle(Event(transactionId: id, error: startErr));
      return;
    }
    unawaited(
      _conn.write(transaction.raw).then((_) {}).catchError((Object writeErr) {
        _delete(id);
        Object err = writeErr;
        try {
          _agent.stop(id);
        } catch (stopErr) {
          err = StopException(err: stopErr, cause: writeErr);
        }
        transaction.handle(Event(transactionId: id, error: err));
      }),
    );
  }

  /// Port of `Client.SetRTO` (client.go:376-378).
  void setRto(Duration rto) => _rto = rto;
}
