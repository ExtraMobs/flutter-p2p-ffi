part of 'extension.dart';

// Port of pkg/protocol/extension/supported_elliptic_curves.go.
//
// Depends on `pkg/crypto/elliptic` (`elliptic.Curve`, `elliptic.curves()`),
// owned by a concurrent agent -- see `extension.dart`'s library doc.

const int _supportedGroupsHeaderSize = 6;

/// SupportedEllipticCurves allows a Client/Server to communicate what curves
/// they both support.
/// https://tools.ietf.org/html/rfc8422#section-5.1.1
///
/// In DTLS 1.3, this extension in renamed to "supported_groups".
/// https://datatracker.ietf.org/doc/html/rfc8446#section-4.2.7
///
/// Port of `SupportedEllipticCurves` (supported_elliptic_curves.go:16-18)
/// and its methods `TypeValue`/`Marshal`/`Unmarshal`
/// (supported_elliptic_curves.go:21-67).
final class SupportedEllipticCurves implements Extension {
  List<elliptic.Curve> ellipticCurves;

  SupportedEllipticCurves([List<elliptic.Curve>? ellipticCurves])
    : ellipticCurves = ellipticCurves ?? [];

  @override
  TypeValue get typeValue => TypeValue.supportedEllipticCurves;

  @override
  Uint8List marshal() {
    final body = BytesBuilder();
    final totalLen = 2 + (ellipticCurves.length * 2);
    final groupsLen = ellipticCurves.length * 2;
    body.add([
      (typeValue.value >> 8) & 0xff,
      typeValue.value & 0xff,
      (totalLen >> 8) & 0xff,
      totalLen & 0xff,
      (groupsLen >> 8) & 0xff,
      groupsLen & 0xff,
    ]);
    for (final v in ellipticCurves) {
      body.add([(v.value >> 8) & 0xff, v.value & 0xff]);
    }
    return body.toBytes();
  }

  @override
  void unmarshal(Uint8List data) {
    if (data.length <= _supportedGroupsHeaderSize) throw _errBufferTooSmall;
    final typeCode = (data[0] << 8) | data[1];
    if (typeCode != typeValue.value) throw _errInvalidExtensionType;

    final groupCount = ((data[4] << 8) | data[5]) ~/ 2;
    if (_supportedGroupsHeaderSize + (groupCount * 2) > data.length) {
      throw _errLengthMismatch;
    }

    ellipticCurves = [];
    final supported = elliptic.curves();
    for (var i = 0; i < groupCount; i++) {
      final idx = _supportedGroupsHeaderSize + (i * 2);
      final code = (data[idx] << 8) | data[idx + 1];
      final curve = elliptic.Curve(code);
      if (supported.contains(curve)) {
        ellipticCurves.add(curve);
      }
    }
  }
}
