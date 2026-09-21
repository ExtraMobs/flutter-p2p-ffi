// ignore_for_file: public_member_api_docs
import 'dart:typed_data';

import 'varint.dart';

/// QUIC Packet Types for Long Headers (RFC 9000, Section 17.2).
const int packetTypeInitial = 0x00;
const int packetType0RTT = 0x01;
const int packetTypeHandshake = 0x02;
const int packetTypeRetry = 0x03;

/// QUIC Version 1 (RFC 9000).
const int quicVersion1 = 0x00000001;

/// Base QUIC Header representation (RFC 9000, Section 17).
class Header {
  Header({
    required this.isLongHeader,
    this.type = packetTypeInitial,
    this.version = quicVersion1,
    Uint8List? destConnectionId,
    Uint8List? srcConnectionId,
    Uint8List? token,
    this.length = 0,
  }) : destConnectionId = destConnectionId ?? Uint8List(0),
       srcConnectionId = srcConnectionId ?? Uint8List(0),
       token = token ?? Uint8List(0);

  final bool isLongHeader;
  int type;
  int version;
  Uint8List destConnectionId;
  Uint8List srcConnectionId;
  Uint8List token;
  int length;
}

/// ExtendedHeader includes the packet number and key phase bit.
class ExtendedHeader extends Header {
  ExtendedHeader({
    required super.isLongHeader,
    super.type = packetTypeInitial,
    super.version = quicVersion1,
    super.destConnectionId,
    super.srcConnectionId,
    super.token,
    super.length = 0,
    this.packetNumber = 0,
    this.packetNumberLen = 4,
    this.keyPhase = 0,
  });

  int packetNumber;
  int packetNumberLen;
  int keyPhase;

  /// Serializes the header to bytes according to RFC 9000 Section 17.
  Uint8List append([List<int> prefix = const []]) {
    final buf = BytesBuilder(copy: false);
    buf.add(prefix);

    if (isLongHeader) {
      // First byte: 0xc0 | (type << 4) | (packetNumberLen - 1)
      final firstByte =
          0xc0 | ((type & 0x03) << 4) | ((packetNumberLen - 1) & 0x03);
      buf.addByte(firstByte);

      // Version (4 bytes big-endian)
      buf.addByte((version >> 24) & 0xff);
      buf.addByte((version >> 16) & 0xff);
      buf.addByte((version >> 8) & 0xff);
      buf.addByte(version & 0xff);

      // DCID
      buf.addByte(destConnectionId.length);
      buf.add(destConnectionId);

      // SCID
      buf.addByte(srcConnectionId.length);
      buf.add(srcConnectionId);

      // Token (only for Initial packets)
      if (type == packetTypeInitial) {
        buf.add(appendVarInt(const [], token.length));
        buf.add(token);
      }

      // Length (varint)
      buf.add(appendVarInt(const [], length));

      // Packet Number (1, 2, 3, or 4 bytes)
      _appendPacketNumber(buf, packetNumber, packetNumberLen);
    } else {
      // Short Header (1-RTT)
      final firstByte =
          0x40 | ((keyPhase & 0x01) << 2) | ((packetNumberLen - 1) & 0x03);
      buf.addByte(firstByte);

      // DCID
      buf.add(destConnectionId);

      // Packet Number
      _appendPacketNumber(buf, packetNumber, packetNumberLen);
    }

    return buf.toBytes();
  }

  static void _appendPacketNumber(BytesBuilder buf, int pn, int len) {
    switch (len) {
      case 1:
        buf.addByte(pn & 0xff);
      case 2:
        buf.addByte((pn >> 8) & 0xff);
        buf.addByte(pn & 0xff);
      case 3:
        buf.addByte((pn >> 16) & 0xff);
        buf.addByte((pn >> 8) & 0xff);
        buf.addByte(pn & 0xff);
      case 4:
        buf.addByte((pn >> 24) & 0xff);
        buf.addByte((pn >> 16) & 0xff);
        buf.addByte((pn >> 8) & 0xff);
        buf.addByte(pn & 0xff);
      default:
        throw ArgumentError('Invalid packet number length: $len');
    }
  }

  /// Parses header fields from an unmasked packet.
  static (ExtendedHeader, int headerLength) parse(
    Uint8List data, {
    int destConnIdLen = 0,
  }) {
    if (data.isEmpty) throw const FormatException('Empty QUIC packet');
    final firstByte = data[0];
    final isLong = (firstByte & 0x80) != 0;

    if (isLong) {
      if ((firstByte & 0x40) == 0) {
        throw const FormatException('Fixed bit must be 1 in QUIC long header');
      }
      final type = (firstByte >> 4) & 0x03;
      final pnLen = (firstByte & 0x03) + 1;

      var cursor = 1;
      if (data.length < cursor + 4)
        throw const FormatException('Truncated QUIC version');
      final version =
          (data[cursor] << 24) |
          (data[cursor + 1] << 16) |
          (data[cursor + 2] << 8) |
          data[cursor + 3];
      cursor += 4;

      if (data.length < cursor + 1)
        throw const FormatException('Truncated DCID len');
      final dcidLen = data[cursor++];
      if (data.length < cursor + dcidLen)
        throw const FormatException('Truncated DCID');
      final dcid = Uint8List.sublistView(data, cursor, cursor + dcidLen);
      cursor += dcidLen;

      if (data.length < cursor + 1)
        throw const FormatException('Truncated SCID len');
      final scidLen = data[cursor++];
      if (data.length < cursor + scidLen)
        throw const FormatException('Truncated SCID');
      final scid = Uint8List.sublistView(data, cursor, cursor + scidLen);
      cursor += scidLen;

      Uint8List token = Uint8List(0);
      if (type == packetTypeInitial) {
        final (tokenLen, n1) = parseVarInt(data, cursor);
        cursor += n1;
        if (data.length < cursor + tokenLen)
          throw const FormatException('Truncated token');
        token = Uint8List.sublistView(data, cursor, cursor + tokenLen);
        cursor += tokenLen;
      }

      final (length, n2) = parseVarInt(data, cursor);
      cursor += n2;

      // Packet number
      if (data.length < cursor + pnLen)
        throw const FormatException('Truncated packet number');
      var pn = 0;
      for (var i = 0; i < pnLen; i++) {
        pn = (pn << 8) | data[cursor++];
      }

      return (
        ExtendedHeader(
          isLongHeader: true,
          type: type,
          version: version,
          destConnectionId: Uint8List.fromList(dcid),
          srcConnectionId: Uint8List.fromList(scid),
          token: token,
          length: length,
          packetNumber: pn,
          packetNumberLen: pnLen,
        ),
        cursor,
      );
    } else {
      // Short Header
      final pnLen = (firstByte & 0x03) + 1;
      final keyPhase = (firstByte >> 2) & 0x01;
      var cursor = 1;

      if (data.length < cursor + destConnIdLen) {
        throw const FormatException('Truncated Short Header DCID');
      }
      final dcid = Uint8List.sublistView(data, cursor, cursor + destConnIdLen);
      cursor += destConnIdLen;

      if (data.length < cursor + pnLen) {
        throw const FormatException('Truncated Short Header packet number');
      }
      var pn = 0;
      for (var i = 0; i < pnLen; i++) {
        pn = (pn << 8) | data[cursor++];
      }

      return (
        ExtendedHeader(
          isLongHeader: false,
          destConnectionId: Uint8List.fromList(dcid),
          packetNumber: pn,
          packetNumberLen: pnLen,
          keyPhase: keyPhase,
        ),
        cursor,
      );
    }
  }
}
