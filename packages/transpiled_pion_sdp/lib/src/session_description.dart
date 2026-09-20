// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
part of '../transpiled_pion_sdp.dart';

// Port of github.com/pion/sdp/v3 session_description.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md).

/// A well-defined format for conveying sufficient information to discover
/// and participate in a multimedia session. Port of
/// `sdp.SessionDescription` (session_description.go:13).
class SessionDescription {
  SessionDescription({
    this.version = const Version(0),
    Origin? origin,
    this.sessionName = const SessionName(''),
    this.sessionInformation,
    this.uri,
    this.emailAddress,
    this.phoneNumber,
    this.connectionInformation,
    List<Bandwidth>? bandwidth,
    List<TimeDescription>? timeDescriptions,
    List<TimeZone>? timeZones,
    this.encryptionKey,
    List<Attribute>? attributes,
    List<MediaDescription>? mediaDescriptions,
  })  : origin = origin ?? Origin(),
        bandwidth = bandwidth ?? [],
        timeDescriptions = timeDescriptions ?? [],
        timeZones = timeZones ?? [],
        attributes = attributes ?? [],
        mediaDescriptions = mediaDescriptions ?? [];

  /// Creates a new [SessionDescription] with settings required by the JSEP
  /// spec. Port of `NewJSEPSessionDescription` (jsep.go:69).
  ///
  /// A named constructor is this port's equivalent of Go's `NewX`
  /// free-function convention (see this project's rules on avoiding
  /// artificial `newX` functions). It has to be declared here, alongside
  /// [SessionDescription]'s other constructors, rather than in jsep.dart
  /// where upstream places `NewJSEPSessionDescription`: Go lets a package
  /// spread one type's methods across files, but Dart requires every
  /// constructor of a class to appear in that class's own declaration --
  /// unlike ordinary methods, a constructor cannot be added from another
  /// file via `extension`. jsep.dart carries a pointer back to this
  /// constructor and to [MediaDescription.jsep] for the same reason.
  ///
  /// Since v2.4.0 upstream, the session ID uses `crypto/rand`, so the Go
  /// signature returns `(*SessionDescription, error)`; per this project's
  /// rule against public error-tuple returns, failure to obtain secure
  /// randomness throws (see [cryptoUint64]) instead.
  factory SessionDescription.jsep({bool identity = false}) {
    final descr = SessionDescription(
      origin: Origin(
        username: '-',
        sessionId: _newSessionId(),
        sessionVersion:
            Golang.Uint64(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        networkType: 'IN',
        addressType: 'IP4',
        unicastAddress: '0.0.0.0',
      ),
      sessionName: const SessionName('-'),
      timeDescriptions: [
        TimeDescription(
          timing: Timing(startTime: Golang.Uint64(), stopTime: Golang.Uint64()),
        ),
      ],
      attributes: [],
    );
    if (identity) {
      descr.withPropertyAttribute(attrKeyIdentity);
    }
    return descr;
  }

  /// `v=0`. https://tools.ietf.org/html/rfc4566#section-5.1
  Version version;

  /// `o=<username>`, `<sess-id>`, `<sess-version>`, `<nettype>`,
  /// `<addrtype>`, `<unicast-address>`.
  /// https://tools.ietf.org/html/rfc4566#section-5.2
  Origin origin;

  /// `s=<session name>`. https://tools.ietf.org/html/rfc4566#section-5.3
  SessionName sessionName;

  /// `i=<session description>`. https://tools.ietf.org/html/rfc4566#section-5.4
  Information? sessionInformation;

  /// `u=<uri>`. https://tools.ietf.org/html/rfc4566#section-5.5
  Uri? uri;

  /// `e=<email-address>`. https://tools.ietf.org/html/rfc4566#section-5.6
  EmailAddress? emailAddress;

  /// `p=<phone-number>`. https://tools.ietf.org/html/rfc4566#section-5.6
  PhoneNumber? phoneNumber;

  /// `c=<nettype> <addrtype> <connection-address>`.
  /// https://tools.ietf.org/html/rfc4566#section-5.7
  ConnectionInformation? connectionInformation;

  /// `b=<bwtype>:<bandwidth>`. https://tools.ietf.org/html/rfc4566#section-5.8
  List<Bandwidth> bandwidth;

  /// https://tools.ietf.org/html/rfc4566#section-5.9
  /// https://tools.ietf.org/html/rfc4566#section-5.10
  List<TimeDescription> timeDescriptions;

  /// `z=<adjustment time> <offset> <adjustment time> <offset> ...`.
  /// https://tools.ietf.org/html/rfc4566#section-5.11
  List<TimeZone> timeZones;

  /// `k=<method>` / `k=<method>:<encryption key>`.
  /// https://tools.ietf.org/html/rfc4566#section-5.12
  EncryptionKey? encryptionKey;

  /// `a=<attribute>` / `a=<attribute>:<value>`.
  /// https://tools.ietf.org/html/rfc4566#section-5.13
  List<Attribute> attributes;

  /// https://tools.ietf.org/html/rfc4566#section-5.14
  List<MediaDescription> mediaDescriptions;

  /// Returns the value of an attribute and whether it exists. Port of
  /// `SessionDescription.Attribute` (session_description.go:73).
  (String, bool) attribute(String key) {
    for (final a in attributes) {
      if (a.key == key) {
        return (a.value, true);
      }
    }
    return ('', false);
  }
}

/// The value of the `v=` field, the Session Description Protocol version.
/// Port of `sdp.Version` (session_description.go:85).
// See the note above `Information` (common_description.dart) on why these
// extension types don't override `toString` and instead expose `.value`.
extension type const Version(int value) {
  int _marshalSize() => _lenInt(value);
}

/// The `o=` field's structure: the session originator plus a session
/// identifier and version number. Port of `sdp.Origin`
/// (session_description.go:101).
class Origin {
  Origin({
    this.username = '',
    Golang.Uint64? sessionId,
    Golang.Uint64? sessionVersion,
    this.networkType = '',
    this.addressType = '',
    this.unicastAddress = '',
  })  : sessionId = sessionId ?? Golang.Uint64(),
        sessionVersion = sessionVersion ?? Golang.Uint64();

  String username;
  Golang.Uint64 sessionId;
  Golang.Uint64 sessionVersion;
  String networkType;
  String addressType;
  String unicastAddress;

  @override
  String toString() =>
      '$username $sessionId $sessionVersion $networkType $addressType '
      '$unicastAddress';

  int _marshalSize() =>
      _utf8Length(username) +
      _lenUint(sessionId) +
      _lenUint(sessionVersion) +
      _utf8Length(networkType) +
      _utf8Length(addressType) +
      _utf8Length(unicastAddress) +
      5;
}

/// The `s=` field: the textual session name. Port of `sdp.SessionName`
/// (session_description.go:136).
extension type const SessionName(String value) {
  int _marshalSize() => _utf8Length(value);
}

/// The `e=` field: email contact information for the person responsible for
/// the conference. Port of `sdp.EmailAddress` (session_description.go:153).
extension type const EmailAddress(String value) {
  int _marshalSize() => _utf8Length(value);
}

/// The `p=` field: phone contact information for the person responsible for
/// the conference. Port of `sdp.PhoneNumber` (session_description.go:170).
extension type const PhoneNumber(String value) {
  int _marshalSize() => _utf8Length(value);
}

/// The `z=` field's structured object, describing repeated session
/// scheduling. Port of `sdp.TimeZone` (session_description.go:186).
class TimeZone {
  TimeZone({required this.adjustmentTime, required this.offset});

  Golang.Uint64 adjustmentTime;
  int offset;

  @override
  String toString() => '$adjustmentTime $offset';

  int _marshalSize() => _lenUint(adjustmentTime) + 1 + _lenInt(offset);
}
