part of 'extension.dart';

// Port of pkg/protocol/extension/use_master_secret.go.

const int _useExtendedMasterSecretHeaderSize = 4;

/// UseExtendedMasterSecret defines a TLS extension that contextually binds
/// the master secret to a log of the full handshake that computes it, thus
/// preventing MITM attacks.
///
/// Port of `UseExtendedMasterSecret` (use_master_secret.go:11-13) and its
/// methods `TypeValue`/`Marshal`/`Unmarshal` (use_master_secret.go:16-45).
final class UseExtendedMasterSecret implements Extension {
  bool supported;

  UseExtendedMasterSecret([this.supported = false]);

  @override
  TypeValue get typeValue => TypeValue.useExtendedMasterSecret;

  @override
  Uint8List marshal() {
    if (!supported) return Uint8List(0);
    return Uint8List.fromList([
      (typeValue.value >> 8) & 0xff,
      typeValue.value & 0xff,
      0,
      0,
    ]);
  }

  @override
  void unmarshal(Uint8List data) {
    if (data.length < _useExtendedMasterSecretHeaderSize) {
      throw _errBufferTooSmall;
    }
    final typeCode = (data[0] << 8) | data[1];
    if (typeCode != typeValue.value) throw _errInvalidExtensionType;
    supported = true;
  }
}
