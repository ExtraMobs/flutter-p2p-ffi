part of 'extension.dart';

// Port of pkg/protocol/extension/connection_id.go.

/// ConnectionID is a DTLS extension that provides an alternative to IP
/// address and port for session association.
/// https://tools.ietf.org/html/rfc9146
///
/// Port of `ConnectionID` (connection_id.go:11-16) and its methods
/// `TypeValue`/`Marshal`/`Unmarshal` (connection_id.go:19-58). Named
/// `ConnectionId` per AGENTS.md (acronyms treated as ordinary words in
/// `UpperCamelCase`).
final class ConnectionId implements Extension {
  /// A zero-length connection ID indicates for a client or server that
  /// negotiated connection IDs from the peer will be sent but there is no
  /// need to respond with one.
  Uint8List cid;

  ConnectionId([Uint8List? cid]) : cid = cid ?? Uint8List(0);

  @override
  TypeValue get typeValue => TypeValue.connectionId;

  @override
  Uint8List marshal() {
    final b = _CryptobyteBuilder();
    b.addUint16(typeValue.value);
    b.addUint16LengthPrefixed((b) {
      b.addUint8LengthPrefixed((b) {
        b.addBytes(cid);
      });
    });
    return b.toBytes();
  }

  @override
  void unmarshal(Uint8List data) {
    final val = _CryptobyteReader(data);
    final extension = val.readUint16();
    if (extension != typeValue.value) throw _errInvalidExtensionType;

    final extData = val.readUint16LengthPrefixedReader();
    try {
      cid = Uint8List.fromList(extData.readUint8LengthPrefixed());
    } on _CryptobyteFormatException {
      throw _errInvalidCidFormat;
    }
  }
}
