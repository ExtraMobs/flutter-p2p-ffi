part of 'extension.dart';

// Port of pkg/protocol/extension/server_name.go.

const int _serverNameTypeDnsHostName = 0;

/// ServerName allows the client to inform the server the specific name it
/// wishes to contact. Useful if multiple DNS names resolve to one IP.
/// https://tools.ietf.org/html/rfc6066#section-3
///
/// Port of `ServerName` (server_name.go:13-15) and its methods
/// `TypeValue`/`Marshal`/`Unmarshal` (server_name.go:18-82).
final class ServerName implements Extension {
  String serverName;

  ServerName([this.serverName = '']);

  @override
  TypeValue get typeValue => TypeValue.serverName;

  @override
  Uint8List marshal() {
    final b = _CryptobyteBuilder();
    b.addUint16(typeValue.value);
    b.addUint16LengthPrefixed((b) {
      b.addUint16LengthPrefixed((b) {
        b.addUint8(_serverNameTypeDnsHostName);
        b.addUint16LengthPrefixed((b) {
          b.addBytes(utf8.encode(serverName));
        });
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

    final nameList = extData.readUint16LengthPrefixedReader();
    if (nameList.isEmpty) throw _errInvalidSniFormat;

    while (!nameList.isEmpty) {
      final nameType = nameList.readUint8();
      final name = nameList.readUint16LengthPrefixed();
      if (name.isEmpty) throw _errInvalidSniFormat;
      if (nameType != _serverNameTypeDnsHostName) continue;
      if (serverName.isNotEmpty) {
        // Multiple names of the same name_type are prohibited.
        throw _errInvalidSniFormat;
      }
      serverName = utf8.decode(name);
      // An SNI value may not include a trailing dot.
      if (serverName.endsWith('.')) throw _errInvalidSniFormat;
    }
  }
}
