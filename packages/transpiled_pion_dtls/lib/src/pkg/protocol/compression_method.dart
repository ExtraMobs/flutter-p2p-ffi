part of 'protocol.dart';

// Port of pkg/protocol/compression_method.go.
//
// Go's `CompressionMethodID` is a `byte` newtype; represented here as a
// plain `int` (0-255), matching how this project represents other Go `byte`
// newtypes used only as small enumerations (see e.g. ContentType, which is
// instead an `enum` because it has several named values used throughout the
// codebase -- CompressionMethodID has exactly one legal value upstream, so a
// bare `int` plus the private sentinel constant is the direct equivalent
// without inventing an enum of one case).

/// Unexported `compressionMethodNull` const (compression_method.go:9-11).
const int _compressionMethodNull = 0;

/// CompressionMethod represents a TLS Compression Method.
///
/// Port of `CompressionMethod` (compression_method.go:13-15).
final class CompressionMethod {
  final int id;
  const CompressionMethod(this.id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CompressionMethod && id == other.id);

  @override
  int get hashCode => id.hashCode;
}

/// CompressionMethods returns all supported CompressionMethods.
///
/// Port of `CompressionMethods` (compression_method.go:17-22).
Map<int, CompressionMethod> compressionMethods() => {
  _compressionMethodNull: const CompressionMethod(_compressionMethodNull),
};

/// DecodeCompressionMethods the given compression methods.
///
/// Port of `DecodeCompressionMethods` (compression_method.go:24-39). Throws
/// [_errBufferTooSmall] rather than returning `(nil, error)`.
List<CompressionMethod> decodeCompressionMethods(Uint8List buf) {
  if (buf.isEmpty) throw _errBufferTooSmall;
  final compressionMethodsCount = buf[0];
  final c = <CompressionMethod>[];
  final supported = compressionMethods();
  for (var i = 0; i < compressionMethodsCount; i++) {
    if (buf.length <= i + 1) throw _errBufferTooSmall;
    final id = buf[i + 1];
    final compressionMethod = supported[id];
    if (compressionMethod != null) c.add(compressionMethod);
  }
  return c;
}

/// EncodeCompressionMethods the given compression methods.
///
/// Port of `EncodeCompressionMethods` (compression_method.go:41-49).
Uint8List encodeCompressionMethods(List<CompressionMethod> c) {
  final out = <int>[c.length];
  for (var i = c.length; i > 0; i--) {
    out.add(c[i - 1].id);
  }
  return Uint8List.fromList(out);
}
