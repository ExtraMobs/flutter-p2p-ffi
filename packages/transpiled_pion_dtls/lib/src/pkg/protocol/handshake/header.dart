part of 'handshake.dart';

// Port of pkg/protocol/handshake/header.go.

/// HeaderLength msg_len for Handshake messages assumes an extra 12 bytes
/// for sequence, fragment and version information vs TLS.
///
/// Port of `HeaderLength` (header.go:12-13). Named `handshakeHeaderLength`
/// (lowerCamelCase per AGENTS.md; kept the pre-existing name from this
/// package's earlier, unstructured version to avoid an unnecessary rename).
const int handshakeHeaderLength = 12;

/// Header is the static first 12 bytes of each RecordLayer of type
/// Handshake. These fields allow us to support message loss, reordering,
/// and message fragmentation.
/// https://tools.ietf.org/html/rfc6347#section-4.2.2
///
/// Port of `Header` (header.go:15-22) and its methods
/// `Marshal`/`Unmarshal` (header.go:25-55). Named `HandshakeHeader` (a bare
/// `Header` would collide, at the point of use, with
/// `pkg/protocol/recordlayer`'s own `Header` -- AGENTS.md Regra 25 resolves
/// same-named cross-package symbols with an import prefix at the *point of
/// use*, but this package's own top-level `Header` would still shadow
/// nothing here; the rename mirrors the pre-existing name from this
/// package's earlier, unstructured version).
final class HandshakeHeader {
  HandshakeType type;
  int length; // uint24 in spec
  int messageSequence;
  int fragmentOffset; // uint24 in spec
  int fragmentLength; // uint24 in spec

  HandshakeHeader({
    this.type = HandshakeType.clientHello,
    this.length = 0,
    this.messageSequence = 0,
    this.fragmentOffset = 0,
    this.fragmentLength = 0,
  });

  /// Marshal encodes the Header.
  Uint8List marshal() {
    final out = Uint8List(handshakeHeaderLength);
    out[0] = type.value;
    util.putBigEndianUint24(Uint8List.sublistView(out, 1), length);
    out[4] = (messageSequence >> 8) & 0xff;
    out[5] = messageSequence & 0xff;
    util.putBigEndianUint24(Uint8List.sublistView(out, 6), fragmentOffset);
    util.putBigEndianUint24(Uint8List.sublistView(out, 9), fragmentLength);
    return out;
  }

  /// Unmarshal populates the header from encoded data.
  ///
  /// KNOWN GAP: Go's `h.Type = Type(data[0])` (header.go:47) is an
  /// unchecked cast -- `Type` is a bare `uint8` newtype, so any byte
  /// round-trips. `HandshakeType` here is a closed Dart `enum` (see
  /// `handshake.dart`'s doc), so an unrecognized byte falls back to
  /// `helloRequest` instead of preserving the raw value. This is a
  /// deliberate, documented gap rather than a silent one: the only
  /// consumer of an out-of-range type byte is `Handshake.unmarshal`, which
  /// re-reads `data[0]` itself (not `header.type`) and throws
  /// `_errNotImplemented` before `header.type`'s wrong value could be
  /// observed on that path. A caller constructing/inspecting a
  /// `HandshakeHeader` directly with a non-standard type byte would not get
  /// full fidelity; revisit if that becomes a real call path.
  void unmarshal(Uint8List data) {
    if (data.length < handshakeHeaderLength) throw _errBufferTooSmall;
    type = HandshakeType.tryFromValue(data[0]) ?? HandshakeType.helloRequest;
    length = util.bigEndianUint24(Uint8List.sublistView(data, 1));
    messageSequence = (data[4] << 8) | data[5];
    fragmentOffset = util.bigEndianUint24(Uint8List.sublistView(data, 6));
    fragmentLength = util.bigEndianUint24(Uint8List.sublistView(data, 9));
  }
}
