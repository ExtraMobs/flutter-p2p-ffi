// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
part of 'interface.dart';

/// Error wraps errors signalled by AutoNAT services.
class AutoNatException implements Exception {
  AutoNatException({required this.status, this.text = ''});

  final int status;
  final String text;

  /// Returns true if the error was due to a dial back failure
  bool isDialError() => status == 100;

  /// Returns true if the error was due to a refusal to dial back
  bool isDialRefused() => status == 101;

  @override
  String toString() => 'AutoNatException: $text (status=$status)';
}

/// IsDialError returns true if the AutoNAT peer signalled an error dialing back.
bool isDialError(Object? e) {
  if (e is AutoNatException) {
    return e.isDialError();
  }
  return false;
}

/// IsDialRefused returns true if the AutoNAT peer signalled refusal to dial back.
bool isDialRefused(Object? e) {
  if (e is AutoNatException) {
    return e.isDialRefused();
  }
  return false;
}

/// _Client is the default implementation of [Client], matching unexported client struct in Go.
class _Client implements Client {
  _Client({required this.host, this.addrFunc});

  final Host host;
  final AddrFunc? addrFunc;

  @override
  Future<void> dialBack(PeerId p) async {
    final stream = await host.newStream(p, [autoNatProto]);
    try {
      final addrs = addrFunc?.call() ?? host.addrs;
      final req = _AutonatMessage.makeDialMessage(
        AddrInfo(id: host.id, addrs: addrs),
      );
      await _writeDelimited(stream, req.marshal());

      final resBytes = await _readDelimited(stream);
      if (resBytes == null) {
        throw AutoNatException(
          status: 300,
          text: 'empty response from AutoNAT peer',
        );
      }
      final res = _AutonatMessage.unmarshal(resBytes);
      if (res.type != _AutonatMessageType.dialResponse) {
        throw AutoNatException(
          status: 300,
          text: 'unexpected response type: ${res.type}',
        );
      }

      final status = res.dialResponse?.status?.value ?? 300;
      if (status == 0) {
        return;
      }
      throw AutoNatException(
        status: status,
        text: res.dialResponse?.statusText ?? '',
      );
    } catch (_) {
      try {
        await stream.reset();
      } catch (_) {}
      rethrow;
    } finally {
      try {
        await stream.close();
      } catch (_) {}
    }
  }

  static Future<Uint8List?> _readDelimited(NetworkStream stream) async {
    final firstByte = await stream.read(1);
    if (firstByte.isEmpty) return null;
    var len = firstByte[0] & 0x7f;
    var shift = 7;
    if ((firstByte[0] & 0x80) != 0) {
      while (true) {
        final b = await stream.read(1);
        if (b.isEmpty) return null;
        len |= (b[0] & 0x7f) << shift;
        if ((b[0] & 0x80) == 0) break;
        shift += 7;
      }
    }
    if (len == 0) return Uint8List(0);
    final buf = <int>[];
    while (buf.length < len) {
      final chunk = await stream.read(len - buf.length);
      if (chunk.isEmpty) break;
      buf.addAll(chunk);
    }
    return Uint8List.fromList(buf);
  }

  static Future<void> _writeDelimited(
    NetworkStream stream,
    Uint8List data,
  ) async {
    final prefix = encodeProtoVarint(data.length);
    final packet = Uint8List(prefix.length + data.length);
    packet.setRange(0, prefix.length, prefix);
    packet.setRange(prefix.length, packet.length, data);
    await stream.write(packet);
  }
}
