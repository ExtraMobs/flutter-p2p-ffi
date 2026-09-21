// ignore_for_file: public_member_api_docs
//
// Ported from `quic-go/http3/frames.go` (module `github.com/quic-go/
// quic-go`, upstream commit fixed in `doc/transpilation/UPSTREAM_LOCK.md`).
//
// Scope: wire framing only (type/length header, SETTINGS payload, GOAWAY
// payload) and the frame dispatch performed by `frameParser.ParseNext`.
// DATA and HEADERS payload bytes are never buffered here, matching upstream:
// `ParseNext` returns as soon as it has read a DATA/HEADERS frame's type and
// length, leaving the payload on the stream for the caller (a QPACK decoder
// for HEADERS, the request/response body reader for DATA) to consume
// separately. Everything downstream of framing — QPACK, the HTTP/3
// client/server, qlog observability (`quic-go/http3/qlog`, `qlogwriter`) —
// is out of scope for this port.
import 'dart:typed_data';

import '../varint.dart';
import 'error_codes.dart';

/// A parsed HTTP/3 frame.
///
/// Mirrors Go's unexported `type frame any` (`frames.go`), used only as the
/// polymorphic return type of `frameParser.ParseNext`. Dart needs a public
/// supertype here because [parseHttp3Frame] — the function that plays that
/// role in this port — is itself public and a public function cannot return
/// a private type; this is the "or less, when not possible" case from
/// `AGENTS.md`'s least-privilege rule for exposing upstream-internal types.
sealed class Http3Frame {
  const Http3Frame();
}

const _http3FrameTypeData = 0x0;
const _http3FrameTypeHeaders = 0x1;
const _http3FrameTypeSettings = 0x4;
const _http3FrameTypeGoAway = 0x7;

/// Frame types reserved by RFC 9114 §7.2.8 (HTTP/2 grease code points
/// carried over into HTTP/3). Receiving one is a connection error of type
/// H3_FRAME_UNEXPECTED. Mirrors the `case 0x2, 0x6, 0x8, 0x9` branch of
/// `frameParser.ParseNext`.
const _reservedHttp3FrameTypes = <int>{0x2, 0x6, 0x8, 0x9};

/// DATA frame (RFC 9114 §7.2.1). Mirrors Go's unexported `dataFrame`.
///
/// [length] is the payload length only; the payload bytes are not part of
/// this frame's encoding here (see the file-level scope note above).
final class Http3DataFrame extends Http3Frame {
  const Http3DataFrame(this.length);

  final int length;

  /// Appends the wire encoding of this frame's header to [prefix].
  /// Mirrors Go's `(*dataFrame).Append(b []byte) []byte`.
  Uint8List append(List<int> prefix) {
    final withType = appendVarInt(prefix, _http3FrameTypeData);
    return appendVarInt(withType, length);
  }
}

/// HEADERS frame (RFC 9114 §7.2.2). Mirrors Go's unexported `headersFrame`.
///
/// [length] is the QPACK-encoded header block's length; the header block
/// itself is not part of this frame's encoding here (see the file-level
/// scope note above). Go's `headersFrame` additionally carries an
/// unexported `headerLen` bookkeeping field (bytes read for the type/length
/// header, used only by `quic-go/http3/qlog.go` for observability); that
/// consumer is out of scope for this port, so the field is omitted rather
/// than carried around unused.
final class Http3HeadersFrame extends Http3Frame {
  const Http3HeadersFrame(this.length);

  final int length;

  /// Appends the wire encoding of this frame's header to [prefix].
  /// Mirrors Go's `(*headersFrame).Append(b []byte) []byte`.
  Uint8List append(List<int> prefix) {
    final withType = appendVarInt(prefix, _http3FrameTypeHeaders);
    return appendVarInt(withType, length);
  }
}

// SETTINGS identifiers (`frames.go`): Go declares these unexported, right
// next to `settingsFrame`, so they stay private here too, in the same file,
// matching both their visibility and their co-location upstream.
const _settingMaxFieldSectionSize = 0x6;
const _settingExtendedConnect = 0x8;
const _settingDatagram = 0x33;

/// Upper bound on a SETTINGS frame's declared length, mirroring Go's
/// `l > 8*(1<<10)` guard in `parseSettingsFrame`.
const _maxSettingsFrameSize = 8 * 1024;

/// SETTINGS frame (RFC 9114 §7.2.4). Mirrors Go's unexported `settingsFrame`.
final class Http3SettingsFrame extends Http3Frame {
  const Http3SettingsFrame({
    this.maxFieldSectionSize = -1,
    this.datagram = false,
    this.extendedConnect = false,
    this.other = const {},
  });

  /// SETTINGS_MAX_FIELD_SECTION_SIZE, `-1` if not set.
  final int maxFieldSectionSize;

  /// HTTP Datagrams, RFC 9297 (SETTINGS_H3_DATAGRAM).
  final bool datagram;

  /// Extended CONNECT, RFC 9220 (SETTINGS_ENABLE_CONNECT_PROTOCOL).
  final bool extendedConnect;

  /// All settings this port does not explicitly recognize.
  final Map<int, int> other;

  /// Appends the wire encoding of this frame to [prefix].
  /// Mirrors Go's `(*settingsFrame).Append(b []byte) []byte`, including its
  /// exact field write order (MaxFieldSectionSize, Datagram, ExtendedConnect,
  /// then Other).
  Uint8List append(List<int> prefix) {
    var out = appendVarInt(prefix, _http3FrameTypeSettings);

    var length = 0;
    if (maxFieldSectionSize >= 0) {
      length +=
          varIntLength(_settingMaxFieldSectionSize) +
          varIntLength(maxFieldSectionSize);
    }
    for (final entry in other.entries) {
      length += varIntLength(entry.key) + varIntLength(entry.value);
    }
    if (datagram) {
      length += varIntLength(_settingDatagram) + varIntLength(1);
    }
    if (extendedConnect) {
      length += varIntLength(_settingExtendedConnect) + varIntLength(1);
    }
    out = appendVarInt(out, length);

    if (maxFieldSectionSize >= 0) {
      out = appendVarInt(out, _settingMaxFieldSectionSize);
      out = appendVarInt(out, maxFieldSectionSize);
    }
    if (datagram) {
      out = appendVarInt(out, _settingDatagram);
      out = appendVarInt(out, 1);
    }
    if (extendedConnect) {
      out = appendVarInt(out, _settingExtendedConnect);
      out = appendVarInt(out, 1);
    }
    for (final entry in other.entries) {
      out = appendVarInt(out, entry.key);
      out = appendVarInt(out, entry.value);
    }
    return out;
  }

  /// Decodes a SETTINGS frame payload of exactly [length] bytes starting at
  /// [offset] in [bytes]. Mirrors Go's unexported free function
  /// `parseSettingsFrame` (kept private here for the same reason: it is not
  /// meant to be called directly, only via [parseHttp3Frame]).
  static Http3SettingsFrame _parsePayload(
    Uint8List bytes,
    int offset,
    int length,
  ) {
    if (length > _maxSettingsFrameSize) {
      throw FormatException('unexpected size for SETTINGS frame: $length');
    }
    if (bytes.length - offset < length) {
      throw const FormatException('truncated SETTINGS frame');
    }
    // Bound parsing to exactly the declared payload, mirroring Go reading
    // into a freshly allocated `buf` of length `l` before parsing it: a
    // malformed varint can never read past this frame's own bytes into the
    // next frame.
    final payload = Uint8List.sublistView(bytes, offset, offset + length);

    var maxFieldSectionSize = -1;
    var datagram = false;
    var extendedConnect = false;
    final other = <int, int>{};
    var readMaxFieldSectionSize = false;
    var readDatagram = false;
    var readExtendedConnect = false;

    var cursor = 0;
    while (cursor < payload.length) {
      final (id, idLen) = parseVarInt(payload, cursor);
      cursor += idLen;
      final (val, valLen) = parseVarInt(payload, cursor);
      cursor += valLen;

      switch (id) {
        case _settingMaxFieldSectionSize:
          if (readMaxFieldSectionSize) {
            throw FormatException('duplicate setting: $id');
          }
          readMaxFieldSectionSize = true;
          maxFieldSectionSize = val;
        case _settingExtendedConnect:
          if (readExtendedConnect) {
            throw FormatException('duplicate setting: $id');
          }
          readExtendedConnect = true;
          if (val != 0 && val != 1) {
            throw FormatException(
              'invalid value for SETTINGS_ENABLE_CONNECT_PROTOCOL: $val',
            );
          }
          extendedConnect = val == 1;
        case _settingDatagram:
          if (readDatagram) {
            throw FormatException('duplicate setting: $id');
          }
          readDatagram = true;
          if (val != 0 && val != 1) {
            throw FormatException(
              'invalid value for SETTINGS_H3_DATAGRAM: $val',
            );
          }
          datagram = val == 1;
        default:
          if (other.containsKey(id)) {
            throw FormatException('duplicate setting: $id');
          }
          other[id] = val;
      }
    }

    return Http3SettingsFrame(
      maxFieldSectionSize: maxFieldSectionSize,
      datagram: datagram,
      extendedConnect: extendedConnect,
      other: other,
    );
  }
}

/// GOAWAY frame (RFC 9114 §7.2.6). Mirrors Go's unexported `goAwayFrame`.
final class Http3GoAwayFrame extends Http3Frame {
  const Http3GoAwayFrame(this.streamId);

  final int streamId;

  /// Appends the wire encoding of this frame to [prefix]. Mirrors Go's
  /// `(*goAwayFrame).Append(b []byte) []byte`: the frame's declared length
  /// is the varint-encoded length of the stream ID itself, not the stream ID
  /// value.
  Uint8List append(List<int> prefix) {
    final withType = appendVarInt(prefix, _http3FrameTypeGoAway);
    final withLength = appendVarInt(withType, varIntLength(streamId));
    return appendVarInt(withLength, streamId);
  }

  /// Decodes a GOAWAY frame payload of exactly [length] bytes starting at
  /// [offset] in [bytes]. Mirrors Go's unexported free function
  /// `parseGoAwayFrame`.
  static Http3GoAwayFrame _parsePayload(
    Uint8List bytes,
    int offset,
    int length,
  ) {
    final (id, idLen) = parseVarInt(bytes, offset);
    if (idLen != length) {
      throw const FormatException('GOAWAY frame: inconsistent length');
    }
    return Http3GoAwayFrame(id);
  }
}

/// Thrown by [parseHttp3Frame] on a reserved frame type (`0x2`, `0x6`,
/// `0x8`, `0x9` — RFC 9114 §7.2.8).
///
/// Mirrors the reserved-frame-type branch of Go's `frameParser.ParseNext`,
/// which calls `closeConn(ApplicationErrorCode(ErrCodeFrameUnexpected), "")`
/// on the QUIC connection before returning
/// `fmt.Errorf("http3: reserved frame type: %d", t)`. This port has no
/// connection object in scope, so closing the connection with [errorCode] is
/// left to the caller; this exception carries everything needed to do that.
final class Http3ReservedFrameTypeException implements Exception {
  const Http3ReservedFrameTypeException(this.frameType);

  final int frameType;

  /// The application error code the connection must be closed with.
  Http3ErrCode get errorCode => Http3ErrCode.frameUnexpected;

  @override
  String toString() => 'http3: reserved frame type: $frameType';
}

/// Parses the next HTTP/3 frame starting at [offset] in [bytes].
///
/// Mirrors Go's `frameParser.ParseNext`: CANCEL_PUSH (`0x3`), PUSH_PROMISE
/// (`0x5`) and MAX_PUSH_ID (`0xd`) are recognized-but-unsupported and are
/// skipped transparently, exactly like any other unknown frame type —
/// upstream loops internally to the next frame instead of surfacing them, so
/// this function does too. A reserved frame type throws
/// [Http3ReservedFrameTypeException] instead of being skipped.
///
/// Returns the decoded frame together with the number of bytes consumed:
/// for [Http3DataFrame] and [Http3HeadersFrame] this is only their header
/// (type + length varints), since their payload is left for the caller to
/// read separately (see the file-level scope note); for
/// [Http3SettingsFrame] and [Http3GoAwayFrame] it is the whole frame,
/// payload included, since upstream decodes those eagerly too.
(Http3Frame frame, int bytesRead) parseHttp3Frame(
  Uint8List bytes, [
  int offset = 0,
]) {
  var cursor = offset;
  while (true) {
    if (cursor >= bytes.length) {
      throw const FormatException('Unexpected EOF in HTTP/3 frames');
    }
    final (type, typeLen) = parseVarInt(bytes, cursor);
    cursor += typeLen;
    final (length, lengthLen) = parseVarInt(bytes, cursor);
    cursor += lengthLen;

    if (type == _http3FrameTypeData) {
      return (Http3DataFrame(length), cursor - offset);
    }
    if (type == _http3FrameTypeHeaders) {
      return (Http3HeadersFrame(length), cursor - offset);
    }
    if (type == _http3FrameTypeSettings) {
      final frame = Http3SettingsFrame._parsePayload(bytes, cursor, length);
      return (frame, cursor + length - offset);
    }
    if (type == _http3FrameTypeGoAway) {
      final frame = Http3GoAwayFrame._parsePayload(bytes, cursor, length);
      return (frame, cursor + length - offset);
    }
    if (_reservedHttp3FrameTypes.contains(type)) {
      throw Http3ReservedFrameTypeException(type);
    }

    // Unsupported-but-benign (CANCEL_PUSH, PUSH_PROMISE, MAX_PUSH_ID) and
    // unknown frame types: skip the payload and loop to the next frame.
    if (bytes.length - cursor < length) {
      throw const FormatException('truncated HTTP/3 frame payload');
    }
    cursor += length;
  }
}
