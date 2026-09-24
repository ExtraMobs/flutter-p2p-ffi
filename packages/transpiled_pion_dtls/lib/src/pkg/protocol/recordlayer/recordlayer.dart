/// Port of `github.com/pion/dtls/v3/pkg/protocol/recordlayer` (revision
/// fixed in doc/transpilation/UPSTREAM_LOCK.md) -- the TLS Record Layer
/// (https://tools.ietf.org/html/rfc5246#section-6).
///
/// Split across `lib/src/pkg/protocol/recordlayer/*.dart` via `part`/`part
/// of`, one Dart file per Go file, mirroring the single Go package
/// `recordlayer` (AGENTS.md "Estrutura"). Not re-exported by the package's
/// top barrel (owned by a concurrent agent -- see progress notes).
library;

import 'dart:typed_data';

import 'package:transpiled_pion_dtls/src/pkg/protocol/alert/alert.dart'
    as alert;
import 'package:transpiled_pion_dtls/src/pkg/protocol/handshake/handshake.dart'
    as handshake;
import 'package:transpiled_pion_dtls/src/pkg/protocol/protocol.dart'
    as protocol;

part 'errors.dart';
part 'header.dart';
part 'inner_plaintext.dart';

/// fixedHeaderLenIdx is the index at which the record layer content length
/// is specified in a fixed length header (i.e. one that does not include a
/// Connection ID).
///
/// Port of `fixedHeaderLenIdx` (recordlayer.go:22).
const int _fixedHeaderLenIdx = 11;

/// RecordLayer which handles all data transport. The record layer is
/// assumed to sit directly on top of some reliable transport such as TCP.
/// The record layer can carry four types of content:
///
/// 1. Handshake messages -- used for algorithm negotiation and key
///    establishment.
/// 2. ChangeCipherSpec messages -- really part of the handshake but
///    technically a separate kind of message.
/// 3. Alert messages -- used to signal that errors have occurred.
/// 4. Application layer data.
///
/// The DTLS record layer is extremely similar to that of TLS 1.1. The only
/// change is the inclusion of an explicit sequence number in the record.
/// This sequence number allows the recipient to correctly verify the TLS
/// MAC.
/// https://tools.ietf.org/html/rfc4347#section-4.1
///
/// Port of `RecordLayer` (recordlayer.go:44-47) and its methods
/// `Marshal`/`Unmarshal` (recordlayer.go:50-83).
final class RecordLayer {
  Header header;
  protocol.Content? content;

  RecordLayer({Header? header, this.content}) : header = header ?? Header();

  /// Marshal encodes the RecordLayer to binary.
  Uint8List marshal() {
    final contentValue = content;
    if (contentValue == null) throw ArgumentError('content must be set');
    final contentRaw = contentValue.marshal();

    header.contentLen = contentRaw.length;
    header.contentType = contentValue.contentType();

    final headerRaw = header.marshal();

    final out = Uint8List(headerRaw.length + contentRaw.length);
    out.setRange(0, headerRaw.length, headerRaw);
    out.setRange(headerRaw.length, out.length, contentRaw);
    return out;
  }

  /// Unmarshal populates the RecordLayer from binary.
  void unmarshal(Uint8List data) {
    header.unmarshal(data);

    switch (header.contentType) {
      case protocol.ContentType.changeCipherSpec:
        content = protocol.ChangeCipherSpec();
      case protocol.ContentType.alert:
        content = alert.Alert();
      case protocol.ContentType.handshake:
        content = handshake.Handshake();
      case protocol.ContentType.applicationData:
        content = protocol.ApplicationData();
      case protocol.ContentType.connectionId:
        throw _errInvalidContentType;
    }

    content!.unmarshal(
      Uint8List.sublistView(
        data,
        header.size() + (header.connectionId?.length ?? 0),
      ),
    );
  }
}

/// UnpackDatagram extracts all RecordLayer messages from a single datagram.
/// Note that as with TLS, multiple handshake messages may be placed in the
/// same DTLS record, provided that there is room and that they are part of
/// the same flight. Thus, there are two acceptable ways to pack two DTLS
/// messages into the same datagram: in the same record or in separate
/// records.
/// https://tools.ietf.org/html/rfc6347#section-4.2.3
///
/// Port of `UnpackDatagram` (recordlayer.go:92-108).
List<Uint8List> unpackDatagram(Uint8List buf) {
  final out = <Uint8List>[];

  var offset = 0;
  while (buf.length != offset) {
    if (buf.length - offset <= fixedHeaderSize) throw errInvalidPacketLength;

    final pktLen =
        fixedHeaderSize + ((buf[offset + 11] << 8) | buf[offset + 12]);
    if (offset + pktLen > buf.length) throw errInvalidPacketLength;

    out.add(Uint8List.sublistView(buf, offset, offset + pktLen));
    offset += pktLen;
  }

  return out;
}

/// ContentAwareUnpackDatagram is the same as UnpackDatagram but considers
/// the presence of a connection identifier if the record is of content type
/// tls12_cid.
///
/// Port of `ContentAwareUnpackDatagram` (recordlayer.go:113-136).
List<Uint8List> contentAwareUnpackDatagram(Uint8List buf, int cidLength) {
  final out = <Uint8List>[];

  var offset = 0;
  while (buf.length != offset) {
    var headerSize = fixedHeaderSize;
    var lenIdx = _fixedHeaderLenIdx;
    if (protocol.ContentType.fromValue(buf[offset]) ==
        protocol.ContentType.connectionId) {
      headerSize += cidLength;
      lenIdx += cidLength;
    }
    if (buf.length - offset <= headerSize) throw errInvalidPacketLength;

    final pktLen =
        headerSize + ((buf[offset + lenIdx] << 8) | buf[offset + lenIdx + 1]);
    if (offset + pktLen > buf.length) throw errInvalidPacketLength;

    out.add(Uint8List.sublistView(buf, offset, offset + pktLen));
    offset += pktLen;
  }

  return out;
}
