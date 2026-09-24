part of 'extension.dart';

// Port of pkg/protocol/extension/psk_key_exchange_modes.go.

/// Port of `PskKeyExchangeMode` (psk_key_exchange_modes.go:12) and its
/// consts (psk_key_exchange_modes.go:14-17). A plain value class rather
/// than an `enum`: `Unmarshal` (psk_key_exchange_modes.go:75,
/// `PskKeyExchangeMode(mode)`) converts *any* wire byte without validating
/// against the two known consts, which a closed Dart `enum` could not
/// round-trip.
final class PskKeyExchangeMode {
  final int value;
  const PskKeyExchangeMode(this.value);

  static const PskKeyExchangeMode pskKe = PskKeyExchangeMode(0);
  static const PskKeyExchangeMode pskDheKe = PskKeyExchangeMode(1);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PskKeyExchangeMode && value == other.value);

  @override
  int get hashCode => value.hashCode;
}

/// PskKeyExchangeModes implements the PskKeyExchangeModes extension in DTLS
/// 1.3. See RFC 8446 section 4.2.9. Pre-Shared Key Exchange Modes.
/// https://datatracker.ietf.org/doc/html/rfc8446#section-4.2.9
///
/// Port of `PskKeyExchangeModes` (psk_key_exchange_modes.go:9-11) and its
/// methods `TypeValue`/`Marshal`/`Unmarshal` (psk_key_exchange_modes.go:24-79).
final class PskKeyExchangeModes implements Extension {
  List<PskKeyExchangeMode> keModes;

  PskKeyExchangeModes([List<PskKeyExchangeMode>? keModes])
    : keModes = keModes ?? [];

  @override
  TypeValue get typeValue => TypeValue.pskKeyExchangeModes;

  @override
  Uint8List marshal() {
    if (keModes.isEmpty) throw _errNoPskKeyExchangeMode;

    final out = _CryptobyteBuilder();
    out.addUint16(typeValue.value);
    out.addUint16LengthPrefixed((b) {
      b.addUint8LengthPrefixed((b) {
        for (final keM in keModes) {
          b.addUint8(keM.value);
        }
      });
    });
    return out.toBytes();
  }

  @override
  void unmarshal(Uint8List data) {
    final val = _CryptobyteReader(data);
    final extension = val.readUint16();
    if (extension != typeValue.value) throw _errInvalidExtensionType;

    final extData = val.readUint16LengthPrefixedReader();

    final Uint8List strModes;
    try {
      strModes = extData.readUint8LengthPrefixed();
    } on _CryptobyteFormatException {
      throw _errPskKeyExchangeModesFormat;
    }
    if (strModes.isEmpty) throw _errPskKeyExchangeModesFormat;

    keModes = [for (final mode in strModes) PskKeyExchangeMode(mode)];
  }
}
