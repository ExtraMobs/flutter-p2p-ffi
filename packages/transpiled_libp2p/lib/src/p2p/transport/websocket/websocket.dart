// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
//
// Port of go-libp2p's `p2p/transport/websocket` package (websocket.go,
// addrs.go, conn.go, listener.go), fixed at the revision in
// doc/transpilation/UPSTREAM_LOCK.md. Frame-level WebSocket handling
// (handshake, masking, fragmentation) is delegated to dart:io's
// WebSocket/HttpServer/WebSocketTransformer rather than re-implemented, per
// AGENTS.md's fidelity-to-observable-behavior (not structure) standard: the
// Dart standard library is not a third-party dependency.
//
// go-libp2p's gorilla/websocket-backed HTTP-sharing machinery (fallback
// http.Handler, tcpreuse.ConnMgr port sharing, RFC 8441 ext-CONNECT plumbing)
// has no upstream-required counterpart for this project's node and is
// deliberately not ported; see the final report for the full list of
// documented gaps.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/crypto/key_types.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/peer_id.dart';
import '../../../core/transport/transport.dart';

/// Default WebSocket handshake timeout. Mirrors upstream's unexported
/// `defaultHandshakeTimeout` (websocket.go).
const Duration _defaultHandshakeTimeout = Duration(seconds: 15);

final Component _wsComponent = Component(Protocols.byCode(Protocols.ws)!, '');
final Component _wssComponent = Component(Protocols.byCode(Protocols.wss)!, '');
final Component _tlsComponent = Component(Protocols.byCode(Protocols.tls)!, '');
final Multiaddr _tlsWsAddr = Multiaddr([_tlsComponent, _wsComponent]);

/// Result of decomposing a `/ws`/`/wss`/`/tls[/sni/<host>]/ws` multiaddr.
/// Mirrors upstream's unexported `parsedWebsocketMultiaddr` (addrs.go).
class _ParsedWebsocketMultiaddr {
  _ParsedWebsocketMultiaddr({
    required this.isWss,
    this.sni,
    required this.restMultiaddr,
  });

  final bool isWss;
  final Component? sni;
  final Multiaddr restMultiaddr;
}

/// Mirrors upstream's unexported `parseWebsocketMultiaddr` (addrs.go),
/// including its "wss" -> "tls/ws" canonicalization and its quirk of never
/// classifying a bare `/tls/ws` (no address component before `tls`) as
/// secure, since the walk-back loop stops as soon as it would consume the
/// last remaining component without inspecting it.
_ParsedWebsocketMultiaddr _parseWebsocketMultiaddr(Multiaddr a) {
  var addr = a;
  final withoutWss = addr.decapsulate(Multiaddr([_wssComponent]));
  if (withoutWss != addr) {
    addr = withoutWss.encapsulate(_tlsWsAddr);
  }

  final withoutWs = addr.decapsulate(Multiaddr([_wsComponent]));
  if (withoutWs == addr) {
    throw const FormatException('not a websocket multiaddr');
  }

  var rest = withoutWs;
  var restMultiaddr = withoutWs;
  var isWss = false;
  Component? sni;
  while (true) {
    final (prefix, head) = rest.splitLast();
    if (head == null || prefix == null) break;
    rest = prefix;
    if (head.protocol.code == Protocols.sni) {
      sni = head;
    } else if (head.protocol.code == Protocols.tls) {
      isWss = true;
      restMultiaddr = rest;
      break;
    }
  }
  return _ParsedWebsocketMultiaddr(
    isWss: isWss,
    sni: sni,
    restMultiaddr: restMultiaddr,
  );
}

/// Mirrors upstream's unexported `(*parsedWebsocketMultiaddr).toMultiaddr`
/// (addrs.go).
Multiaddr _reconstructMultiaddr(_ParsedWebsocketMultiaddr p) {
  if (!p.isWss) return p.restMultiaddr.encapsulate(Multiaddr([_wsComponent]));
  if (p.sni == null) {
    return p.restMultiaddr.encapsulate(
      Multiaddr([_tlsComponent, _wsComponent]),
    );
  }
  return p.restMultiaddr.encapsulate(
    Multiaddr([_tlsComponent, p.sni!, _wsComponent]),
  );
}

/// Whether [m] is exactly a `/<ip4|ip6|dns|dns4|dns6|dnsaddr>/<tcp>` pair,
/// matching upstream's `dialMatcher` shape (websocket.go) closely enough for
/// [WebsocketTransport.canDial]. `dnsaddr` is accepted here for matcher
/// parity even though neither this transport's dial path nor
/// `TcpTransport._extractTcpEndpoint` can resolve it: DNSADDR TXT-record
/// resolution lives in `go-multiaddr-dns`, which is not ported to this
/// project (same pre-existing gap `TcpTransport` already has).
bool _looksLikeTcpEndpoint(Multiaddr m) {
  if (m.components.length != 2) return false;
  const validHosts = {
    Protocols.ip4,
    Protocols.ip6,
    Protocols.dns,
    Protocols.dns4,
    Protocols.dns6,
    Protocols.dnsaddr,
  };
  return validHosts.contains(m.components[0].protocol.code) &&
      m.components[1].protocol.code == Protocols.tcp;
}

/// Extracts `(host, port)` for the protocols this transport can actually
/// dial/bind. Mirrors `TcpTransport._extractTcpEndpoint`'s scope
/// deliberately (this project has no `manet.DialArgs` port); `dnsaddr` is
/// intentionally excluded, see [_looksLikeTcpEndpoint].
(String, int)? _tcpEndpoint(Multiaddr addr) {
  String? host;
  int? port;
  for (final c in addr.components) {
    final name = c.protocol.name;
    if (name == 'ip4' ||
        name == 'ip6' ||
        name == 'dns' ||
        name == 'dns4' ||
        name == 'dns6') {
      host = c.value;
    } else if (name == 'tcp') {
      port = int.tryParse(c.value);
    }
  }
  if (host != null && port != null) return (host, port);
  return null;
}

Multiaddr _buildListenMultiaddr(
  InternetAddress address,
  int port, {
  required bool isWss,
  Component? sni,
}) {
  final ipProto = address.type == InternetAddressType.IPv6 ? 'ip6' : 'ip4';
  final base = Multiaddr.parse('/$ipProto/${address.address}/tcp/$port');
  if (!isWss) return base.encapsulate(Multiaddr([_wsComponent]));
  final tlsPart = sni == null
      ? Multiaddr([_tlsComponent])
      : Multiaddr([_tlsComponent, sni]);
  return base.encapsulate(tlsPart).encapsulate(Multiaddr([_wsComponent]));
}

/// WebSocket implementation of [Transport] for `/ws` and `/wss`. Mirrors
/// upstream's exported `WebsocketTransport` (websocket.go). Go's functional
/// options (`WithTLSClientConfig`, `WithTLSConfig`, `WithHandshakeTimeout`)
/// collapse into named constructor parameters, matching this package's
/// existing `TcpTransport`/`BasicUpgrader` convention. `WithHTTPHandler` and
/// `WithHTTPServerConfig` (sharing a `/wss` port with an ordinary HTTPS
/// site) and the `sharedTcp`/`tcpreuse.ConnMgr` port-sharing constructor
/// argument are not ported: nothing in this project shares a TCP port
/// between transports, and TcpTransport itself has no such option either.
class WebsocketTransport implements Transport {
  WebsocketTransport({
    required this.upgrader,
    this.resourceManager = const NullResourceManager(),
    this.handshakeTimeout = _defaultHandshakeTimeout,
    this.tlsClientContext,
    this.tlsSecurityContext,
  });

  final Upgrader upgrader;
  final ResourceManager resourceManager;

  /// Bounds both the outbound WebSocket upgrade (`Dial`) and, once accepted,
  /// how long an inbound connection may sit unupgraded before [Listener]
  /// drops it. Mirrors `WithHandshakeTimeout` (websocket.go).
  final Duration handshakeTimeout;

  /// TLS trust configuration for outbound `/wss` dials. `null` uses the
  /// platform default trust store, mirroring the Go zero-value
  /// `tlsClientConf: &tls.Config{}`. Certificate validation is never
  /// disabled here; see [WebsocketTransport.dial].
  final SecurityContext? tlsClientContext;

  /// TLS certificate/key configuration for accepting inbound `/wss`
  /// connections. `null` means listening on `/wss` is unsupported, matching
  /// upstream's `"cannot listen on wss address %s without a tls.Config"`.
  final SecurityContext? tlsSecurityContext;

  final List<Listener> _listeners = [];
  bool _closed = false;

  @override
  bool canDial(Multiaddr addr) {
    try {
      return _looksLikeTcpEndpoint(
        _parseWebsocketMultiaddr(addr).restMultiaddr,
      );
    } on FormatException {
      return false;
    }
  }

  @override
  List<int> protocols() => const [Protocols.ws, Protocols.wss];

  @override
  bool proxy() => false;

  /// Canonicalizes a `/wss` multiaddr into its `/tls/sni/<host>/ws` form,
  /// deriving the SNI value from a `dns`/`dns4`/`dns6` component when no
  /// explicit `sni` component is present. A non-`wss` address, or a `wss`
  /// address with no derivable SNI, is returned unchanged. Mirrors
  /// upstream's exported `WebsocketTransport.Resolve` (websocket.go); `ctx`
  /// is dropped as upstream's implementation never reads it.
  List<Multiaddr> resolve(Multiaddr maddr) {
    final parsed = _parseWebsocketMultiaddr(maddr);
    if (!parsed.isWss) return [maddr];

    var sni = parsed.sni;
    if (sni == null) {
      for (final c in parsed.restMultiaddr.components) {
        final code = c.protocol.code;
        if (code == Protocols.dns ||
            code == Protocols.dns4 ||
            code == Protocols.dns6) {
          sni = Component(Protocols.byCode(Protocols.sni)!, c.value);
          break;
        }
      }
    }
    if (sni == null) return [maddr];
    return [
      _reconstructMultiaddr(
        _ParsedWebsocketMultiaddr(
          isWss: true,
          sni: sni,
          restMultiaddr: parsed.restMultiaddr,
        ),
      ),
    ];
  }

  @override
  Future<CapableConn> dial(Multiaddr addr, PeerId peer) async {
    if (_closed) throw StateError('WebsocketTransport is closed');
    final rawConn = await _maDial(addr);
    try {
      final upgraded = await upgrader.upgrade(
        rawConn,
        Direction.outbound,
        peer,
      );
      return _WebsocketCapableConn(upgraded);
    } catch (err) {
      await rawConn.close();
      rethrow;
    }
  }

  /// Mirrors upstream's unexported `WebsocketTransport.maDial` (websocket.go).
  Future<_WebsocketConn> _maDial(Multiaddr raddr) async {
    final parsed = _parseWebsocketMultiaddr(raddr);
    final endpoint = _tcpEndpoint(parsed.restMultiaddr);
    if (endpoint == null) {
      throw ArgumentError(
        'Address $raddr is not a dialable websocket multiaddr',
      );
    }
    final (restHost, port) = endpoint;
    // Upstream dials the already-resolved IP directly and only overrides the
    // TLS ServerName/Host header when an explicit `sni` component differs
    // from it, avoiding a second DNS lookup. dart:io's WebSocket.connect
    // only accepts a URL, so when `sni` is present we connect by that
    // hostname directly (a documented, minor behavioral difference: one
    // extra resolution, not an extra round trip to the peer).
    final connectHost = parsed.sni?.value ?? restHost;
    final scheme = parsed.isWss ? 'wss' : 'ws';
    final uri = Uri(scheme: scheme, host: connectHost, port: port);

    HttpClient? client;
    if (parsed.isWss && tlsClientContext != null) {
      client = HttpClient(context: tlsClientContext);
    }
    final socket = await WebSocket.connect(
      uri.toString(),
      customClient: client,
    ).timeout(handshakeTimeout);

    return _WebsocketConn(
      socket: socket,
      transportInstance: this,
      isSecure: parsed.isWss,
      // dart:io's client-side WebSocket does not expose the underlying
      // Socket (or its local address) after connect(), unlike Go's gorilla
      // dialer which hands back a *net.Conn. There is no stdlib way to
      // recover the real local ephemeral address here; this is a
      // documented gap, not a silent workaround.
      localMultiaddr: Multiaddr.parse('/ip4/0.0.0.0/tcp/0/$scheme'),
      remoteMultiaddr: raddr,
    );
  }

  @override
  Future<Listener> listen(Multiaddr addr) async {
    if (_closed) throw StateError('WebsocketTransport is closed');
    final parsed = _parseWebsocketMultiaddr(addr);
    if (parsed.isWss && tlsSecurityContext == null) {
      throw ArgumentError(
        'cannot listen on wss address $addr without a tls SecurityContext',
      );
    }
    final endpoint = _tcpEndpoint(parsed.restMultiaddr);
    if (endpoint == null) {
      throw ArgumentError('Address $addr is not a valid websocket multiaddr');
    }
    final (host, port) = endpoint;

    final server = parsed.isWss
        ? await HttpServer.bindSecure(host, port, tlsSecurityContext!)
        : await HttpServer.bind(host, port);

    final boundMultiaddr = _buildListenMultiaddr(
      server.address,
      server.port,
      isWss: parsed.isWss,
      sni: parsed.sni,
    );

    // The socket listener yields raw connections; the upgrader negotiates
    // them concurrently, with a timeout, exactly as it does for TCP.
    final listener = _WebsocketUpgradedListener(
      upgrader.upgradeGatedMaListener(
        this,
        _WebsocketListener(
          server: server,
          transportInstance: this,
          isWss: parsed.isWss,
          multiaddr: boundMultiaddr,
        ),
      ),
    );
    _listeners.add(listener);
    return listener;
  }

  /// Closes every listener created by this transport. Not part of the
  /// [Transport] interface, mirroring `TcpTransport.close`'s precedent for
  /// tearing down owned listeners.
  Future<void> close() async {
    _closed = true;
    for (final l in _listeners.toList()) {
      await l.close();
    }
    _listeners.clear();
  }
}

/// Presents a [WebSocket] connection as a continuous byte stream. Mirrors
/// upstream's exported `Conn` (conn.go). Renamed *and* made private, unlike
/// most exported-Go-type mappings in this project: Dart has no
/// package-qualified `websocket.Conn` spelling, so keeping the name `Conn`
/// would collide with this project's own public `Conn` interface
/// (`core/network/network.dart`), and nothing outside this file ever needs
/// to name the type directly -- every caller sees it only through the
/// [RawConn] interface it implements, exactly like `TcpTransport`'s own
/// private raw-conn wrapper. Being private, it carries no individual Rule-24
/// atomic-test obligation of its own; its behavior (including the
/// partial-frame-read buffering described below) is exercised end to end by
/// `test/atomic/nivel_2/libp2p_websocket_atomic_tests.dart` through
/// [WebsocketTransport.dial]/`listen()`/`accept()`.
///
/// [read] buffers whole WebSocket messages and serves them out in
/// caller-requested chunks exactly like upstream's `Read` loops over
/// `ws.Conn.NextReader` -- a single incoming frame/message can be larger
/// than the caller's buffer, and a partial read must not discard the
/// remainder. A zero-length message adds no bytes and is transparently
/// skipped, matching upstream's `prepNextReader` loop (see
/// `TestWriteZero`/`conn.go`).
///
/// Text frames are treated as raw bytes (UTF-8 encoded), matching upstream:
/// `NextReader` never distinguishes text from binary before handing back an
/// `io.Reader` either.
class _WebsocketConn implements RawConn {
  _WebsocketConn({
    required WebSocket socket,
    required Transport transportInstance,
    required bool isSecure,
    required Multiaddr localMultiaddr,
    required Multiaddr remoteMultiaddr,
  }) : _socket = socket,
       _transport = transportInstance,
       _local = localMultiaddr,
       _remote = remoteMultiaddr {
    // Same hazard as `_TcpRawConn`: a WebSocket that dies mid-write reports
    // it through `done`, asynchronously and in the root zone, so leaving it
    // unobserved turns one peer's reset into an unhandled asynchronous error
    // and kills the isolate.
    unawaited(
      _socket.done.then<void>(
        (_) {},
        onError: (Object error) {
          _isClosed = true;
          dev.log('websocket failed', name: 'websocket', error: error);
        },
      ),
    );
    _subscription = _socket.listen(
      (dynamic message) {
        final bytes = message is String
            ? utf8.encode(message)
            : (message as List<int>);
        if (bytes.isNotEmpty) _buffer.addAll(bytes);
        _wake();
      },
      onError: (Object err) {
        _isClosed = true;
        final waiting = _completer;
        if (waiting != null && !waiting.isCompleted) waiting.completeError(err);
      },
      onDone: () {
        _isClosed = true;
        _wake();
      },
      cancelOnError: true,
    );
  }

  final WebSocket _socket;
  final Transport _transport;
  final Multiaddr _local;
  final Multiaddr _remote;
  StreamSubscription<dynamic>? _subscription;
  final List<int> _buffer = [];
  Completer<void>? _completer;
  bool _isClosed = false;

  void _wake() {
    final waiting = _completer;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }

  @override
  Transport transport() => _transport;

  @override
  Multiaddr localMultiaddr() => _local;

  @override
  Multiaddr remoteMultiaddr() => _remote;

  @override
  Future<Uint8List> read([int? maxLength]) async {
    while (_buffer.isEmpty && !_isClosed) {
      _completer = Completer<void>();
      await _completer!.future;
      _completer = null;
    }
    if (_buffer.isEmpty) return Uint8List(0);
    final count = maxLength != null && maxLength > 0
        ? (maxLength < _buffer.length ? maxLength : _buffer.length)
        : _buffer.length;
    final chunk = Uint8List.fromList(_buffer.sublist(0, count));
    _buffer.removeRange(0, count);
    return chunk;
  }

  // dart:io's WebSocket (a StreamSink) throws if add()/close() race; TCP's
  // raw conn has the same constraint on its IOSink and serializes for the
  // same reason.
  Future<void> _pending = Future<void>.value();

  Future<void> _serialized(Future<void> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<void> write(Uint8List data) => _serialized(() async {
    if (_isClosed) throw StateError('WebSocket connection is closed');
    _socket.add(data);
  });

  @override
  Future<void> close() => _serialized(() async {
    if (_isClosed) return;
    _isClosed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _socket.close();
  });

  @override
  bool get isClosed => _isClosed;
}

/// Wraps an upgraded [CapableConn] to report `transport: 'websocket'` in
/// [connState], mirroring upstream's unexported `capableConn` wrapper
/// (websocket.go). `BasicUpgrader` (shared with `TcpTransport`, out of this
/// file's scope) hardcodes `transport: 'tcp'` in the connection it returns;
/// wrapping here -- exactly as upstream itself wraps rather than modifying
/// its shared upgrader -- corrects that for connections dialed/accepted
/// through this transport without touching `basic_upgrader.dart`.
class _WebsocketCapableConn implements CapableConn {
  _WebsocketCapableConn(this._inner);

  final CapableConn _inner;

  @override
  Transport transport() => _inner.transport();

  @override
  PeerId localPeer() => _inner.localPeer();

  @override
  PeerId remotePeer() => _inner.remotePeer();

  @override
  PubKey remotePublicKey() => _inner.remotePublicKey();

  @override
  ConnectionState connState() {
    final cs = _inner.connState();
    return ConnectionState(
      streamMultiplexer: cs.streamMultiplexer,
      security: cs.security,
      transport: 'websocket',
      usedEarlyMuxerNegotiation: cs.usedEarlyMuxerNegotiation,
    );
  }

  @override
  Multiaddr localMultiaddr() => _inner.localMultiaddr();

  @override
  Multiaddr remoteMultiaddr() => _inner.remoteMultiaddr();

  @override
  ConnScope scope() => _inner.scope();

  @override
  ConnStats stat() => _inner.stat();

  @override
  Future<NetworkStream> openStream() => _inner.openStream();

  @override
  Future<NetworkStream> acceptStream() => _inner.acceptStream();

  @override
  Future<void> close() => _inner.close();

  @override
  bool get isClosed => _inner.isClosed;
}

/// Accepts inbound WebSocket connections over an [HttpServer]. Mirrors
/// upstream's unexported `listener` (listener.go), simplified: dart:io's
/// `HttpServer` + `WebSocketTransformer` already perform the HTTP
/// upgrade/TLS handshake, so the handshake-timeout `negotiatingConn`/
/// `ConnContext` machinery and the non-upgrade HTTP fallback path
/// (`WithHTTPHandler`) are not ported -- see the class doc on
/// [WebsocketTransport] for the latter. A slow (non-WebSocket-upgrading)
/// client can hold an accepted TCP connection open past [handshakeTimeout]
/// with this simplification; upstream bounds it explicitly.
/// Restores the transport label that [_WebsocketCapableConn] carries, on top
/// of the generic listener the upgrader builds.
///
/// The upgrader's listener is transport-agnostic by design -- it is the same
/// one TCP uses -- and Go has no equivalent because there the transport name
/// is read off the transport itself rather than by wrapping the connection.
class _WebsocketUpgradedListener implements Listener {
  _WebsocketUpgradedListener(this._inner);

  final Listener _inner;

  @override
  Future<CapableConn> accept() async =>
      _WebsocketCapableConn(await _inner.accept());

  @override
  Future<void> close() => _inner.close();

  @override
  Multiaddr multiaddr() => _inner.multiaddr();
}

/// Hands out raw inbound WebSocket connections, one per accepted socket.
///
/// Like `_TcpListener`, it deliberately does not negotiate: that is the
/// upgrader's job, and doing it here would serialise every inbound connection
/// behind the slowest handshake.
class _WebsocketListener implements GatedMaListener {
  _WebsocketListener({
    required HttpServer server,
    required Transport transportInstance,
    required bool isWss,
    required Multiaddr multiaddr,
  }) : _server = server,
       _transport = transportInstance,
       _isWss = isWss,
       _multiaddr = multiaddr {
    _subscription = _server.listen(
      _handleRequest,
      onError: (Object _) {},
      onDone: () {
        _closed = true;
        _wake();
      },
    );
  }

  final HttpServer _server;
  final Transport _transport;
  final bool _isWss;
  final Multiaddr _multiaddr;
  StreamSubscription<HttpRequest>? _subscription;
  final List<_WebsocketConn> _pending = [];
  Completer<void>? _completer;
  bool _closed = false;

  void _wake() {
    final waiting = _completer;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final info = request.connectionInfo;
    final scheme = _isWss ? 'wss' : 'ws';
    final remote = info == null
        ? Multiaddr.parse('/ip4/0.0.0.0/tcp/0/$scheme')
        : Multiaddr.parse(
            '/${info.remoteAddress.type == InternetAddressType.IPv6 ? 'ip6' : 'ip4'}'
            '/${info.remoteAddress.address}/tcp/${info.remotePort}/$scheme',
          );
    try {
      final socket = await WebSocketTransformer.upgrade(request);
      _pending.add(
        _WebsocketConn(
          socket: socket,
          transportInstance: _transport,
          isSecure: _isWss,
          localMultiaddr: _multiaddr,
          remoteMultiaddr: remote,
        ),
      );
      _wake();
    } on Object {
      // Upgrade failed (bad handshake, client disconnect mid-upgrade, ...);
      // nothing to hand to accept() for this request.
    }
  }

  @override
  Future<RawConn> accept() async {
    while (_pending.isEmpty && !_closed) {
      _completer = Completer<void>();
      await _completer!.future;
      _completer = null;
    }
    if (_pending.isEmpty) throw const ListenerClosedException();
    return _pending.removeAt(0);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    await _server.close(force: true);
    _wake();
  }

  @override
  Multiaddr multiaddr() => _multiaddr;
}
