part of 'extension.dart';

// Port of pkg/protocol/extension/supported_versions.go.

/// SupportedVersions is a TLS extension used by the client to indicate
/// which versions of TLS it supports and by the server to indicate which
/// version it is using.
/// https://datatracker.ietf.org/doc/html/rfc8446#section-4.2.1
///
/// Port of `SupportedVersions` (supported_versions.go:13-16) and its
/// methods `TypeValue`/`Marshal`/`Unmarshal` (supported_versions.go:18-125).
final class SupportedVersions implements Extension {
  /// ClientHello's preference-ordered list.
  List<protocol.Version> versions;

  SupportedVersions([List<protocol.Version>? versions])
    : versions = versions ?? [];

  @override
  TypeValue get typeValue => TypeValue.supportedVersions;

  /// Marshal encodes the extension without carrying negotiation state.
  @override
  Uint8List marshal() {
    if (versions.isEmpty) throw _errInvalidSupportedVersionsFormat;

    final totalBytes = versions.length * 2;
    // The 2..254 bound is defined in
    // https://datatracker.ietf.org/doc/html/rfc8446#section-4.2.1
    if (totalBytes < 2 || totalBytes > 254) {
      throw _errInvalidSupportedVersionsFormat;
    }

    // Only checking for *valid* versions, not to be confused with supported
    // versions. Error on invalid versions to protect against
    // malformed messages/DOS attacks.
    for (final v in versions) {
      if (!protocol.isValidVersion(v)) throw _errInvalidDtlsVersion;
    }

    final builder = _CryptobyteBuilder();
    builder.addUint16(typeValue.value);
    builder.addUint16LengthPrefixed((b) {
      if (versions.length == 1) {
        // In the case that there's only one version, do not add the length
        // (uint8).
        b.addUint8(versions[0].major);
        b.addUint8(versions[0].minor);
        return;
      }

      b.addUint8LengthPrefixed((b) {
        for (final v in versions) {
          b.addUint8(v.major);
          b.addUint8(v.minor);
        }
      });
    });

    return builder.toBytes();
  }

  /// Unmarshal parses either the ClientHello list or the
  /// ServerHello/HelloRetryRequest single value. Any version not recognized
  /// is discarded.
  @override
  void unmarshal(Uint8List data) {
    final val = _CryptobyteReader(data);

    final extension = val.readUint16();
    if (extension != typeValue.value) throw _errInvalidExtensionType;

    final extData = val.readUint16LengthPrefixedReader();
    if (extData.isEmpty) throw _errInvalidSupportedVersionsFormat;

    // Try ClientHello list: versions<2..254> (1-byte length, then pairs).
    final peek = extData.clone();
    var listLenOk = false;
    var listLen = 0;
    try {
      listLen = peek.readUint8();
      listLenOk =
          listLen == peek.remainingLength && listLen >= 2 && (listLen % 2) == 0;
    } on _CryptobyteFormatException {
      listLenOk = false;
    }
    if (listLenOk) {
      versions = [];
      while (!peek.isEmpty) {
        final major = peek.readUint8();
        final minor = peek.readUint8();
        // Only checking for *valid* versions, not to be confused with
        // supported versions.
        if (protocol.isValidBytes(major, minor)) {
          versions.add(protocol.Version(major, minor));
        }
      }
      extData.skip(1 + listLen);
      return;
    }

    // Otherwise, expect ServerHello/HelloRetryRequest selected_version,
    // which should be exactly 2 bytes.
    if (extData.remainingLength != 2) {
      throw _errInvalidSupportedVersionsFormat;
    }

    final major = extData.readUint8();
    final minor = extData.readUint8();
    // Only checking for *valid* versions, not to be confused with supported
    // versions.
    if (protocol.isValidBytes(major, minor)) {
      versions = [protocol.Version(major, minor)];
    }
  }
}
