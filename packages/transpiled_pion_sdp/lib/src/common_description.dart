// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
part of '../transpiled_pion_sdp.dart';

// Port of github.com/pion/sdp/v3 common_description.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md).

/// The `i=` field, providing free-text session information. Port of
/// `sdp.Information` (common_description.go:12).
// Extension types cannot redeclare `Object` members (`toString`, `==`,
// `hashCode`) -- Dart resolves those to identity-based defaults unless the
// extension type `implements` an interface that brings in different ones.
// Rather than `implements String` (which would pull in String's entire
// method surface just to get a working `toString`), these thin wrappers
// expose their text via the representation parameter `value` -- already a
// public getter -- and callers use `.value` where upstream would call
// `.String()`.
extension type const Information(String value) {
  int _marshalSize() => _utf8Length(value);
}

/// The `c=` field's structured representation, containing connection data.
/// Port of `sdp.ConnectionInformation` (common_description.go:28).
class ConnectionInformation {
  ConnectionInformation({
    this.networkType = '',
    this.addressType = '',
    this.address,
  });

  String networkType;
  String addressType;
  Address? address;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..write(networkType)
      ..write(' ')
      ..write(addressType);
    if (address != null) {
      buffer
        ..write(' ')
        ..write(address);
    }
    return buffer.toString();
  }

  int _marshalSize() {
    var size = _utf8Length(networkType) + 1 + _utf8Length(addressType);
    if (address != null) {
      size += 1 + address!._marshalSize();
    }
    return size;
  }
}

/// A structured address token from within the `c=` field. Port of
/// `sdp.Address` (common_description.go:61).
class Address {
  Address({required this.address, this.ttl, this.range});

  String address;
  int? ttl;
  int? range;

  @override
  String toString() {
    final buffer = StringBuffer(address);
    if (ttl != null) {
      buffer
        ..write('/')
        ..write(ttl);
    }
    if (range != null) {
      buffer
        ..write('/')
        ..write(range);
    }
    return buffer.toString();
  }

  int _marshalSize() {
    var size = _utf8Length(address);
    if (ttl != null) {
      size += 1 + _lenUint(Golang.Uint64(ttl!));
    }
    if (range != null) {
      size += 1 + _lenUint(Golang.Uint64(range!));
    }
    return size;
  }
}

/// The optional field denoting proposed session or media bandwidth. Port of
/// `sdp.Bandwidth` (common_description.go:99).
class Bandwidth {
  Bandwidth({
    this.experimental = false,
    required this.type,
    required this.bandwidth,
  });

  bool experimental;
  String type;
  Golang.Uint64 bandwidth;

  @override
  String toString() {
    final buffer = StringBuffer();
    if (experimental) {
      buffer.write('X-');
    }
    buffer
      ..write(type)
      ..write(':')
      ..write(bandwidth);
    return buffer.toString();
  }

  int _marshalSize() {
    var size = 0;
    if (experimental) {
      size += 2;
    }
    return size + _utf8Length(type) + 1 + _lenUint(bandwidth);
  }
}

/// The `k=` field, conveying encryption key information. Port of
/// `sdp.EncryptionKey` (common_description.go:129).
extension type const EncryptionKey(String value) {
  int _marshalSize() => _utf8Length(value);
}

/// The `a=` field, the primary means for extending SDP. Port of
/// `sdp.Attribute` (common_description.go:145).
class Attribute {
  Attribute({this.key = '', this.value = ''});

  /// Constructs a property attribute (`a=key`). Port of
  /// `sdp.NewPropertyAttribute` (common_description.go:151).
  factory Attribute.property(String key) => Attribute(key: key);

  /// Constructs a value attribute (`a=key:value`). Port of
  /// `sdp.NewAttribute` (common_description.go:158).
  factory Attribute.withValue(String key, String value) =>
      Attribute(key: key, value: value);

  String key;
  String value;

  @override
  String toString() {
    final buffer = StringBuffer(key);
    if (value.isNotEmpty) {
      buffer
        ..write(':')
        ..write(value);
    }
    return buffer.toString();
  }

  int _marshalSize() {
    var size = _utf8Length(key);
    if (value.isNotEmpty) {
      size += 1 + _utf8Length(value);
    }
    return size;
  }

  /// Whether this attribute's key equals `"candidate"`. Port of
  /// `Attribute.IsICECandidate` (common_description.go:188).
  bool isIceCandidate() => key == 'candidate';
}
