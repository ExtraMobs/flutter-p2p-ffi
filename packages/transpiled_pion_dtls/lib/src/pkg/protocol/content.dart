part of 'protocol.dart';

// Port of pkg/protocol/content.go.

/// ContentType represents the IANA Registered ContentTypes.
///
/// https://tools.ietf.org/html/rfc4346#section-6.2.1
///
/// Port of `ContentType` (content.go:9) plus its enum consts (content.go:13-18).
enum ContentType {
  changeCipherSpec(20),
  alert(21),
  handshake(22),
  applicationData(23),
  connectionId(25);

  final int value;
  const ContentType(this.value);

  /// Reconstructs a [ContentType] from its wire byte value.
  static ContentType fromValue(int val) {
    for (final ct in ContentType.values) {
      if (ct.value == val) return ct;
    }
    throw FormatException('invalid content type: $val');
  }
}

/// Content is the top level distinguisher for a DTLS Datagram.
///
/// Port of `Content` (content.go:20-24). `Marshal`/`Unmarshal` return the
/// value directly and throw on failure per AGENTS.md Regra 8 rather than the
/// Go `([]byte, error)` / `error` tuple.
abstract class Content {
  ContentType contentType();
  Uint8List marshal();
  void unmarshal(Uint8List data);
}
