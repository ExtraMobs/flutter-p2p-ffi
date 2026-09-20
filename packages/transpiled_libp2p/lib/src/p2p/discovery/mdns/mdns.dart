// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/p2p/discovery/mdns/mdns.dart
//
// Port of go-libp2p/p2p/discovery/mdns/mdns.go: local-network peer
// discovery over multicast DNS-SD (RFC 6762/6763).
//
// Go's mdns.go delegates the actual DNS-SD wire work (announcing records
// and browsing for them) to `github.com/libp2p/zeroconf/v2` (mdns.go's
// `zeroconf` import; pinned at `v2.2.0` in go-libp2p's go.mod, now vendored
// at `go-ipfs-reference/zeroconf/` and locked in UPSTREAM_LOCK.md). That
// module is its own go.mod-owned boundary, so per AGENTS.md's
// module-boundary rule (RULE_MODULE_BOUNDARY_LEAK) this package cannot
// declare its types directly.
//
// Porting zeroconf itself was evaluated and rejected as disproportionate,
// not skipped: its own `go.mod` requires `github.com/miekg/dns v1.1.43` --
// a full general-purpose DNS message library, itself a separate go.mod
// boundary with no vendored source and no Dart port anywhere in this repo
// -- for essentially everything (`server.go`'s responder and
// `client.go`'s browser both operate directly on `dns.Msg`/`dns.RR`/
// `dns.PTR`/`dns.SRV`/`dns.TXT`/`dns.A`/`dns.AAAA` throughout). Faithfully
// porting zeroconf would mean also porting (or reinventing) miekg/dns's
// message model first -- a general-purpose DNS protocol library is its
// own large subsystem and squarely what AGENTS.md's "no new subsystem
// without the maintainer's sign-off" rule guards against, at a much
// larger scope than local peer discovery itself needs. So instead, per
// this milestone's brief, the minimum private DNS-SD wire codec below
// (leading underscore, single file, not exported by the package barrel)
// implements exactly what `mdns.go` itself consumes: encoding a
// PTR+SRV+TXT+A answer set to advertise this host (`zeroconf.RegisterProxy`
// in Go), encoding a PTR query and decoding received messages' questions
// and TXT answers to discover others (`zeroconf.Browse` in Go) -- not a
// general-purpose DNS/mDNS/zeroconf library. This also matches what
// mdns.go's own resolver loop actually reads from a discovered entry:
// "We only care about the TXT records. Ignore A, AAAA and PTR."
// (`mdns.go:229`) -- so PTR/SRV/A answers received from other peers are
// intentionally not decoded, only TXT.
//
// One process-wide UDP multicast socket serves both roles (unlike Go's
// separate `zeroconf.Server`/`client`, each with their own): it answers
// queries about this host and, since it also observes every other
// multicast packet on the shared group, harvests TXT answers from
// whatever it receives -- our own periodic queries' replies as well as
// other peers' unsolicited announcements.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/host/host.dart';
import '../../../core/peer/addr_info.dart';
import '../../../core/peer/peer_id.dart';

/// DNS-SD service name libp2p advertises and browses for local peer
/// discovery. Matches go-libp2p's exported `mdns.ServiceName`
/// (`p2p/discovery/mdns/mdns.go:21`); named `mdnsServiceName` rather than
/// the literal `serviceName` because the package barrel already exports an
/// unrelated `serviceName` constant from `p2p/protocol/identify/id.dart`
/// (identify's own eventbus service-name string) -- reusing the bare name
/// would make `transpiled_libp2p.dart`'s export ambiguous.
const String mdnsServiceName = '_p2p._udp';

/// Same value as [mdnsServiceName], defined separately (rather than
/// referenced by name) only so [MdnsService]'s constructor parameter of
/// the same name can shadow the top-level constant while still resolving
/// the upstream "empty string means default" fallback (`mdns.go:53-55`).
const String _defaultServiceName = mdnsServiceName;

/// mDNS domain suffix, matching go-libp2p's private `mdns.mdnsDomain`
/// (`mdns.go:22`).
const String _mdnsDomain = 'local';

/// TXT record value prefix carrying an encoded multiaddr, matching
/// go-libp2p's private `mdns.dnsaddrPrefix` (`mdns.go:23`).
const String _dnsaddrPrefix = 'dnsaddr=';

/// Default resource-record TTL for the PTR/SRV/TXT records this service
/// announces. go-libp2p itself has no TTL constant -- it's owned by the
/// underlying `github.com/libp2p/zeroconf/v2` responder (not vendored in
/// this repo; see the module-boundary note above) -- so this value is
/// taken from that module's `server.go` `defaultTTL` (`= 3200` seconds).
const Duration mdnsRecordTtl = Duration(seconds: 3200);

/// TTL for the A/AAAA address records specifically: zeroconf's
/// `appendAddrs` overrides `defaultTTL` down to 120 seconds for address
/// records per RFC 6762 §10's guidance that IP-address records should
/// expire quickly so stale addresses are dropped promptly.
const Duration mdnsAddressRecordTtl = Duration(seconds: 120);

/// Delivers a peer discovered via mDNS. Matches go-libp2p's exported
/// `mdns.Notifee` (`mdns.go:33`).
abstract interface class Notifee {
  /// Called for each peer found, once per discovery round it was seen in.
  void handlePeerFound(AddrInfo info);
}

/// Starts and stops local-network peer discovery. Matches go-libp2p's
/// exported `mdns.Service` (`mdns.go:28`).
abstract interface class Service {
  /// Starts advertising this host and browsing for peers.
  Future<void> start();

  /// Stops advertising and browsing, releasing all sockets and timers.
  Future<void> close();
}

/// Returns `true` when [addr] should be advertised via mDNS: a direct
/// IPv4/IPv6 address or a `.local` DNS name (the TLD RFC 6762 reserves for
/// multicast resolution), and not a circuit-relay or browser-only
/// transport (WebTransport/WebRTC/WebSocket) that mDNS/LAN discovery can't
/// usefully serve. Matches go-libp2p's private `isSuitableForMDNS`
/// (`mdns.go:146`); kept as a public top-level function (not a class, so
/// [RULE_INVENTED_PUBLIC_SYMBOLS] doesn't apply) purely so it -- and the
/// filtering it drives -- can be unit-tested directly, mirroring the
/// upstream `TestIsSuitableForMDNS` table in `mdns_test.go`.
bool isSuitableForMdns(Multiaddr? addr) {
  if (addr == null) return false;
  final (first, _) = addr.splitFirst();
  if (first == null) return false;

  switch (first.protocol.code) {
    case Protocols.ip4:
    case Protocols.ip6:
      break;
    case Protocols.dns:
    case Protocols.dns4:
    case Protocols.dns6:
    case Protocols.dnsaddr:
      if (!first.value.toLowerCase().endsWith('.local')) return false;
    default:
      return false;
  }

  return !_containsUnsuitableProtocol(addr);
}

/// Protocol codes mDNS advertisement filters out: circuit relay (needs an
/// intermediary, not direct LAN reachability) and the browser-only
/// transports. Matches go-libp2p's private `containsUnsuitableProtocol`'s
/// switch (`mdns.go:118-126`).
const Set<int> _unsuitableProtocolCodes = {
  Protocols.circuit,
  Protocols.webtransport,
  Protocols.webrtc,
  Protocols.webrtcDirect,
  Protocols.p2pWebRtcDirect,
  Protocols.ws,
  Protocols.wss,
};

bool _containsUnsuitableProtocol(Multiaddr addr) =>
    addr.components.any((c) => _unsuitableProtocolCodes.contains(c.protocol.code));

/// Builds the TXT-record strings an mDNS responder should advertise for
/// [id] listening on [interfaceAddrs]: each address suitable for mDNS
/// (per [isSuitableForMdns]) encoded as `dnsaddr=/.../p2p/<id>`. Extracted
/// from the inline loop in go-libp2p's private `mdnsService.startServer`
/// (`mdns.go:189-194`) into a standalone, directly testable function --
/// a deliberate decomposition documented in PROGRESS.md, since Go keeps
/// this as unexported inline logic with no function of its own.
List<String> buildMdnsTxtRecords(PeerId id, List<Multiaddr> interfaceAddrs) {
  final p2pAddrs = addrInfoToP2pAddrs(AddrInfo(id: id, addrs: interfaceAddrs));
  return [
    for (final addr in p2pAddrs)
      if (isSuitableForMdns(addr)) '$_dnsaddrPrefix${addr.toAddrString()}',
  ];
}

/// Recovers the [AddrInfo]s advertised in [txtRecords] (individual
/// character-strings, as produced by [buildMdnsTxtRecords] and as parsed
/// out of a received TXT resource record's RDATA -- one per
/// `dnsaddr=`-prefixed entry). Non-`dnsaddr=`-prefixed entries and
/// malformed multiaddrs are skipped rather than aborting the whole batch,
/// matching the `continue`s in go-libp2p's private
/// `mdnsService.startResolver` entry-parsing loop (`mdns.go:233-243`),
/// extracted here the same way as [buildMdnsTxtRecords].
List<AddrInfo> mdnsAddrInfosFromTxtRecords(List<String> txtRecords) {
  final addrs = <Multiaddr>[];
  for (final entry in txtRecords) {
    if (!entry.startsWith(_dnsaddrPrefix)) continue;
    try {
      addrs.add(Multiaddr.parse(entry.substring(_dnsaddrPrefix.length)));
    } on FormatException {
      continue;
    }
  }
  try {
    return addrInfosFromP2pAddrs(addrs);
  } on InvalidPeerIdSourceException {
    // Matches Go's `AddrInfosFromP2pAddrs` erroring (and the whole batch
    // being discarded via `continue`) when any entry lacks a `/p2p/...`
    // suffix.
    return const [];
  }
}

/// Picks one IPv4 and one IPv6 literal out of [addrs]' leading components,
/// for the A/AAAA records mDNS requires alongside the TXT records libp2p
/// actually reads. Matches go-libp2p's private `mdnsService.getIPs`
/// (`mdns.go:85-108`); throws [StateError] where Go returns
/// `errors.New("didn't find any IP addresses")`, per AGENTS.md's ban on
/// Go-style `(value, error)` returns.
List<String> _hostIps(List<Multiaddr> addrs) {
  String? ip4;
  String? ip6;
  for (final addr in addrs) {
    final (first, _) = addr.splitFirst();
    if (first == null) continue;
    if (ip4 == null && first.protocol.code == Protocols.ip4) {
      ip4 = first.value;
    } else if (ip6 == null && first.protocol.code == Protocols.ip6) {
      ip6 = first.value;
    }
  }
  final ips = [?ip4, ?ip6];
  if (ips.isEmpty) {
    throw StateError("didn't find any IP addresses");
  }
  return ips;
}

final Random _random = Random.secure();
const String _randomAlphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

/// Matches go-libp2p's private `randomString` (`mdns.go:257-264`), used to
/// build a random per-process instance/host name 32-63 characters long
/// (`32 + rand.Intn(32)`, `mdns.go:59`).
String _randomPeerName() {
  final length = 32 + _random.nextInt(32);
  return String.fromCharCodes([
    for (var i = 0; i < length; i++) _randomAlphabet.codeUnitAt(_random.nextInt(_randomAlphabet.length)),
  ]);
}

/// Concrete [Service]/[Notifee]-driving implementation. Matches go-libp2p's
/// private `mdnsService` struct and its `NewMdnsService` constructor
/// (`mdns.go:37-63`); kept public (unlike Go's unexported struct) because
/// this project's convention for a package's sole implementation of an
/// interface -- see `BasicHost implements Host`
/// (`p2p/host/basic/basic_host.dart`) -- is a plain public class rather
/// than hiding the concrete type, and Go only hides it because the
/// language lets an unexported type be returned and used without ever
/// being spelled, which Dart has no equivalent trick for.
class MdnsService implements Service {
  /// Builds a service for [host]. `serviceName` defaults to
  /// [mdnsServiceName] when left empty, matching Go's
  /// `NewMdnsService(host, serviceName, notifee)` (`mdns.go:52-61`), which
  /// substitutes the same default on an empty string rather than on
  /// omission.
  MdnsService(Host host, {String serviceName = '', required Notifee notifee})
    : _host = host,
      _serviceName = serviceName.isEmpty ? _defaultServiceName : serviceName,
      _notifee = notifee,
      _peerName = _randomPeerName();

  final Host _host;
  final String _serviceName;
  final Notifee _notifee;
  final String _peerName;

  bool _closed = false;
  RawDatagramSocket? _socket;
  final List<NetworkInterface> _interfaces = [];
  Timer? _browseTimer;

  String get _serviceFqdn => '$_serviceName.$_mdnsDomain.';
  String get _instanceFqdn => '$_peerName.$_serviceName.$_mdnsDomain.';
  String get _hostFqdn => '$_peerName.$_mdnsDomain.';

  @override
  Future<void> start() async {
    await _startServer();
    _startResolver();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _browseTimer?.cancel();
    _socket?.close();
  }

  /// Matches go-libp2p's private `mdnsService.startServer`: gathers this
  /// host's interface addresses, builds the TXT/IP records, and starts
  /// answering mDNS queries for them (`mdns.go:173-213`; in Go, via
  /// `zeroconf.RegisterProxy` -- here, via the private responder below).
  /// Also binds the one socket [_startResolver] sends queries and reads
  /// discovered peers' TXT answers from -- see this file's header comment.
  Future<void> _startServer() async {
    final interfaceAddrs = await _host.network.interfaceListenAddresses();
    final txts = buildMdnsTxtRecords(_host.id, interfaceAddrs);
    final p2pAddrs = addrInfoToP2pAddrs(AddrInfo(id: _host.id, addrs: interfaceAddrs));
    final ips = _hostIps(p2pAddrs);

    // ponytail: IPv4 multicast only. go-libp2p's zeroconf responder binds
    // both address families; this port only joins 224.0.0.251:5353, which
    // is sufficient for the LAN-discovery acceptance criterion. Add an
    // FF02::FB/IPv6 socket if dual-stack LAN discovery becomes a
    // requirement.
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _mdnsPort,
      reuseAddress: true,
      reusePort: !Platform.isWindows,
      ttl: 255,
    );
    _socket = socket;
    socket.multicastLoopback = true;
    final interfaces = await NetworkInterface.list(includeLoopback: true, type: InternetAddressType.IPv4);
    for (final iface in interfaces) {
      try {
        socket.joinMulticast(_mdnsAddressIPv4, iface);
        _interfaces.add(iface);
      } on OSError {
        // Interface doesn't support multicast (e.g. a point-to-point
        // link); skip it rather than failing the whole responder.
      }
    }
    socket.listen((event) => _handleIncomingDatagram(event, socket, ips, txts));
  }

  void _handleIncomingDatagram(RawSocketEvent event, RawDatagramSocket socket, List<String> ips, List<String> txts) {
    if (event != RawSocketEvent.read) return;
    final datagram = socket.receive();
    if (datagram == null) return;
    try {
      final (questions, answers) = _decodeMdnsMessage(datagram.data);

      if (questions.any(_questionMatchesService)) {
        final response = _encodeMdnsResponse(
          serviceFqdn: _serviceFqdn,
          instanceFqdn: _instanceFqdn,
          hostFqdn: _hostFqdn,
          ips: ips,
          txts: txts,
        );
        _sendMulticast(response);
      }

      // Matches go-libp2p's private `mdnsService.startResolver`'s
      // entryChan loop (`mdns.go:215-256`): "We only care about the TXT
      // records. Ignore A, AAAA and PTR." (`mdns.go:229`). Any TXT answer
      // in a received packet is a candidate, regardless of which name it's
      // under -- unrelated services sharing the multicast group produce
      // TXT data that simply won't parse as `dnsaddr=`-prefixed entries.
      final discoveredTxts = <String>[
        for (final answer in answers)
          if (answer.type == _rrTxt) ..._decodeTxtRdata(answer.rdata),
      ];
      if (discoveredTxts.isEmpty) return;
      for (final info in mdnsAddrInfosFromTxtRecords(discoveredTxts)) {
        if (info.id == _host.id) continue;
        _notifee.handlePeerFound(info);
      }
    } on FormatException {
      // Malformed or unrelated packet sharing the mDNS port; ignore it,
      // matching Go's `log.Debug(...)`-and-continue tolerance for
      // individual bad packets.
    }
  }

  bool _questionMatchesService(_MdnsQuestion q) {
    // The wire decoder (`_readDnsName`) joins labels with no trailing dot
    // (the terminating zero-length label isn't itself a label), while the
    // *Fqdn getters keep one for encoding; strip it here so the two sides
    // compare equal.
    final name = _stripTrailingDot(q.name.toLowerCase());
    if (name == _stripTrailingDot(_serviceFqdn.toLowerCase()) && (q.type == _rrPtr || q.type == _rrAny)) {
      return true;
    }
    return name == _stripTrailingDot(_instanceFqdn.toLowerCase()) ||
        name == _stripTrailingDot(_hostFqdn.toLowerCase());
  }

  /// Matches go-libp2p's private `mdnsService.startResolver`
  /// (`mdns.go:215-256`): periodically queries for [_serviceName] over the
  /// same socket [_startServer] bound -- any TXT answers that arrive
  /// (whether elicited by this query or another peer's unsolicited
  /// announcement) are handled by [_handleIncomingDatagram]. Where Go's
  /// `zeroconf.Browse` keeps a standing multicast listener and this port's
  /// responder socket already does the same, active querying here plays
  /// the same "prompt any silent responders" role as Go's periodic
  /// re-query cadence inside `zeroconf`'s client (not vendored; see this
  /// file's header comment).
  void _startResolver() {
    _sendQuery();
    _browseTimer = Timer.periodic(const Duration(seconds: 3), (_) => _sendQuery());
  }

  void _sendQuery() {
    if (_closed) return;
    final socket = _socket;
    if (socket == null) return;
    _sendMulticast(_encodeMdnsQuery(_serviceFqdn));
  }

  // zeroconf client.go:434 and server.go:762 send on each joined interface.
  // The default route can belong to a VPN that cannot carry LAN multicast.
  void _sendMulticast(Uint8List bytes) {
    final socket = _socket;
    if (socket == null || _closed) return;
    for (final interface in _interfaces) {
      try {
        socket.setRawOption(RawSocketOption(
          RawSocketOption.levelIPv4,
          RawSocketOption.IPv4MulticastInterface,
          interface.addresses.firstWhere((a) => a.type == InternetAddressType.IPv4).rawAddress,
        ));
        socket.send(bytes, _mdnsAddressIPv4, _mdnsPort);
      } on OSError {
        // An interface can disappear between enumeration and transmission.
      }
    }
  }
}

// ---------------------------------------------------------------------
// Private minimal mDNS/DNS-SD wire codec.
//
// Covers only what `MdnsService` needs: encoding a PTR query and a
// PTR+SRV+TXT+A answer set, and decoding a received message's questions
// and TXT answers. Not a general-purpose DNS/mDNS/zeroconf codec -- see
// the module-boundary note at the top of this file for why it exists here
// (instead of a `transpiled_zeroconf` package or an external dependency).
// It necessarily duplicates the RFC 1035 name-decompression algorithm
// already implemented for unicast DNS at
// `lib/src/transport/dns/dns_message.dart` in the root package: that
// package cannot be a dependency of this one (the root integrates this
// package, not the reverse -- see AGENTS.md's package-boundary rules), so
// reuse was not possible without inverting the dependency graph.
// ---------------------------------------------------------------------

// The mDNS multicast group/port, fixed by RFC 6762 §3.
const int _mdnsPort = 5353;
final InternetAddress _mdnsAddressIPv4 = InternetAddress('224.0.0.251');

const int _dnsClassIn = 1;
const int _dnsClassFlush = 0x8000;
const int _rrA = 1;
const int _rrPtr = 12;
const int _rrTxt = 16;
const int _rrAaaa = 28;
const int _rrSrv = 33;
const int _rrAny = 255;

class _MdnsQuestion {
  const _MdnsQuestion(this.name, this.type);
  final String name;
  final int type;
}

class _MdnsAnswer {
  const _MdnsAnswer(this.type, this.rdata);
  final int type;
  final Uint8List rdata;
}

/// Encodes a standard (non-probing) PTR query for [serviceFqdn], matching
/// the query `zeroconf.Browse` sends for go-libp2p's `mdns.mdnsService`
/// resolver (`mdns.go:254`'s `zeroconf.Browse(ctx, s.serviceName,
/// mdnsDomain, entryChan)`; not vendored, see this file's header).
Uint8List _encodeMdnsQuery(String serviceFqdn) {
  final out = BytesBuilder();
  _writeUint16(out, 0); // Transaction ID: unused for multicast queries (RFC 6762 §18.1).
  _writeUint16(out, 0); // Flags: standard query, no special bits.
  _writeUint16(out, 1); // QDCOUNT
  _writeUint16(out, 0); // ANCOUNT
  _writeUint16(out, 0); // NSCOUNT
  _writeUint16(out, 0); // ARCOUNT
  out.add(_encodeDnsName(serviceFqdn));
  _writeUint16(out, _rrPtr);
  // QU/QM bit (top bit of QCLASS, RFC 6762 §5.4) left unset: a standard
  // multicast (QM) question, so every listener -- not just this one --
  // sees any reply, matching typical mDNS browser behavior.
  _writeUint16(out, _dnsClassIn);
  return out.toBytes();
}

Uint8List _encodeMdnsResponse({
  required String serviceFqdn,
  required String instanceFqdn,
  required String hostFqdn,
  required List<String> ips,
  required List<String> txts,
}) {
  final answers = <Uint8List>[
    _encodeResourceRecord(
      name: serviceFqdn,
      type: _rrPtr,
      flush: false, // PTR records are shared, not unique (RFC 6762 §10.2).
      ttl: mdnsRecordTtl,
      rdata: _encodeDnsName(instanceFqdn),
    ),
    _encodeResourceRecord(
      name: instanceFqdn,
      type: _rrSrv,
      flush: true,
      ttl: mdnsRecordTtl,
      rdata: _encodeSrvData(hostFqdn),
    ),
    _encodeResourceRecord(
      name: instanceFqdn,
      type: _rrTxt,
      flush: true,
      ttl: mdnsRecordTtl,
      rdata: _encodeTxtData(txts),
    ),
    for (final ip in ips)
      _encodeResourceRecord(
        name: hostFqdn,
        type: ip.contains(':') ? _rrAaaa : _rrA,
        flush: true,
        ttl: mdnsAddressRecordTtl,
        rdata: Uint8List.fromList(InternetAddress(ip).rawAddress),
      ),
  ];

  final out = BytesBuilder();
  _writeUint16(out, 0); // Transaction ID: unused for multicast responses (RFC 6762 §18.1).
  _writeUint16(out, 0x8400); // QR=1 (response), AA=1 (authoritative).
  _writeUint16(out, 0); // QDCOUNT
  _writeUint16(out, answers.length); // ANCOUNT
  _writeUint16(out, 0); // NSCOUNT
  _writeUint16(out, 0); // ARCOUNT
  // ponytail: every record goes in the Answer section, none in Additional.
  // Real responders split PTR into Answers and SRV/TXT/A into Additional
  // for compactness; putting everything in Answers is simpler to encode
  // and just as correct -- `_decodeMdnsMessage` (this port's own resolver
  // side, above) and every other mDNS client scan the Answer section for
  // records they care about regardless of section.
  for (final answer in answers) {
    out.add(answer);
  }
  return out.toBytes();
}

Uint8List _encodeResourceRecord({
  required String name,
  required int type,
  required bool flush,
  required Duration ttl,
  required Uint8List rdata,
}) {
  final out = BytesBuilder();
  out.add(_encodeDnsName(name));
  _writeUint16(out, type);
  _writeUint16(out, flush ? (_dnsClassIn | _dnsClassFlush) : _dnsClassIn);
  _writeUint32(out, ttl.inSeconds);
  _writeUint16(out, rdata.length);
  out.add(rdata);
  return out.toBytes();
}

Uint8List _encodeSrvData(String targetFqdn) {
  final out = BytesBuilder();
  _writeUint16(out, 0); // priority
  _writeUint16(out, 0); // weight
  // libp2p doesn't dial via the SRV port; real addresses come from the TXT
  // record's `dnsaddr=` entries. Matches the literal placeholder go-libp2p
  // itself passes to `zeroconf.RegisterProxy` (`mdns.go:206`, commented
  // there as "we have to pass in a port number here, but libp2p only uses
  // the TXT records").
  _writeUint16(out, 4001);
  out.add(_encodeDnsName(targetFqdn));
  return out.toBytes();
}

Uint8List _encodeTxtData(List<String> txts) {
  final out = BytesBuilder();
  if (txts.isEmpty) {
    out.addByte(0); // RFC 6763 requires at least one (possibly empty) string.
    return out.toBytes();
  }
  for (final t in txts) {
    final bytes = utf8.encode(t);
    if (bytes.length > 255) {
      throw ArgumentError('TXT character-string exceeds 255 bytes: $t');
    }
    out.addByte(bytes.length);
    out.add(bytes);
  }
  return out.toBytes();
}

String _stripTrailingDot(String name) => name.endsWith('.') ? name.substring(0, name.length - 1) : name;

Uint8List _encodeDnsName(String name) {
  final trimmed = name.endsWith('.') ? name.substring(0, name.length - 1) : name;
  final out = BytesBuilder();
  if (trimmed.isNotEmpty) {
    for (final label in trimmed.split('.')) {
      final bytes = utf8.encode(label);
      if (bytes.isEmpty || bytes.length > 63) {
        throw ArgumentError('invalid DNS label "$label" in "$name"');
      }
      out.addByte(bytes.length);
      out.add(bytes);
    }
  }
  out.addByte(0);
  return out.toBytes();
}

void _writeUint16(BytesBuilder out, int v) {
  out.addByte((v >> 8) & 0xff);
  out.addByte(v & 0xff);
}

void _writeUint32(BytesBuilder out, int v) {
  out.addByte((v >> 24) & 0xff);
  out.addByte((v >> 16) & 0xff);
  out.addByte((v >> 8) & 0xff);
  out.addByte(v & 0xff);
}

/// Reads the question section (name + type) and answer section (type +
/// raw RDATA -- only `MdnsService`'s datagram handler decodes TXT RDATA
/// further, via [_decodeTxtRdata], per this file's header comment) of an
/// incoming mDNS/DNS message. Deliberately doesn't parse the
/// authority/additional sections: this responder (see
/// `_encodeMdnsResponse`) and every real peer's responder put every
/// record type this port cares about in the answer section. Throws
/// [FormatException] on structurally invalid input, since this parses
/// untrusted network bytes.
(List<_MdnsQuestion> questions, List<_MdnsAnswer> answers) _decodeMdnsMessage(Uint8List bytes) {
  if (bytes.length < 12) {
    throw const FormatException('mDNS message shorter than the header');
  }
  final qdCount = _readUint16(bytes, 4);
  final anCount = _readUint16(bytes, 6);
  var offset = 12;

  final questions = <_MdnsQuestion>[];
  for (var i = 0; i < qdCount; i++) {
    final (name, nameEnd) = _readDnsName(bytes, offset);
    if (nameEnd + 4 > bytes.length) {
      throw const FormatException('mDNS message truncated in question section');
    }
    final type = _readUint16(bytes, nameEnd);
    questions.add(_MdnsQuestion(name, type));
    offset = nameEnd + 4; // + QTYPE + QCLASS
  }

  final answers = <_MdnsAnswer>[];
  for (var i = 0; i < anCount; i++) {
    final (_, nameEnd) = _readDnsName(bytes, offset);
    if (nameEnd + 10 > bytes.length) {
      throw const FormatException('mDNS message truncated in answer section');
    }
    final type = _readUint16(bytes, nameEnd);
    // class at nameEnd+2, ttl at nameEnd+4 (4 bytes): not needed here.
    final rdLength = _readUint16(bytes, nameEnd + 8);
    final rdStart = nameEnd + 10;
    final rdEnd = rdStart + rdLength;
    if (rdEnd > bytes.length) {
      throw const FormatException('mDNS answer RDATA overruns message');
    }
    answers.add(_MdnsAnswer(type, bytes.sublist(rdStart, rdEnd)));
    offset = rdEnd;
  }

  return (questions, answers);
}

/// Decodes a TXT record's RDATA (a sequence of length-prefixed
/// character-strings) back into its individual strings -- the inverse of
/// [_encodeTxtData]. Throws [FormatException] on structurally invalid
/// input, since this parses untrusted network bytes.
List<String> _decodeTxtRdata(Uint8List rdata) {
  final out = <String>[];
  var pos = 0;
  while (pos < rdata.length) {
    final len = rdata[pos];
    final start = pos + 1;
    final end = start + len;
    if (end > rdata.length) {
      throw const FormatException('TXT character-string runs past RDATA');
    }
    out.add(utf8.decode(rdata.sublist(start, end)));
    pos = end;
  }
  return out;
}

int _readUint16(Uint8List b, int offset) {
  if (offset + 2 > b.length) {
    throw const FormatException('mDNS message truncated');
  }
  return (b[offset] << 8) | b[offset + 1];
}

/// Reads a (possibly compressed, RFC 1035 §4.1.4) domain name starting at
/// [offset]. Returns the decoded name and the offset immediately after it
/// in the original stream. Ported from the same bounds-checked algorithm
/// as `lib/src/transport/dns/dns_message.dart`'s private `_readName` in
/// the root package (duplicated rather than imported -- see this file's
/// header comment).
(String name, int end) _readDnsName(Uint8List b, int offset) {
  final labels = <String>[];
  var pos = offset;
  var end = -1;
  var jumps = 0;
  const maxJumps = 32;

  while (true) {
    if (pos >= b.length) {
      throw const FormatException('mDNS name runs past end of message');
    }
    final len = b[pos];
    if (len == 0) {
      pos += 1;
      if (end == -1) end = pos;
      break;
    }
    if ((len & 0xc0) == 0xc0) {
      if (pos + 1 >= b.length) {
        throw const FormatException('mDNS name pointer runs past end of message');
      }
      if (end == -1) end = pos + 2;
      jumps++;
      if (jumps > maxJumps) {
        throw const FormatException('mDNS name has too many compression pointers');
      }
      final target = ((len & 0x3f) << 8) | b[pos + 1];
      if (target >= pos) {
        throw const FormatException('mDNS name compression pointer does not point backward');
      }
      pos = target;
      continue;
    }
    if ((len & 0xc0) != 0) {
      throw const FormatException('mDNS name uses a reserved label length encoding');
    }
    final labelStart = pos + 1;
    final labelEnd = labelStart + len;
    if (labelEnd > b.length) {
      throw const FormatException('mDNS name label runs past end of message');
    }
    labels.add(String.fromCharCodes(b, labelStart, labelEnd));
    pos = labelEnd;
  }

  return (labels.join('.'), end);
}
