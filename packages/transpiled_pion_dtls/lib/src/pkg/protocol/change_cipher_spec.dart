part of 'protocol.dart';

// Port of pkg/protocol/change_cipher_spec.go.

/// ChangeCipherSpec protocol exists to signal transitions in ciphering
/// strategies. The protocol consists of a single message, which is
/// encrypted and compressed under the current (not the pending) connection
/// state. The message consists of a single byte of value 1.
/// https://tools.ietf.org/html/rfc5246#section-7.1
///
/// Port of `ChangeCipherSpec` (change_cipher_spec.go:9) and its methods
/// `ContentType`/`Marshal`/`Unmarshal` (change_cipher_spec.go:12-28).
final class ChangeCipherSpec implements Content {
  @override
  ContentType contentType() => ContentType.changeCipherSpec;

  @override
  Uint8List marshal() => Uint8List.fromList([0x01]);

  @override
  void unmarshal(Uint8List data) {
    if (data.length == 1 && data[0] == 0x01) return;
    throw _errInvalidCipherSpec;
  }
}
