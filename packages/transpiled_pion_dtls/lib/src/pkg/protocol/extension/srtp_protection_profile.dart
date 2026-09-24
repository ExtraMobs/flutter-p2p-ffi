part of 'extension.dart';

// Port of pkg/protocol/extension/srtp_protection_profile.go.

/// SRTPProtectionProfile defines the parameters and options that are in
/// effect for the SRTP processing.
/// https://tools.ietf.org/html/rfc5764#section-4.1.2
///
/// Port of `SRTPProtectionProfile` (srtp_protection_profile.go:8) and its
/// consts (srtp_protection_profile.go:10-18).
enum SrtpProtectionProfile {
  srtpAes128CmHmacSha180(0x0001),
  srtpAes128CmHmacSha132(0x0002),
  srtpAes256CmSha180(0x0003),
  srtpAes256CmSha132(0x0004),
  srtpNullHmacSha180(0x0005),
  srtpNullHmacSha132(0x0006),
  srtpAeadAes128Gcm(0x0007),
  srtpAeadAes256Gcm(0x0008);

  final int value;
  const SrtpProtectionProfile(this.value);

  static SrtpProtectionProfile? tryFromValue(int val) {
    for (final p in SrtpProtectionProfile.values) {
      if (p.value == val) return p;
    }
    return null;
  }
}

/// Port of unexported `srtpProtectionProfiles` (srtp_protection_profile.go:20-31).
Set<SrtpProtectionProfile> _srtpProtectionProfiles() =>
    SrtpProtectionProfile.values.toSet();
