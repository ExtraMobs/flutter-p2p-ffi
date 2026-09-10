// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/multiaddr/transcoders.dart
//
// Port of go-multiaddr's per-protocol Transcoder implementations
// (github.com/multiformats/go-multiaddr transcoders.go). Each function pair
// mirrors its Go counterpart (`xStB`/`xBtS`/`xValidate`) closely enough to
// diff against the original.
//
// No `dart:io` here (transpiled_multiaddr stays platform-agnostic for web
// targets), so IPv4/IPv6 parsing is hand-rolled rather than delegated to
// `InternetAddress`.
import 'dart:convert';
import 'dart:typed_data';

import 'package:base32/base32.dart' as b32;
import 'package:base32/encodings.dart' as b32enc;
import 'package:multibase/multibase.dart' as mb;
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_multibase/transpiled_multibase.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

import 'protocol.dart';

FormatException _err(String msg) => FormatException(msg);

// ---------------------------------------------------------------------------
// ip4 / ip6 / ip6zone / ipcidr
// ---------------------------------------------------------------------------

Uint8List _ip4StB(String s) {
  final parts = s.split('.');
  if (parts.length != 4) {
    throw _err('failed to parse ip4 addr: $s');
  }
  final bytes = Uint8List(4);
  for (var i = 0; i < 4; i++) {
    final v = int.tryParse(parts[i]);
    if (v == null || v < 0 || v > 255 || parts[i].isEmpty) {
      throw _err('failed to parse ip4 addr: $s');
    }
    bytes[i] = v;
  }
  return bytes;
}

String _ip4BtS(Uint8List b) => '${b[0]}.${b[1]}.${b[2]}.${b[3]}';

/// Parses a textual IPv6 address (RFC 4291, including `::` compression and
/// an embedded trailing IPv4 dotted-decimal group) into 16 raw bytes.
Uint8List _ip6StB(String s) {
  if (s.isEmpty) throw _err('failed to parse ip6 addr: $s');

  var head = s;
  var tail = '';
  var hasDoubleColon = false;
  final dc = s.indexOf('::');
  if (dc != -1) {
    if (s.indexOf('::', dc + 1) != -1) {
      throw _err('failed to parse ip6 addr: $s');
    }
    hasDoubleColon = true;
    head = s.substring(0, dc);
    tail = s.substring(dc + 2);
  }

  List<int> parseGroups(String part) {
    if (part.isEmpty) return [];
    var groups = part.split(':');
    final out = <int>[];
    // An embedded IPv4 tail (e.g. "ffff:1.2.3.4") occupies the last two
    // 16-bit groups.
    if (groups.last.contains('.')) {
      final v4 = _ip4StB(groups.last);
      out.addAll(_toHextets(groups.sublist(0, groups.length - 1)));
      out.add((v4[0] << 8) | v4[1]);
      out.add((v4[2] << 8) | v4[3]);
      return out;
    }
    return _toHextets(groups);
  }

  final headGroups = parseGroups(head);
  final tailGroups = parseGroups(tail);

  List<int> groups16;
  if (hasDoubleColon) {
    final missing = 8 - headGroups.length - tailGroups.length;
    if (missing < 0) throw _err('failed to parse ip6 addr: $s');
    groups16 = [
      ...headGroups,
      ...List.filled(missing, 0),
      ...tailGroups,
    ];
  } else {
    groups16 = headGroups;
  }
  if (groups16.length != 8) throw _err('failed to parse ip6 addr: $s');

  final out = Uint8List(16);
  for (var i = 0; i < 8; i++) {
    out[i * 2] = (groups16[i] >> 8) & 0xff;
    out[i * 2 + 1] = groups16[i] & 0xff;
  }
  return out;
}

List<int> _toHextets(List<String> groups) {
  return groups.map((g) {
    if (g.isEmpty || g.length > 4) throw _err('failed to parse ip6 addr');
    final v = int.tryParse(g, radix: 16);
    if (v == null || v < 0 || v > 0xffff) {
      throw _err('failed to parse ip6 addr');
    }
    return v;
  }).toList();
}

/// Formats 16 raw bytes as RFC 5952 canonical IPv6 text, with go-multiaddr's
/// `::ffff:a.b.c.d` rendering for IPv4-mapped addresses.
String _ip6BtS(Uint8List b) {
  if (b.length != 16) throw _err('invalid ip6 length: ${b.length}');

  const v4MappedPrefix = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff];
  var isV4Mapped = true;
  for (var i = 0; i < 12; i++) {
    if (b[i] != v4MappedPrefix[i]) {
      isV4Mapped = false;
      break;
    }
  }
  if (isV4Mapped) {
    return '::ffff:${_ip4BtS(b.sublist(12, 16))}';
  }

  final groups = List<int>.generate(8, (i) => (b[i * 2] << 8) | b[i * 2 + 1]);

  var bestStart = -1;
  var bestLen = 0;
  var curStart = -1;
  var curLen = 0;
  for (var i = 0; i < 8; i++) {
    if (groups[i] == 0) {
      if (curStart == -1) curStart = i;
      curLen++;
      if (curLen > bestLen) {
        bestLen = curLen;
        bestStart = curStart;
      }
    } else {
      curStart = -1;
      curLen = 0;
    }
  }
  // RFC 5952: only compress runs of 2+ zero groups.
  if (bestLen < 2) {
    bestStart = -1;
    bestLen = 0;
  }

  if (bestStart == -1) {
    return groups.map((g) => g.toRadixString(16)).join(':');
  }

  final before = groups
      .sublist(0, bestStart)
      .map((g) => g.toRadixString(16))
      .join(':');
  final after = groups
      .sublist(bestStart + bestLen)
      .map((g) => g.toRadixString(16))
      .join(':');
  return '$before::$after';
}

Uint8List _ip6zoneStB(String s) {
  if (s.isEmpty) throw _err('empty ip6zone');
  if (s.contains('/')) throw _err("IPv6 zone ID contains '/': $s");
  return Uint8List.fromList(utf8.encode(s));
}

String _ip6zoneBtS(Uint8List b) {
  if (b.isEmpty) throw _err('invalid length (should be > 0)');
  return utf8.decode(b);
}

void _ip6zoneVal(Uint8List b) {
  if (b.isEmpty) throw _err('invalid length (should be > 0)');
  if (b.contains(0x2f)) throw _err("IPv6 zone ID contains '/'");
}

Uint8List _ipcidrStB(String s) {
  final v = int.tryParse(s);
  if (v == null || v < 0 || v > 255) throw _err('invalid ipcidr: $s');
  return Uint8List.fromList([v]);
}

String _ipcidrBtS(Uint8List b) {
  _ipcidrValidate(b);
  return b[0].toString();
}

void _ipcidrValidate(Uint8List b) {
  if (b.length != 1) throw _err('invalid length (should be == 1)');
}

// ---------------------------------------------------------------------------
// port (tcp/udp/dccp/sctp)
// ---------------------------------------------------------------------------

Uint8List _portStB(String s) {
  final v = int.tryParse(s);
  if (v == null || v < 0 || v > 0xffff) {
    throw _err('failed to parse port addr: $s');
  }
  return Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.big);
}

String _portBtS(Uint8List b) {
  return b.buffer.asByteData(b.offsetInBytes, b.length).getUint16(0, Endian.big).toString();
}

// ---------------------------------------------------------------------------
// dns / dns4 / dns6 / dnsaddr / sni
// ---------------------------------------------------------------------------

void _dnsVal(Uint8List b) {
  if (b.isEmpty) throw _err('empty dns addr');
  if (b.contains(0x2f)) throw _err('domain name contains a slash');
}

Uint8List _dnsStB(String s) {
  final b = Uint8List.fromList(utf8.encode(s));
  _dnsVal(b);
  return b;
}

String _dnsBtS(Uint8List b) => utf8.decode(b);

// ---------------------------------------------------------------------------
// onion / onion3 (Tor)
// ---------------------------------------------------------------------------

(String, int) _splitOnionAddr(String s) {
  final parts = s.split(':');
  if (parts.length != 2) {
    throw _err('failed to parse onion addr: $s does not contain a port number');
  }
  final port = int.tryParse(parts[1]);
  if (port == null || port < 0 || port > 0xffff) {
    throw _err('failed to parse onion addr: invalid port in $s');
  }
  if (port == 0) throw _err('failed to parse onion addr: non-zero port');
  return (parts[0], port);
}

Uint8List _onionStB(String s) {
  final (host, port) = _splitOnionAddr(s);
  // A 10-byte onion host is exactly 16 unpadded base32 characters; unlike
  // Go's strictly-padded StdEncoding.DecodeString, package:base32 pads
  // lenient input automatically, so a wrong-length host must be rejected
  // here rather than relying on the decoded byte count alone.
  if (host.length != 16) {
    throw _err('failed to parse onion addr: $s not a Tor onion address');
  }
  final hostBytes = b32.base32.decode(host.toUpperCase());
  if (hostBytes.length != 10) {
    throw _err('failed to parse onion addr: $s not a Tor onion address');
  }
  final out = Uint8List(12);
  out.setRange(0, 10, hostBytes);
  out.buffer.asByteData().setUint16(10, port, Endian.big);
  return out;
}

String _onionBtS(Uint8List b) {
  _onionValidate(b);
  final addr = b32.base32.encode(b.sublist(0, 10)).toLowerCase();
  final port = b.buffer.asByteData(b.offsetInBytes, b.length).getUint16(10, Endian.big);
  return '$addr:$port';
}

void _onionValidate(Uint8List b) {
  if (b.length != 12) {
    throw _err('invalid len for onion addr: got ${b.length} expected 12');
  }
  final port = b.buffer.asByteData(b.offsetInBytes, b.length).getUint16(10, Endian.big);
  if (port == 0) throw _err('invalid port 0 for onion addr');
}

Uint8List _onion3StB(String s) {
  final (host, port) = _splitOnionAddr(s);
  if (host.length != 56) {
    throw _err(
      'failed to parse onion addr: $s not a Tor onionv3 address. len == ${host.length}',
    );
  }
  final hostBytes = b32.base32.decode(host.toUpperCase());
  final out = Uint8List(37);
  out.setRange(0, 35, hostBytes.sublist(0, 35));
  out.buffer.asByteData().setUint16(35, port, Endian.big);
  return out;
}

String _onion3BtS(Uint8List b) {
  _onion3Validate(b);
  final addr = b32.base32.encode(b.sublist(0, 35)).toLowerCase();
  final port = b.buffer.asByteData(b.offsetInBytes, b.length).getUint16(35, Endian.big);
  return '$addr:$port';
}

void _onion3Validate(Uint8List b) {
  if (b.length != 37) {
    throw _err('invalid len for onion addr: got ${b.length} expected 37');
  }
  final port = b.buffer.asByteData(b.offsetInBytes, b.length).getUint16(35, Endian.big);
  if (port == 0) throw _err('invalid port 0 for onion addr');
}

// ---------------------------------------------------------------------------
// garlic64 / garlic32 (I2P)
// ---------------------------------------------------------------------------

Uint8List _garlic64StB(String s) {
  // i2p's base64 alphabet is standard base64 with '-' and '~' instead of
  // '+' and '/'; translate to standard alphabet and reuse dart:convert.
  final standard = s.replaceAll('-', '+').replaceAll('~', '/');
  final padded = standard.padRight(
    (standard.length + 3) ~/ 4 * 4,
    '=',
  );
  final Uint8List bytes;
  try {
    bytes = base64.decode(padded);
  } on FormatException {
    throw _err('failed to decode base64 i2p addr: $s');
  }
  _garlic64Validate(bytes);
  return bytes;
}

String _garlic64BtS(Uint8List b) {
  _garlic64Validate(b);
  return base64.encode(b).replaceAll('+', '-').replaceAll('/', '~');
}

void _garlic64Validate(Uint8List b) {
  if (b.length < 386) {
    throw _err('failed to validate garlic addr: not an i2p base64 address. len: ${b.length}');
  }
}

Uint8List _garlic32StB(String s) {
  var padded = s;
  while (padded.length % 8 != 0) {
    padded += '=';
  }
  final Uint8List bytes;
  try {
    bytes = b32.base32.decode(
      padded.toUpperCase(),
      encoding: b32enc.Encoding.standardRFC4648,
    );
  } on Exception {
    throw _err('failed to decode base32 garlic addr: $s');
  }
  _garlic32Validate(bytes);
  return bytes;
}

String _garlic32BtS(Uint8List b) {
  _garlic32Validate(b);
  final encoded = b32.base32.encode(
    b,
    encoding: b32enc.Encoding.nonStandardRFC4648Lower,
  );
  var end = encoded.length;
  while (end > 0 && encoded[end - 1] == '=') {
    end--;
  }
  return encoded.substring(0, end);
}

void _garlic32Validate(Uint8List b) {
  if (b.length < 35 && b.length != 32) {
    throw _err('failed to validate garlic addr: not an i2p base32 address. len: ${b.length}');
  }
}

// ---------------------------------------------------------------------------
// p2p (libp2p PeerId: base58 multihash, or a Cid with the libp2p-key codec)
// ---------------------------------------------------------------------------

void _p2pVal(Uint8List multihashBytes) {
  final mh = MultihashUtils.decode(multihashBytes);
  // Peer IDs require either a sha2-256 or an identity multihash:
  // https://github.com/libp2p/specs/blob/master/peer-ids/peer-ids.md#peer-ids
  if (mh.code.toBigInt() != BigInt.from(0x12) && mh.code.toBigInt() != BigInt.zero) {
    throw _err('invalid multihash code ${mh.code} expected sha-256 or identity');
  }
  if (mh.code.toBigInt() == BigInt.from(0x12) && mh.size != 32) {
    throw _err('invalid digest length ${mh.size} for sha256 addr: expected 32');
  }
}

Uint8List _p2pStB(String s) {
  if (s.startsWith('Qm') || s.startsWith('1')) {
    final decoded = MultibaseUtils.decode('z$s');
    _p2pVal(decoded);
    return decoded;
  }
  final cid = Cid.decode(s);
  if (cid.codec != 'libp2p-key') {
    throw _err('failed to parse p2p addr: $s has the invalid codec ${cid.codec}');
  }
  final hashBytes = cid.multihash.toBytes();
  _p2pVal(hashBytes);
  return hashBytes;
}

String _p2pBtS(Uint8List b) {
  final mh = MultihashUtils.decode(b);
  return MultibaseUtils.encode(mb.Multibase.base58btc, mh.toBytes()).substring(1);
}

// ---------------------------------------------------------------------------
// unix
// ---------------------------------------------------------------------------

Uint8List _unixStB(String s) => Uint8List.fromList(utf8.encode(s));

String _unixBtS(Uint8List b) => utf8.decode(b);

void _unixValidate(Uint8List b) {
  if (b.length < 2) throw _err('byte slice too short: ${b.length}');
  if (b[0] != 0x2f) throw _err("path protocol must begin with '/'");
  if (b[b.length - 1] == 0x2f) {
    throw _err("unix socket path must not end in '/'");
  }
}

// ---------------------------------------------------------------------------
// certhash
// ---------------------------------------------------------------------------

Uint8List _certHashStB(String s) {
  final data = MultibaseUtils.decode(s);
  // Validates that `data` is a well-formed multihash.
  MultihashUtils.decode(data);
  return data;
}

String _certHashBtS(Uint8List b) =>
    MultibaseUtils.encode(mb.Multibase.base64url, b);

void _validateCertHash(Uint8List b) => MultihashUtils.decode(b);

// ---------------------------------------------------------------------------
// http-path
// ---------------------------------------------------------------------------

Uint8List _httpPathStB(String s) {
  final unescaped = Uri.decodeQueryComponent(s);
  if (unescaped.isEmpty) throw _err('empty http path is not allowed');
  return Uint8List.fromList(utf8.encode(unescaped));
}

String _httpPathBtS(Uint8List b) {
  if (b.isEmpty) throw _err('empty http path is not allowed');
  return Uri.encodeQueryComponent(utf8.decode(b));
}

void _validateHTTPPath(Uint8List b) {
  if (b.isEmpty) throw _err('empty http path is not allowed');
}

// ---------------------------------------------------------------------------
// memory
// ---------------------------------------------------------------------------

Uint8List _memoryStB(String s) {
  final v = int.tryParse(s);
  if (v == null || v < 0) throw _err('invalid memory value: $s');
  final b = ByteData(8)..setUint64(0, v, Endian.big);
  return b.buffer.asUint8List();
}

String _memoryBtS(Uint8List b) {
  _memoryValidate(b);
  return b.buffer.asByteData(b.offsetInBytes, b.length).getUint64(0, Endian.big).toString();
}

void _memoryValidate(Uint8List b) {
  if (b.length != 8) throw _err('invalid length: must be exactly 8 bytes');
}

// ---------------------------------------------------------------------------
// Public Transcoder instances (referenced from protocol.dart's registry).
// ---------------------------------------------------------------------------

/// Transcoder for `ip4` (4-byte dotted-decimal).
const transcoderIP4 = Transcoder(_ip4StB, _ip4BtS);

/// Transcoder for `ip6` (16-byte RFC 5952 canonical text).
const transcoderIP6 = Transcoder(_ip6StB, _ip6BtS);

/// Transcoder for `ip6zone` (UTF-8 zone id, no `/`).
const transcoderIP6Zone = Transcoder(_ip6zoneStB, _ip6zoneBtS, _ip6zoneVal);

/// Transcoder for `ipcidr` (1-byte prefix length, 0-255).
const transcoderIPCIDR = Transcoder(_ipcidrStB, _ipcidrBtS, _ipcidrValidate);

/// Transcoder for `tcp`/`udp`/`dccp`/`sctp` (2-byte big-endian port).
const transcoderPort = Transcoder(_portStB, _portBtS);

/// Transcoder for `dns`/`dns4`/`dns6`/`dnsaddr`/`sni` (UTF-8 hostname, no
/// `/`).
const transcoderDns = Transcoder(_dnsStB, _dnsBtS, _dnsVal);

/// Transcoder for `onion` (Tor v2 address, 10-byte host + 2-byte port).
const transcoderOnion = Transcoder(_onionStB, _onionBtS, _onionValidate);

/// Transcoder for `onion3` (Tor v3 address, 35-byte host + 2-byte port).
const transcoderOnion3 = Transcoder(_onion3StB, _onion3BtS, _onion3Validate);

/// Transcoder for `garlic64` (I2P base64 destination, i2p alphabet).
const transcoderGarlic64 = Transcoder(
  _garlic64StB,
  _garlic64BtS,
  _garlic64Validate,
);

/// Transcoder for `garlic32` (I2P base32 destination, unpadded).
const transcoderGarlic32 = Transcoder(
  _garlic32StB,
  _garlic32BtS,
  _garlic32Validate,
);

/// Transcoder for `p2p` (a PeerId: base58 multihash, or a `libp2p-key` Cid).
const transcoderP2P = Transcoder(_p2pStB, _p2pBtS, _p2pVal);

/// Transcoder for `unix` (UTF-8 filesystem path, must start with `/`).
const transcoderUnix = Transcoder(_unixStB, _unixBtS, _unixValidate);

/// Transcoder for `certhash` (a multibase-encoded multihash).
const transcoderCertHash = Transcoder(
  _certHashStB,
  _certHashBtS,
  _validateCertHash,
);

/// Transcoder for `http-path` (a query-escaped URL path).
const transcoderHTTPPath = Transcoder(
  _httpPathStB,
  _httpPathBtS,
  _validateHTTPPath,
);

/// Transcoder for `memory` (8-byte big-endian unsigned integer).
const transcoderMemory = Transcoder(_memoryStB, _memoryBtS, _memoryValidate);
