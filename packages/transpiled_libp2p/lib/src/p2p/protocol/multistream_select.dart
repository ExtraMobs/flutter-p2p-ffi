// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:convert';
import 'dart:typed_data';

import '../../core/crypto/proto_varint.dart';
import '../../core/network/network.dart';
import '../../core/protocol/protocol.dart';

/// Multistream-select 1.0.0 protocol identifier.
const String multistreamProtocol = '/multistream/1.0.0';

/// Writes a varint-delimited string message to [stream].
Future<void> writeDelimited(StreamReadWriter stream, String message) async {
  final body = utf8.encode(message.endsWith('\n') ? message : '$message\n');
  final prefix = encodeProtoVarint(body.length);
  final wire = Uint8List(prefix.length + body.length);
  wire.setRange(0, prefix.length, prefix);
  wire.setRange(prefix.length, wire.length, body);
  await stream.write(wire);
}

/// Reads a varint-delimited string message from [stream].
///
/// Reads the length prefix byte-by-byte to avoid consuming trailing protocol data.
Future<String> readDelimited(StreamReadWriter stream) async {
  var length = 0;
  var shift = 0;
  for (var i = 0; i < 10; i++) {
    final byte = await stream.read(1);
    if (byte.isEmpty) {
      throw StateError('EOF reading multistream varint');
    }
    final b = byte[0];
    length |= (b & 0x7f) << shift;
    if ((b & 0x80) == 0) break;
    shift += 7;
  }

  if (length <= 0) return '';
  final buffer = BytesBuilder(copy: false);
  while (buffer.length < length) {
    final chunk = await stream.read(length - buffer.length);
    if (chunk.isEmpty) {
      throw StateError('EOF reading multistream payload: expected $length bytes, got ${buffer.length}');
    }
    buffer.add(chunk);
  }

  var text = utf8.decode(buffer.toBytes());
  if (text.endsWith('\n')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

/// Performs initiator-side multistream negotiation on [stream], selecting the first
/// mutually supported protocol from [preferredProtocols].
Future<ProtocolId> selectOutbound(
  StreamReadWriter stream,
  List<ProtocolId> preferredProtocols,
) async {
  await writeDelimited(stream, multistreamProtocol);
  final header = await readDelimited(stream);
  if (header != multistreamProtocol) {
    throw StateError('Multistream protocol mismatch: expected $multistreamProtocol, got $header');
  }

  for (final proto in preferredProtocols) {
    await writeDelimited(stream, proto);
    final response = await readDelimited(stream);
    if (response == proto) {
      return proto;
    }
    if (response == 'na') {
      continue;
    }
    throw StateError('Unexpected multistream response for $proto: $response');
  }
  throw StateError('Protocols not supported: $preferredProtocols');
}

/// Performs responder-side multistream negotiation on [stream] using [supportedProtocols].
Future<ProtocolId> selectInbound(
  StreamReadWriter stream,
  List<ProtocolId> supportedProtocols,
) async {
  final header = await readDelimited(stream);
  if (header != multistreamProtocol) {
    throw StateError('Multistream protocol mismatch: expected $multistreamProtocol, got $header');
  }
  await writeDelimited(stream, multistreamProtocol);

  while (true) {
    final requested = await readDelimited(stream);
    if (requested == 'ls') {
      // Send protocol list
      for (final p in supportedProtocols) {
        await writeDelimited(stream, p);
      }
      continue;
    }
    if (supportedProtocols.contains(requested)) {
      await writeDelimited(stream, requested);
      return requested;
    }
    await writeDelimited(stream, 'na');
  }
}
