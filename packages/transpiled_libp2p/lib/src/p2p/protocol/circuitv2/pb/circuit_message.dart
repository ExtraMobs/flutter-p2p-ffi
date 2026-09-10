// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import '../../../../core/crypto/proto_varint.dart';

enum HopMessageType { reserve, connect, status }

enum HopStatus {
  ok(100),
  reservationRefused(200),
  resourceLimitExceeded(201),
  permissionDenied(202),
  connectionFailed(203),
  noReservation(204),
  malformedMessage(400),
  unexpectedMessage(401);

  const HopStatus(this.code);
  final int code;

  static HopStatus fromCode(int code) {
    for (final s in HopStatus.values) {
      if (s.code == code) return s;
    }
    return HopStatus.connectionFailed;
  }
}

class CircuitPeer {
  CircuitPeer({required this.id, this.addrs = const []});
  final Uint8List id;
  final List<Uint8List> addrs;
}

class CircuitReservation {
  CircuitReservation({
    required this.expire,
    this.addrs = const [],
    this.voucher,
  });
  final int expire; // Unix timestamp in seconds
  final List<Uint8List> addrs;
  final Uint8List? voucher;
}

class CircuitLimit {
  CircuitLimit({this.duration = 0, this.data = 0});
  final int duration;
  final int data;
}

class HopMessage {
  HopMessage({
    required this.type,
    this.peer,
    this.reservation,
    this.limit,
    this.status = HopStatus.ok,
  });

  final HopMessageType type;
  final CircuitPeer? peer;
  final CircuitReservation? reservation;
  final CircuitLimit? limit;
  final HopStatus status;

  Uint8List marshal() {
    final out = BytesBuilder();

    void writeVarint(int fieldNumber, int value) {
      out.add(encodeProtoVarint((fieldNumber << 3) | 0));
      out.add(encodeProtoVarint(value));
    }

    void writeBytes(int fieldNumber, Uint8List bytes) {
      out.add(encodeProtoVarint((fieldNumber << 3) | 2));
      out.add(encodeProtoVarint(bytes.length));
      out.add(bytes);
    }

    // field 1: type (varint)
    writeVarint(1, type.index);

    // field 3: reservation
    if (reservation != null) {
      final resBuilder = BytesBuilder();
      if (reservation!.expire > 0) {
        resBuilder.add(encodeProtoVarint((1 << 3) | 0));
        resBuilder.add(encodeProtoVarint(reservation!.expire));
      }
      for (final a in reservation!.addrs) {
        resBuilder.add(encodeProtoVarint((2 << 3) | 2));
        resBuilder.add(encodeProtoVarint(a.length));
        resBuilder.add(a);
      }
      if (reservation!.voucher != null) {
        resBuilder.add(encodeProtoVarint((3 << 3) | 2));
        resBuilder.add(encodeProtoVarint(reservation!.voucher!.length));
        resBuilder.add(reservation!.voucher!);
      }
      writeBytes(3, resBuilder.toBytes());
    }

    // field 4: limit
    if (limit != null) {
      final limBuilder = BytesBuilder();
      if (limit!.duration > 0) {
        limBuilder.add(encodeProtoVarint((1 << 3) | 0));
        limBuilder.add(encodeProtoVarint(limit!.duration));
      }
      if (limit!.data > 0) {
        limBuilder.add(encodeProtoVarint((2 << 3) | 0));
        limBuilder.add(encodeProtoVarint(limit!.data));
      }
      writeBytes(4, limBuilder.toBytes());
    }

    // field 5: status (varint)
    if (type == HopMessageType.status) {
      writeVarint(5, status.code);
    }

    return out.toBytes();
  }

  factory HopMessage.unmarshal(Uint8List bytes) {
    var type = HopMessageType.reserve;
    CircuitReservation? reservation;
    CircuitLimit? limit;
    var status = HopStatus.ok;

    var offset = 0;
    while (offset < bytes.length) {
      final (tag, tagLen) = readProtoVarint(bytes, offset);
      offset += tagLen;
      final fieldNumber = tag >> 3;
      final wireType = tag & 0x7;

      if (wireType == 0) {
        final (val, vLen) = readProtoVarint(bytes, offset);
        offset += vLen;
        if (fieldNumber == 1) {
          if (val >= 0 && val < HopMessageType.values.length) {
            type = HopMessageType.values[val];
          }
        } else if (fieldNumber == 5) {
          status = HopStatus.fromCode(val);
        }
      } else if (wireType == 2) {
        final (length, lenLen) = readProtoVarint(bytes, offset);
        offset += lenLen;
        final fieldBytes = bytes.sublist(offset, offset + length);
        offset += length;

        if (fieldNumber == 3) {
          var rOffset = 0;
          var expire = 0;
          final addrs = <Uint8List>[];
          Uint8List? voucher;
          while (rOffset < fieldBytes.length) {
            final (rTag, rTagLen) = readProtoVarint(fieldBytes, rOffset);
            rOffset += rTagLen;
            final rField = rTag >> 3;
            final rWire = rTag & 0x7;
            if (rWire == 0) {
              final (rVal, rValLen) = readProtoVarint(fieldBytes, rOffset);
              rOffset += rValLen;
              if (rField == 1) expire = rVal;
            } else if (rWire == 2) {
              final (rLen, rLenLen) = readProtoVarint(fieldBytes, rOffset);
              rOffset += rLenLen;
              final b = fieldBytes.sublist(rOffset, rOffset + rLen);
              rOffset += rLen;
              if (rField == 2) addrs.add(b);
              if (rField == 3) voucher = b;
            }
          }
          reservation = CircuitReservation(expire: expire, addrs: addrs, voucher: voucher);
        }
      } else {
        break;
      }
    }

    return HopMessage(
      type: type,
      reservation: reservation,
      limit: limit,
      status: status,
    );
  }
}
