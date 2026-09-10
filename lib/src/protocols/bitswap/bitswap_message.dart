import 'dart:typed_data';

import 'package:transpiled_block_format/transpiled_block_format.dart' as blocks;
import 'package:transpiled_boxo/bitswap/message.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

/// Maximum libp2p message size, matching go-libp2p `MessageSizeMax`.
const int bitswapMessageSizeMax = 1 << 22;

/// Creates a varint-framed Bitswap `WANT_BLOCK` message delegating to [BitSwapMessage].
Uint8List encodeWantBlock(Cid cid, {int priority = 1}) {
  final msg = BitSwapMessage(false);
  msg.addEntry(cid, priority, WantType.block, true);
  final buf = Buffer();
  msg.toNetV1(buf);
  return buf.bytes();
}

/// Encodes a [BitSwapMessage] into a varint-framed wire format byte buffer.
Uint8List encodeBitswapMessage(BitSwapMessage message) {
  final buf = Buffer();
  message.toNetV1(buf);
  return buf.bytes();
}

/// Reads one varint-framed Bitswap protobuf message and decodes to [BitSwapMessage].
Future<BitSwapMessage> readBitswapMessage(NetworkStream stream) async {
  var length = 0;
  var shift = 0;
  for (var index = 0; index < 10; index++) {
    final byte = await _readExactly(stream, 1);
    length |= (byte.single & 0x7f) << shift;
    if ((byte.single & 0x80) == 0) {
      if (length > bitswapMessageSizeMax) {
        throw const FormatException('Bitswap message exceeds 4 MiB');
      }
      final payload = await _readExactly(stream, length);
      return BitSwapMessage.fromBytes(payload);
    }
    shift += 7;
  }
  throw const FormatException('Bitswap frame length varint is too long');
}

/// Extracts and validates a requested block from a decoded message.
blocks.Block? blockFromMessage(BitSwapMessage message, Cid requested) {
  for (final block in message.blocks()) {
    if (block.cid() == requested) return block;
  }
  if (message.dontHaves().contains(requested)) {
    throw StateError('Bitswap provider does not have $requested');
  }
  return null;
}

Future<Uint8List> _readExactly(NetworkStream stream, int length) async {
  final output = BytesBuilder(copy: false);
  while (output.length < length) {
    final chunk = await stream.read(length - output.length);
    if (chunk.isEmpty) {
      throw const FormatException('Unexpected EOF in Bitswap frame');
    }
    output.add(chunk);
  }
  return output.takeBytes();
}
