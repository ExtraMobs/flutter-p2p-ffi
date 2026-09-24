part of 'extension.dart';

// Port of pkg/protocol/extension/use_srtp.go.

const int _useSrtpHeaderSize = 6;

/// UseSRTP allows a Client/Server to negotiate what SRTPProtectionProfiles
/// they both support.
/// https://tools.ietf.org/html/rfc8422
///
/// Port of `UseSRTP` (use_srtp.go:15-18) and its methods
/// `TypeValue`/`Marshal`/`Unmarshal` (use_srtp.go:21-79).
final class UseSrtp implements Extension {
  List<SrtpProtectionProfile> protectionProfiles;
  Uint8List masterKeyIdentifier;

  UseSrtp({
    List<SrtpProtectionProfile>? protectionProfiles,
    Uint8List? masterKeyIdentifier,
  }) : protectionProfiles = protectionProfiles ?? [],
       masterKeyIdentifier = masterKeyIdentifier ?? Uint8List(0);

  @override
  TypeValue get typeValue => TypeValue.useSrtp;

  @override
  Uint8List marshal() {
    final out = BytesBuilder();
    out.add([
      (typeValue.value >> 8) & 0xff,
      typeValue.value & 0xff,
      0,
      0,
      0,
      0,
    ]);
    final totalLen =
        2 + (protectionProfiles.length * 2) + 1 + masterKeyIdentifier.length;
    final profilesLen = protectionProfiles.length * 2;
    final headerBytes = out.toBytes();
    headerBytes[2] = (totalLen >> 8) & 0xff;
    headerBytes[3] = totalLen & 0xff;
    headerBytes[4] = (profilesLen >> 8) & 0xff;
    headerBytes[5] = profilesLen & 0xff;

    final body = BytesBuilder();
    body.add(headerBytes);
    for (final v in protectionProfiles) {
      body.add([(v.value >> 8) & 0xff, v.value & 0xff]);
    }
    if (masterKeyIdentifier.length > 255) {
      throw _errMasterKeyIdentifierTooLarge;
    }
    body.addByte(masterKeyIdentifier.length);
    body.add(masterKeyIdentifier);
    return body.toBytes();
  }

  @override
  void unmarshal(Uint8List data) {
    if (data.length <= _useSrtpHeaderSize) throw _errBufferTooSmall;
    final typeCode = (data[0] << 8) | data[1];
    if (typeCode != typeValue.value) throw _errInvalidExtensionType;

    final profileCount = ((data[4] << 8) | data[5]) ~/ 2;
    final masterKeyIdentifierIndex = _useSrtpHeaderSize + (profileCount * 2);
    if (masterKeyIdentifierIndex + 1 > data.length) throw _errLengthMismatch;

    protectionProfiles = [];
    for (var i = 0; i < profileCount; i++) {
      final idx = _useSrtpHeaderSize + (i * 2);
      final code = (data[idx] << 8) | data[idx + 1];
      final supportedProfile = SrtpProtectionProfile.tryFromValue(code);
      if (supportedProfile != null &&
          _srtpProtectionProfiles().contains(supportedProfile)) {
        protectionProfiles.add(supportedProfile);
      }
    }

    final masterKeyIdentifierLen = data[masterKeyIdentifierIndex];
    if (masterKeyIdentifierIndex + masterKeyIdentifierLen >= data.length) {
      throw _errLengthMismatch;
    }
    masterKeyIdentifier = Uint8List.fromList(
      data.sublist(
        masterKeyIdentifierIndex + 1,
        masterKeyIdentifierIndex + 1 + masterKeyIdentifierLen,
      ),
    );
  }
}
