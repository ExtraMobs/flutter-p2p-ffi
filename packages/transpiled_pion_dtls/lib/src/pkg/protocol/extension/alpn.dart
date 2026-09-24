part of 'extension.dart';

// Port of pkg/protocol/extension/alpn.go.

/// ALPN is a TLS extension for application-layer protocol negotiation
/// within the TLS handshake.
/// https://tools.ietf.org/html/rfc7301
///
/// Port of `ALPN` (alpn.go:14-16) and its methods
/// `TypeValue`/`Marshal`/`Unmarshal` (alpn.go:19-67). Named `Alpn` per
/// AGENTS.md (acronyms treated as ordinary words in `UpperCamelCase`).
final class Alpn implements Extension {
  List<String> protocolNameList;

  Alpn([List<String>? protocolNameList])
    : protocolNameList = protocolNameList ?? [];

  @override
  TypeValue get typeValue => TypeValue.alpn;

  @override
  Uint8List marshal() {
    final builder = _CryptobyteBuilder();
    builder.addUint16(typeValue.value);
    builder.addUint16LengthPrefixed((b) {
      b.addUint16LengthPrefixed((b) {
        for (final proto in protocolNameList) {
          b.addUint8LengthPrefixed((b) {
            b.addBytes(utf8.encode(proto));
          });
        }
      });
    });
    return builder.toBytes();
  }

  @override
  void unmarshal(Uint8List data) {
    final val = _CryptobyteReader(data);
    final extension = val.readUint16();
    if (extension != typeValue.value) throw _errInvalidExtensionType;

    final extData = val.readUint16LengthPrefixedReader();

    final protoList = extData.readUint16LengthPrefixedReader();
    if (protoList.isEmpty) throw errAlpnInvalidFormat;

    protocolNameList = [];
    while (!protoList.isEmpty) {
      final proto = protoList.readUint8LengthPrefixed();
      if (proto.isEmpty) throw errAlpnInvalidFormat;
      protocolNameList.add(utf8.decode(proto));
    }
  }
}

/// ALPNProtocolSelection negotiates a shared protocol according to #3.2 of
/// rfc7301.
///
/// Port of `ALPNProtocolSelection` (alpn.go:70-81).
String alpnProtocolSelection(
  List<String> supportedProtocols,
  List<String> peerSupportedProtocols,
) {
  if (supportedProtocols.isEmpty || peerSupportedProtocols.isEmpty) return '';
  for (final s in supportedProtocols) {
    if (peerSupportedProtocols.contains(s)) return s;
  }
  throw _errAlpnNoAppProto;
}
