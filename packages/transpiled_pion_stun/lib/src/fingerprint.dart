/// Port of `fingerprint.go` (pion/stun v3.1.1).
library;

import 'dart:typed_data';

import 'attributes.dart';
import 'checks.dart';
import 'helpers.dart';
import 'message.dart';

/// Port of `ErrFingerprintMismatch` (fingerprint.go:12): computed CRC-32
/// differs from the value carried in the FINGERPRINT attribute.
final class FingerprintMismatchException implements Exception {
  const FingerprintMismatchException();

  @override
  String toString() => 'fingerprint check failed';
}

const int _fingerprintXorValue = 0x5354554e;
const int _fingerprintSize = 4;

/// Port of `FingerprintValue` (fingerprint.go:26-28): CRC-32 (IEEE) of `b`
/// XOR-ed by `0x5354554e`.
int fingerprintValue(Uint8List b) => _crc32Ieee(b) ^ _fingerprintXorValue;

/// Port of `FingerprintAttr` (fingerprint.go:9) and the package-level
/// [fingerprint] value (Go's `var Fingerprint FingerprintAttr`,
/// fingerprint.go:19).
final class FingerprintAttr implements Setter, Checker {
  const FingerprintAttr();

  /// Port of `FingerprintAttr.AddTo` (fingerprint.go:31-41).
  @override
  void addTo(Message m) {
    final l = m.length;
    m.length += _fingerprintSize + attributeHeaderSize;
    m.writeLength();
    final b = ByteData(_fingerprintSize);
    final val = fingerprintValue(m.raw);
    b.setUint32(0, val, Endian.big);
    m.length = l;
    m.add(AttrType.fingerprint, b.buffer.asUint8List());
  }

  /// Port of `FingerprintAttr.Check` (fingerprint.go:44-56). Throws
  /// [AttributeSizeInvalidException]/[AttributeNotFoundException] (via
  /// [Message.get]/[checkSize]) or [FingerprintMismatchException].
  @override
  void check(Message m) {
    final b = m.get(AttrType.fingerprint);
    checkSize(AttrType.fingerprint, b.length, _fingerprintSize);
    final val = ByteData.sublistView(b).getUint32(0, Endian.big);
    final attrStart = m.raw.length - (_fingerprintSize + attributeHeaderSize);
    final expected = fingerprintValue(m.raw.sublist(0, attrStart));

    checkFingerprint(val, expected);
  }
}

/// Port of the package-level `Fingerprint` value (fingerprint.go:19).
const FingerprintAttr fingerprint = FingerprintAttr();

// CRC-32 (IEEE 802.3) table-driven implementation, matching Go's
// `hash/crc32.ChecksumIEEE`. Dart's stdlib has no CRC-32; this is the
// standard reflected polynomial 0xEDB88320 algorithm, not a STUN-specific
// invention.
final Uint32List _crcTable = _buildCrc32Table();

Uint32List _buildCrc32Table() {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
    }
    table[n] = c;
  }
  return table;
}

int _crc32Ieee(Uint8List data) {
  // Every intermediate value here is already bounded to 32 bits (the seed,
  // the table entries, and XOR/shift-right of 32-bit values never produce
  // more than 32 bits), so no final masking is needed to stay within Go's
  // uint32 range.
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}
