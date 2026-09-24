part of 'handshake.dart';

// Port of pkg/protocol/handshake/cipher_suite.go. Both functions are
// Go-unexported, so private (AGENTS.md).

/// Port of `decodeCipherSuiteIDs` (cipher_suite.go:7-19).
List<int> _decodeCipherSuiteIds(Uint8List buf) {
  if (buf.length < 2) throw _errBufferTooSmall;
  final cipherSuitesCount = ((buf[0] << 8) | buf[1]) ~/ 2;
  final rtrn = List<int>.filled(cipherSuitesCount, 0);
  for (var i = 0; i < cipherSuitesCount; i++) {
    if (buf.length < (i * 2 + 4)) throw _errBufferTooSmall;
    rtrn[i] = (buf[(i * 2) + 2] << 8) | buf[(i * 2) + 3];
  }
  return rtrn;
}

/// Port of `encodeCipherSuiteIDs` (cipher_suite.go:21-30).
Uint8List _encodeCipherSuiteIds(List<int> cipherSuiteIds) {
  final out = BytesBuilder();
  final len = cipherSuiteIds.length * 2;
  out.add([(len >> 8) & 0xff, len & 0xff]);
  for (final id in cipherSuiteIds) {
    out.add([(id >> 8) & 0xff, id & 0xff]);
  }
  return out.toBytes();
}
