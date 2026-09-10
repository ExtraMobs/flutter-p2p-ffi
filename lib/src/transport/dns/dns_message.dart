// lib/src/transport/dns/dns_message.dart
//
// Minimal RFC 1035 DNS message encoder/decoder: just enough to build an A/
// AAAA/TXT query and parse the matching response. This exists because
// `dart:io` has no TXT lookup API (`InternetAddress.lookup` only covers
// A/AAAA) -- see doc/transpilation/PROGRESS.md's go-multiaddr-dns row.
// pub.dev has no well-maintained pure-Dart classic (UDP) DNS client with
// TXT support (checked: the `dns` package has 30/160 pub points, 6 likes,
// 33 downloads -- an unmaintained-looking single-digit-adoption package,
// not something to depend on for this; `dns_client`/`super_dns_client`/
// `dnsolve` are DNS-over-HTTPS or FFI/native-resolver wrappers, which don't
// match the classic-DNS resolution real libp2p bootstrap peers and kubo's
// own resolver assume), so this is hand-rolled against the RFC.
import 'dart:typed_data';

/// DNS record types this client understands (RFC 1035 §3.2.2, RFC 3596).
class DnsRecordType {
  DnsRecordType._();

  /// A record (IPv4 address).
  static const int a = 1;

  /// AAAA record (IPv6 address).
  static const int aaaa = 28;

  /// TXT record.
  static const int txt = 16;
}

const int _dnsClassIn = 1;

/// Encodes a standard recursive query for [name] and [type] (see
/// [DnsRecordType]). [id] should be unpredictable per query (basic
/// anti-spoofing hygiene: an off-path attacker must also guess it to inject
/// a forged reply).
Uint8List encodeDnsQuery({required int id, required String name, required int type}) {
  final out = BytesBuilder();

  // Header: ID, flags (RD=1, everything else 0), QDCOUNT=1, AN/NS/AR=0.
  _writeUint16(out, id);
  _writeUint16(out, 0x0100);
  _writeUint16(out, 1);
  _writeUint16(out, 0);
  _writeUint16(out, 0);
  _writeUint16(out, 0);

  out.add(_encodeName(name));
  _writeUint16(out, type);
  _writeUint16(out, _dnsClassIn);

  return out.toBytes();
}

void _writeUint16(BytesBuilder out, int v) {
  out.addByte((v >> 8) & 0xff);
  out.addByte(v & 0xff);
}

Uint8List _encodeName(String name) {
  final out = BytesBuilder();
  var trimmed = name;
  if (trimmed.endsWith('.')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  if (trimmed.isNotEmpty) {
    for (final label in trimmed.split('.')) {
      final bytes = Uint8List.fromList(label.codeUnits);
      if (bytes.isEmpty || bytes.length > 63) {
        throw FormatException('invalid DNS label "$label" in "$name"');
      }
      out.addByte(bytes.length);
      out.add(bytes);
    }
  }
  out.addByte(0);
  return out.toBytes();
}

/// One parsed resource record's relevant fields: enough to serve
/// `BasicResolver.lookupIpAddr`/`lookupTxt`.
class DnsRecord {
  /// Builds a record with the given [type] and text [data].
  const DnsRecord({required this.type, required this.data});

  /// The record type ([DnsRecordType.a]/[aaaa]/[txt]).
  final int type;

  /// For A/AAAA: the address as text (dotted-decimal or colon-form). For
  /// TXT: the record's character-strings concatenated with no separator
  /// (matching Go's `net.LookupTXT`, which joins each RR's strings the same
  /// way -- see resolve.go's `dnsaddrTXTPrefix` handling in
  /// go-multiaddr-dns, which expects one prefixed string per record).
  final String data;
}

/// A parsed DNS response: the records answering the query, or an error
/// diagnosing why there are none.
class DnsResponse {
  /// Builds a response with the given [id]/[rcode]/[records].
  const DnsResponse({required this.id, required this.rcode, required this.records});

  /// The transaction id, echoed from the query.
  final int id;

  /// RFC 1035 §4.1.1 RCODE (0 = no error).
  final int rcode;

  /// The parsed answer-section records this client understands.
  final List<DnsRecord> records;
}

/// Parses a raw DNS message from the wire. Throws [FormatException] on any
/// structurally invalid input -- this parses untrusted network bytes, so
/// every read is bounds-checked rather than trusting header-declared counts
/// or lengths.
DnsResponse decodeDnsMessage(Uint8List bytes) {
  if (bytes.length < 12) {
    throw const FormatException('DNS message shorter than the header');
  }
  final id = _readUint16(bytes, 0);
  final flags = _readUint16(bytes, 2);
  final rcode = flags & 0x0f;
  final qdCount = _readUint16(bytes, 4);
  final anCount = _readUint16(bytes, 6);

  var offset = 12;
  for (var i = 0; i < qdCount; i++) {
    final (_, nameEnd) = _readName(bytes, offset);
    offset = nameEnd + 4; // + QTYPE + QCLASS
    if (offset > bytes.length) {
      throw const FormatException('DNS message truncated in question section');
    }
  }

  final records = <DnsRecord>[];
  for (var i = 0; i < anCount; i++) {
    final (_, nameEnd) = _readName(bytes, offset);
    offset = nameEnd;
    if (offset + 10 > bytes.length) {
      throw const FormatException('DNS message truncated in answer record');
    }
    final type = _readUint16(bytes, offset);
    // class at offset+2, ttl at offset+4 (4 bytes): not needed here.
    final rdLength = _readUint16(bytes, offset + 8);
    final rdStart = offset + 10;
    final rdEnd = rdStart + rdLength;
    if (rdEnd > bytes.length) {
      throw const FormatException('DNS resource record RDATA overruns message');
    }

    switch (type) {
      case DnsRecordType.a:
        if (rdLength != 4) {
          throw const FormatException('malformed A record (expected 4 bytes)');
        }
        records.add(
          DnsRecord(
            type: type,
            data: '${bytes[rdStart]}.${bytes[rdStart + 1]}.'
                '${bytes[rdStart + 2]}.${bytes[rdStart + 3]}',
          ),
        );
      case DnsRecordType.aaaa:
        if (rdLength != 16) {
          throw const FormatException('malformed AAAA record (expected 16 bytes)');
        }
        records.add(
          DnsRecord(type: type, data: _formatIp6(bytes, rdStart)),
        );
      case DnsRecordType.txt:
        records.add(
          DnsRecord(
            type: type,
            data: _readTxtStrings(bytes, rdStart, rdEnd),
          ),
        );
      default:
        // Not a type this client resolves; skip its RDATA.
        break;
    }

    offset = rdEnd;
  }

  return DnsResponse(id: id, rcode: rcode, records: records);
}

int _readUint16(Uint8List b, int offset) {
  if (offset + 2 > b.length) {
    throw const FormatException('DNS message truncated');
  }
  return (b[offset] << 8) | b[offset + 1];
}

/// Reads a (possibly compressed, RFC 1035 §4.1.4) domain name starting at
/// [offset]. Returns the decoded name and the offset immediately after it
/// *in the original (non-followed) stream* -- i.e. after a compression
/// pointer, not after whatever it points to.
(String name, int end) _readName(Uint8List b, int offset) {
  final labels = <String>[];
  var pos = offset;
  var end = -1; // set once we take the first pointer jump.
  var jumps = 0;
  const maxJumps = 32; // generous; guards against pointer loops.

  while (true) {
    if (pos >= b.length) {
      throw const FormatException('DNS name runs past end of message');
    }
    final len = b[pos];
    if (len == 0) {
      pos += 1;
      if (end == -1) end = pos;
      break;
    }
    if ((len & 0xc0) == 0xc0) {
      // Compression pointer: 14-bit offset from the low 6 bits of this
      // byte plus the next byte.
      if (pos + 1 >= b.length) {
        throw const FormatException('DNS name pointer runs past end of message');
      }
      if (end == -1) end = pos + 2;
      jumps++;
      if (jumps > maxJumps) {
        throw const FormatException('DNS name has too many compression pointers');
      }
      final target = ((len & 0x3f) << 8) | b[pos + 1];
      if (target >= pos) {
        // RFC 1035 requires pointers to point backward; reject forward/
        // self pointers outright rather than risk a loop.
        throw const FormatException('DNS name compression pointer does not point backward');
      }
      pos = target;
      continue;
    }
    if ((len & 0xc0) != 0) {
      throw const FormatException('DNS name uses a reserved label length encoding');
    }
    final labelStart = pos + 1;
    final labelEnd = labelStart + len;
    if (labelEnd > b.length) {
      throw const FormatException('DNS name label runs past end of message');
    }
    labels.add(String.fromCharCodes(b, labelStart, labelEnd));
    pos = labelEnd;
  }

  return (labels.join('.'), end);
}

String _formatIp6(Uint8List b, int start) {
  final groups = List<int>.generate(
    8,
    (i) => (b[start + i * 2] << 8) | b[start + i * 2 + 1],
  );
  var bestStart = -1;
  var bestLen = 0;
  var curStart = -1;
  var curLen = 0;
  for (var i = 0; i < 8; i++) {
    if (groups[i] == 0) {
      curStart = curStart == -1 ? i : curStart;
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
  if (bestLen < 2) return groups.map((g) => g.toRadixString(16)).join(':');
  final before = groups.sublist(0, bestStart).map((g) => g.toRadixString(16)).join(':');
  final after = groups.sublist(bestStart + bestLen).map((g) => g.toRadixString(16)).join(':');
  return '$before::$after';
}

String _readTxtStrings(Uint8List b, int start, int end) {
  final out = StringBuffer();
  var pos = start;
  while (pos < end) {
    final len = b[pos];
    final strStart = pos + 1;
    final strEnd = strStart + len;
    if (strEnd > end) {
      throw const FormatException('TXT character-string runs past RDATA');
    }
    out.write(String.fromCharCodes(b, strStart, strEnd));
    pos = strEnd;
  }
  return out.toString();
}
