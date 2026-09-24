part of 'extension.dart';

// Port of pkg/protocol/extension/renegotiation_info.go.

const int _renegotiationInfoHeaderSize = 5;

/// RenegotiationInfo allows a Client/Server to communicate their
/// renegotation support.
/// https://tools.ietf.org/html/rfc5746
///
/// Port of `RenegotiationInfo` (renegotiation_info.go:11-13) and its methods
/// `TypeValue`/`Marshal`/`Unmarshal` (renegotiation_info.go:16-45).
final class RenegotiationInfo implements Extension {
  int renegotiatedConnection;

  RenegotiationInfo([this.renegotiatedConnection = 0]);

  @override
  TypeValue get typeValue => TypeValue.renegotiationInfo;

  @override
  Uint8List marshal() => Uint8List.fromList([
    (typeValue.value >> 8) & 0xff,
    typeValue.value & 0xff,
    0,
    1,
    renegotiatedConnection & 0xff,
  ]);

  @override
  void unmarshal(Uint8List data) {
    if (data.length < _renegotiationInfoHeaderSize) throw _errBufferTooSmall;
    final typeCode = (data[0] << 8) | data[1];
    if (typeCode != typeValue.value) throw _errInvalidExtensionType;
    renegotiatedConnection = data[4];
  }
}
