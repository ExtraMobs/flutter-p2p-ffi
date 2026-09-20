// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
part of '../transpiled_pion_sdp.dart';

// Port of github.com/pion/sdp/v3 util.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md).

/// Indicates which of the end points should initiate the connection
/// establishment. Port of `sdp.ConnectionRole` (util.go:33).
///
/// Modeled as a value class rather than a Dart `enum` because the Go type
/// permits arbitrary underlying `int` values -- upstream's own
/// `TestConnectionRole_String` exercises `ConnectionRole(99)` and expects
/// `"Unknown"`, not a parse failure -- so [toString] falls back to
/// `"Unknown"` for any value that doesn't match a named constant, exactly
/// as the Go `String()` method's default case does.
final class ConnectionRole {
  const ConnectionRole([this.value = 0]);

  /// The endpoint will initiate an outgoing connection.
  static const active = ConnectionRole(1);

  /// The endpoint will accept an incoming connection.
  static const passive = ConnectionRole(2);

  /// The endpoint is willing to accept an incoming connection or to
  /// initiate an outgoing connection.
  static const actpass = ConnectionRole(3);

  /// The endpoint does not want the connection to be established for the
  /// time being.
  static const holdconn = ConnectionRole(4);

  final int value;

  @override
  String toString() => switch (value) {
        1 => 'active',
        2 => 'passive',
        3 => 'actpass',
        4 => 'holdconn',
        _ => 'Unknown',
      };

  @override
  bool operator ==(Object other) =>
      other is ConnectionRole && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Thrown for the sentinel `errPayloadTypeNotFound` (util.go:26), returned
/// by the exported `SessionDescription.GetCodecForPayloadType`.
class PayloadTypeNotFoundException implements Exception {
  PayloadTypeNotFoundException(this.payloadType);

  final int payloadType;

  @override
  String toString() => 'payload type not found: $payloadType';
}

/// Thrown for the sentinel `errCodecNotFound` (util.go:27), returned by the
/// exported `SessionDescription.GetPayloadTypeForCodec`.
class CodecNotFoundException implements Exception {
  @override
  String toString() => 'codec not found';
}

/// A codec. Port of `sdp.Codec` (util.go:76).
class Codec {
  Codec({
    this.payloadType = 0,
    this.name = '',
    this.clockRate = 0,
    this.encodingParameters = '',
    this.fmtp = '',
    List<String>? rtcpFeedback,
  }) : rtcpFeedback = rtcpFeedback ?? [];

  /// uint8 (0-255).
  int payloadType;
  String name;

  /// uint32.
  int clockRate;
  String encodingParameters;
  String fmtp;
  List<String> rtcpFeedback;

  @override
  String toString() =>
      '$payloadType $name/$clockRate/$encodingParameters ($fmtp) '
      '[${rtcpFeedback.join(', ')}]';

  void _appendRtcpFeedback(String rtcpFeedback) {
    if (this.rtcpFeedback.contains(rtcpFeedback)) {
      return;
    }
    this.rtcpFeedback.add(rtcpFeedback);
  }
}

// a=rtpmap:<payload type> <encoding name>/<clock rate>[/<encoding parameters>]
//
// Upstream's `parseRtpmap`/`parseFmtp`/`parseRtcpFb` (util.go) are
// unexported and their `error` results are only ever used as a
// success/failure signal by `buildCodecMap`, which silently skips whatever
// failed to parse; the error *value* never escapes. This port keeps that
// same "skip on failure" behavior with a nullable return instead of
// throwing-then-immediately-catching a private exception.
Codec? _parseRtpmap(String rtpmap) {
  final split = rtpmap.split(' ');
  if (split.length != 2) {
    return null;
  }

  final ptSplit = split[0].split(':');
  if (ptSplit.length != 2) {
    return null;
  }

  final payloadType = int.tryParse(ptSplit[1]);
  if (payloadType == null || payloadType < 0 || payloadType > 255) {
    return null;
  }

  final codec = Codec(payloadType: payloadType);

  final rest = split[1].split('/');
  codec.name = rest[0];
  if (rest.length > 1) {
    final rate = int.tryParse(rest[1]);
    if (rate == null || rate < 0 || rate > 0xffffffff) {
      return null;
    }
    codec.clockRate = rate;
  }
  if (rest.length > 2) {
    codec.encodingParameters = rest[2];
  }

  return codec;
}

// a=fmtp:<format> <format specific parameters>
Codec? _parseFmtp(String fmtp) {
  final spaceIndex = fmtp.indexOf(' ');
  if (spaceIndex == -1) {
    return null;
  }
  final formatParams = fmtp.substring(spaceIndex + 1);

  final head = fmtp.substring(0, spaceIndex).split(':');
  if (head.length != 2) {
    return null;
  }

  final payloadType = int.tryParse(head[1]);
  if (payloadType == null || payloadType < 0 || payloadType > 255) {
    return null;
  }

  return Codec(payloadType: payloadType, fmtp: formatParams);
}

// a=rtcp-fb:<payload type> <RTCP feedback type> [<RTCP feedback parameter>]
//
// Returns `(codec, isWildcard)`, or `null` on parse failure -- see the note
// above `_parseRtpmap`. This mirrors Go's `(codec Codec, isWildcard bool,
// err error)` triple return with a private record instead of a public
// tuple, which this project's rules only forbid in public APIs.
(Codec, bool)? _parseRtcpFb(String rtcpFb) {
  final spaceIndex = rtcpFb.indexOf(' ');
  if (spaceIndex == -1) {
    return null;
  }
  final head = rtcpFb.substring(0, spaceIndex);
  final rest = rtcpFb.substring(spaceIndex + 1);

  final ptSplit = head.split(':');
  if (ptSplit.length != 2) {
    return null;
  }

  final isWildcard = ptSplit[1] == '*';
  final codec = Codec();
  if (!isWildcard) {
    final payloadType = int.tryParse(ptSplit[1]);
    if (payloadType == null || payloadType < 0 || payloadType > 255) {
      return null;
    }
    codec.payloadType = payloadType;
  }
  codec.rtcpFeedback.add(rest);

  return (codec, isWildcard);
}

void _mergeCodecs(Codec codec, Map<int, Codec> codecs) {
  final savedCodec = codecs[codec.payloadType] ?? Codec();

  if (savedCodec.payloadType == 0) {
    savedCodec.payloadType = codec.payloadType;
  }
  if (savedCodec.name.isEmpty) {
    savedCodec.name = codec.name;
  }
  if (savedCodec.clockRate == 0) {
    savedCodec.clockRate = codec.clockRate;
  }
  if (savedCodec.encodingParameters.isEmpty) {
    savedCodec.encodingParameters = codec.encodingParameters;
  }
  if (savedCodec.fmtp.isEmpty) {
    savedCodec.fmtp = codec.fmtp;
  }
  savedCodec.rtcpFeedback.addAll(codec.rtcpFeedback);

  codecs[savedCodec.payloadType] = savedCodec;
}

bool _equivalentFmtp(String want, String got) {
  final wantSplit = want.split(';');
  final gotSplit = got.split(';');
  if (wantSplit.length != gotSplit.length) {
    return false;
  }

  wantSplit.sort();
  gotSplit.sort();

  for (var i = 0; i < wantSplit.length; i++) {
    final wantPart = wantSplit[i].trim();
    final gotPart = gotSplit[i].trim();
    if (gotPart != wantPart) {
      return false;
    }
  }

  return true;
}

bool _codecsMatch(Codec wanted, Codec got) {
  if (wanted.name.isNotEmpty &&
      wanted.name.toLowerCase() != got.name.toLowerCase()) {
    return false;
  }
  if (wanted.clockRate != 0 && wanted.clockRate != got.clockRate) {
    return false;
  }
  if (wanted.encodingParameters.isNotEmpty &&
      wanted.encodingParameters != got.encodingParameters) {
    return false;
  }
  if (wanted.fmtp.isNotEmpty && !_equivalentFmtp(wanted.fmtp, got.fmtp)) {
    return false;
  }
  return true;
}

/// Codec lookups over a [SessionDescription]. Port of the `buildCodecMap`,
/// `GetCodecForPayloadType`, `GetCodecsForPayloadTypes` and
/// `GetPayloadTypeForCodec` methods (util.go:229-365), added here via
/// extension because upstream defines them on `*SessionDescription` from a
/// file other than the one declaring the struct -- Go allows a type's
/// methods to live in any file of the same package, but a Dart class must
/// be fully declared in one place, so an extension is this port's
/// equivalent for "more members, different file, same type".
extension SessionDescriptionCodecs on SessionDescription {
  Map<int, Codec> _buildCodecMap() {
    final codecs = <int, Codec>{
      // Static codecs that do not require an rtpmap.
      0: Codec(payloadType: 0, name: 'PCMU', clockRate: 8000),
      8: Codec(payloadType: 8, name: 'PCMA', clockRate: 8000),
      9: Codec(payloadType: 9, name: 'G722', clockRate: 8000),
    };

    final wildcardRtcpFeedback = <String>[];
    for (final m in mediaDescriptions) {
      for (final a in m.attributes) {
        final attr = a.toString();
        if (attr.startsWith('rtpmap:')) {
          final codec = _parseRtpmap(attr);
          if (codec != null) {
            _mergeCodecs(codec, codecs);
          }
        } else if (attr.startsWith('fmtp:')) {
          final codec = _parseFmtp(attr);
          if (codec != null) {
            _mergeCodecs(codec, codecs);
          }
        } else if (attr.startsWith('rtcp-fb:')) {
          final parsed = _parseRtcpFb(attr);
          if (parsed != null) {
            final (codec, isWildcard) = parsed;
            if (isWildcard) {
              wildcardRtcpFeedback.addAll(codec.rtcpFeedback);
            } else {
              _mergeCodecs(codec, codecs);
            }
          }
        }
      }
    }

    for (final key in codecs.keys.toList()) {
      final codec = codecs[key]!;
      for (final newRtcpFeedback in wildcardRtcpFeedback) {
        codec._appendRtcpFeedback(newRtcpFeedback);
      }
      codecs[key] = codec;
    }

    return codecs;
  }

  /// Scans this session description for [payloadType] and returns its
  /// codec. Port of `SessionDescription.GetCodecForPayloadType`
  /// (util.go:328).
  Codec getCodecForPayloadType(int payloadType) {
    final codecs = _buildCodecMap();
    final codec = codecs[payloadType];
    if (codec != null) {
      return codec;
    }
    throw PayloadTypeNotFoundException(payloadType);
  }

  /// Port of `SessionDescription.GetCodecsForPayloadTypes` (util.go:339).
  List<Codec> getCodecsForPayloadTypes(List<int> payloadTypes) {
    final codecs = _buildCodecMap();
    final result = <Codec>[];
    for (final payloadType in payloadTypes) {
      final codec = codecs[payloadType];
      if (codec != null) {
        result.add(codec);
      }
    }
    return result;
  }

  /// Scans this session description for a codec that matches [wanted] as
  /// closely as possible and returns its payload type. Port of
  /// `SessionDescription.GetPayloadTypeForCodec` (util.go:355).
  int getPayloadTypeForCodec(Codec wanted) {
    final codecs = _buildCodecMap();
    for (final entry in codecs.entries) {
      if (_codecsMatch(wanted, entry.value)) {
        return entry.key;
      }
    }
    throw CodecNotFoundException();
  }
}

/// Generates a session ID per the JSEP recommendation of a 64-bit quantity
/// with the highest bit cleared. Port of `newSessionID` (util.go:65).
Golang.Uint64 _newSessionId() {
  final id = Golang.Uint64(cryptoUint64());
  return id & ~(Golang.Uint64(1) << 63);
}

/// A parser state: consumes from [_Lexer] and returns the next state (a
/// value of this same shape again), or `null` at a clean end of input. Port
/// of `sdp.stateFn` (util.go:367).
///
/// Go's `type stateFn func(*lexer) (stateFn, error)` refers to itself
/// directly; Dart's `typedef` rejects any function-type alias that
/// references itself, even indirectly. Since this state-machine plumbing is
/// entirely private and never crosses the package's public API, this port
/// aliases the return type as `dynamic` and casts back to `_StateFn?` at
/// the two places a state is actually invoked ([_LexerHandleType.handleType]
/// and the loop in `SessionDescriptionUnmarshal.unmarshalString`), rather
/// than introducing a wrapper class purely to route around the typedef
/// restriction.
typedef _StateFn = dynamic Function(_Lexer);

/// Port of `sdp.keyToState` (util.go:375).
typedef _KeyToState = dynamic Function(int key);

/// Parser cursor carrying the [SessionDescription] being populated and the
/// attribute cache. Port of `sdp.lexer` (util.go:369), which embeds
/// `baseLexer` for Go method promotion; this port uses ordinary class
/// inheritance for the same effect.
class _Lexer extends _BaseLexer {
  _Lexer(super.value);

  SessionDescription? desc;
  _UnmarshalCache? cache;
}

extension _LexerHandleType on _Lexer {
  /// Port of `lexer.handleType` (util.go:377).
  _StateFn? handleType(_KeyToState fn) {
    final key = readType();
    if (key == null) {
      return null;
    }

    final res = fn(key) as _StateFn?;
    if (res != null) {
      return res;
    }

    throw syntaxError();
  }
}
