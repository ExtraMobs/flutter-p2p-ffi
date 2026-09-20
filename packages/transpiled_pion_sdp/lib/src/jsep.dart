// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
part of '../transpiled_pion_sdp.dart';

// Port of github.com/pion/sdp/v3 jsep.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md) -- API to match
// draft-ietf-rtcweb-jsep. `SessionDescription.jsep` and `MediaDescription.jsep`
// (the ports of `NewJSEPSessionDescription`/`NewJSEPMediaDescription`) live
// in session_description.dart/media_description.dart instead of here; see
// the doc comment on `SessionDescription.jsep` for why.

/// SDP attribute keys used in JSEP. Port of the `AttrKey*` constants
/// (jsep.go:15-36).
const String attrKeyCandidate = 'candidate';
const String attrKeyEndOfCandidates = 'end-of-candidates';
const String attrKeyIdentity = 'identity';
const String attrKeyGroup = 'group';
const String attrKeySsrc = 'ssrc';
const String attrKeySsrcGroup = 'ssrc-group';
const String attrKeyMsid = 'msid';
const String attrKeyMsidSemantic = 'msid-semantic';
const String attrKeyConnectionSetup = 'setup';
const String attrKeyMid = 'mid';
const String attrKeyIceLite = 'ice-lite';
const String attrKeyIceOptions = 'ice-options';
const String attrKeyRtcpMux = 'rtcp-mux';
const String attrKeyRtcpRsize = 'rtcp-rsize';
const String attrKeyInactive = 'inactive';
const String attrKeyRecvOnly = 'recvonly';
const String attrKeySendOnly = 'sendonly';
const String attrKeySendRecv = 'sendrecv';
const String attrKeyExtMap = 'extmap';
const String attrKeyExtMapAllowMixed = 'extmap-allow-mixed';
const String attrKeyCryptex = 'cryptex';

/// Semantic tokens used in JSEP. Port of the `SemanticToken*` constants
/// (jsep.go:39-46).
const String semanticTokenLipSynchronization = 'LS';
const String semanticTokenFlowIdentification = 'FID';
const String semanticTokenForwardErrorCorrection = 'FEC';

/// https://datatracker.ietf.org/doc/html/rfc5956#section-4.1
const String semanticTokenForwardErrorCorrectionFramework = 'FEC-FR';
const String semanticTokenWebRtcMediaStreams = 'WMS';

/// Port of `ExtMapValueTransportCC` (jsep.go:50).
const int extMapValueTransportCc = 3;

Map<int, String> _extMapUri() => {
      extMapValueTransportCc: 'http://www.ietf.org/id/draft-holmer-rmcat-'
          'transport-wide-cc-extensions-01',
    };

/// JSEP convenience builders for [SessionDescription]. Port of the
/// `SessionDescription` methods in jsep.go.
extension SessionDescriptionJsep on SessionDescription {
  /// Adds a property attribute (`a=key`) to this session description. Port
  /// of `SessionDescription.WithPropertyAttribute` (jsep.go:107).
  SessionDescription withPropertyAttribute(String key) {
    attributes.add(Attribute.property(key));
    return this;
  }

  /// Adds a value attribute (`a=key:value`) to this session description.
  /// Port of `SessionDescription.WithValueAttribute` (jsep.go:114).
  SessionDescription withValueAttribute(String key, String value) {
    attributes.add(Attribute.withValue(key, value));
    return this;
  }

  SessionDescription _addOrUpdateIceOption(String value) {
    for (final attribute in attributes) {
      if (attribute.key == attrKeyIceOptions) {
        final prefix = attribute.value.isEmpty ? '' : ' ';
        attribute.value += prefix + value;
        return this;
      }
    }
    return withValueAttribute(attrKeyIceOptions, value);
  }

  /// Advertises ICE trickle support in this session description. Port of
  /// `SessionDescription.WithICETrickleAdvertised` (jsep.go:140).
  /// See https://datatracker.ietf.org/doc/html/rfc9429#section-5.2.1
  SessionDescription withIceTrickleAdvertised() =>
      _addOrUpdateIceOption('trickle');

  /// Advertises ICE renomination support in this session description. Port
  /// of `SessionDescription.WithICERenomination` (jsep.go:146). See
  /// https://datatracker.ietf.org/doc/html/draft-thatcher-ice-renomination-01#section-3
  SessionDescription withIceRenomination() =>
      _addOrUpdateIceOption('renomination');

  /// Adds a fingerprint to this session description. Port of
  /// `SessionDescription.WithFingerprint` (jsep.go:151).
  SessionDescription withFingerprint(String algorithm, String value) =>
      withValueAttribute('fingerprint', '$algorithm $value');

  /// Adds a media description to this session description. Port of
  /// `SessionDescription.WithMedia` (jsep.go:156).
  SessionDescription withMedia(MediaDescription md) {
    mediaDescriptions.add(md);
    return this;
  }
}

/// JSEP convenience builders for [MediaDescription]. Port of the
/// `MediaDescription` methods in jsep.go.
extension MediaDescriptionJsep on MediaDescription {
  /// Adds a property attribute (`a=key`) to this media description. Port of
  /// `MediaDescription.WithPropertyAttribute` (jsep.go:182).
  MediaDescription withPropertyAttribute(String key) {
    attributes.add(Attribute.property(key));
    return this;
  }

  /// Adds a value attribute (`a=key:value`) to this media description.
  /// Port of `MediaDescription.WithValueAttribute` (jsep.go:189).
  MediaDescription withValueAttribute(String key, String value) {
    attributes.add(Attribute.withValue(key, value));
    return this;
  }

  /// Adds a fingerprint to this media description. Port of
  /// `MediaDescription.WithFingerprint` (jsep.go:196).
  MediaDescription withFingerprint(String algorithm, String value) =>
      withValueAttribute('fingerprint', '$algorithm $value');

  /// Adds ICE credentials to this media description. Port of
  /// `MediaDescription.WithICECredentials` (jsep.go:201).
  MediaDescription withIceCredentials(String username, String password) =>
      withValueAttribute('ice-ufrag', username)
          .withValueAttribute('ice-pwd', password);

  /// Adds codec information to this media description. Port of
  /// `MediaDescription.WithCodec` (jsep.go:208).
  MediaDescription withCodec(
    int payloadType,
    String name,
    int clockrate,
    int channels,
    String fmtp,
  ) {
    mediaName.formats.add('$payloadType');
    var rtpmap = '$payloadType $name/$clockrate';
    if (channels > 0) {
      rtpmap += '/$channels';
    }
    withValueAttribute('rtpmap', rtpmap);
    if (fmtp.isNotEmpty) {
      withValueAttribute('fmtp', '$payloadType $fmtp');
    }
    return this;
  }

  /// Adds media source information to this media description. Port of
  /// `MediaDescription.WithMediaSource` (jsep.go:229).
  MediaDescription withMediaSource(
    int ssrc,
    String cname,
    String streamLabel,
    String label,
  ) =>
      withValueAttribute('ssrc', '$ssrc cname:$cname') // Deprecated but not phased out?
          .withValueAttribute('ssrc', '$ssrc msid:$streamLabel $label')
          .withValueAttribute('ssrc', '$ssrc mslabel:$streamLabel') // Deprecated but not phased out?
          .withValueAttribute('ssrc', '$ssrc label:$label'); // Deprecated but not phased out?

  /// Adds an ICE candidate to this media description.
  ///
  /// Deprecated: upstream's own doc comment says "use WithICECandidate
  /// instead" (jsep.go:239), but no such method exists in the pinned
  /// revision (`doc/transpilation/UPSTREAM_LOCK.md`) -- it is referenced
  /// only in this deprecation comment. Ported as-is rather than invented.
  @Deprecated('Use a WithICECandidate equivalent instead.')
  MediaDescription withCandidate(String value) =>
      withValueAttribute('candidate', value);

  /// Adds an extmap to this media description. Port of
  /// `MediaDescription.WithExtMap` (jsep.go:245).
  MediaDescription withExtMap(ExtMap extMap) =>
      withPropertyAttribute(extMap.marshal());

  /// Adds a transport-cc extmap to this media description. Port of
  /// `MediaDescription.WithTransportCCExtMap` (jsep.go:250).
  MediaDescription withTransportCcExtMap() {
    final extMap = ExtMap(
      value: extMapValueTransportCc,
      uri: Uri.parse(_extMapUri()[extMapValueTransportCc]!),
    );
    return withExtMap(extMap);
  }
}
