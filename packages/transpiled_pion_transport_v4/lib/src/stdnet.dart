// Port of github.com/pion/transport/v4/stdnet/net.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md) -- PARTIAL, by design.
//
// Upstream's `stdnet.Net` implements the full `transport.Net` interface by
// forwarding to Go's real `net` package (Dial, DialUDP, DialTCP,
// ListenPacket, ListenUDP, ListenTCP, ResolveIPAddr, ResolveUDPAddr,
// ResolveTCPAddr, Interfaces, InterfaceByIndex, InterfaceByName,
// CreateDialer, CreateListenConfig). Per net.dart's file-level doc comment,
// this port's [Net] (renamed from Go's `Net` to [StdNet]; see below) only
// needs to implement [transport_net.Net]'s two ported members, [dial] and
// [dialUdp] -- the only two the locked `pion/stun`/`pion/dtls` revisions
// call (`pion-stun/client.go:64,74,87,100`). Every other upstream member is
// left out for the same reason net.dart leaves the matching interface
// members out; see that file for the full accounting.
//
// Go's `NewNet()` (stdnet/net.go:29-33) also eagerly calls
// `UpdateInterfaces()`, which enumerates the host's network interfaces via
// the third-party `github.com/wlynxg/anet` package solely to populate
// `Interfaces`/`InterfaceByIndex`/`InterfaceByName` -- none of which any
// real consumer calls. Porting cross-platform OS interface enumeration for
// zero observable behavior is exactly the speculative work this pass was
// told to avoid, so this port's constructor does no such enumeration and
// cannot fail (Go's `NewNet` returns `(*Net, error)`; this port's
// constructor needs no error channel at all).
//
// Naming: Go disambiguates the `Net` interface (`transport.Net`, net.go:29)
// from this concrete implementation (`stdnet.Net`, stdnet/net.go:24) by
// package qualification -- two different types both named `Net` in two
// different packages. This port's single library/barrel has no such
// per-file namespace: exporting two public `Net` symbols from one barrel is
// a Dart compile error. Folding the Go package name into the Dart
// identifier (`StdNet`, i.e. `stdnet.Net`) is the same mechanical
// disambiguation this project already applies at import points for
// cross-module name collisions (AGENTS.md, "Suíte verde é a linha de base"
// section), just applied once here at definition time instead, since both
// names originate in this same Dart package.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'net.dart' as transport_net;

/// Concrete [transport_net.Net] over `dart:io` sockets. Port of `stdnet.Net`
/// (stdnet/net.go:22-25); see the file-level doc comment for the naming
/// rationale and the scope of what is/isn't ported.
class StdNet implements transport_net.Net {
  /// Port of `NewNet()` (stdnet/net.go:29-33), minus the interface
  /// enumeration described in the file-level doc comment.
  StdNet();

  /// Port of `Net.Dial` (stdnet/net.go:111-113), called as `nw.Dial(...)`
  /// at `pion-stun/client.go:64` (STUN scheme, `nw.Dial("udp", addr)`),
  /// `:74` (TURN scheme, `nw.Dial(network, addr)`) and `:100` (TURNS/STUNS
  /// over TCP, `nw.Dial("tcp", addr)`).
  @override
  Future<transport_net.NetConn> dial(String network, String address) async {
    final (host, port) = _splitHostPort(address);
    if (network.startsWith('tcp')) {
      return _TcpNetConn(await Socket.connect(host, port));
    }
    if (network.startsWith('udp')) {
      final peer = await _resolveOne(host);
      final socket = await RawDatagramSocket.bind(
        peer.type == InternetAddressType.IPv6
            ? InternetAddress.anyIPv6
            : InternetAddress.anyIPv4,
        0,
      );
      return _ConnectedUdpNetConn(socket, peer, port);
    }
    throw ArgumentError.value(network, 'network', 'unsupported network');
  }

  /// Port of `Net.DialUDP` (stdnet/net.go:116-118), called as
  /// `nw.DialUDP("udp", nil, udpAddr)` at `pion-stun/client.go:87` (TURNS
  /// over UDP scheme).
  ///
  /// Divergence documented in `_StdUdpConn` below: unlike a real OS-level
  /// connected UDP socket, [readFrom]/[writeTo] on the returned [UdpConn]
  /// are not restricted to [remoteAddr] -- see that class's doc comment.
  @override
  Future<transport_net.UdpConn> dialUdp(
    String network,
    transport_net.UdpAddr? localAddr,
    transport_net.UdpAddr remoteAddr,
  ) async {
    final socket = await RawDatagramSocket.bind(
      localAddr?.address ??
          (remoteAddr.address.type == InternetAddressType.IPv6
              ? InternetAddress.anyIPv6
              : InternetAddress.anyIPv4),
      localAddr?.port ?? 0,
    );
    return _StdUdpConn(socket, remoteAddr);
  }
}

(String, int) _splitHostPort(String address) {
  final idx = address.lastIndexOf(':');
  if (idx < 0) {
    throw FormatException('address missing port', address);
  }
  var host = address.substring(0, idx);
  final port = int.parse(address.substring(idx + 1));
  if (host.startsWith('[') && host.endsWith(']')) {
    host = host.substring(1, host.length - 1);
  }
  return (host, port);
}

Future<InternetAddress> _resolveOne(String host) async {
  final direct = InternetAddress.tryParse(host);
  if (direct != null) return direct;
  final results = await InternetAddress.lookup(host);
  if (results.isEmpty) {
    throw SocketException('could not resolve host: $host');
  }
  return results.first;
}

/// Buffers a `dart:io` byte [Stream] (a TCP [Socket]'s incoming side) so it
/// can be drained through repeated bounded [read] calls, matching the
/// partial-read contract of Go's `io.Reader`/`net.Conn.Read`, which
/// `dart:io`'s push-based `Stream<Uint8List>` does not offer directly.
class _ByteStreamReader {
  _ByteStreamReader(Stream<Uint8List> source) {
    _sub = source.listen(
      _onData,
      onDone: () {
        _done = true;
        _wake();
      },
      onError: (Object e) {
        _error = e;
        _wake();
      },
      cancelOnError: true,
    );
  }

  late final StreamSubscription<Uint8List> _sub;
  final List<int> _buffer = [];
  Completer<void>? _waiter;
  Object? _error;
  bool _done = false;

  void _onData(Uint8List chunk) {
    _buffer.addAll(chunk);
    _wake();
  }

  void _wake() {
    _waiter?.complete();
    _waiter = null;
  }

  Future<int> read(Uint8List dst) async {
    while (_buffer.isEmpty && !_done && _error == null) {
      final waiter = Completer<void>();
      _waiter = waiter;
      await waiter.future;
    }
    if (_buffer.isEmpty && _error != null) {
      final e = _error!;
      _error = null;
      throw e;
    }
    if (_buffer.isEmpty) return 0; // End of stream (Go's io.EOF).
    final n = _buffer.length < dst.length ? _buffer.length : dst.length;
    for (var i = 0; i < n; i++) {
      dst[i] = _buffer[i];
    }
    _buffer.removeRange(0, n);
    return n;
  }

  /// Stops consuming the socket and releases any reader blocked waiting for
  /// more data.
  ///
  /// Marking this done *before* cancelling the subscription is what lets a
  /// pending read terminate: once `_sub.cancel()` has run the stream's
  /// `onDone` can no longer fire, so a [Completer] parked by a waiting
  /// reader would never complete and the caller's `read` would hang
  /// forever. Go's `net.Conn` unblocks a concurrent `Read` when the
  /// connection is closed (returning "use of closed network connection"),
  /// and terminating the waiter here is this port's equivalent.
  Future<void> cancel() async {
    _done = true;
    _wake();
    await _sub.cancel();
  }
}

class _TcpNetConn implements transport_net.NetConn {
  _TcpNetConn(this._socket) : _reader = _ByteStreamReader(_socket);

  final Socket _socket;
  final _ByteStreamReader _reader;

  @override
  Future<int> read(Uint8List buffer) => _reader.read(buffer);

  @override
  Future<int> write(Uint8List buffer) {
    _socket.add(buffer);
    return Future.value(buffer.length);
  }

  @override
  Future<void> close() async {
    await _reader.cancel();
    await _socket.close();
  }
}

/// Queues incoming [Datagram]s off a [RawDatagramSocket]'s push-based
/// [RawSocketEvent] stream so they can be consumed one at a time through
/// [next], mirroring the pull-based shape of Go's blocking
/// `net.PacketConn.ReadFrom`.
class _DatagramQueue {
  _DatagramQueue(this._socket) {
    _sub = _socket.listen(
      _onEvent,
      onDone: () {
        _done = true;
        _wake();
      },
      onError: (Object e) {
        _error = e;
        _wake();
      },
      cancelOnError: true,
    );
  }

  final RawDatagramSocket _socket;
  late final StreamSubscription<RawSocketEvent> _sub;
  final List<Datagram> _queue = [];
  Completer<void>? _waiter;
  Object? _error;
  bool _done = false;

  void _onEvent(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket.receive();
      if (datagram != null) _queue.add(datagram);
    }
    _wake();
  }

  void _wake() {
    _waiter?.complete();
    _waiter = null;
  }

  Future<Datagram> next() async {
    while (_queue.isEmpty) {
      if (_error != null) {
        final e = _error!;
        _error = null;
        throw e;
      }
      if (_done) {
        throw const SocketException('socket closed');
      }
      final waiter = Completer<void>();
      _waiter = waiter;
      await waiter.future;
    }
    return _queue.removeAt(0);
  }

  /// Stops consuming the socket and releases any reader blocked waiting for
  /// more data.
  ///
  /// Marking this done *before* cancelling the subscription is what lets a
  /// pending read terminate: once `_sub.cancel()` has run the stream's
  /// `onDone` can no longer fire, so a [Completer] parked by a waiting
  /// reader would never complete and the caller's `read` would hang
  /// forever. Go's `net.Conn` unblocks a concurrent `Read` when the
  /// connection is closed (returning "use of closed network connection"),
  /// and terminating the waiter here is this port's equivalent.
  Future<void> cancel() async {
    _done = true;
    _wake();
    await _sub.cancel();
  }
}

/// [transport_net.NetConn] for `stdnet.Net.Dial`'s `"udp"` case, emulating
/// Go's connected-UDP `net.Conn` (`net.Dial("udp", addr)` internally
/// produces a `*net.UDPConn` bound to a fixed peer, so its OS-level `Read`
/// only ever returns data from that peer). `dart:io`'s `RawDatagramSocket`
/// has no OS-level "connect" for UDP, so [read] filters incoming datagrams
/// by source address/port itself, discarding any not from [_peerHost]:[_peerPort]
/// -- reproducing the same observable behavior an OS-connected socket gives
/// for free.
class _ConnectedUdpNetConn implements transport_net.NetConn {
  _ConnectedUdpNetConn(this._socket, this._peerHost, this._peerPort)
    : _queue = _DatagramQueue(_socket);

  final RawDatagramSocket _socket;
  final InternetAddress _peerHost;
  final int _peerPort;
  final _DatagramQueue _queue;

  @override
  Future<int> read(Uint8List buffer) async {
    while (true) {
      final datagram = await _queue.next();
      if (datagram.address == _peerHost && datagram.port == _peerPort) {
        final n = datagram.data.length < buffer.length
            ? datagram.data.length
            : buffer.length;
        buffer.setRange(0, n, datagram.data);
        return n;
      }
      // A real OS-level connected UDP socket never delivers a datagram from
      // a different peer; discard it and keep waiting for one that matches.
    }
  }

  @override
  Future<int> write(Uint8List buffer) =>
      Future.value(_socket.send(buffer, _peerHost, _peerPort));

  @override
  Future<void> close() async {
    await _queue.cancel();
    _socket.close();
  }
}

/// [transport_net.UdpConn] for `stdnet.Net.DialUDP`. Port of the value Go's
/// `net.DialUDP` returns, narrowed per net.dart's file-level doc comment to
/// [close]/[localAddr]/[remoteAddr]/[readFrom]/[writeTo].
///
/// Divergence: a real Go `net.DialUDP` result is OS-level connected, so
/// [readFrom]/[writeTo] on it are restricted to the dialed peer (indeed,
/// real Go returns `ErrWriteToConnected` if `WriteTo` is called on one at
/// all). This port does not reproduce that restriction: [readFrom] returns
/// whatever arrives on the bound socket and [writeTo] sends to whatever
/// [transport_net.NetAddr] is passed, from any peer/to any peer. Resolving
/// the exact Go behavior here would require deciding how the not-yet-ported
/// `pion/dtls` actually drives this value (it is handed to
/// `dtls.Client(udpConn, ...)`, which wraps it in `netctx.PacketConn` and
/// calls `ReadFrom`/`WriteTo` on it via `netctx.dart`'s port) -- out of this
/// pass's scope to resolve. This class still faithfully implements
/// `pion/transport/v4`'s own [UdpConn] contract; a future pass porting
/// `pion/dtls` should re-verify this narrowing against dtls's real usage.
class _StdUdpConn implements transport_net.UdpConn {
  _StdUdpConn(this._socket, this._remote) : _queue = _DatagramQueue(_socket);

  final RawDatagramSocket _socket;
  final transport_net.UdpAddr _remote;
  final _DatagramQueue _queue;

  @override
  transport_net.NetAddr get localAddr =>
      transport_net.UdpAddr(_socket.address, _socket.port);

  @override
  transport_net.NetAddr get remoteAddr => _remote;

  @override
  Future<void> close() async {
    await _queue.cancel();
    _socket.close();
  }

  @override
  Future<(int, transport_net.NetAddr)> readFrom(Uint8List buffer) async {
    final datagram = await _queue.next();
    final n = datagram.data.length < buffer.length
        ? datagram.data.length
        : buffer.length;
    buffer.setRange(0, n, datagram.data);
    return (n, transport_net.UdpAddr(datagram.address, datagram.port));
  }

  @override
  Future<int> writeTo(Uint8List buffer, transport_net.NetAddr addr) {
    if (addr is! transport_net.UdpAddr) {
      throw ArgumentError.value(addr, 'addr', 'must be a UdpAddr');
    }
    return Future.value(_socket.send(buffer, addr.address, addr.port));
  }
}
