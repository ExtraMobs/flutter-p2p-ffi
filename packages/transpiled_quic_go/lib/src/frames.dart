import 'dart:typed_data';

import 'varint.dart';

sealed class QuicFrame {
  const QuicFrame();
  Uint8List encode();
}

final class PingFrame extends QuicFrame {
  const PingFrame();
  @override
  Uint8List encode() => Uint8List.fromList(const [0x01]);
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

QuicFrame parseFrame(Uint8List bytes) {
  final (type, typeLen) = parseVarInt(bytes);
  if (type == 0x01) return const PingFrame();
  var cursor = typeLen;
  if (type == 0x06) {
    final (offset, n1) = parseVarInt(bytes, cursor);
    cursor += n1;
    final (length, n2) = parseVarInt(bytes, cursor);
    cursor += n2;
    if (bytes.length - cursor < length)
      throw const FormatException('truncated CRYPTO frame');
    return CryptoFrame(
      offset,
      Uint8List.sublistView(bytes, cursor, cursor + length),
    );
  }
  if (type >= 0x08 && type <= 0x0f) {
    final (streamId, n1) = parseVarInt(bytes, cursor);
    cursor += n1;
    var offset = 0;
    if (type & 0x04 != 0) {
      final parsed = parseVarInt(bytes, cursor);
      offset = parsed.$1;
      cursor += parsed.$2;
    }
    final length = type & 0x02 != 0
        ? parseVarInt(bytes, cursor)
        : (bytes.length - cursor, 0);
    cursor += length.$2;
    if (bytes.length - cursor < length.$1)
      throw const FormatException('truncated STREAM frame');
    return StreamFrame(
      streamId: streamId,
      offset: offset,
      data: Uint8List.sublistView(bytes, cursor, cursor + length.$1),
      fin: type & 1 != 0,
    );
  }
  throw FormatException('unsupported QUIC frame type: $type');
}
