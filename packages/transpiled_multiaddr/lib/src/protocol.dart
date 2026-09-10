// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/multiaddr/protocol.dart
//
// Port of go-multiaddr's Protocol/Transcoder types and protocol registry
// (github.com/multiformats/go-multiaddr protocol.go + protocols.go).
// Protocol codes and sizes are copied verbatim from that file so wire
// encoding stays byte-compatible with real libp2p peers.
import 'dart:typed_data';

import 'transcoders.dart';

/// Marker for [Protocol.size]: the value is a varint-length-prefixed byte
/// string rather than a fixed bit width. Equivalent to go-multiaddr's
/// `LengthPrefixedVarSize` (-1).
const int kLengthPrefixedVarSize = -1;

/// Encodes/decodes/validates one protocol's component value. Equivalent to
/// go-multiaddr's `Transcoder` interface.
class Transcoder {
  /// Builds a transcoder from its string/bytes conversion functions and an
  /// optional validator.
  const Transcoder(this.stringToBytes, this.bytesToString, [this.validate]);

  /// Parses a component's string-form value into its wire bytes. Throws
  /// [FormatException] on invalid input.
  final Uint8List Function(String) stringToBytes;

  /// Renders a component's wire bytes as its string-form value.
  final String Function(Uint8List) bytesToString;

  /// Throws [FormatException] if [bytes] is not a valid encoded value.
  /// `null` means "always valid" (matches go-multiaddr's nil ValidateBytes).
  final void Function(Uint8List bytes)? validate;

  /// Runs [validate] on [bytes], if set; a no-op otherwise.
  void validateBytes(Uint8List bytes) => validate?.call(bytes);
}

/// A multiaddr protocol descriptor. Equivalent to go-multiaddr's `Protocol`
/// struct.
class Protocol {
  /// Describes one protocol's wire encoding.
  const Protocol({
    required this.name,
    required this.code,
    required this.size,
    this.path = false,
    this.transcoder,
  });

  /// The protocol's canonical name, e.g. `ip4`, `tcp`, `p2p`.
  final String name;

  /// The multicodec code identifying this protocol on the wire.
  final int code;

  /// Value width in bits. `0` = no value (flag protocol). Negative
  /// ([kLengthPrefixedVarSize]) = varint-length-prefixed. Positive = fixed
  /// bit width (e.g. 32 for ip4).
  final int size;

  /// Whether this is a terminal "path" protocol (e.g. `unix`) that consumes
  /// the rest of the multiaddr string as its value.
  final bool path;

  /// This protocol's value transcoder, or `null` for a flag protocol
  /// ([size] `0`) that carries no value.
  final Transcoder? transcoder;

  /// Whether this protocol's value is varint-length-prefixed rather than a
  /// fixed byte width.
  bool get isVariableSize => size < 0;
}

/// Registry of standard multiaddr protocols, mirroring go-multiaddr's
/// `P_*` code constants and `protocols.go` init table. Each constant below
/// is that protocol's multicodec code.
class Protocols {
  /// Not instantiable; every member is static.
  Protocols._();

  /// IPv4 address.
  static const ip4 = 4;

  /// TCP port.
  static const tcp = 6;

  /// DNS name resolving to either an A or AAAA record.
  static const dns = 53;

  /// DNS name resolving to an A record.
  static const dns4 = 54;

  /// DNS name resolving to an AAAA record.
  static const dns6 = 55;

  /// DNS TXT record listing further multiaddrs (bootstrap-style).
  static const dnsaddr = 56;

  /// UDP port.
  static const udp = 273;

  /// DCCP port.
  static const dccp = 33;

  /// IPv6 address.
  static const ip6 = 41;

  /// IPv6 zone (scope) id.
  static const ip6zone = 42;

  /// CIDR prefix length applied to a preceding IP address.
  static const ipcidr = 43;

  /// QUIC (pre-v1, draft versions).
  static const quic = 460;

  /// QUIC over TLS 1.3, RFC 9001.
  static const quicV1 = 461;

  /// WebTransport, layered over [quicV1].
  static const webtransport = 465;

  /// TLS/Noise certificate hash, used with [webtransport].
  static const certhash = 466;

  /// SCTP port.
  static const sctp = 132;

  /// Circuit Relay v2 (`/p2p-circuit`).
  static const circuit = 290;

  /// Deprecated UDP-based transport.
  static const udt = 301;

  /// Deprecated uTorrent transport protocol.
  static const utp = 302;

  /// Unix domain socket path.
  static const unix = 400;

  /// libp2p PeerId.
  static const p2p = 421;

  /// Alias for [p2p], kept for backwards compatibility (same code).
  static const ipfs = p2p;

  /// HTTP.
  static const http = 480;

  /// A URL path, for use after [http]/[https].
  static const httpPath = 481;

  /// Deprecated alias for `/tls/http`.
  static const https = 443;

  /// Tor v2 onion address (deprecated by the Tor network itself).
  static const onion = 444;

  /// Tor v3 onion address.
  static const onion3 = 445;

  /// I2P destination, base64-encoded.
  static const garlic64 = 446;

  /// I2P destination, base32-encoded.
  static const garlic32 = 447;

  /// Deprecated; use [webrtcDirect] instead.
  static const p2pWebRtcDirect = 276;

  /// TLS.
  static const tls = 448;

  /// TLS/QUIC Server Name Indication hostname.
  static const sni = 449;

  /// Noise transport security handshake.
  static const noise = 454;

  /// WebSocket.
  static const ws = 477;

  /// Deprecated alias for `/tls/ws`.
  static const wss = 478;

  /// Deprecated plaintext transport security (multistream v2 negotiation).
  static const plaintextv2 = 7367777;

  /// WebRTC with an out-of-band signaling channel.
  static const webrtcDirect = 280;

  /// Browser-to-browser WebRTC.
  static const webrtc = 281;

  /// In-process transport, addressed by an opaque 64-bit id.
  static const memory = 777;

  /// All registered protocols, in go-multiaddr's `init()` registration
  /// order. This is the single source of truth; [byName]/[byCode] are
  /// derived from it.
  static const List<Protocol> all = [
    Protocol(name: 'ip4', code: ip4, size: 32, transcoder: transcoderIP4),
    Protocol(name: 'tcp', code: tcp, size: 16, transcoder: transcoderPort),
    Protocol(
      name: 'dns',
      code: dns,
      size: kLengthPrefixedVarSize,
      transcoder: transcoderDns,
    ),
    Protocol(
      name: 'dns4',
      code: dns4,
      size: kLengthPrefixedVarSize,
      transcoder: transcoderDns,
    ),
    Protocol(
      name: 'dns6',
      code: dns6,
      size: kLengthPrefixedVarSize,
      transcoder: transcoderDns,
    ),
    Protocol(
      name: 'dnsaddr',
      code: dnsaddr,
      size: kLengthPrefixedVarSize,
      transcoder: transcoderDns,
    ),
    Protocol(name: 'udp', code: udp, size: 16, transcoder: transcoderPort),
    Protocol(name: 'dccp', code: dccp, size: 16, transcoder: transcoderPort),
    Protocol(name: 'ip6', code: ip6, size: 128, transcoder: transcoderIP6),
    Protocol(
      name: 'ip6zone',
      code: ip6zone,
      size: kLengthPrefixedVarSize,
      transcoder: transcoderIP6Zone,
    ),
    Protocol(
      name: 'ipcidr',
      code: ipcidr,
      size: 8,
      transcoder: transcoderIPCIDR,
    ),
    Protocol(name: 'sctp', code: sctp, size: 16, transcoder: transcoderPort),
    Protocol(name: 'p2p-circuit', code: circuit, size: 0),
    Protocol(
      name: 'onion',
      code: onion,
      size: 96,
      transcoder: transcoderOnion,
    ),
    Protocol(
      name: 'onion3',
      code: onion3,
      size: 296,
      transcoder: transcoderOnion3,
    ),
    Protocol(
      name: 'garlic64',
      code: garlic64,
      size: kLengthPrefixedVarSize,
      transcoder: transcoderGarlic64,
    ),
    Protocol(
      name: 'garlic32',
      code: garlic32,
      size: kLengthPrefixedVarSize,
      transcoder: transcoderGarlic32,
    ),
    Protocol(name: 'utp', code: utp, size: 0),
    Protocol(name: 'udt', code: udt, size: 0),
    Protocol(name: 'quic', code: quic, size: 0),
    Protocol(name: 'quic-v1', code: quicV1, size: 0),
    Protocol(name: 'webtransport', code: webtransport, size: 0),
    Protocol(
      name: 'certhash',
      code: certhash,
      size: kLengthPrefixedVarSize,
      transcoder: transcoderCertHash,
    ),
    Protocol(name: 'http', code: http, size: 0),
    Protocol(
      name: 'http-path',
      code: httpPath,
      size: kLengthPrefixedVarSize,
      transcoder: transcoderHTTPPath,
    ),
    Protocol(name: 'https', code: https, size: 0),
    Protocol(
      name: 'p2p',
      code: p2p,
      size: kLengthPrefixedVarSize,
      transcoder: transcoderP2P,
    ),
    Protocol(
      name: 'unix',
      code: unix,
      size: kLengthPrefixedVarSize,
      path: true,
      transcoder: transcoderUnix,
    ),
    Protocol(name: 'p2p-webrtc-direct', code: p2pWebRtcDirect, size: 0),
    Protocol(name: 'tls', code: tls, size: 0),
    Protocol(
      name: 'sni',
      code: sni,
      size: kLengthPrefixedVarSize,
      transcoder: transcoderDns,
    ),
    Protocol(name: 'noise', code: noise, size: 0),
    Protocol(name: 'ws', code: ws, size: 0),
    Protocol(name: 'wss', code: wss, size: 0),
    Protocol(name: 'plaintextv2', code: plaintextv2, size: 0),
    Protocol(name: 'webrtc-direct', code: webrtcDirect, size: 0),
    Protocol(name: 'webrtc', code: webrtc, size: 0),
    Protocol(
      name: 'memory',
      code: memory,
      size: 64,
      transcoder: transcoderMemory,
    ),
  ];

  static final Map<String, Protocol> _byName = {
    for (final p in all) p.name: p,
    // go-multiaddr explicitly registers "ipfs" as a name alias for "p2p".
    'ipfs': all.firstWhere((p) => p.code == p2p),
  };

  static final Map<int, Protocol> _byCode = {for (final p in all) p.code: p};

  /// Looks up a protocol by its string name (e.g. `ip4`), or `null` if
  /// unknown.
  static Protocol? byName(String name) => _byName[name];

  /// Looks up a protocol by its multicodec code, or `null` if unknown.
  static Protocol? byCode(int code) => _byCode[code];
}
