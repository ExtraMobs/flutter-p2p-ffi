// test/atomic/nivel_2/ping_atomic_tests.dart
// Testes atomicos 1 para 1 para go-libp2p/p2p/protocol/ping (ping.go),
// portado em packages/transpiled_libp2p/lib/src/p2p/protocol/ping/ping.dart.
//
// Nivel 2: emulacao local em memoria -- dois _FakeHost interligados por
// _LoopStream, sem sockets reais nem daemon externo.

import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p/src/p2p/protocol/ping/ping.dart' as ping;
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

const _peerA = '12D3KooWDsMmX7axDC6HTTXUNe4upxEvFbNQjmE2FToVVbBzUK6f';
const _peerB = '12D3KooWM6CgA9iBFZmcYAHA6A2qvbAxqfkmrYiRQuz3XEsk4Ksv';

/// Minimal [Conn] stand-in: ping.dart never calls [NetworkStream.conn], but
/// [NetworkStream] requires one.
class _FakeConn implements Conn {
  _FakeConn(this._local, this._remote);
  final PeerId _local;
  final PeerId _remote;

  @override
  PeerId localPeer() => _local;
  @override
  PeerId remotePeer() => _remote;
  @override
  PubKey remotePublicKey() => throw UnimplementedError();
  @override
  ConnectionState connState() => const ConnectionState();
  @override
  Multiaddr localMultiaddr() => Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
  @override
  Multiaddr remoteMultiaddr() => Multiaddr.parse('/ip4/127.0.0.1/tcp/4002');
  @override
  ConnScope scope() => const NullScope();
  @override
  ConnStats stat() =>
      ConnStats(direction: Direction.outbound, opened: DateTime.now());
  @override
  String id() => 'fake-conn';
  @override
  Future<NetworkStream> newStream() async => throw UnimplementedError();
  @override
  List<NetworkStream> getStreams() => const [];
  @override
  bool get isClosed => false;
  @override
  Future<void> close() async {}
  @override
  Future<void> closeWithError(ConnErrorCode errorCode) async {}
}

/// An in-memory duplex byte pipe implementing [NetworkStream], paired with
/// another instance so writes on one side surface as reads on the other --
/// enough to run the real ping request/response protocol without sockets.
class _LoopStream implements NetworkStream {
  _LoopStream(this._localPeer, this._remotePeer);

  static (_LoopStream, _LoopStream) pair(PeerId a, PeerId b) {
    final sa = _LoopStream(a, b);
    final sb = _LoopStream(b, a);
    sa._peer = sb;
    sb._peer = sa;
    return (sa, sb);
  }

  final PeerId _localPeer;
  final PeerId _remotePeer;
  late _LoopStream _peer;

  final List<int> _buffer = [];
  Completer<void>? _waiter;
  bool _closed = false;
  ProtocolId _proto = ping.id;

  bool wasReset = false;

  void _wake() {
    final w = _waiter;
    if (w == null || w.isCompleted) return;
    // Complete on a fresh macrotask (never synchronously/via a bare
    // microtask): a zero-latency loopback where every hop resolves through
    // microtasks alone lets a tight caller loop (this port deliberately
    // mirrors Go's unthrottled retry loop in `Ping`, ping.go:135-153) starve
    // the event loop's timer queue forever, so `Future.delayed` in a test
    // never fires and `dart test` hangs. A real network stream never has
    // this problem because every read/write genuinely crosses I/O.
    Timer(Duration.zero, () {
      if (!w.isCompleted) w.complete();
    });
  }

  @override
  String get id => 'loop';
  @override
  ProtocolId protocol() => _proto;
  @override
  Future<void> setProtocol(ProtocolId id) async => _proto = id;
  @override
  Stats stat() => Stats(direction: Direction.outbound, opened: DateTime.now());
  @override
  Conn conn() => _FakeConn(_localPeer, _remotePeer);
  @override
  StreamScope scope() => const NullScope();

  @override
  bool get isClosed => _closed;

  @override
  Future<Uint8List> read([int? maxLength]) async {
    while (_buffer.isEmpty && !_closed) {
      _waiter = Completer<void>();
      await _waiter!.future;
    }
    if (_buffer.isEmpty) return Uint8List(0);
    final n = maxLength == null || maxLength > _buffer.length
        ? _buffer.length
        : maxLength;
    final chunk = Uint8List.fromList(_buffer.sublist(0, n));
    _buffer.removeRange(0, n);
    return chunk;
  }

  @override
  Future<void> write(Uint8List data) async {
    if (_closed) throw StateError('write on closed stream');
    _peer._buffer.addAll(data);
    _peer._wake();
  }

  @override
  Future<void> close() async {
    _closed = true;
    _wake();
  }

  @override
  Future<void> reset() async {
    wasReset = true;
    _closed = true;
    _wake();
    _peer._closed = true;
    _peer._wake();
  }

  @override
  Future<void> resetWithError(StreamErrorCode errorCode) async => reset();
  @override
  Future<void> closeWrite() async {}
  @override
  Future<void> closeRead() async {}
  @override
  Future<void> setDeadline(DateTime? time) async {}
  @override
  Future<void> setReadDeadline(DateTime? time) async {}
  @override
  Future<void> setWriteDeadline(DateTime? time) async {}
}

/// A [Host] whose [newStream] dials directly into a paired [_FakeHost]'s
/// registered handler over a [_LoopStream], modeling two libp2p nodes
/// without any real transport.
class _FakeHost implements Host {
  _FakeHost(this.id) : peerstore = MemoryPeerstore();

  @override
  final PeerId id;
  @override
  final MemoryPeerstore peerstore;

  _FakeHost? peer;
  StreamHandler? handler;
  bool failNewStream = false;

  @override
  List<Multiaddr> get addrs => const [];
  @override
  Network get network => throw UnimplementedError();
  @override
  ProtocolSwitch get mux => throw UnimplementedError();

  @override
  Future<void> connect(
    AddrInfo pi, {
    NetworkContext context = NetworkContext.empty,
  }) async {}

  @override
  void setStreamHandler(ProtocolId pid, StreamHandler handler) {
    this.handler = handler;
  }

  @override
  void setStreamHandlerMatch(
    ProtocolId pid,
    bool Function(ProtocolId) match,
    StreamHandler handler,
  ) => throw UnimplementedError();

  @override
  void removeStreamHandler(ProtocolId pid) => handler = null;

  @override
  Future<NetworkStream> newStream(
    PeerId p,
    List<ProtocolId> pids, {
    NetworkContext context = NetworkContext.empty,
  }) async {
    if (failNewStream) throw StateError('dial failed');
    final remote = peer;
    if (remote == null || remote.handler == null) {
      throw StateError('no handler registered on remote peer');
    }
    final (mine, theirs) = _LoopStream.pair(id, p);
    await mine.setProtocol(pids.first);
    await theirs.setProtocol(pids.first);
    remote.handler!(theirs);
    return mine;
  }

  @override
  Future<void> close() async {}
  @override
  ConnManager get connManager => throw UnimplementedError();
  @override
  Bus get eventBus => throw UnimplementedError();
}

void main() {
  group('ping protocol constants [Atomic Audit]', () {
    test('id - matches go-libp2p ping.ID (ping.go:26)', () {
      expect(ping.id, equals('/ipfs/ping/1.0.0'));
    });

    test('pingSize - matches go-libp2p ping.PingSize (ping.go:22)', () {
      expect(ping.pingSize, equals(32));
    });

    test('serviceName - matches go-libp2p ping.ServiceName (ping.go:28)', () {
      expect(ping.serviceName, equals('libp2p.ping'));
    });
  });

  group('Result [Atomic Audit]', () {
    test('Result() - defaults to zero rtt and null error', () {
      final r = ping.Result();
      expect(r.rtt, equals(Duration.zero));
      expect(r.error, isNull);
    });

    test('rtt - can be set and read back', () {
      final r = ping.Result();
      r.rtt = const Duration(milliseconds: 5);
      expect(r.rtt, equals(const Duration(milliseconds: 5)));
    });

    test('error - can be set and read back', () {
      final r = ping.Result();
      final err = StateError('boom');
      r.error = err;
      expect(r.error, same(err));
    });
  });

  group('PingService [Atomic Audit]', () {
    test(
      'PingService() - registers pingHandler on host for ping.id (ping.go:36-40)',
      () {
        final host = _FakeHost(PeerId.decode(_peerA));
        final svc = ping.PingService(host);
        expect(host.handler, isNotNull);
        expect(host.handler, equals(svc.pingHandler));
      },
    );

    test('host - exposes the Host the service was constructed with', () {
      final host = _FakeHost(PeerId.decode(_peerA));
      final svc = ping.PingService(host);
      expect(svc.host, same(host));
    });

    test(
      'pingHandler() - echoes a ping.pingSize payload back to the initiator',
      () async {
        final hostA = _FakeHost(PeerId.decode(_peerA));
        final hostB = _FakeHost(PeerId.decode(_peerB));
        final svc = ping.PingService(hostB);

        final (client, server) = _LoopStream.pair(hostA.id, hostB.id);
        svc.pingHandler(server);

        final payload = Uint8List.fromList(
          List<int>.generate(ping.pingSize, (i) => i),
        );
        await client.write(payload);
        final echoed = await client.read(ping.pingSize);
        expect(echoed, equals(payload));

        await client.close();
      },
    );

    test(
      'ping() - completes round trips and records latency in the peerstore (ping.go:102-104)',
      () async {
        final peerA = PeerId.decode(_peerA);
        final peerB = PeerId.decode(_peerB);
        final hostA = _FakeHost(peerA);
        final hostB = _FakeHost(peerB);
        hostA.peer = hostB;
        hostB.peer = hostA;
        ping.PingService(hostB);
        final svc = ping.PingService(hostA);

        final results = <ping.Result>[];
        final sub = svc.ping(peerB).listen(results.add);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await sub.cancel();

        expect(results, isNotEmpty);
        expect(results.first.error, isNull);
        expect(hostA.peerstore.latencyEwma(peerB), greaterThan(Duration.zero));
      },
    );

    test(
      'ping() - yields an error Result when newStream fails, without throwing',
      () async {
        final peerA = PeerId.decode(_peerA);
        final peerB = PeerId.decode(_peerB);
        final hostA = _FakeHost(peerA)..failNewStream = true;
        final svc = ping.PingService(hostA);

        final results = <ping.Result>[];
        final sub = svc.ping(peerB).listen(results.add);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();

        expect(results, hasLength(1));
        expect(results.single.error, isNotNull);
      },
    );
  });

  group('ping() [Atomic Audit]', () {
    test(
      'ping(host, peer) - top-level entry point runs the same protocol as PingService.ping',
      () async {
        final peerA = PeerId.decode(_peerA);
        final peerB = PeerId.decode(_peerB);
        final hostA = _FakeHost(peerA);
        final hostB = _FakeHost(peerB);
        hostA.peer = hostB;
        ping.PingService(hostB);

        final results = <ping.Result>[];
        final sub = ping.ping(hostA, peerB).listen(results.add);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await sub.cancel();

        expect(results, isNotEmpty);
        expect(results.first.error, isNull);
      },
    );

    test(
      'ping(host, peer) - canceling the subscription resets the underlying stream (ping.go:150-153)',
      () async {
        final peerA = PeerId.decode(_peerA);
        final peerB = PeerId.decode(_peerB);
        final hostA = _FakeHost(peerA);
        final hostB = _FakeHost(peerB);
        hostA.peer = hostB;

        _LoopStream? serverSide;
        hostB.setStreamHandler(ping.id, (stream) {
          serverSide = stream as _LoopStream;
        });

        final sub = ping.ping(hostA, peerB).listen((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(serverSide, isNotNull);
        // reset() force-closes the paired stream from the other side too;
        // observing that from the peer's stream is how this test confirms
        // the cancellation actually reached the wire, since only the
        // dialing side's own stream instance records wasReset directly.
        expect(serverSide!.isClosed, isTrue);
      },
    );
  });
}
