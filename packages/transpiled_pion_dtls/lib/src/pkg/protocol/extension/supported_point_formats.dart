part of 'extension.dart';

// Port of pkg/protocol/extension/supported_point_formats.go.
//
// Depends on `pkg/crypto/elliptic` (`elliptic.CurvePointFormat`,
// `elliptic.CurvePointFormat.curvePointFormatUncompressed`), owned by a
// concurrent agent -- see `extension.dart`'s library doc.

const int _supportedPointFormatsSize = 5;

/// SupportedPointFormats allows a Client/Server to negotiate the
/// EllipticCurvePointFormats.
/// https://tools.ietf.org/html/rfc4492#section-5.1.2
///
/// Port of `SupportedPointFormats` (supported_point_formats.go:16-18) and
/// its methods `TypeValue`/`Marshal`/`Unmarshal`
/// (supported_point_formats.go:21-69).
final class SupportedPointFormats implements Extension {
  List<elliptic.CurvePointFormat> pointFormats;

  SupportedPointFormats([List<elliptic.CurvePointFormat>? pointFormats])
    : pointFormats = pointFormats ?? [];

  @override
  TypeValue get typeValue => TypeValue.supportedPointFormats;

  @override
  Uint8List marshal() {
    final totalLen = 1 + pointFormats.length;
    final body = BytesBuilder();
    body.add([
      (typeValue.value >> 8) & 0xff,
      typeValue.value & 0xff,
      (totalLen >> 8) & 0xff,
      totalLen & 0xff,
      pointFormats.length & 0xff,
    ]);
    for (final v in pointFormats) {
      body.addByte(v.value);
    }
    return body.toBytes();
  }

  @override
  void unmarshal(Uint8List data) {
    if (data.length <= _supportedPointFormatsSize) throw _errBufferTooSmall;
    final typeCode = (data[0] << 8) | data[1];
    if (typeCode != typeValue.value) throw _errInvalidExtensionType;

    final pointFormatCount = data[4];
    if (_supportedPointFormatsSize + pointFormatCount > data.length) {
      throw _errLengthMismatch;
    }

    pointFormats = [];
    for (var i = 0; i < pointFormatCount; i++) {
      final p = data[_supportedPointFormatsSize + i];
      if (p == elliptic.CurvePointFormat.curvePointFormatUncompressed.value) {
        pointFormats.add(
          elliptic.CurvePointFormat.curvePointFormatUncompressed,
        );
      }
    }
  }
}
