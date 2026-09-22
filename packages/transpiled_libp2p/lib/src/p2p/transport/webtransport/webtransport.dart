// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:crypto/crypto.dart' as crypto_pkg;
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:transpiled_multibase/transpiled_multibase.dart' as multibase;
import 'package:transpiled_multihash/transpiled_multihash.dart' as multihash;
import 'package:transpiled_quic_go/transpiled_quic_go.dart';
import 'package:transpiled_quic_go/transpiled_quic_go.dart' as quicgo;
import 'package:transpiled_webtransport_go/transpiled_webtransport_go.dart'
    as webtransport;

import '../../../core/connmgr/gater.dart';
import '../../../core/crypto/key_types.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/peer_id.dart';
import '../../../core/sec/security.dart';
import '../../../core/transport/transport.dart';
import '../../security/noise/noise_handshake_payload.dart';
import '../../security/noise/transport.dart' as noise;
import 'cert_manager.dart';
import 'crypto.dart' as wtcrypto;

/// The HTTP/3 path a libp2p WebTransport session is established on.
///
/// Go: `webtransportHTTPEndpoint` (`p2p/transport/webtransport/transport.go`).
/// It is unexported there, so it stays private here too.
const String _webtransportHttpEndpoint = '/.well-known/libp2p-webtransport';

/// Checks whether [multiaddr] is a valid WebTransport multiaddr and returns
/// whether it is valid along with the count of certhashes.
(bool, int) isWebtransportMultiaddr(Multiaddr multiaddr) {
  var foundUdp = false;
  var foundQuicV1 = false;
  var foundWebTransport = false;
  var certhashCount = 0;

  for (final c in multiaddr.components) {
    final code = c.protocol.code;
    if (code == Protocols.udp) {
      if (!foundUdp) foundUdp = true;
    } else if (code == Protocols.quicV1 || c.protocol.name == 'quic-v1') {
      if (foundUdp && !foundQuicV1) foundQuicV1 = true;
    } else if (code == Protocols.webtransport ||
        c.protocol.name == 'webtransport') {
      if (foundQuicV1) foundWebTransport = true;
    } else if (code == Protocols.certhash || c.protocol.name == 'certhash') {
      if (foundWebTransport) certhashCount++;
    }
  }
  return (foundUdp && foundQuicV1 && foundWebTransport, certhashCount);
}

/// Extracts multihash certificate digests from a multiaddr containing /certhash components.
List<Uint8List> extractCertHashes(Multiaddr addr) {
  final hashes = <Uint8List>[];
  for (final c in addr.components) {
    if (c.protocol.code == Protocols.certhash ||
        c.protocol.name == 'certhash') {
      try {
        final (_, bytes) = multibase.decode(c.value);
        final mh = multihash.decode(bytes);
        hashes.add(Uint8List.fromList(mh.digest));
      } catch (_) {
        // Ignore unparseable certhash
      }
    }
  }
  return hashes;
}

/// Constructs a certhash multiaddr component from raw certificate bytes.
Component addrComponentForCert(Uint8List certBytes) {
  final digest = Uint8List.fromList(crypto_pkg.sha256.convert(certBytes).bytes);
  final mh = multihash.encode(digest, Golang.Uint64(multihash.sha2_256));
  final str = multibase.encode(multibase.Encoding.base58btc, mh);
  return Multiaddr.parse('/certhash/$str').components.first;
}

/// WebTransport transport implementation for libp2p.
class WebtransportTransport implements Transport {
  WebtransportTransport({
    required this.privKey,
    this.rcmgr = const NullResourceManager(),
    this.gater,
    this.handshakeTimeout = const Duration(seconds: 10),
  }) : localPeer = PeerId.fromPubKey(privKey.getPublic());

  final PrivKey privKey;
  final PeerId localPeer;
  final ResourceManager rcmgr;
  final ConnectionGater? gater;

  /// How long the QUIC, HTTP/3 and Noise handshakes may take.
  ///
  /// Go: `handshakeTimeout` (`listener.go:25`), overridable with
  /// `WithHandshakeTimeout`.
  final Duration handshakeTimeout;
  final List<Listener> _listeners = [];
  bool _closed = false;

  /// The short-lived certificates this transport presents and advertises.
  ///
  /// Go keeps it on the transport too (`transport.go`'s `certManager`),
  /// created on the first `Listen` and shared by every listener, so that one
  /// node advertises one set of `/certhash/` values however many addresses it
  /// listens on.
  CertManager? _certManager;

  @override
  bool canDial(Multiaddr addr) {
    final (ok, _) = isWebtransportMultiaddr(addr);
    return ok;
  }

  @override
  List<int> protocols() => const [
    Protocols.ip4,
    Protocols.ip6,
    Protocols.udp,
    Protocols.quicV1,
    Protocols.webtransport,
  ];

  @override
  bool proxy() => false;

  /// Resolves multiaddr endpoint.
  Future<Multiaddr> resolve(Multiaddr addr) async => addr;

  /// Appends this transport's `/certhash/` components to [addr].
  ///
  /// Go: `AddCertHashes` (`transport.go`), which appends the cert manager's
  /// current and next hashes. Before a listener exists there is no
  /// certificate to name, so [addr] comes back unchanged -- Go answers the
  /// same way, with `ok == false`.
  ///
  /// This used to hash `privKey.raw()`, the raw private key, which is not a
  /// certificate at all: the `/certhash/` it produced could never match what
  /// the TLS handshake presented, so no peer could dial the address.
  Multiaddr addCertHashes(Multiaddr addr) {
    final manager = _certManager;
    if (manager == null) return addr;
    return addr.encapsulate(Multiaddr.parse(_certhashPath(manager)));
  }

  /// The `/certhash/<current>/certhash/<next>` suffix a listener publishes.
  ///
  /// Go: `certManager.cacheAddrComponent` (`cert_manager.go:201-215`), which
  /// advertises the current and next certificates but not the retired one --
  /// that one is still accepted from a peer holding a cached multiaddr.
  static String _certhashPath(CertManager manager) =>
      '/certhash/${addrComponentForCert(manager.current.certificateDer).value}'
      '/certhash/${addrComponentForCert(manager.next.certificateDer).value}';

  @override
  Future<Listener> listen(Multiaddr addr) async {
    if (_closed) throw StateError('WebtransportTransport is closed');
    final (isValid, certhashCount) = isWebtransportMultiaddr(addr);
    if (!isValid) {
      throw ArgumentError(
        'Address $addr is not a valid WebTransport multiaddr',
      );
    }
    if (certhashCount > 0) {
      throw ArgumentError(
        'Cannot listen on multiaddr with specific certhash: $addr',
      );
    }

    final endpoint = _endpointOf(addr);
    final host = endpoint?.$1 ?? '0.0.0.0';
    final port = endpoint?.$2 ?? 0;

    final bindAddress = (host == '127.0.0.1' || host == 'localhost')
        ? InternetAddress.loopbackIPv4
        : (host == '::1'
              ? InternetAddress.loopbackIPv6
              : (host.contains(':')
                    ? InternetAddress.anyIPv6
                    : InternetAddress.anyIPv4));

    final socket = await RawDatagramSocket.bind(bindAddress, port);

    // NOT the libp2p identity certificate. That one is valid for a century,
    // and the W3C WebTransport specification caps a pinned certificate at
    // fourteen days -- a Go peer refuses anything longer outright, with
    // "cert must not be valid for longer than 14 days", so presenting the
    // identity certificate made this listener undiallable by any real peer.
    final manager = _certManager ??= await CertManager.create(privKey);
    final certificate = manager.current;

    final server = quicgo.QuicServer(
      socket: socket,
      certificate: quicgo.QuicServerCertificate(
        der: certificate.certificateDer,
        sign: certificate.sign,
      ),
      nextProtos: const [nextProtoH3],
      // WebTransport authenticates the peer with the Noise handshake that
      // runs inside the session, not with a TLS client certificate: a
      // browser has none to offer. Go: `getTLSConf` builds a server config
      // with no `ClientAuth`.
      requestClientCertificate: false,
      // An HTTP/3 server refuses a WebTransport session whose peer did not
      // enable datagrams, so this side has to offer them too.
      enableDatagrams: true,
    );

    final boundAddr = Multiaddr.parse(
      '/${socket.address.type == InternetAddressType.IPv6 ? 'ip6' : 'ip4'}'
      '/${socket.address.address}/udp/${socket.port}/quic-v1/webtransport'
      '${_certhashPath(manager)}',
    );

    final listener = _WebtransportListener(
      transport: this,
      socket: socket,
      server: server,
      boundAddr: boundAddr,
      certManager: manager,
    );
    _listeners.add(listener);
    return listener;
  }

  @override
  Future<CapableConn> dial(Multiaddr addr, PeerId peer) async {
    if (_closed) throw StateError('WebtransportTransport is closed');
    if (!canDial(addr)) {
      throw ArgumentError('Cannot dial non-WebTransport address: $addr');
    }

    // Go's `dialWithScope` refuses outright without certhashes: they are the
    // only thing authenticating the TLS certificate, because the server has
    // no CA-issued chain.
    final certHashes = _certHashMultihashes(addr);
    if (certHashes.isEmpty) {
      throw ArgumentError("can't dial webtransport without certhashes: $addr");
    }

    final endpoint = _endpointOf(addr);
    if (endpoint == null) {
      throw ArgumentError('Could not resolve host/port from $addr');
    }
    final (host, port) = endpoint;
    final remoteAddress =
        InternetAddress.tryParse(host) ??
        (await InternetAddress.lookup(host)).first;
    final isIPv6 = remoteAddress.type == InternetAddressType.IPv6;

    final socket = await RawDatagramSocket.bind(
      isIPv6
          ? (remoteAddress.isLoopback
                ? InternetAddress.loopbackIPv6
                : InternetAddress.anyIPv6)
          : (remoteAddress.isLoopback
                ? InternetAddress.loopbackIPv4
                : InternetAddress.anyIPv4),
      0,
    );
    final localAddr = Multiaddr.parse(
      '/${isIPv6 ? 'ip6' : 'ip4'}/${socket.address.address}'
      '/udp/${socket.port}/quic-v1/webtransport',
    );

    try {
      final quicConn = await quicgo.dial(
        socket: socket,
        remoteAddress: remoteAddress,
        remotePort: port,
        tlsConfig: quicgo.QuicTlsConfig(
          // A WebTransport endpoint is an HTTP/3 endpoint, so ALPN is `h3`,
          // not `libp2p` -- Go appends `http3.NextProtoH3` in `transport.dial`.
          nextProtos: const [nextProtoH3],
          // Not insecure: the certificate is verified against the certhashes
          // carried by the multiaddr itself, per
          // https://www.w3.org/TR/webtransport/#certificate-hashes and Go's
          // `verifyRawCerts`.
          verifyPeerCertificate: (chain) async =>
              _verifyRawCerts(chain, certHashes),
        ),
        // webtransport-go's server refuses a session whose client did not
        // advertise QUIC datagram support.
        enableDatagrams: true,
        handshakeTimeout: handshakeTimeout,
      );

      final session =
          await webtransport.Dialer(handshakeTimeout: handshakeTimeout).dial(
            conn: quicConn,
            authority: isIPv6 ? '[$host]:$port' : '$host:$port',
            path: '$_webtransportHttpEndpoint?type=noise',
          );

      final secured = await _upgrade(
        session: session,
        peer: peer,
        certHashes: certHashes,
        localAddr: localAddr,
        remoteAddr: addr,
      );

      if (gater != null &&
          !gater!.interceptSecured(Direction.outbound, peer, secured)) {
        await session.close();
        throw StateError('secured connection gated');
      }

      return _WebtransportSessionConn(
        transport: this,
        session: session,
        localPeer: localPeer,
        remotePeer: secured.remotePeer(),
        remotePubKey: secured.remotePublicKey(),
        localMultiaddr: localAddr,
        remoteMultiaddr: addr,
        direction: Direction.outbound,
      );
    } catch (_) {
      socket.close();
      rethrow;
    }
  }

  /// Authenticates the peer over the session, per Go's `transport.upgrade`.
  ///
  /// The WebTransport certificate proves nothing about the libp2p identity, so
  /// a Noise handshake runs on the session's first stream. Its early data
  /// carries the server's full set of certificate hashes, and the ones this
  /// side dialled with must all be in it -- otherwise a server could hand out
  /// a multiaddr pinning a certificate it does not actually hold.
  Future<SecureConn> _upgrade({
    required webtransport.Session session,
    required PeerId peer,
    required List<Uint8List> certHashes,
    required Multiaddr localAddr,
    required Multiaddr remoteAddr,
  }) async {
    final stream = session.openStream();
    final insecure = _SessionRawConn(
      transport: this,
      stream: stream,
      localMultiaddr: localAddr,
      remoteMultiaddr: remoteAddr,
    );
    final receiver = _CertHashesReceiver(certHashes);
    final secured = await noise.NoiseTransport(
      privKey: privKey,
      initiatorEarlyDataHandler: receiver,
    ).secureOutbound(insecure, peer);
    // The Noise handshake _should_ guarantee the callback ran; Go
    // double-checks and so does this.
    if (!receiver.verified) {
      await secured.close();
      throw StateError('WebTransport peer never sent its certificate hashes');
    }
    await secured.close();
    return secured;
  }

  void _removeListener(Listener listener) => _listeners.remove(listener);

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final l in List<Listener>.from(_listeners)) {
      await l.close();
    }
    _listeners.clear();
    _certManager?.close();
    _certManager = null;
  }
}

/// Accepts inbound WebTransport sessions, per Go's `listener`
/// (`p2p/transport/webtransport/listener.go`).
///
/// Three handshakes stack up before a libp2p connection exists: QUIC with
/// ALPN `h3`, the HTTP/3 Extended CONNECT that turns that connection into a
/// WebTransport session, and a Noise handshake on the session's first stream
/// that finally names the peer. A failure in any of them concerns only the
/// peer that caused it, so it is logged and the wait resumes rather than
/// failing the listener for everyone.
class _WebtransportListener implements Listener {
  _WebtransportListener({
    required WebtransportTransport transport,
    required RawDatagramSocket socket,
    required quicgo.QuicServer server,
    required Multiaddr boundAddr,
    required CertManager certManager,
  }) : _transport = transport,
       _socket = socket,
       _server = server,
       _boundAddr = boundAddr,
       _certManager = certManager {
    // The listener owns the socket and the server multiplexes every peer over
    // it, so datagrams are read here once and handed across.
    _subscription = _socket.listen((event) {
      if (event != RawSocketEvent.read || _closed) return;
      final datagram = _socket.receive();
      if (datagram != null) _server.handleDatagram(datagram);
    }, onError: (Object _) {});
  }

  StreamSubscription<RawSocketEvent>? _subscription;

  final WebtransportTransport _transport;
  final RawDatagramSocket _socket;
  final quicgo.QuicServer _server;
  final Multiaddr _boundAddr;
  final CertManager _certManager;

  /// The multihashes of the certificates this listener presents, sent to
  /// every peer as Noise early data so it can check that the `/certhash/` it
  /// dialled really belongs to this server.
  ///
  /// Read from the cert manager on every use rather than captured once:
  /// after a rollover the set changes, and a peer dialling with a cached
  /// multiaddr has to still find its hash among them. Go reads it the same
  /// way, through `certManager.SerializedCertHashes()`.
  List<Uint8List> get _certHashes => [
    for (final digest in _certManager.certHashes)
      multihash.encode(digest, Golang.Uint64(multihash.sha2_256)),
  ];

  bool _closed = false;

  @override
  Multiaddr multiaddr() => _boundAddr;

  @override
  Future<CapableConn> accept() async {
    while (true) {
      if (_closed) throw const ListenerClosedException();
      final quicConn = await _server.accept();
      try {
        final session =
            await webtransport.Server(
              handshakeTimeout: _transport.handshakeTimeout,
            ).accept(
              conn: quicConn,
              acceptPath: (path) => path.startsWith(_webtransportHttpEndpoint),
            );
        return await _upgradeInbound(session, quicConn);
      } catch (e, st) {
        await quicConn.close();
        if (_closed) throw const ListenerClosedException();
        dev.log(
          'inbound WebTransport session rejected',
          name: 'webtransport',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  /// Authenticates the peer over the session's first stream.
  ///
  /// Go: `listener.Accept` -> `transport.upgrade`, with the roles reversed --
  /// here this side is the Noise responder, and the early data it sends is
  /// its own certificate hashes, which is what lets the dialling peer check
  /// the `/certhash/` it pinned.
  Future<CapableConn> _upgradeInbound(
    webtransport.Session session,
    quicgo.QuicConn quicConn,
  ) async {
    final localAddr = _boundAddr;
    final remoteAddr = _remoteMultiaddrOf(quicConn);
    final stream = await session.acceptStream();
    final insecure = _SessionRawConn(
      transport: _transport,
      stream: stream,
      localMultiaddr: localAddr,
      remoteMultiaddr: remoteAddr,
    );
    final secured = await noise.NoiseTransport(
      privKey: _transport.privKey,
      responderEarlyDataHandler: _CertHashesSender(_certHashes),
      // An inbound peer is whoever authenticates, so there is no expected
      // PeerId to check against: an empty one disables that comparison.
    ).secureInbound(insecure, PeerId(value: Uint8List(0)));
    await secured.close();

    final gater = _transport.gater;
    if (gater != null &&
        !gater.interceptSecured(
          Direction.inbound,
          secured.remotePeer(),
          secured,
        )) {
      await session.close();
      throw StateError('secured connection gated');
    }

    return _WebtransportSessionConn(
      transport: _transport,
      session: session,
      localPeer: _transport.localPeer,
      remotePeer: secured.remotePeer(),
      remotePubKey: secured.remotePublicKey(),
      localMultiaddr: localAddr,
      remoteMultiaddr: remoteAddr,
      direction: Direction.inbound,
    );
  }

  Multiaddr _remoteMultiaddrOf(quicgo.QuicConn conn) {
    final address = conn.remoteAddress;
    final ip = address.type == InternetAddressType.IPv6 ? 'ip6' : 'ip4';
    return Multiaddr.parse(
      '/$ip/${address.address}/udp/${conn.remotePort}/quic-v1/webtransport',
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _server.close();
    _socket.close();
    _transport._removeListener(this);
  }
}

/// Sends this side's WebTransport certificate hashes as Noise early data.
///
/// Go: `newEarlyDataSender(&pb.NoiseExtensions{WebtransportCerthashes: ...})`
/// in `listener.Accept`.
class _CertHashesSender implements noise.NoiseEarlyDataHandler {
  _CertHashesSender(this._certHashes);

  final List<Uint8List> _certHashes;

  @override
  NoiseExtensions? send(RawConn insecure, PeerId remote) =>
      NoiseExtensions(webtransportCerthashes: _certHashes);

  @override
  Future<void> received(RawConn insecure, NoiseExtensions? extensions) async {}
}

/// The `(host, port)` a WebTransport multiaddr points at, or `null` when it
/// carries neither.
(String, int)? _endpointOf(Multiaddr addr) {
  String? host;
  int? port;
  for (final c in addr.components) {
    final code = c.protocol.code;
    if (code == Protocols.ip4 ||
        code == Protocols.ip6 ||
        code == Protocols.dns ||
        code == Protocols.dns4 ||
        code == Protocols.dns6) {
      host = c.value;
    } else if (code == Protocols.udp) {
      port = int.tryParse(c.value);
    }
  }
  if (host == null || port == null) return null;
  return (host, port);
}

/// The raw multihashes carried by the `/certhash/...` components of [addr].
///
/// [extractCertHashes] returns only the digests; the comparison against a
/// peer's advertised `webtransport_certhashes` is over whole multihashes, so
/// that two digests of different hash functions can never match each other --
/// the same guarantee Go gets by comparing `DecodedMultihash.Code` alongside
/// `Digest`.
List<Uint8List> _certHashMultihashes(Multiaddr addr) {
  final hashes = <Uint8List>[];
  for (final c in addr.components) {
    if (c.protocol.code != Protocols.certhash &&
        c.protocol.name != 'certhash') {
      continue;
    }
    final (_, bytes) = multibase.decode(c.value);
    // Decoding validates that the bytes really are a multihash; the raw form
    // is what gets compared.
    multihash.decode(bytes);
    hashes.add(Uint8List.fromList(bytes));
  }
  return hashes;
}

/// Verifies the server's certificate chain against the pinned [certHashes],
/// which arrive multihash-encoded from the dialled multiaddr.
///
/// Unwraps them to the raw SHA-256 digests -- the only code the W3C
/// WebTransport specification allows for `serverCertificateHashes`, which is
/// why Go filters on it too (`crypto.go:117`) -- and hands the work to the
/// port of `verifyRawCerts`, which also enforces the three checks this
/// function used to skip: no RSA, no more than fourteen days of validity, and
/// valid right now.
void _verifyRawCerts(List<Uint8List> chain, List<Uint8List> certHashes) {
  final digests = <Uint8List>[];
  for (final pinned in certHashes) {
    final decoded = multihash.decode(pinned);
    if (decoded.code != Golang.Uint64(multihash.sha2_256)) continue;
    digests.add(Uint8List.fromList(decoded.digest));
  }
  wtcrypto.verifyRawCerts(chain, digests);
}

/// Receives the peer's `webtransport_certhashes` Noise extension and checks
/// that every hash this side dialled with is among them.
///
/// Go: the closure `transport.upgrade` builds `newEarlyDataReceiver` with.
class _CertHashesReceiver implements noise.NoiseEarlyDataHandler {
  _CertHashesReceiver(this._dialled);

  final List<Uint8List> _dialled;

  /// Whether the peer's hashes arrived and covered every dialled hash.
  bool verified = false;

  @override
  NoiseExtensions? send(RawConn insecure, PeerId remote) => null;

  @override
  Future<void> received(RawConn insecure, NoiseExtensions? extensions) async {
    final received = extensions?.webtransportCerthashes ?? const <Uint8List>[];
    for (final sent in _dialled) {
      // Decoding both sides keeps the comparison on (code, digest) rather than
      // on an encoding that could differ byte-for-byte for the same hash.
      final want = multihash.decode(sent);
      final found = received.any((raw) {
        try {
          final got = multihash.decode(raw);
          return got.code == want.code && _sameBytes(got.digest, want.digest);
        } on FormatException {
          return false;
        }
      });
      if (!found) {
        throw FormatException('missing cert hash: ${_hex(sent)}');
      }
    }
    verified = true;
  }
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Presents one WebTransport session stream as the raw connection a security
/// transport upgrades.
///
/// Go: `webtransportStream` (`stream.go`), which adapts a
/// `webtransport.Stream` to `net.Conn` so `noise.SecureOutbound` can run on it.
class _SessionRawConn implements RawConn {
  _SessionRawConn({
    required Transport transport,
    required webtransport.SessionStream stream,
    required Multiaddr localMultiaddr,
    required Multiaddr remoteMultiaddr,
  }) : _transport = transport,
       _stream = stream,
       _localMultiaddr = localMultiaddr,
       _remoteMultiaddr = remoteMultiaddr;

  final Transport _transport;
  final webtransport.SessionStream _stream;
  final Multiaddr _localMultiaddr;
  final Multiaddr _remoteMultiaddr;
  final BytesBuilder _surplus = BytesBuilder(copy: false);
  bool _closed = false;

  @override
  Transport transport() => _transport;

  @override
  Multiaddr localMultiaddr() => _localMultiaddr;

  @override
  Multiaddr remoteMultiaddr() => _remoteMultiaddr;

  @override
  bool get isClosed => _closed;

  @override
  Future<Uint8List> read([int? maxLength]) async {
    if (_surplus.isEmpty) {
      if (_closed) return Uint8List(0);
      _surplus.add(await _stream.read());
    }
    final available = _surplus.takeBytes();
    if (maxLength == null || maxLength <= 0 || available.length <= maxLength) {
      return available;
    }
    _surplus.add(Uint8List.sublistView(available, maxLength));
    return Uint8List.sublistView(available, 0, maxLength);
  }

  @override
  Future<void> write(Uint8List data) async {
    if (_closed) throw StateError('Stream is closed');
    _stream.write(data);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _stream.closeWrite();
  }
}

/// A libp2p connection carried by a WebTransport session.
///
/// WebTransport multiplexes natively, so a libp2p stream *is* a session
/// stream: no yamux frame sits in between. Go: `conn` (`conn.go`).
class _WebtransportSessionConn implements CapableConn {
  _WebtransportSessionConn({
    required Transport transport,
    required webtransport.Session session,
    required PeerId localPeer,
    required PeerId remotePeer,
    required PubKey remotePubKey,
    required Multiaddr localMultiaddr,
    required Multiaddr remoteMultiaddr,
    required Direction direction,
  }) : _transport = transport,
       _session = session,
       _localPeer = localPeer,
       _remotePeer = remotePeer,
       _remotePubKey = remotePubKey,
       _localMultiaddr = localMultiaddr,
       _remoteMultiaddr = remoteMultiaddr,
       _direction = direction,
       _opened = DateTime.now();

  final Transport _transport;
  final webtransport.Session _session;
  final PeerId _localPeer;
  final PeerId _remotePeer;
  final PubKey _remotePubKey;
  final Multiaddr _localMultiaddr;
  final Multiaddr _remoteMultiaddr;
  final Direction _direction;
  final DateTime _opened;
  int _numStreams = 0;

  @override
  Transport transport() => _transport;

  @override
  PeerId localPeer() => _localPeer;

  @override
  PeerId remotePeer() => _remotePeer;

  @override
  PubKey remotePublicKey() => _remotePubKey;

  @override
  Multiaddr localMultiaddr() => _localMultiaddr;

  @override
  Multiaddr remoteMultiaddr() => _remoteMultiaddr;

  @override
  bool get isClosed => _session.isClosed;

  @override
  ConnectionState connState() => const ConnectionState(
    streamMultiplexer: 'webtransport',
    security: noise.ID,
    transport: 'webtransport',
  );

  @override
  ConnStats stat() => ConnStats(
    direction: _direction,
    opened: _opened,
    numStreams: _numStreams,
  );

  @override
  ConnScope scope() => const NullScope();

  @override
  Future<MuxedStream> openStream() async {
    _numStreams++;
    return _WebtransportSessionStream(stream: _session.openStream());
  }

  @override
  Future<MuxedStream> acceptStream() async {
    final stream = await _session.acceptStream();
    _numStreams++;
    return _WebtransportSessionStream(stream: stream);
  }

  @override
  Future<void> close() => _session.close();

  /// `webtransport.Session.close` (`transpiled_webtransport_go`'s
  /// `session.dart:149-161`) always tears down the underlying QUIC
  /// connection with error code `0` and carries no parameter to send a
  /// different one, so there is nothing here to forward [errorCode] to; this
  /// degrades to a plain close exactly as upstream's fallback describes for
  /// transports that cannot signal an error code (`core/network/conn.go:72-74`).
  @override
  Future<void> closeWithError(ConnErrorCode errorCode) => close();
}

/// Adapts a WebTransport session stream to libp2p's [MuxedStream].
///
/// The libp2p-level identity (id, protocol, stat, scope, owning [Conn]) is
/// not this type's concern -- it belongs to the [NetworkStream] that wraps
/// it, i.e. `SwarmStream`, exactly as upstream's `network.MuxedStream` has
/// none of it either (`core/network/mux.go:33-71`).
class _WebtransportSessionStream implements MuxedStream {
  _WebtransportSessionStream({required webtransport.SessionStream stream})
    : _stream = stream;

  final webtransport.SessionStream _stream;
  final BytesBuilder _surplus = BytesBuilder(copy: false);
  bool _closed = false;

  @override
  bool get isClosed => _closed;

  @override
  Future<Uint8List> read([int? maxLength]) async {
    if (_surplus.isEmpty) {
      if (_closed) return Uint8List(0);
      try {
        _surplus.add(await _stream.read());
      } on quicgo.ConnectionClosedException {
        return Uint8List(0);
      } on quicgo.StreamResetException {
        return Uint8List(0);
      } on webtransport.SessionClosedException {
        return Uint8List(0);
      }
    }
    final available = _surplus.takeBytes();
    if (maxLength == null || maxLength <= 0 || available.length <= maxLength) {
      return available;
    }
    _surplus.add(Uint8List.sublistView(available, maxLength));
    return Uint8List.sublistView(available, 0, maxLength);
  }

  @override
  Future<void> write(Uint8List data) async {
    if (_closed) throw StateError('Stream is closed');
    _stream.write(data);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _stream.closeWrite();
  }

  @override
  Future<void> reset() async {
    _closed = true;
    _stream.reset();
  }

  @override
  Future<void> closeRead() async {}

  @override
  Future<void> closeWrite() async => _stream.closeWrite();

  @override
  Future<void> resetWithError(StreamErrorCode errorCode) async {
    _closed = true;
    _stream.reset(errorCode);
  }

  @override
  Future<void> setDeadline(DateTime? time) async {}

  @override
  Future<void> setReadDeadline(DateTime? time) async {}

  @override
  Future<void> setWriteDeadline(DateTime? time) async {}
}
