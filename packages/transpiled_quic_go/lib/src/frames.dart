// ignore_for_file: public_member_api_docs
import 'dart:convert';
import 'dart:typed_data';

import 'varint.dart';

sealed class QuicFrame {
  const QuicFrame();
  Uint8List encode();
}

/// The maximum size of a DATAGRAM frame (RFC 9221), chosen so that every
/// datagram that fits in a QUIC packet is allowed while the value still
/// encodes as a 2-byte varint. Go: `wire.MaxDatagramSize`
/// (`internal/wire/datagram_frame.go`).
const int maxDatagramSize = 16383;

/// A DATAGRAM frame (RFC 9221), Go's `wire.DatagramFrame`.
///
/// Type 0x30 carries the datagram to the end of the packet; 0x31 prefixes it
/// with an explicit length so other frames can follow.
final class DatagramFrame extends QuicFrame {
  const DatagramFrame(this.data, {this.dataLenPresent = true});

  final Uint8List data;
  final bool dataLenPresent;

  @override
  Uint8List encode() {
    final buf = BytesBuilder(copy: false)
      ..addByte(dataLenPresent ? 0x31 : 0x30);
    if (dataLenPresent) {
      buf.add(appendVarInt(const [], data.length));
    }
    buf.add(data);
    return buf.toBytes();
  }
}

final class PaddingFrame extends QuicFrame {
  const PaddingFrame([this.length = 1]);
  final int length;

  @override
  Uint8List encode() => Uint8List(length);
}

final class PingFrame extends QuicFrame {
  const PingFrame();
  @override
  Uint8List encode() => Uint8List.fromList(const [0x01]);
}

final class AckRange {
  const AckRange({required this.gap, required this.length});
  final int gap;
  final int length;
}

final class AckFrame extends QuicFrame {
  const AckFrame({
    required this.largestAcked,
    this.delayTimeMicros = 0,
    this.firstAckRange = 0,
    this.additionalRanges = const [],
  });

  final int largestAcked;
  final int delayTimeMicros;
  final int firstAckRange;
  final List<AckRange> additionalRanges;

  @override
  Uint8List encode() {
    final buf = BytesBuilder(copy: false);
    buf.add(appendVarInt(const [], 0x02));
    buf.add(appendVarInt(const [], largestAcked));
    buf.add(appendVarInt(const [], delayTimeMicros));
    buf.add(appendVarInt(const [], additionalRanges.length));
    buf.add(appendVarInt(const [], firstAckRange));

    for (final r in additionalRanges) {
      buf.add(appendVarInt(const [], r.gap));
      buf.add(appendVarInt(const [], r.length));
    }
    return buf.toBytes();
  }
}

final class CryptoFrame extends QuicFrame {
  const CryptoFrame(this.offset, this.data);
  final int offset;
  final Uint8List data;

  @override
  Uint8List encode() {
    final header = appendVarInt(
      appendVarInt(appendVarInt(const [], 0x06), offset),
      data.length,
    );
    return Uint8List(header.length + data.length)
      ..setAll(0, header)
      ..setAll(header.length, data);
  }
}

final class StreamFrame extends QuicFrame {
  const StreamFrame({
    required this.streamId,
    required this.offset,
    required this.data,
    this.fin = false,
  });

  final int streamId;
  final int offset;
  final Uint8List data;
  final bool fin;

  @override
  Uint8List encode() {
    final type = 0x0e | (fin ? 1 : 0);
    final header = appendVarInt(
      appendVarInt(
        appendVarInt(appendVarInt(const [], type), streamId),
        offset,
      ),
      data.length,
    );
    return Uint8List(header.length + data.length)
      ..setAll(0, header)
      ..setAll(header.length, data);
  }
}

final class ResetStreamFrame extends QuicFrame {
  const ResetStreamFrame({
    required this.streamId,
    required this.applicationErrorCode,
    required this.finalSize,
  });

  final int streamId;
  final int applicationErrorCode;
  final int finalSize;

  @override
  Uint8List encode() {
    final buf = BytesBuilder(copy: false);
    buf.add(appendVarInt(const [], 0x04));
    buf.add(appendVarInt(const [], streamId));
    buf.add(appendVarInt(const [], applicationErrorCode));
    buf.add(appendVarInt(const [], finalSize));
    return buf.toBytes();
  }
}

final class StopSendingFrame extends QuicFrame {
  const StopSendingFrame({
    required this.streamId,
    required this.applicationErrorCode,
  });

  final int streamId;
  final int applicationErrorCode;

  @override
  Uint8List encode() {
    final buf = BytesBuilder(copy: false);
    buf.add(appendVarInt(const [], 0x05));
    buf.add(appendVarInt(const [], streamId));
    buf.add(appendVarInt(const [], applicationErrorCode));
    return buf.toBytes();
  }
}

final class HandshakeDoneFrame extends QuicFrame {
  const HandshakeDoneFrame();
  @override
  Uint8List encode() => Uint8List.fromList(const [0x1e]);
}

final class NewTokenFrame extends QuicFrame {
  const NewTokenFrame(this.token);
  final Uint8List token;
  @override
  Uint8List encode() {
    final buf = BytesBuilder(copy: false);
    buf.add(appendVarInt(const [], 0x07));
    buf.add(appendVarInt(const [], token.length));
    buf.add(token);
    return buf.toBytes();
  }
}

final class NewConnectionIdFrame extends QuicFrame {
  const NewConnectionIdFrame({
    required this.sequenceNumber,
    required this.retirePriorTo,
    required this.connectionId,
    required this.statelessResetToken,
  });

  final int sequenceNumber;
  final int retirePriorTo;
  final Uint8List connectionId;
  final Uint8List statelessResetToken;

  @override
  Uint8List encode() {
    final buf = BytesBuilder(copy: false);
    buf.add(appendVarInt(const [], 0x18));
    buf.add(appendVarInt(const [], sequenceNumber));
    buf.add(appendVarInt(const [], retirePriorTo));
    buf.addByte(connectionId.length);
    buf.add(connectionId);
    buf.add(statelessResetToken);
    return buf.toBytes();
  }
}

final class MaxDataFrame extends QuicFrame {
  const MaxDataFrame(this.maximumData);
  final int maximumData;
  @override
  Uint8List encode() {
    final buf = BytesBuilder(copy: false);
    buf.add(appendVarInt(const [], 0x10));
    buf.add(appendVarInt(const [], maximumData));
    return buf.toBytes();
  }
}

final class MaxStreamDataFrame extends QuicFrame {
  const MaxStreamDataFrame({
    required this.streamId,
    required this.maximumStreamData,
  });
  final int streamId;
  final int maximumStreamData;
  @override
  Uint8List encode() {
    final buf = BytesBuilder(copy: false);
    buf.add(appendVarInt(const [], 0x11));
    buf.add(appendVarInt(const [], streamId));
    buf.add(appendVarInt(const [], maximumStreamData));
    return buf.toBytes();
  }
}

final class MaxStreamsFrame extends QuicFrame {
  const MaxStreamsFrame({
    required this.isBidirectional,
    required this.maximumStreams,
  });
  final bool isBidirectional;
  final int maximumStreams;
  @override
  Uint8List encode() {
    final buf = BytesBuilder(copy: false);
    buf.add(appendVarInt(const [], isBidirectional ? 0x12 : 0x13));
    buf.add(appendVarInt(const [], maximumStreams));
    return buf.toBytes();
  }
}

final class ConnectionCloseFrame extends QuicFrame {
  const ConnectionCloseFrame({
    required this.errorCode,
    this.isApplicationError = false,
    this.frameType = 0,
    this.reasonPhrase = '',
  });

  final int errorCode;
  final bool isApplicationError;
  final int frameType;
  final String reasonPhrase;

  @override
  Uint8List encode() {
    final buf = BytesBuilder(copy: false);
    buf.add(appendVarInt(const [], isApplicationError ? 0x1d : 0x1c));
    buf.add(appendVarInt(const [], errorCode));
    if (!isApplicationError) {
      buf.add(appendVarInt(const [], frameType));
    }
    final reasonBytes = utf8.encode(reasonPhrase);
    buf.add(appendVarInt(const [], reasonBytes.length));
    buf.add(reasonBytes);
    return buf.toBytes();
  }
}

/// Parses a single frame from the start of [bytes].
QuicFrame parseFrame(Uint8List bytes) {
  final (frame, _) = parseFrameWithLength(bytes, 0);
  return frame;
}

/// Parses a frame starting at [offset], returning the parsed frame and the number of bytes consumed.
(QuicFrame, int bytesRead) parseFrameWithLength(Uint8List bytes, int offset) {
  if (offset >= bytes.length)
    throw const FormatException('Unexpected EOF in frames');
  final (type, typeLen) = parseVarInt(bytes, offset);
  var cursor = offset + typeLen;

  if (type == 0x00) {
    // Count contiguous padding bytes
    var count = 1;
    while (cursor < bytes.length && bytes[cursor] == 0x00) {
      count++;
      cursor++;
    }
    return (PaddingFrame(count), cursor - offset);
  }

  if (type == 0x01) {
    return (const PingFrame(), typeLen);
  }

  if (type == 0x02 || type == 0x03) {
    // ACK frame
    final (la, l1) = parseVarInt(bytes, cursor);
    cursor += l1;
    final (delay, l2) = parseVarInt(bytes, cursor);
    cursor += l2;
    final (numRanges, l3) = parseVarInt(bytes, cursor);
    cursor += l3;
    final (firstRange, l4) = parseVarInt(bytes, cursor);
    cursor += l4;

    final ranges = <AckRange>[];
    for (var i = 0; i < numRanges; i++) {
      final (gap, gLen) = parseVarInt(bytes, cursor);
      cursor += gLen;
      final (rLen, rlLen) = parseVarInt(bytes, cursor);
      cursor += rlLen;
      ranges.add(AckRange(gap: gap, length: rLen));
    }

    if (type == 0x03) {
      // ECN counts (3 varints)
      final (_, e1) = parseVarInt(bytes, cursor);
      cursor += e1;
      final (_, e2) = parseVarInt(bytes, cursor);
      cursor += e2;
      final (_, e3) = parseVarInt(bytes, cursor);
      cursor += e3;
    }

    return (
      AckFrame(
        largestAcked: la,
        delayTimeMicros: delay,
        firstAckRange: firstRange,
        additionalRanges: ranges,
      ),
      cursor - offset,
    );
  }

  if (type == 0x04) {
    final (streamId, n1) = parseVarInt(bytes, cursor);
    cursor += n1;
    final (errorCode, n2) = parseVarInt(bytes, cursor);
    cursor += n2;
    final (finalSize, n3) = parseVarInt(bytes, cursor);
    cursor += n3;
    return (
      ResetStreamFrame(
        streamId: streamId,
        applicationErrorCode: errorCode,
        finalSize: finalSize,
      ),
      cursor - offset,
    );
  }

  if (type == 0x05) {
    final (streamId, n1) = parseVarInt(bytes, cursor);
    cursor += n1;
    final (errorCode, n2) = parseVarInt(bytes, cursor);
    cursor += n2;
    return (
      StopSendingFrame(streamId: streamId, applicationErrorCode: errorCode),
      cursor - offset,
    );
  }

  if (type == 0x06) {
    final (cryptoOffset, n1) = parseVarInt(bytes, cursor);
    cursor += n1;
    final (length, n2) = parseVarInt(bytes, cursor);
    cursor += n2;
    if (bytes.length - cursor < length) {
      throw const FormatException('truncated CRYPTO frame');
    }
    final data = Uint8List.sublistView(bytes, cursor, cursor + length);
    cursor += length;
    return (CryptoFrame(cryptoOffset, data), cursor - offset);
  }

  if (type >= 0x08 && type <= 0x0f) {
    final (streamId, n1) = parseVarInt(bytes, cursor);
    cursor += n1;
    var streamOffset = 0;
    if (type & 0x04 != 0) {
      final parsed = parseVarInt(bytes, cursor);
      streamOffset = parsed.$1;
      cursor += parsed.$2;
    }
    final int length;
    if (type & 0x02 != 0) {
      final parsed = parseVarInt(bytes, cursor);
      length = parsed.$1;
      cursor += parsed.$2;
    } else {
      length = bytes.length - cursor;
    }

    if (bytes.length - cursor < length) {
      throw const FormatException('truncated STREAM frame');
    }
    final data = Uint8List.sublistView(bytes, cursor, cursor + length);
    cursor += length;
    return (
      StreamFrame(
        streamId: streamId,
        offset: streamOffset,
        data: data,
        fin: (type & 0x01) != 0,
      ),
      cursor - offset,
    );
  }

  if (type == 0x07) {
    final (tokLen, n) = parseVarInt(bytes, cursor);
    cursor += n;
    if (bytes.length - cursor < tokLen) {
      throw const FormatException('truncated NEW_TOKEN frame');
    }
    final token = Uint8List.sublistView(bytes, cursor, cursor + tokLen);
    cursor += tokLen;
    return (NewTokenFrame(token), cursor - offset);
  }

  if (type == 0x10) {
    final (maxData, n) = parseVarInt(bytes, cursor);
    cursor += n;
    return (MaxDataFrame(maxData), cursor - offset);
  }

  if (type == 0x11) {
    final (sId, n1) = parseVarInt(bytes, cursor);
    cursor += n1;
    final (maxData, n2) = parseVarInt(bytes, cursor);
    cursor += n2;
    return (
      MaxStreamDataFrame(streamId: sId, maximumStreamData: maxData),
      cursor - offset,
    );
  }

  if (type == 0x12 || type == 0x13) {
    final (maxStreams, n) = parseVarInt(bytes, cursor);
    cursor += n;
    return (
      MaxStreamsFrame(
        isBidirectional: type == 0x12,
        maximumStreams: maxStreams,
      ),
      cursor - offset,
    );
  }

  if (type == 0x18) {
    final (seq, n1) = parseVarInt(bytes, cursor);
    cursor += n1;
    final (retire, n2) = parseVarInt(bytes, cursor);
    cursor += n2;
    final cidLen = bytes[cursor++];
    if (bytes.length - cursor < cidLen + 16) {
      throw const FormatException('truncated NEW_CONNECTION_ID frame');
    }
    final cid = Uint8List.sublistView(bytes, cursor, cursor + cidLen);
    cursor += cidLen;
    final resetToken = Uint8List.sublistView(bytes, cursor, cursor + 16);
    cursor += 16;
    return (
      NewConnectionIdFrame(
        sequenceNumber: seq,
        retirePriorTo: retire,
        connectionId: cid,
        statelessResetToken: resetToken,
      ),
      cursor - offset,
    );
  }

  if (type == 0x1e) {
    return (const HandshakeDoneFrame(), typeLen);
  }

  if (type == 0x1c || type == 0x1d) {
    final isApp = type == 0x1d;
    final (code, cLen) = parseVarInt(bytes, cursor);
    cursor += cLen;
    var frameType = 0;
    if (!isApp) {
      final (ft, ftLen) = parseVarInt(bytes, cursor);
      frameType = ft;
      cursor += ftLen;
    }
    final (reasonLen, rLen) = parseVarInt(bytes, cursor);
    cursor += rLen;
    if (bytes.length - cursor < reasonLen) {
      throw const FormatException(
        'truncated reason phrase in CONNECTION_CLOSE',
      );
    }
    final reasonPhrase = utf8.decode(
      Uint8List.sublistView(bytes, cursor, cursor + reasonLen),
    );
    cursor += reasonLen;
    return (
      ConnectionCloseFrame(
        errorCode: code,
        isApplicationError: isApp,
        frameType: frameType,
        reasonPhrase: reasonPhrase,
      ),
      cursor - offset,
    );
  }

  if (type == 0x30 || type == 0x31) {
    final dataLenPresent = (type & 0x01) != 0;
    final int length;
    if (dataLenPresent) {
      final parsed = parseVarInt(bytes, cursor);
      length = parsed.$1;
      cursor += parsed.$2;
      if (bytes.length - cursor < length) {
        throw const FormatException('truncated DATAGRAM frame');
      }
    } else {
      length = bytes.length - cursor;
    }
    final data = Uint8List.sublistView(bytes, cursor, cursor + length);
    cursor += length;
    return (
      DatagramFrame(Uint8List.fromList(data), dataLenPresent: dataLenPresent),
      cursor - offset,
    );
  }

  throw FormatException('unsupported QUIC frame type: $type');
}

/// Parses all frames from [payloadBytes].
List<QuicFrame> parseFrames(Uint8List payloadBytes) {
  final frames = <QuicFrame>[];
  var cursor = 0;
  while (cursor < payloadBytes.length) {
    final (frame, bytesRead) = parseFrameWithLength(payloadBytes, cursor);
    frames.add(frame);
    cursor += bytesRead;
  }
  return frames;
}
