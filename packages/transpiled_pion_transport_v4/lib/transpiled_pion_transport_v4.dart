/// Port of `github.com/pion/transport/v4` (revision fixed in
/// doc/transpilation/UPSTREAM_LOCK.md).
///
/// Only the subpackages actually consumed by `pion/stun` and `pion/dtls`
/// (this project's real, upcoming consumers of this module) are ported
/// here: `deadline` (dtls `conn.go:25`, `internal/net/buffer.go:23`,
/// `internal/net/udp/packet_conn.go:29`), `replaydetector` (dtls
/// `conn.go:27`, `state.go:16`), `utils/xor` (stun `xoraddr.go:13`),
/// `netctx` (dtls `conn.go:26,222`), `stdnet` (stun `client.go:20-21,54`)
/// and the root `Net`/`UDPConn`/`NetAddr` types of `net.go` (stun
/// `client.go:20,43,52-100`).
///
/// `netctx`, `stdnet` and `net.go` are ported PARTIALLY, by design: each of
/// `lib/src/net.dart`, `lib/src/netctx.dart` and `lib/src/stdnet.dart`
/// carries a file-level doc comment accounting for exactly which members of
/// the corresponding upstream type were ported (with the real `pion/stun`
/// or `pion/dtls` call site that justifies each one) and which were left
/// out because no locked-revision call site reaches them -- rather than
/// mirroring Go's full stdlib-`net`-shaped surface (`Net` alone declares
/// ~15 methods, `UDPConn` ~15 more, plus `TCPConn`/`TCPListener`/`Dialer`
/// /`ListenConfig`/`Interface`) speculatively.
///
/// `vnet` (network simulator for pion's own tests), `packetio`, `udp`,
/// `dpipe` and `reuseport` are out of scope entirely: no real consumer
/// imports them.
library;

export 'src/deadline.dart' show Deadline, DeadlineExceededException;
export 'src/net.dart' show Net, NetAddr, NetConn, UdpAddr, UdpConn;
export 'src/netctx.dart' show ClosingException, PacketConn;
export 'src/replaydetector.dart' show ReplayDetector;
export 'src/stdnet.dart' show StdNet;
export 'src/xor.dart' show xorBytes;
