part of 'protocol.dart';

// Port of pkg/protocol/version.go.

/// Version is the minor/major value in the RecordLayer and
/// ClientHello/ServerHello.
/// https://tools.ietf.org/html/rfc4346#section-6.2.1
///
/// Port of `Version` (version.go:16-19) and `Equal` (version.go:22-24).
final class Version {
  final int major;
  final int minor;

  const Version(this.major, this.minor);

  /// Equal determines if two protocol versions are equal.
  bool equal(Version x) => major == x.major && minor == x.minor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Version && major == other.major && minor == other.minor);

  @override
  int get hashCode => Object.hash(major, minor);

  @override
  String toString() => 'DTLS $major.$minor';
}

/// Version enums (version.go:8-12).
final Version version1_0 = const Version(0xfe, 0xff);
final Version version1_2 = const Version(0xfe, 0xfd);
final Version version1_3 = const Version(0xfe, 0xfc);

/// IsSupportedBytes returns true if it's supported by Pion. Only DTLS 1.2 is
/// currently supported. DTLS 1.3 is a work in progress and is currently
/// being implemented.
///
/// Port of `IsSupportedBytes` (version.go:27-30).
bool isSupportedBytes(int major, int minor) =>
    major == 0xfe && (minor == 0xfd || minor == 0xfc);

/// IsSupportedVersion returns true if it's supported by Pion. Only DTLS 1.2
/// is currently supported. DTLS 1.3 is a work in progress and is currently
/// being implemented.
///
/// Port of `IsSupportedVersion` (version.go:33-36).
bool isSupportedVersion(Version v) =>
    v.equal(version1_2) || v.equal(version1_3);

/// IsValidBytes returns true if the bytes represent a valid DTLS version as
/// defined in RFC9147. Note that this is not the same as whether it's
/// *supported* by Pion. See [isSupportedBytes] for more info.
///
/// https://tools.ietf.org/html/rfc9147#section-5.3 (see legacy_version)
///
/// Port of `IsValidBytes` (version.go:40-43).
bool isValidBytes(int major, int minor) =>
    major == 0xfe && (minor == 0xff || minor == 0xfd || minor == 0xfc);

/// IsValidVersion returns true if the bytes represent a valid DTLS version
/// as defined in RFC9147. Note that this is not the same as whether it's
/// *supported* by Pion. See [isSupportedBytes] for more info.
///
/// https://tools.ietf.org/html/rfc9147#section-5.3 (see legacy_version)
///
/// Port of `IsValidVersion` (version.go:47-50).
bool isValidVersion(Version v) =>
    v.equal(version1_0) || v.equal(version1_2) || v.equal(version1_3);
