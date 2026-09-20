// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
part of '../transpiled_pion_sdp.dart';

// Port of github.com/pion/sdp/v3 media_description.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md).

/// A media type. Port of `sdp.MediaDescription` (media_description.go:12).
/// https://tools.ietf.org/html/rfc4566#section-5.14
class MediaDescription {
  MediaDescription({
    required this.mediaName,
    this.mediaTitle,
    this.connectionInformation,
    List<Bandwidth>? bandwidth,
    this.encryptionKey,
    List<Attribute>? attributes,
  })  : bandwidth = bandwidth ?? [],
        attributes = attributes ?? [];

  /// Creates a new [MediaDescription] with settings required by the JSEP
  /// spec. Port of `NewJSEPMediaDescription` (jsep.go:164).
  ///
  /// Declared here rather than in jsep.dart for the same reason as
  /// [SessionDescription.jsep] -- see that constructor's doc comment.
  ///
  /// [formats] is accepted but unused, matching upstream's own unused
  /// `_ []string` parameter (jsep.go:164).
  // ignore: avoid_unused_constructor_parameters
  factory MediaDescription.jsep(String codecType, List<String> formats) {
    return MediaDescription(
      mediaName: MediaName(
        media: codecType,
        port: RangedPort(value: 9),
        protos: ['UDP', 'TLS', 'RTP', 'SAVPF'],
      ),
      connectionInformation: ConnectionInformation(
        networkType: 'IN',
        addressType: 'IP4',
        address: Address(address: '0.0.0.0'),
      ),
    );
  }

  /// `m=<media> <port>/<number of ports> <proto> <fmt> ...`.
  /// https://tools.ietf.org/html/rfc4566#section-5.14
  MediaName mediaName;

  /// `i=<session description>`. https://tools.ietf.org/html/rfc4566#section-5.4
  Information? mediaTitle;

  /// `c=<nettype> <addrtype> <connection-address>`.
  /// https://tools.ietf.org/html/rfc4566#section-5.7
  ConnectionInformation? connectionInformation;

  /// `b=<bwtype>:<bandwidth>`. https://tools.ietf.org/html/rfc4566#section-5.8
  List<Bandwidth> bandwidth;

  /// `k=<method>` / `k=<method>:<encryption key>`.
  /// https://tools.ietf.org/html/rfc4566#section-5.12
  EncryptionKey? encryptionKey;

  /// `a=<attribute>` / `a=<attribute>:<value>`.
  /// https://tools.ietf.org/html/rfc4566#section-5.13
  List<Attribute> attributes;

  /// Returns the value of an attribute and whether it exists. Port of
  /// `MediaDescription.Attribute` (media_description.go:41).
  (String, bool) attribute(String key) {
    for (final a in attributes) {
      if (a.key == key) {
        return (a.value, true);
      }
    }
    return ('', false);
  }
}

/// Supports the special format for the media field `m=` port value: when it
/// is necessary to specify multiple transport ports, the protocol allows
/// `<port>/<number of ports>`, `number of ports` being an offsetting range.
/// Port of `sdp.RangedPort` (media_description.go:55).
class RangedPort {
  RangedPort({required this.value, this.range});

  int value;
  int? range;

  @override
  String toString() {
    final buffer = StringBuffer(value.toString());
    if (range != null) {
      buffer
        ..write('/')
        ..write(range);
    }
    return buffer.toString();
  }

  int _marshalSize() {
    var size = _lenInt(value);
    if (range != null) {
      size += 1 + _lenInt(range!);
    }
    return size;
  }
}

/// The `m=` field's storage structure. Port of `sdp.MediaName`
/// (media_description.go:89).
class MediaName {
  MediaName({
    this.media = '',
    RangedPort? port,
    List<String>? protos,
    List<String>? formats,
  })  : port = port ?? RangedPort(value: 0),
        protos = protos ?? [],
        formats = formats ?? [];

  String media;
  RangedPort port;
  List<String> protos;
  List<String> formats;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..write(media)
      ..write(' ')
      ..write(port)
      ..write(' ')
      ..write(protos.join('/'))
      ..write(' ')
      ..write(formats.join(' '));
    return buffer.toString();
  }

  int _marshalSize() {
    var size = _utf8Length(media) + 1 + port._marshalSize();
    for (final p in protos) {
      size += 1 + _utf8Length(p);
    }
    for (final f in formats) {
      size += 1 + _utf8Length(f);
    }
    return size;
  }
}
