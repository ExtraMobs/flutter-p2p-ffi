// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
part of '../transpiled_pion_sdp.dart';

// Port of github.com/pion/sdp/v3 unmarshal.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md).
//
// See `SessionDescription.unmarshalString` below for the state-transition
// table this state machine implements -- reproduced verbatim from upstream's
// doc comment, since it documents the DFA `s1`..`s16` encode.

/// Thrown for the sentinel `errSDPInvalidSyntax` (unmarshal.go:16).
class SdpInvalidSyntaxException implements Exception {
  SdpInvalidSyntaxException(this.detail);

  final String detail;

  @override
  String toString() => 'sdp: invalid syntax `$detail`';
}

/// Thrown for the sentinel `errSDPInvalidNumericValue` (unmarshal.go:17).
class SdpInvalidNumericValueException implements Exception {
  SdpInvalidNumericValueException(this.detail);

  final String detail;

  @override
  String toString() => 'sdp: invalid numeric value `$detail`';
}

/// Thrown for the sentinel `errSDPInvalidValue` (unmarshal.go:18).
class SdpInvalidValueException implements Exception {
  SdpInvalidValueException(this.detail);

  final String detail;

  @override
  String toString() => 'sdp: invalid value `$detail`';
}

/// Thrown for the sentinel `errSDPInvalidPortValue` (unmarshal.go:19).
class SdpInvalidPortValueException implements Exception {
  SdpInvalidPortValueException(this.detail);

  final String detail;

  @override
  String toString() => 'sdp: invalid port value `$detail`';
}

final BigInt _maxUint64 = (BigInt.one << 64) - BigInt.one;

/// Parsing (`Unmarshal*`) for [SessionDescription]. Port of
/// unmarshal.go:30-1050. Added via extension for the same reason as
/// [SessionDescriptionCodecs] in util.dart: upstream attaches these methods
/// to `*SessionDescription` from a file other than the one declaring the
/// struct, which Go permits and Dart's single-class-body rule does not.
extension SessionDescriptionUnmarshal on SessionDescription {
  /// Deserializes [value] and stores it into this [SessionDescription].
  /// Port of `SessionDescription.UnmarshalString` (unmarshal.go:111).
  ///
  /// The state-transition table below (reproduced from upstream) describes
  /// the computation flow between states `s1`..`s16` for a parsing
  /// procedure that complies with RFC 4566 section 5 and the JSEP draft:
  ///
  ///     https://tools.ietf.org/html/rfc4566#section-5
  ///     https://tools.ietf.org/html/draft-ietf-rtcweb-jsep-24
  ///
  /// derived from the regex `vosi?u?e?p?c?b*(tr*)+z?k?a*(mi?c?b*k?a*)*`.
  ///
  /// Upstream pools `*unmarshalCache` instances via `sync.Pool` purely to
  /// reduce GC pressure across concurrent Go calls; since the cache is
  /// unconditionally `reset()` before use either way, this has no effect on
  /// observable output, so this port simply allocates a fresh cache per
  /// call instead of pooling one.
  void unmarshalString(String value) {
    final lex = _Lexer(value)
      ..cache = _UnmarshalCache()
      ..desc = this;

    _StateFn? state = _s1;
    while (state != null) {
      state = state(lex) as _StateFn?;
    }

    attributes = lex.cache!.cloneSessionAttributes();
    _populateMediaAttributes(lex.cache!, lex.desc!);
  }

  /// Converts [value] into a string and calls [unmarshalString]. Callers
  /// should use the more performant [unmarshalString]. Port of
  /// `SessionDescription.Unmarshal` (unmarshal.go:139).
  void unmarshal(List<int> value) => unmarshalString(utf8.decode(value));
}

_StateFn? _s1(_Lexer l) => l.handleType(
      (key) => String.fromCharCode(key) == 'v' ? _unmarshalProtocolVersion : null,
    );

_StateFn? _s2(_Lexer l) => l.handleType(
      (key) => String.fromCharCode(key) == 'o' ? _unmarshalOrigin : null,
    );

_StateFn? _s3(_Lexer l) => l.handleType(
      (key) => String.fromCharCode(key) == 's' ? _unmarshalSessionName : null,
    );

_StateFn? _s4(_Lexer l) => l.handleType((key) {
      switch (String.fromCharCode(key)) {
        case 'i':
          return _unmarshalSessionInformation;
        case 'u':
          return _unmarshalUri;
        case 'e':
          return _unmarshalEmail;
        case 'p':
          return _unmarshalPhone;
        case 'c':
          return _unmarshalSessionConnectionInformation;
        case 'b':
          return _unmarshalSessionBandwidth;
        case 't':
          return _unmarshalTiming;
      }
      return null;
    });

_StateFn? _s5(_Lexer l) => l.handleType((key) {
      switch (String.fromCharCode(key)) {
        case 'b':
          return _unmarshalSessionBandwidth;
        case 't':
          return _unmarshalTiming;
      }
      return null;
    });

_StateFn? _s6(_Lexer l) => l.handleType((key) {
      switch (String.fromCharCode(key)) {
        case 'p':
          return _unmarshalPhone;
        case 'c':
          return _unmarshalSessionConnectionInformation;
        case 'b':
          return _unmarshalSessionBandwidth;
        case 't':
          return _unmarshalTiming;
      }
      return null;
    });

_StateFn? _s7(_Lexer l) => l.handleType((key) {
      switch (String.fromCharCode(key)) {
        case 'u':
          return _unmarshalUri;
        case 'e':
          return _unmarshalEmail;
        case 'p':
          return _unmarshalPhone;
        case 'c':
          return _unmarshalSessionConnectionInformation;
        case 'b':
          return _unmarshalSessionBandwidth;
        case 't':
          return _unmarshalTiming;
      }
      return null;
    });

_StateFn? _s8(_Lexer l) => l.handleType((key) {
      switch (String.fromCharCode(key)) {
        case 'c':
          return _unmarshalSessionConnectionInformation;
        case 'b':
          return _unmarshalSessionBandwidth;
        case 't':
          return _unmarshalTiming;
      }
      return null;
    });

_StateFn? _s9(_Lexer l) => l.handleType((key) {
      switch (String.fromCharCode(key)) {
        case 'z':
          return _unmarshalTimeZones;
        case 'k':
          return _unmarshalSessionEncryptionKey;
        case 'a':
          return _unmarshalSessionAttribute;
        case 'r':
          return _unmarshalRepeatTimes;
        case 't':
          return _unmarshalTiming;
        case 'm':
          return _unmarshalMediaDescription;
      }
      return null;
    });

_StateFn? _s10(_Lexer l) => l.handleType((key) {
      switch (String.fromCharCode(key)) {
        case 'e':
          return _unmarshalEmail;
        case 'p':
          return _unmarshalPhone;
        case 'c':
          return _unmarshalSessionConnectionInformation;
        case 'b':
          return _unmarshalSessionBandwidth;
        case 't':
          return _unmarshalTiming;
      }
      return null;
    });

_StateFn? _s11(_Lexer l) => l.handleType((key) {
      switch (String.fromCharCode(key)) {
        case 'a':
          return _unmarshalSessionAttribute;
        case 'm':
          return _unmarshalMediaDescription;
      }
      return null;
    });

_StateFn? _s12(_Lexer l) => l.handleType((key) {
      switch (String.fromCharCode(key)) {
        case 'a':
          return _unmarshalMediaAttribute;
        case 'k':
          return _unmarshalMediaEncryptionKey;
        case 'b':
          return _unmarshalMediaBandwidth;
        case 'c':
          return _unmarshalMediaConnectionInformation;
        case 'i':
          return _unmarshalMediaTitle;
        case 'm':
          return _unmarshalMediaDescription;
      }
      return null;
    });

_StateFn? _s13(_Lexer l) => l.handleType((key) {
      switch (String.fromCharCode(key)) {
        case 'a':
          return _unmarshalSessionAttribute;
        case 'k':
          return _unmarshalSessionEncryptionKey;
        case 'm':
          return _unmarshalMediaDescription;
      }
      return null;
    });

_StateFn? _s14(_Lexer l) => l.handleType((key) {
      switch (String.fromCharCode(key)) {
        case 'a':
          return _unmarshalMediaAttribute;
        case 'k': // Non-spec ordering.
          return _unmarshalMediaEncryptionKey;
        case 'b': // Non-spec ordering.
          return _unmarshalMediaBandwidth;
        case 'c': // Non-spec ordering.
          return _unmarshalMediaConnectionInformation;
        case 'i': // Non-spec ordering.
          return _unmarshalMediaTitle;
        case 'm':
          return _unmarshalMediaDescription;
      }
      return null;
    });

_StateFn? _s15(_Lexer l) => l.handleType((key) {
      switch (String.fromCharCode(key)) {
        case 'a':
          return _unmarshalMediaAttribute;
        case 'k':
          return _unmarshalMediaEncryptionKey;
        case 'b':
          return _unmarshalMediaBandwidth;
        case 'c':
          return _unmarshalMediaConnectionInformation;
        case 'i': // Non-spec ordering.
          return _unmarshalMediaTitle;
        case 'm':
          return _unmarshalMediaDescription;
      }
      return null;
    });

_StateFn? _s16(_Lexer l) => l.handleType((key) {
      switch (String.fromCharCode(key)) {
        case 'a':
          return _unmarshalMediaAttribute;
        case 'k':
          return _unmarshalMediaEncryptionKey;
        case 'c':
          return _unmarshalMediaConnectionInformation;
        case 'b':
          return _unmarshalMediaBandwidth;
        case 'i': // Non-spec ordering.
          return _unmarshalMediaTitle;
        case 'm':
          return _unmarshalMediaDescription;
      }
      return null;
    });

_StateFn? _unmarshalProtocolVersion(_Lexer l) {
  final version = l.readUint64Field();
  // As of the latest draft of the RFC, this value is required to be 0.
  // https://tools.ietf.org/html/draft-ietf-rtcweb-jsep-24#section-5.8.1
  if (version != Golang.Uint64()) {
    throw SdpInvalidValueException('$version');
  }
  l.nextLine();
  return _s2;
}

_StateFn? _unmarshalOrigin(_Lexer lex) {
  final origin = lex.desc!.origin;

  origin.username = lex.readField();
  origin.sessionId = lex.readUint64Field();
  origin.sessionVersion = lex.readUint64Field();
  origin.networkType = lex.readField();

  // Set according to currently registered with IANA.
  // https://tools.ietf.org/html/rfc4566#section-8.2.6
  if (!_anyOf(origin.networkType, const ['IN'])) {
    throw SdpInvalidValueException(origin.networkType);
  }

  _handleAddressType(lex);

  // Set according to currently registered with IANA.
  // https://tools.ietf.org/html/rfc4566#section-8.2.7
  if (!_anyOf(origin.addressType, const ['IP4', 'IP6'])) {
    throw SdpInvalidValueException(origin.addressType);
  }

  _handleUnicastAddress(lex);

  lex.nextLine();
  return _s3;
}

/// Processes the `AddressType` field with graceful handling for missing
/// fields. Port of `handleAddressType` (unmarshal.go:494).
void _handleAddressType(_Lexer lex) {
  final String addressType;
  try {
    addressType = lex.readRequiredField();
  } on _FieldMissingException {
    // Field missing -- use defaults for camera compatibility.
    lex.desc!.origin
      ..addressType = 'IP4'
      ..unicastAddress = '0.0.0.0';
    return;
  }
  lex.desc!.origin.addressType = addressType;
}

/// Processes the `UnicastAddress` field with graceful handling for missing
/// fields. Port of `handleUnicastAddress` (unmarshal.go:514).
void _handleUnicastAddress(_Lexer lex) {
  final String unicastAddress;
  try {
    unicastAddress = lex.readRequiredField();
  } on _FieldMissingException {
    lex.desc!.origin.unicastAddress =
        lex.desc!.origin.addressType == 'IP6' ? '::' : '0.0.0.0';
    return;
  }
  lex.desc!.origin.unicastAddress = unicastAddress;
}

_StateFn? _unmarshalSessionName(_Lexer l) {
  l.desc!.sessionName = SessionName(l.readLine());
  return _s4;
}

_StateFn? _unmarshalSessionInformation(_Lexer l) {
  l.desc!.sessionInformation = Information(l.readLine());
  return _s7;
}

_StateFn? _unmarshalUri(_Lexer l) {
  l.desc!.uri = Uri.parse(l.readLine());
  return _s10;
}

_StateFn? _unmarshalEmail(_Lexer l) {
  l.desc!.emailAddress = EmailAddress(l.readLine());
  return _s6;
}

_StateFn? _unmarshalPhone(_Lexer l) {
  l.desc!.phoneNumber = PhoneNumber(l.readLine());
  return _s8;
}

_StateFn? _unmarshalSessionConnectionInformation(_Lexer l) {
  l.desc!.connectionInformation = l._unmarshalConnectionInformation();
  return _s5;
}

extension _LexerConnectionInformation on _Lexer {
  ConnectionInformation _unmarshalConnectionInformation() {
    final connInfo = ConnectionInformation();

    connInfo.networkType = readField();
    // Set according to currently registered with IANA.
    // https://tools.ietf.org/html/rfc4566#section-8.2.6
    if (!_anyOf(connInfo.networkType, const ['IN'])) {
      throw SdpInvalidValueException(connInfo.networkType);
    }

    connInfo.addressType = readField();
    // Set according to currently registered with IANA.
    // https://tools.ietf.org/html/rfc4566#section-8.2.7
    if (!_anyOf(connInfo.addressType, const ['IP4', 'IP6'])) {
      throw SdpInvalidValueException(connInfo.addressType);
    }

    final address = readField();
    if (address.isNotEmpty) {
      connInfo.address = Address(address: address);
    }

    nextLine();
    return connInfo;
  }
}

_StateFn? _unmarshalSessionBandwidth(_Lexer l) {
  final value = l.readLine();
  final Bandwidth bandwidth;
  try {
    bandwidth = _unmarshalBandwidth(value);
  } on Exception catch (_) {
    // Upstream discards the inner error here and always re-wraps as
    // errSDPInvalidValue at the session level (unmarshal.go:658), unlike
    // the media-level call site below which re-wraps as
    // errSDPInvalidSyntax -- an upstream inconsistency preserved as-is.
    throw SdpInvalidValueException('b=$value');
  }
  l.desc!.bandwidth.add(bandwidth);
  return _s5;
}

Bandwidth _unmarshalBandwidth(String value) {
  final parts = value.split(':');
  if (parts.length != 2) {
    throw SdpInvalidValueException('b=$parts');
  }

  var type = parts[0];
  final experimental = type.startsWith('X-');
  if (experimental) {
    type = type.substring(2);
  } else if (!_anyOf(type, const ['CT', 'AS', 'TIAS', 'RS', 'RR'])) {
    // Set according to currently registered with IANA.
    // https://tools.ietf.org/html/rfc4566#section-5.8
    // https://tools.ietf.org/html/rfc3890#section-6.2
    // https://tools.ietf.org/html/rfc3556#section-2
    throw SdpInvalidValueException(type);
  }

  final parsed = BigInt.tryParse(parts[1]);
  if (parsed == null || parsed.isNegative || parsed > _maxUint64) {
    throw SdpInvalidNumericValueException(parts[1]);
  }

  return Bandwidth(
    experimental: experimental,
    type: type,
    bandwidth: Golang.Uint64.fromBigInt(parsed),
  );
}

_StateFn? _unmarshalTiming(_Lexer lex) {
  final startTime = lex.readUint64Field();
  final stopTime = lex.readUint64Field();
  lex.nextLine();
  lex.desc!.timeDescriptions.add(
    TimeDescription(timing: Timing(startTime: startTime, stopTime: stopTime)),
  );
  return _s9;
}

_StateFn? _unmarshalRepeatTimes(_Lexer lex) {
  final latestTimeDesc = lex.desc!.timeDescriptions.last;

  var field = lex.readField();
  final interval = _parseTimeUnits(field);

  field = lex.readField();
  final duration = _parseTimeUnits(field);

  final offsets = <int>[];
  while (true) {
    field = lex.readField();
    if (field.isEmpty) {
      break;
    }
    offsets.add(_parseTimeUnits(field));
  }

  lex.nextLine();
  latestTimeDesc.repeatTimes.add(
    RepeatTime(interval: interval, duration: duration, offsets: offsets),
  );
  return _s9;
}

_StateFn? _unmarshalTimeZones(_Lexer lex) {
  // These fields are transmitted in pairs:
  // z=<adjustment time> <offset> <adjustment time> <offset> ....
  while (true) {
    final adjustmentTime = lex.readUint64Field();

    final offsetField = lex.readField();
    if (offsetField.isEmpty) {
      break;
    }

    final offset = _parseTimeUnits(offsetField);
    lex.desc!.timeZones.add(
      TimeZone(adjustmentTime: adjustmentTime, offset: offset),
    );
  }

  lex.nextLine();
  return _s13;
}

_StateFn? _unmarshalSessionEncryptionKey(_Lexer l) {
  l.desc!.encryptionKey = EncryptionKey(l.readLine());
  return _s11;
}

_StateFn? _unmarshalSessionAttribute(_Lexer l) {
  final value = l.readLine();
  final i = value.indexOf(':');
  final a = l.cache!.getSessionAttribute();
  if (i > 0) {
    a.key = value.substring(0, i);
    a.value = value.substring(i + 1);
  } else {
    a.key = value;
  }
  return _s11;
}

_StateFn? _unmarshalMediaDescription(_Lexer lex) {
  _populateMediaAttributes(lex.cache!, lex.desc!);

  // <media>
  final mediaField = lex.readField();
  // Set according to currently registered with IANA.
  // https://tools.ietf.org/html/rfc4566#section-5.14
  if (!_anyOf(
    mediaField,
    const ['audio', 'video', 'text', 'application', 'message'],
  )) {
    throw SdpInvalidValueException(mediaField);
  }

  final newMediaDesc = MediaDescription(
    mediaName: MediaName(media: mediaField),
  );

  // <port>
  final portField = lex.readField();
  final portParts = portField.split('/');
  newMediaDesc.mediaName.port.value = _parsePort(portParts[0]);

  if (portParts.length > 1) {
    final portRange = int.tryParse(portParts[1]);
    if (portRange == null) {
      throw SdpInvalidValueException('$portParts');
    }
    newMediaDesc.mediaName.port.range = portRange;
  }

  // <proto>
  final protoField = lex.readField();
  // Set according to currently registered with IANA.
  // https://tools.ietf.org/html/rfc4566#section-5.14
  // https://tools.ietf.org/html/rfc4975#section-8.1
  for (final proto in protoField.split('/')) {
    if (!_anyOf(proto, const [
      'UDP',
      'RTP',
      'AVP',
      'SAVP',
      'SAVPF',
      'TLS',
      'DTLS',
      'SCTP',
      'AVPF',
      'TCP',
      'MSRP',
      'BFCP',
      'UDT',
      'IX',
      'MRCPv2',
      'FEC',
    ])) {
      throw SdpInvalidNumericValueException(protoField);
    }
    newMediaDesc.mediaName.protos.add(proto);
  }

  // <fmt>...
  while (true) {
    final field = lex.readField();
    if (field.isEmpty) {
      break;
    }
    newMediaDesc.mediaName.formats.add(field);
  }

  lex.nextLine();
  lex.desc!.mediaDescriptions.add(newMediaDesc);
  return _s12;
}

_StateFn? _unmarshalMediaTitle(_Lexer l) {
  final latestMediaDesc = l.desc!.mediaDescriptions.last;
  latestMediaDesc.mediaTitle = Information(l.readLine());
  return _s16;
}

_StateFn? _unmarshalMediaConnectionInformation(_Lexer l) {
  final latestMediaDesc = l.desc!.mediaDescriptions.last;
  latestMediaDesc.connectionInformation = l._unmarshalConnectionInformation();
  return _s15;
}

_StateFn? _unmarshalMediaBandwidth(_Lexer l) {
  final value = l.readLine();
  final latestMediaDesc = l.desc!.mediaDescriptions.last;
  final Bandwidth bandwidth;
  try {
    bandwidth = _unmarshalBandwidth(value);
  } on Exception catch (_) {
    throw SdpInvalidSyntaxException('b=$value');
  }
  latestMediaDesc.bandwidth.add(bandwidth);
  return _s15;
}

_StateFn? _unmarshalMediaEncryptionKey(_Lexer l) {
  final latestMediaDesc = l.desc!.mediaDescriptions.last;
  latestMediaDesc.encryptionKey = EncryptionKey(l.readLine());
  return _s14;
}

_StateFn? _unmarshalMediaAttribute(_Lexer l) {
  final value = l.readLine();
  final i = value.indexOf(':');
  final a = l.cache!.getMediaAttribute();
  if (i > 0) {
    a.key = value.substring(0, i);
    a.value = value.substring(i + 1);
  } else {
    a.key = value;
  }
  return _s14;
}

int _parseTimeUnits(String value) {
  if (value.isEmpty) {
    throw SdpInvalidValueException(value);
  }
  var multiplier = _timeShorthand(value.codeUnitAt(value.length - 1));
  final String numStr;
  if (multiplier > 0) {
    numStr = value.substring(0, value.length - 1);
  } else {
    multiplier = 1;
    numStr = value;
  }
  final num = int.tryParse(numStr);
  if (num == null) {
    throw SdpInvalidValueException(value);
  }
  return num * multiplier;
}

/// Converts a shorthand time-offset suffix to its multiplier in seconds
/// (RFC 4566's NTP-timestamp-format offsets). Port of `timeShorthand`
/// (unmarshal.go:1015).
int _timeShorthand(int b) {
  switch (String.fromCharCode(b)) {
    case 'd': // days
      return 86400;
    case 'h': // hours
      return 3600;
    case 'm': // minutes
      return 60;
    case 's': // seconds (allowed for completeness)
      return 1;
    default:
      return 0;
  }
}

int _parsePort(String value) {
  final port = int.tryParse(value);
  if (port == null) {
    throw SdpInvalidPortValueException(value);
  }
  if (port < 0 || port > 65535) {
    throw SdpInvalidPortValueException('$port -- out of range');
  }
  return port;
}

void _populateMediaAttributes(_UnmarshalCache c, SessionDescription s) {
  if (s.mediaDescriptions.isNotEmpty) {
    s.mediaDescriptions.last.attributes = c.cloneMediaAttributes();
  }
}
