// SPDX-FileCopyrightText: 2023 The Go-Libp2p Authors
// SPDX-License-Identifier: MIT

// ignore_for_file: public_member_api_docs

import 'dart:io';
import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:transpiled_multibase/transpiled_multibase.dart' as multibase;
import 'package:transpiled_multihash/transpiled_multihash.dart' as multihash;

const String clientSdpTemplate = '''v=0
o=- 0 0 IN %1 %2
s=-
c=IN %1 %2
t=0 0

m=application %3 UDP/DTLS/SCTP webrtc-datachannel
a=mid:0
a=ice-options:ice2
a=ice-ufrag:%4
a=ice-pwd:%5
a=fingerprint:sha-256 ba:78:16:bf:8f:01:cf:ea:41:41:40:de:5d:ae:22:23:b0:03:61:a3:96:17:7a:9c:b4:10:ff:61:f2:00:15:ad
a=setup:actpass
a=sctp-port:5000
a=max-message-size:16384
''';

const String serverSdpTemplate = '''v=0
o=- 0 0 IN %1 %2
s=-
t=0 0
a=ice-lite
m=application %3 UDP/DTLS/SCTP webrtc-datachannel
c=IN %1 %2
a=mid:0
a=ice-options:ice2
a=ice-ufrag:%4
a=ice-pwd:%4
a=fingerprint:%5

a=setup:passive
a=sctp-port:5000
a=max-message-size:16384
a=candidate:1 1 UDP 1 %2 %3 typ host
a=end-of-candidates
''';

String createClientSDP(
  InternetAddress addr,
  int port,
  String ufrag,
  String pwd,
) {
  final ipVersion = addr.type == InternetAddressType.IPv6 ? 'IP6' : 'IP4';
  return clientSdpTemplate
      .replaceAll('%1', ipVersion)
      .replaceAll('%2', addr.address)
      .replaceAll('%3', port.toString())
      .replaceAll('%4', ufrag)
      .replaceAll('%5', pwd);
}

String createServerSDP(
  InternetAddress addr,
  int port,
  String ufrag,
  Uint8List fingerprintDigest,
) {
  final ipVersion = addr.type == InternetAddressType.IPv6 ? 'IP6' : 'IP4';
  final hexFp = encodeInterspersedHex(fingerprintDigest);
  final fpLine = 'sha-256 $hexFp';
  return serverSdpTemplate
      .replaceAll('%1', ipVersion)
      .replaceAll('%2', addr.address)
      .replaceAll('%3', port.toString())
      .replaceAll('%4', ufrag)
      .replaceAll('%5', fpLine);
}

String encodeInterspersedHex(Uint8List bytes) {
  final sb = StringBuffer();
  for (var i = 0; i < bytes.length; i++) {
    if (i > 0) sb.write(':');
    sb.write(bytes[i].toRadixString(16).padLeft(2, '0').toLowerCase());
  }
  return sb.toString();
}

Uint8List decodeInterspersedHexFromASCIIString(String str) {
  final clean = str.replaceAll(':', '').replaceAll(' ', '');
  final bytes = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

/// Decodes the remote DTLS certificate fingerprint from a /certhash component.
multihash.DecodedMultihash decodeRemoteFingerprint(Multiaddr addr) {
  final certhashComp = addr.components
      .where(
        (c) =>
            c.protocol.code == Protocols.certhash ||
            c.protocol.name == 'certhash',
      )
      .firstOrNull;

  if (certhashComp == null) {
    throw ArgumentError('Address $addr does not contain a /certhash component');
  }

  final (_, data) = multibase.decode(certhashComp.value);
  return multihash.decode(data);
}

/// Encodes a raw SHA-256 fingerprint into a multibase base64url certhash string.
String encodeDTLSFingerprint(Uint8List digest) {
  final mh = multihash.encode(digest, Golang.Uint64(multihash.sha2_256));
  return multibase.encode(multibase.Encoding.base58btc, mh);
}
