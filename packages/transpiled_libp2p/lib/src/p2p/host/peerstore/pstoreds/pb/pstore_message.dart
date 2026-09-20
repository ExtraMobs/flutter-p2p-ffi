// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/p2p/host/peerstore/pstoreds/pb/pstore_message.dart
//
// Port of go-libp2p's p2p/host/peerstore/pstoreds/pb/pstore.proto: the
// AddrBookRecord message used to persist one peer's addresses. Hand-rolled
// against the shared varint helpers (proto_varint.dart), like every other
// small protobuf message in this package (see circuitv2/pb, holepunch/pb,
// identify/pb) -- not complex enough to justify pulling in protoc codegen.
//
// `expiry`/`ttl` are stored in microseconds (Dart's native `Duration` and
// `DateTime` unit) rather than Go's nanoseconds -- this datastore is never
// read by a Go node, so wire-compatibility with the upstream's bytes isn't
// a requirement, only internal round-trip fidelity.
import 'dart:typed_data';

import '../../../../../core/crypto/proto_varint.dart';

/// A single multiaddr entry inside an [AddrBookRecord]. Equivalent to
/// go-libp2p's `pb.AddrBookRecord_AddrEntry`.
class AddrBookRecord_AddrEntry {
  AddrBookRecord_AddrEntry({required this.addr, required this.expiry, required this.ttl});

  /// The multiaddr's binary representation.
  final Uint8List addr;

  /// Microseconds-since-epoch at which this address expires. Mutable: an
  /// existing entry's expiry is bumped in place on a TTL refresh (mirrors
  /// go-libp2p's `dsAddrBook.setAddrs`, which mutates `*pb.AddrBookRecord_AddrEntry`
  /// pointers held in its address map).
  int expiry;

  /// The original TTL of this address, in microseconds. Mutable; see
  /// [expiry].
  int ttl;
}

/// A stored signed `PeerRecord` envelope. Equivalent to go-libp2p's
/// `pb.AddrBookRecord_CertifiedRecord`.
class CertifiedRecord {
  CertifiedRecord({required this.seq, required this.raw});

  /// The `Seq` counter from the signed PeerRecord envelope.
  final int seq;

  /// The serialized bytes of the signed envelope containing the PeerRecord.
  final Uint8List raw;
}

/// Persisted record for a single peer's addresses. Equivalent to
/// go-libp2p's `pb.AddrBookRecord`.
class AddrBookRecord {
  AddrBookRecord({required this.id, List<AddrBookRecord_AddrEntry>? addrs, this.certifiedRecord})
    : addrs = addrs ?? <AddrBookRecord_AddrEntry>[];

  /// The peer ID, as raw bytes.
  final Uint8List id;

  /// The multiaddresses. Sorted so element 0 expires soonest.
  List<AddrBookRecord_AddrEntry> addrs;

  /// The most recently received signed PeerRecord, if any.
  CertifiedRecord? certifiedRecord;

  /// Serializes this record to its protobuf wire representation.
  Uint8List marshal() {
    final out = BytesBuilder();

    void writeBytesField(int field, Uint8List bytes) {
      out.add(encodeProtoVarint((field << 3) | 2));
      out.add(encodeProtoVarint(bytes.length));
      out.add(bytes);
    }

    writeBytesField(1, id);

    for (final a in addrs) {
      final entry = BytesBuilder();
      entry.add(encodeProtoVarint((1 << 3) | 2));
      entry.add(encodeProtoVarint(a.addr.length));
      entry.add(a.addr);
      entry.add(encodeProtoVarint((2 << 3) | 0));
      entry.add(encodeProtoVarint(a.expiry));
      entry.add(encodeProtoVarint((3 << 3) | 0));
      entry.add(encodeProtoVarint(a.ttl));
      writeBytesField(2, entry.toBytes());
    }

    final cr = certifiedRecord;
    if (cr != null) {
      final crBuilder = BytesBuilder();
      crBuilder.add(encodeProtoVarint((1 << 3) | 0));
      crBuilder.add(encodeProtoVarint(cr.seq));
      crBuilder.add(encodeProtoVarint((2 << 3) | 2));
      crBuilder.add(encodeProtoVarint(cr.raw.length));
      crBuilder.add(cr.raw);
      writeBytesField(3, crBuilder.toBytes());
    }

    return out.toBytes();
  }

  /// Deserializes a record from [bytes] (the output of [marshal]).
  factory AddrBookRecord.unmarshal(Uint8List bytes) {
    var id = Uint8List(0);
    final addrs = <AddrBookRecord_AddrEntry>[];
    CertifiedRecord? certifiedRecord;

    var offset = 0;
    while (offset < bytes.length) {
      final (tag, tagLen) = readProtoVarint(bytes, offset);
      offset += tagLen;
      final field = tag >> 3;
      final wireType = tag & 0x7;

      if (wireType == 0) {
        final (_, vLen) = readProtoVarint(bytes, offset);
        offset += vLen;
      } else if (wireType == 2) {
        final (length, lenLen) = readProtoVarint(bytes, offset);
        offset += lenLen;
        final fieldBytes = bytes.sublist(offset, offset + length);
        offset += length;

        switch (field) {
          case 1:
            id = fieldBytes;
          case 2:
            addrs.add(_decodeAddrEntry(fieldBytes));
          case 3:
            certifiedRecord = _decodeCertifiedRecord(fieldBytes);
        }
      } else {
        break;
      }
    }

    return AddrBookRecord(id: id, addrs: addrs, certifiedRecord: certifiedRecord);
  }
}

AddrBookRecord_AddrEntry _decodeAddrEntry(Uint8List bytes) {
  var addr = Uint8List(0);
  var expiry = 0;
  var ttl = 0;
  var offset = 0;
  while (offset < bytes.length) {
    final (tag, tagLen) = readProtoVarint(bytes, offset);
    offset += tagLen;
    final field = tag >> 3;
    final wireType = tag & 0x7;
    if (wireType == 0) {
      final (val, vLen) = readProtoVarint(bytes, offset);
      offset += vLen;
      if (field == 2) expiry = val;
      if (field == 3) ttl = val;
    } else if (wireType == 2) {
      final (length, lenLen) = readProtoVarint(bytes, offset);
      offset += lenLen;
      final fieldBytes = bytes.sublist(offset, offset + length);
      offset += length;
      if (field == 1) addr = fieldBytes;
    } else {
      break;
    }
  }
  return AddrBookRecord_AddrEntry(addr: addr, expiry: expiry, ttl: ttl);
}

CertifiedRecord _decodeCertifiedRecord(Uint8List bytes) {
  var seq = 0;
  var raw = Uint8List(0);
  var offset = 0;
  while (offset < bytes.length) {
    final (tag, tagLen) = readProtoVarint(bytes, offset);
    offset += tagLen;
    final field = tag >> 3;
    final wireType = tag & 0x7;
    if (wireType == 0) {
      final (val, vLen) = readProtoVarint(bytes, offset);
      offset += vLen;
      if (field == 1) seq = val;
    } else if (wireType == 2) {
      final (length, lenLen) = readProtoVarint(bytes, offset);
      offset += lenLen;
      final fieldBytes = bytes.sublist(offset, offset + length);
      offset += length;
      if (field == 2) raw = fieldBytes;
    } else {
      break;
    }
  }
  return CertifiedRecord(seq: seq, raw: raw);
}
