// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages, unused_element
part of 'interface.dart';

/// AutoNATProto identifies the autonat service protocol
const String autoNatProto = '/libp2p/autonat/1.0.0';

enum _AutonatMessageType {
  dial(0),
  dialResponse(1);

  const _AutonatMessageType(this.value);
  final int value;

  static _AutonatMessageType? fromValue(int v) {
    for (final t in _AutonatMessageType.values) {
      if (t.value == v) return t;
    }
    return null;
  }
}

enum _AutonatResponseStatus {
  ok(0),
  eDialError(100),
  eDialRefused(101),
  eBadRequest(200),
  eInternalError(300);

  const _AutonatResponseStatus(this.value);
  final int value;

  static _AutonatResponseStatus fromValue(int v) {
    for (final s in _AutonatResponseStatus.values) {
      if (s.value == v) return s;
    }
    return _AutonatResponseStatus.eInternalError;
  }
}

class _AutonatPeerInfo {
  _AutonatPeerInfo({this.id, this.addrs = const []});
  final Uint8List? id;
  final List<Uint8List> addrs;
}

class _AutonatDial {
  _AutonatDial({this.peer});
  final _AutonatPeerInfo? peer;
}

class _AutonatDialResponse {
  _AutonatDialResponse({this.status, this.statusText, this.addr});
  final _AutonatResponseStatus? status;
  final String? statusText;
  final Uint8List? addr;
}

class _AutonatMessage {
  _AutonatMessage({this.type, this.dial, this.dialResponse});

  final _AutonatMessageType? type;
  final _AutonatDial? dial;
  final _AutonatDialResponse? dialResponse;

  static _AutonatMessage makeDialMessage(AddrInfo pi) {
    return _AutonatMessage(
      type: _AutonatMessageType.dial,
      dial: _AutonatDial(
        peer: _AutonatPeerInfo(
          id: pi.id.value,
          addrs: pi.addrs.map((a) => a.toBytes()).toList(),
        ),
      ),
    );
  }

  static _AutonatDialResponse makeDialResponseOk(Multiaddr addr) {
    return _AutonatDialResponse(
      status: _AutonatResponseStatus.ok,
      addr: addr.toBytes(),
    );
  }

  static _AutonatDialResponse makeDialResponseError(
    _AutonatResponseStatus status,
    String text,
  ) {
    return _AutonatDialResponse(status: status, statusText: text);
  }

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

    // field 1: type
    if (type != null) {
      writeVarint(1, type!.value);
    }

    // field 2: dial
    if (dial != null) {
      final dialBuilder = BytesBuilder();
      if (dial!.peer != null) {
        final peerBuilder = BytesBuilder();
        if (dial!.peer!.id != null) {
          peerBuilder.add(encodeProtoVarint((1 << 3) | 2));
          peerBuilder.add(encodeProtoVarint(dial!.peer!.id!.length));
          peerBuilder.add(dial!.peer!.id!);
        }
        for (final a in dial!.peer!.addrs) {
          peerBuilder.add(encodeProtoVarint((2 << 3) | 2));
          peerBuilder.add(encodeProtoVarint(a.length));
          peerBuilder.add(a);
        }
        final peerBytes = peerBuilder.toBytes();
        dialBuilder.add(encodeProtoVarint((1 << 3) | 2));
        dialBuilder.add(encodeProtoVarint(peerBytes.length));
        dialBuilder.add(peerBytes);
      }
      writeBytes(2, dialBuilder.toBytes());
    }

    // field 3: dialResponse
    if (dialResponse != null) {
      final resBuilder = BytesBuilder();
      if (dialResponse!.status != null) {
        resBuilder.add(encodeProtoVarint((1 << 3) | 0));
        resBuilder.add(encodeProtoVarint(dialResponse!.status!.value));
      }
      if (dialResponse!.statusText != null) {
        final textBytes = utf8.encode(dialResponse!.statusText!);
        resBuilder.add(encodeProtoVarint((2 << 3) | 2));
        resBuilder.add(encodeProtoVarint(textBytes.length));
        resBuilder.add(textBytes);
      }
      if (dialResponse!.addr != null) {
        resBuilder.add(encodeProtoVarint((3 << 3) | 2));
        resBuilder.add(encodeProtoVarint(dialResponse!.addr!.length));
        resBuilder.add(dialResponse!.addr!);
      }
      writeBytes(3, resBuilder.toBytes());
    }

    return out.toBytes();
  }

  factory _AutonatMessage.unmarshal(Uint8List bytes) {
    _AutonatMessageType? type;
    _AutonatDial? dial;
    _AutonatDialResponse? dialResponse;

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
          type = _AutonatMessageType.fromValue(val);
        }
      } else if (wireType == 2) {
        final (length, lenLen) = readProtoVarint(bytes, offset);
        offset += lenLen;
        final fieldBytes = bytes.sublist(offset, offset + length);
        offset += length;

        if (fieldNumber == 2) {
          // dial
          var dOffset = 0;
          _AutonatPeerInfo? peer;
          while (dOffset < fieldBytes.length) {
            final (dTag, dTagLen) = readProtoVarint(fieldBytes, dOffset);
            dOffset += dTagLen;
            final dField = dTag >> 3;
            final dWire = dTag & 0x7;
            if (dWire == 2 && dField == 1) {
              final (pLen, pLenLen) = readProtoVarint(fieldBytes, dOffset);
              dOffset += pLenLen;
              final peerBytes = fieldBytes.sublist(dOffset, dOffset + pLen);
              dOffset += pLen;

              var pOffset = 0;
              Uint8List? id;
              final addrs = <Uint8List>[];
              while (pOffset < peerBytes.length) {
                final (pTag, pTagLen) = readProtoVarint(peerBytes, pOffset);
                pOffset += pTagLen;
                final pField = pTag >> 3;
                final pWire = pTag & 0x7;
                if (pWire == 2) {
                  final (bLen, bLenLen) = readProtoVarint(peerBytes, pOffset);
                  pOffset += bLenLen;
                  final b = peerBytes.sublist(pOffset, pOffset + bLen);
                  pOffset += bLen;
                  if (pField == 1) id = b;
                  if (pField == 2) addrs.add(b);
                } else {
                  break;
                }
              }
              peer = _AutonatPeerInfo(id: id, addrs: addrs);
            } else {
              break;
            }
          }
          dial = _AutonatDial(peer: peer);
        } else if (fieldNumber == 3) {
          // dialResponse
          var rOffset = 0;
          _AutonatResponseStatus? status;
          String? statusText;
          Uint8List? addr;
          while (rOffset < fieldBytes.length) {
            final (rTag, rTagLen) = readProtoVarint(fieldBytes, rOffset);
            rOffset += rTagLen;
            final rField = rTag >> 3;
            final rWire = rTag & 0x7;
            if (rWire == 0 && rField == 1) {
              final (rVal, rValLen) = readProtoVarint(fieldBytes, rOffset);
              rOffset += rValLen;
              status = _AutonatResponseStatus.fromValue(rVal);
            } else if (rWire == 2) {
              final (rLen, rLenLen) = readProtoVarint(fieldBytes, rOffset);
              rOffset += rLenLen;
              final b = fieldBytes.sublist(rOffset, rOffset + rLen);
              rOffset += rLen;
              if (rField == 2) statusText = utf8.decode(b);
              if (rField == 3) addr = b;
            } else {
              break;
            }
          }
          dialResponse = _AutonatDialResponse(
            status: status,
            statusText: statusText,
            addr: addr,
          );
        }
      } else {
        break;
      }
    }

    return _AutonatMessage(type: type, dial: dial, dialResponse: dialResponse);
  }
}
