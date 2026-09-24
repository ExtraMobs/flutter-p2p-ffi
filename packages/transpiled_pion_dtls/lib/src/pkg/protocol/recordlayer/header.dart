part of 'recordlayer.dart';

// Port of pkg/protocol/recordlayer/header.go.

/// FixedHeaderSize is the size of a DTLS record header when connection IDs
/// are not in use.
///
/// Port of `FixedHeaderSize` (header.go:27-28).
const int fixedHeaderSize = 13;

/// Port of `MaxSequenceNumber` (header.go:29).
const int maxSequenceNumber = 0x0000FFFFFFFFFFFF;

/// Header implements a TLS RecordLayer header.
///
/// Port of `Header` (header.go:13-21) and its methods
/// `Marshal`/`Unmarshal`/`Size` (header.go:32-79).
final class Header {
  protocol.ContentType contentType;
  int contentLen;
  protocol.Version version;
  int epoch;
  int sequenceNumber; // uint48 in spec

  /// Optional Fields.
  Uint8List? connectionId;

  Header({
    this.contentType = protocol.ContentType.handshake,
    this.contentLen = 0,
    protocol.Version? version,
    this.epoch = 0,
    this.sequenceNumber = 0,
    this.connectionId,
  }) : version = version ?? protocol.version1_2;

  /// Marshal encodes a TLS RecordLayer Header to binary.
  Uint8List marshal() {
    if (sequenceNumber > maxSequenceNumber) throw _errSequenceNumberOverflow;

    final cid = connectionId ?? Uint8List(0);
    final hs = fixedHeaderSize + cid.length;

    final out = Uint8List(hs);
    out[0] = contentType.value;
    out[1] = version.major;
    out[2] = version.minor;
    out[3] = (epoch >> 8) & 0xff;
    out[4] = epoch & 0xff;
    out[5] = (sequenceNumber >> 40) & 0xff;
    out[6] = (sequenceNumber >> 32) & 0xff;
    out[7] = (sequenceNumber >> 24) & 0xff;
    out[8] = (sequenceNumber >> 16) & 0xff;
    out[9] = (sequenceNumber >> 8) & 0xff;
    out[10] = sequenceNumber & 0xff;
    out.setRange(11, 11 + cid.length, cid);
    out[hs - 2] = (contentLen >> 8) & 0xff;
    out[hs - 1] = contentLen & 0xff;

    return out;
  }

  /// Unmarshal populates a TLS RecordLayer Header from binary.
  void unmarshal(Uint8List data) {
    if (data.length < fixedHeaderSize) throw _errBufferTooSmall;
    contentType = protocol.ContentType.fromValue(data[0]);
    if (contentType == protocol.ContentType.connectionId) {
      // If a CID was expected the ConnectionID should have been
      // initialized.
      final expectedLen = connectionId?.length ?? 0;
      if (data.length < fixedHeaderSize + expectedLen) {
        throw _errBufferTooSmall;
      }
      connectionId = Uint8List.fromList(data.sublist(11, 11 + expectedLen));
    }

    version = protocol.Version(data[1], data[2]);
    epoch = (data[3] << 8) | data[4];

    sequenceNumber =
        (data[5] << 40) |
        (data[6] << 32) |
        (data[7] << 24) |
        (data[8] << 16) |
        (data[9] << 8) |
        data[10];

    if (!version.equal(protocol.version1_0) &&
        !version.equal(protocol.version1_2)) {
      throw _errUnsupportedProtocolVersion;
    }
  }

  /// Size returns the total size of the header.
  int size() => fixedHeaderSize + (connectionId?.length ?? 0);
}
