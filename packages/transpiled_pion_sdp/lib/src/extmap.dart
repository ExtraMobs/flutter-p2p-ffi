// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
part of '../transpiled_pion_sdp.dart';

// Port of github.com/pion/sdp/v3 extmap.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md).

/// Default `extmap` values. Port of the `DefExtMapValue*` constants
/// (extmap.go:15-18).
const int defExtMapValueAbsSendTime = 1;
const int defExtMapValueTransportCc = 2;
const int defExtMapValueSdesMid = 3;
const int defExtMapValueSdesRtpStreamId = 4;

/// Port of `ABSSendTimeURI` (extmap.go:20).
const String absSendTimeUri =
    'http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time';

/// Port of `TransportCCURI` (extmap.go:21).
const String transportCcUri =
    'http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01';

/// Port of `SDESMidURI` (extmap.go:22).
const String sdesMidUri = 'urn:ietf:params:rtp-hdrext:sdes:mid';

/// Port of `SDESRTPStreamIDURI` (extmap.go:23).
const String sdesRtpStreamIdUri =
    'urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id';

/// Port of `SDESRepairRTPStreamIDURI` (extmap.go:24).
const String sdesRepairRtpStreamIdUri =
    'urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id';

/// Port of `AudioLevelURI` (extmap.go:25).
const String audioLevelUri = 'urn:ietf:params:rtp-hdrext:ssrc-audio-level';

/// Thrown for the `errSyntaxError` sentinel wrapped by `ExtMap.Unmarshal`
/// (extmap.go:45,50). Named distinctly from [SdpSyntaxException] (which
/// ports the unrelated `syntaxError` struct used by the line lexer) because
/// upstream keeps these as two separate sentinel error values.
class ExtMapSyntaxException implements Exception {
  ExtMapSyntaxException(this.raw);

  final String raw;

  @override
  String toString() => 'SyntaxError: $raw';
}

/// The activation of a single RTP header extension. Port of `sdp.ExtMap`
/// (extmap.go:29).
class ExtMap {
  ExtMap({this.value = 0, this.direction, this.uri, this.extAttr});

  int value;
  Direction? direction;
  Uri? uri;
  String? extAttr;

  /// Converts this object to an [Attribute]. Port of `ExtMap.Clone`
  /// (extmap.go:37).
  Attribute clone() => Attribute(key: 'extmap', value: _string());

  /// Populates this [ExtMap] from [raw]. Port of `ExtMap.Unmarshal`
  /// (extmap.go:42).
  void unmarshal(String raw) {
    final colonIndex = raw.indexOf(':');
    final parts = colonIndex == -1
        ? [raw]
        : [raw.substring(0, colonIndex), raw.substring(colonIndex + 1)];
    if (parts.length != 2) {
      throw ExtMapSyntaxException(raw);
    }

    final fields = parts[1]
        .split(RegExp(r'\s+'))
        .where((f) => f.isNotEmpty)
        .toList();
    if (fields.length < 2) {
      throw ExtMapSyntaxException(raw);
    }

    final valdir = fields[0].split('/');

    // Upstream parses valdir[0] and checks the 1-246 range BEFORE checking
    // the parse error, so any parse failure also observably surfaces as the
    // range error below rather than a numeric-parse error; that second Go
    // check is therefore unreachable dead code, reproduced here for
    // traceability. See extmap.go:54-60.
    final parsedValue = int.tryParse(valdir[0]);
    final value = parsedValue ?? 0;
    if (value < 1 || value > 246) {
      throw ExtMapSyntaxException(
        '${valdir[0]} -- extmap key must be in the range 1-256',
      );
    }

    Direction? direction;
    if (valdir.length == 2) {
      direction = Direction.fromRaw(valdir[1]);
    }

    final uri = Uri.parse(fields[1]);

    if (fields.length == 3) {
      extAttr = fields[2];
    }

    this.value = value;
    this.direction = direction;
    this.uri = uri;
  }

  /// Creates a string from this [ExtMap]. Port of `ExtMap.Marshal`
  /// (extmap.go:88).
  String marshal() => '${name()}:${_string()}';

  String _string() {
    final buffer = StringBuffer('$value');
    final dir = direction;
    if (dir != null) {
      buffer
        ..write('/')
        ..write(dir);
    }
    if (uri != null) {
      buffer
        ..write(' ')
        ..write(uri);
    }
    if (extAttr != null) {
      buffer
        ..write(' ')
        ..write(extAttr);
    }
    return buffer.toString();
  }

  /// Returns the constant name of this object. Port of `ExtMap.Name`
  /// (extmap.go:111).
  String name() => 'extmap';
}
