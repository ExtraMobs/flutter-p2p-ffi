// Port of github.com/pion/transport/v4/net.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md) -- PARTIAL, by design.
//
// Upstream declares one `Net` interface with ~15 methods (Dial, DialUDP,
// DialTCP, ListenPacket, ListenUDP, ListenTCP, ResolveIPAddr,
// ResolveUDPAddr, ResolveTCPAddr, Interfaces, InterfaceByIndex,
// InterfaceByName, CreateDialer, CreateListenConfig), plus the ~15-method
// `UDPConn`, ~9-method `TCPConn`, `TCPListener`, `Dialer`, `ListenConfig` and
// `Interface` types it returns. Per this project's rule against inventing
// unused public API (Rule 12) and the explicit project instruction to port
// only what real consumers call rather than the full stdlib-`net` mirror,
// this file ports only the two `Net` members, and the two supporting types,
// that the locked revisions of `pion/stun` and `pion/dtls` actually invoke:
//
// - `Net.Dial` (net.go:127) -- called as `nw.Dial(...)` at
//   pion-stun/client.go:64,74,100. Its return value (`net.Conn`) is only
//   ever used through `pion-stun/client.go:264`'s own `Connection` interface
//   (`io.Reader`, `io.Writer`, `io.Closer`), so [NetConn] below ports exactly
//   that: `read`, `write`, `close`. Every other `net.Conn` member
//   (LocalAddr, RemoteAddr, SetDeadline, SetReadDeadline, SetWriteDeadline)
//   is not exercised by any call this project can point to and is left out.
// - `Net.DialUDP` (net.go:136) -- called as `nw.DialUDP(...)` at
//   pion-stun/client.go:87. Its return value's only member called directly
//   by stun is `.RemoteAddr()` (client.go:96); the very same value is then
//   handed to `dtls.Client(udpConn, ...)`, which (per
//   pion-dtls/conn.go:65,222) wraps it in `netctx.NewPacketConn`
//   (lib/src/netctx.dart in this port) -- and netctx's own implementation
//   (packetconn.go) calls exactly `Close`, `LocalAddr`, `ReadFrom`, `WriteTo`
//   on that wrapped value. [UdpConn] below ports the union of those two call
//   sets: `close`, `localAddr`, `remoteAddr`, `readFrom`, `writeTo`. Go's
//   `SetReadDeadline`/`SetWriteDeadline` (used upstream only so netctx can
//   force-unblock an in-flight blocking read/write on context cancellation)
//   are dropped: this port's [readFrom]/[writeTo] are already
//   `Future`-returning, non-blocking-at-the-Dart-layer operations, so
//   lib/src/netctx.dart cancels a pending call by racing its `Future`
//   against the cancellation signal directly, with nothing left for a
//   deadline to force-unblock. `SetDeadline`/`SetReadBuffer`/`SetWriteBuffer`
//   /`Read`/`Write`/`ReadFromUDP`/`ReadMsgUDP`/`WriteToUDP`/`WriteMsgUDP` are
//   never called by any real consumer and are left out entirely.
//
// Every other `Net` member (`DialTCP`, `ListenPacket`, `ListenUDP`,
// `ListenTCP`, `ResolveIPAddr`, `ResolveUDPAddr`, `ResolveTCPAddr`,
// `Interfaces`, `InterfaceByIndex`, `InterfaceByName`, `CreateDialer`,
// `CreateListenConfig`) and every other declared type (`TCPConn`,
// `TCPListener`, `Dialer`, `ListenConfig`, `Interface`) is NOT ported: no
// call site in the locked `pion/stun` or `pion/dtls` revisions reaches them.
// If a future consumer needs one, port it then, against that consumer's real
// call site, rather than here speculatively.
import 'dart:io';
import 'dart:typed_data';

/// Port of the Go stdlib `net.Addr` interface (referenced throughout
/// net.go), narrowed to the one member this port's consumers observe: the
/// address family/network name. `Addr.String()` (the other `net.Addr`
/// member) maps to Dart's built-in [Object.toString]; every implementer of
/// this interface must override it.
abstract interface class NetAddr {
  /// Port of `Addr.Network() string`.
  String get network;
}

/// Port of the Go stdlib `net.UDPAddr` struct, the concrete [NetAddr] used
/// wherever `pion/transport/v4`'s `Net` interface exchanges UDP endpoints
/// (`DialUDP`'s `laddr`/`raddr` parameters, [UdpConn.localAddr] and
/// [UdpConn.remoteAddr]).
final class UdpAddr implements NetAddr {
  /// Creates a UDP address. Port of the Go struct literal
  /// `net.UDPAddr{IP: ip, Port: port, Zone: zone}`.
  const UdpAddr(this.address, this.port, [this.zone = '']);

  /// Port of `UDPAddr.IP`.
  final InternetAddress address;

  /// Port of `UDPAddr.Port`.
  final int port;

  /// Port of `UDPAddr.Zone` (IPv6 zone identifier; empty for IPv4 or an
  /// unzoned IPv6 address).
  final String zone;

  @override
  String get network => 'udp';

  /// Port of `UDPAddr.String()`.
  @override
  String toString() =>
      zone.isEmpty ? '${address.address}:$port' : '${address.address}%$zone:$port';

  @override
  bool operator ==(Object other) =>
      other is UdpAddr &&
      other.address == address &&
      other.port == port &&
      other.zone == zone;

  @override
  int get hashCode => Object.hash(address, port, zone);
}

/// Port of the subset of the Go stdlib `net.Conn` interface that
/// `pion-stun/client.go:264`'s own `Connection` interface
/// (`io.Reader`+`io.Writer`+`io.Closer`) actually requires from the value
/// `Net.Dial` returns. See the file-level doc comment for why the rest of
/// `net.Conn` (LocalAddr, RemoteAddr, SetDeadline, SetReadDeadline,
/// SetWriteDeadline) is not ported.
abstract interface class NetConn {
  /// Port of `io.Reader.Read`. Reads up to `buffer.length` bytes, returning
  /// the number of bytes actually read (which may be less than
  /// `buffer.length`, mirroring Go's partial-read contract); returns 0 at
  /// end of stream instead of Go's `(0, io.EOF)` pair, since EOF is not an
  /// error condition worth a thrown exception here and no consumer in this
  /// port's scope distinguishes it.
  Future<int> read(Uint8List buffer);

  /// Port of `io.Writer.Write`. Writes `buffer` and returns the number of
  /// bytes written.
  Future<int> write(Uint8List buffer);

  /// Port of `io.Closer.Close`.
  Future<void> close();
}

/// Port of the subset of `transport.UDPConn` (net.go:231) actually called:
/// directly by `pion-stun/client.go:96` (`.RemoteAddr()`), and by
/// `lib/src/netctx.dart`'s port of `netctx.packetConn`, which needs exactly
/// `Close`, `LocalAddr`, `ReadFrom`, `WriteTo` from the connection it wraps.
/// See the file-level doc comment for the full accounting of what upstream's
/// ~15-method `UDPConn` declares and why the rest is not ported.
abstract interface class UdpConn {
  /// Port of `UDPConn.Close`.
  Future<void> close();

  /// Port of `UDPConn.LocalAddr`.
  NetAddr get localAddr;

  /// Port of `UDPConn.RemoteAddr`.
  NetAddr get remoteAddr;

  /// Port of `UDPConn.ReadFrom`. Returns the number of bytes copied into
  /// [buffer] and the address the packet arrived from.
  Future<(int, NetAddr)> readFrom(Uint8List buffer);

  /// Port of `UDPConn.WriteTo`. Returns the number of bytes written.
  Future<int> writeTo(Uint8List buffer, NetAddr addr);
}

/// Port of the two `Net` interface (net.go:29) members real consumers call.
/// See the file-level doc comment for the full accounting of what upstream's
/// ~15-method interface declares and why only these two are ported.
abstract interface class Net {
  /// Port of `Net.Dial` (net.go:127). `network` is `"tcp"`/`"tcp4"`/`"tcp6"`
  /// or `"udp"`/`"udp4"`/`"udp6"`; `address` is `"host:port"`.
  Future<NetConn> dial(String network, String address);

  /// Port of `Net.DialUDP` (net.go:136). Unlike the Go signature, [remoteAddr]
  /// is non-nullable here: every real call site
  /// (`pion-stun/client.go:87`, `nw.DialUDP("udp", nil, udpAddr)`) passes a
  /// destination, and Go's own `net.DialUDP` has no defined behavior for a
  /// nil `raddr` either -- dialing requires somewhere to dial.
  Future<UdpConn> dialUdp(String network, UdpAddr? localAddr, UdpAddr remoteAddr);
}
