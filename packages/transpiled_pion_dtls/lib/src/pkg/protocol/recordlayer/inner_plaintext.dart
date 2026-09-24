part of 'recordlayer.dart';

// Port of pkg/protocol/recordlayer/inner_plaintext.go.
//
// Go builds this with `golang.org/x/crypto/cryptobyte`, but the usage here
// is trivial (unconditional concatenation, no length-prefixing), so it is
// reproduced directly with `BytesBuilder` rather than pulling in a
// cryptobyte-shim part file for a single call site (unlike `extension`/
// `handshake`, which use length-prefixing pervasively enough to warrant
// one).

/// InnerPlaintext implements DTLSInnerPlaintext.
/// https://datatracker.ietf.org/doc/html/rfc9146#name-record-layer-extensions
///
/// Port of `InnerPlaintext` (inner_plaintext.go:12-16) and its methods
/// `Marshal`/`Unmarshal` (inner_plaintext.go:19-47).
final class InnerPlaintext {
  Uint8List content;
  protocol.ContentType realType;
  int zeros;

  InnerPlaintext({
    Uint8List? content,
    this.realType = protocol.ContentType.handshake,
    this.zeros = 0,
  }) : content = content ?? Uint8List(0);

  /// Marshal encodes a DTLS InnerPlaintext to binary.
  Uint8List marshal() {
    final out = BytesBuilder();
    out.add(content);
    out.addByte(realType.value);
    out.add(Uint8List(zeros));
    return out.toBytes();
  }

  /// Unmarshal populates a DTLS InnerPlaintext from binary.
  void unmarshal(Uint8List data) {
    // Process in reverse.
    var i = data.length - 1;
    while (i >= 0) {
      if (data[i] != 0) {
        zeros = data.length - 1 - i;
        break;
      }
      i--;
    }
    if (i == 0) throw _errBufferTooSmall;
    realType = protocol.ContentType.fromValue(data[i]);
    content = Uint8List.fromList(data.sublist(0, i));
  }
}
