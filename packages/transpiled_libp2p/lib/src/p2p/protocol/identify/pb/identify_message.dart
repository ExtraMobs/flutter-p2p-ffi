// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/crypto/key_codec.dart';
import '../../../../core/crypto/key_types.dart';
import '../../../../core/crypto/proto_varint.dart';

/// Protobuf representation of the Identify message (/ipfs/id/1.0.0).
class Identify {
  Identify({
    this.publicKey,
    this.listenAddrs = const [],
    this.protocols = const [],
    this.observedAddr,
    this.protocolVersion = '',
    this.agentVersion = '',
    this.signedPeerRecord,
  });

  final PubKey? publicKey;
  final List<Uint8List> listenAddrs;
  final List<String> protocols;
  final Uint8List? observedAddr;
  final String protocolVersion;
  final String agentVersion;
  final Uint8List? signedPeerRecord;

  Uint8List marshal() {
    final out = BytesBuilder();

    void writeBytes(int fieldNumber, Uint8List bytes) {
      out.add(encodeProtoVarint((fieldNumber << 3) | 2));
      out.add(encodeProtoVarint(bytes.length));
      out.add(bytes);
    }

    void writeString(int fieldNumber, String s) {
      final b = utf8.encode(s);
      writeBytes(fieldNumber, Uint8List.fromList(b));
    }

    if (publicKey != null) {
      writeBytes(1, marshalPublicKey(publicKey!));
    }
    for (final addr in listenAddrs) {
      writeBytes(2, addr);
    }
    for (final p in protocols) {
      writeString(3, p);
    }
    if (observedAddr != null) {
      writeBytes(4, observedAddr!);
    }
    if (protocolVersion.isNotEmpty) {
      writeString(5, protocolVersion);
    }
    if (agentVersion.isNotEmpty) {
      writeString(6, agentVersion);
    }
    if (signedPeerRecord != null) {
      writeBytes(8, signedPeerRecord!);
    }

    return out.toBytes();
  }

  factory Identify.unmarshal(Uint8List bytes) {
    PubKey? publicKey;
    final listenAddrs = <Uint8List>[];
    final protocols = <String>[];
    Uint8List? observedAddr;
    var protocolVersion = '';
    var agentVersion = '';
    Uint8List? signedPeerRecord;

    var offset = 0;
    while (offset < bytes.length) {
      final (tag, tagLen) = readProtoVarint(bytes, offset);
      offset += tagLen;
      final fieldNumber = tag >> 3;
      final wireType = tag & 0x7;

      if (wireType == 2) {
        final (length, lenLen) = readProtoVarint(bytes, offset);
        offset += lenLen;
        if (offset + length > bytes.length) {
          throw const FormatException('protobuf field runs past end of message');
        }
        final fieldBytes = bytes.sublist(offset, offset + length);
        offset += length;

        switch (fieldNumber) {
          case 1:
            try {
              publicKey = unmarshalPublicKey(fieldBytes);
            } catch (_) {}
            break;
          case 2:
            listenAddrs.add(fieldBytes);
            break;
          case 3:
            protocols.add(utf8.decode(fieldBytes));
            break;
          case 4:
            observedAddr = fieldBytes;
            break;
          case 5:
            protocolVersion = utf8.decode(fieldBytes);
            break;
          case 6:
            agentVersion = utf8.decode(fieldBytes);
            break;
          case 8:
            signedPeerRecord = fieldBytes;
            break;
        }
      } else if (wireType == 0) {
        final (_, vLen) = readProtoVarint(bytes, offset);
        offset += vLen;
      } else if (wireType == 1) {
        offset += 8;
      } else if (wireType == 5) {
        offset += 4;
      } else {
        throw FormatException('unsupported wire type $wireType in Identify');
      }
    }

    return Identify(
      publicKey: publicKey,
      listenAddrs: listenAddrs,
      protocols: protocols,
      observedAddr: observedAddr,
      protocolVersion: protocolVersion,
      agentVersion: agentVersion,
      signedPeerRecord: signedPeerRecord,
    );
  }
}
