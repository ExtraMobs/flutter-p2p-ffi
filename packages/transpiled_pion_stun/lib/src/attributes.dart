/// Port of `attributes.go` (pion/stun v3.1.1).
///
/// Go's `type Attributes []RawAttribute` becomes a plain `List<RawAttribute>`
/// (that is exactly [Message.attributes]'s Dart type) plus the [get]
/// extension method below, rather than a dedicated wrapper class: the Go
/// type exists only to hang one method (`Get`) off a slice, and
/// `List<RawAttribute>` already is the natural Dart shape for that slice
/// everywhere else it is used (`Message.Attributes`, `ForEach`, `Equal`).
library;

import 'dart:typed_data';

import 'helpers.dart';
import 'message.dart';

/// Port of `AttrType` (attributes.go:29): a STUN attribute type.
final class AttrType {
  const AttrType(this.value);

  /// Port of `AttrType.Value` (attributes.go:220-222).
  final int value;

  /// Port of `AttrType.Required` (attributes.go:32-34): true if type is
  /// from the comprehension-required range (0x0000-0x7FFF).
  bool get required => value <= 0x7FFF;

  /// Port of `AttrType.Optional` (attributes.go:36-38): true if type is
  /// from the comprehension-optional range (0x8000-0xFFFF).
  bool get optional => value >= 0x8000;

  /// Port of `AttrType.Known` (attributes.go:225-229).
  bool get known => _attrNames.containsKey(this);

  @override
  bool operator ==(Object other) => other is AttrType && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// Port of `AttrType.String` (attributes.go:215-222).
  @override
  String toString() => _attrNames[this] ?? '0x${value.toRadixString(16)}';

  // Attributes from comprehension-required range (0x0000-0x7FFF).
  static const AttrType mappedAddress = AttrType(0x0001);
  static const AttrType username = AttrType(0x0006);
  static const AttrType messageIntegrity = AttrType(0x0008);
  static const AttrType errorCode = AttrType(0x0009);
  static const AttrType unknownAttributes = AttrType(0x000A);
  static const AttrType realm = AttrType(0x0014);
  static const AttrType nonce = AttrType(0x0015);
  static const AttrType xorMappedAddress = AttrType(0x0020);

  // Attributes from comprehension-optional range (0x8000-0xFFFF).
  static const AttrType software = AttrType(0x8022);
  static const AttrType alternateServer = AttrType(0x8023);
  static const AttrType fingerprint = AttrType(0x8028);

  // Attributes from RFC 5245 ICE.
  static const AttrType priority = AttrType(0x0024);
  static const AttrType useCandidate = AttrType(0x0025);
  static const AttrType iceControlled = AttrType(0x8029);
  static const AttrType iceControlling = AttrType(0x802A);

  // Attributes from RFC 5766 TURN.
  static const AttrType channelNumber = AttrType(0x000C);
  static const AttrType lifetime = AttrType(0x000D);
  static const AttrType xorPeerAddress = AttrType(0x0012);
  static const AttrType data = AttrType(0x0013);
  static const AttrType xorRelayedAddress = AttrType(0x0016);
  static const AttrType evenPort = AttrType(0x0018);
  static const AttrType requestedTransport = AttrType(0x0019);
  static const AttrType dontFragment = AttrType(0x001A);
  static const AttrType reservationToken = AttrType(0x0022);

  // Attributes from RFC 5780 NAT Behavior Discovery.
  static const AttrType changeRequest = AttrType(0x0003);
  static const AttrType padding = AttrType(0x0026);
  static const AttrType responsePort = AttrType(0x0027);
  static const AttrType cacheTimeout = AttrType(0x8027);
  static const AttrType responseOrigin = AttrType(0x802b);
  static const AttrType otherAddress = AttrType(0x802C);

  // Attributes from RFC 3489, removed by RFC 5389, but still used by
  // RFC5389-implementing software like Vovida.org, reTURNServer, etc.
  static const AttrType sourceAddress = AttrType(0x0004);
  static const AttrType changedAddress = AttrType(0x0005);

  // Attributes from RFC 6062 TURN Extensions for TCP Allocations.
  static const AttrType connectionId = AttrType(0x002a);

  // Attributes from RFC 6156 TURN IPv6.
  static const AttrType requestedAddressFamily = AttrType(0x0017);

  // Attributes from An Origin Attribute for the STUN Protocol.
  static const AttrType origin = AttrType(0x802F);

  // Attributes from RFC 8489 STUN.
  static const AttrType messageIntegritySha256 = AttrType(0x001C);
  static const AttrType passwordAlgorithm = AttrType(0x001D);
  static const AttrType userhash = AttrType(0x001E);
  static const AttrType passwordAlgorithms = AttrType(0x8002);
  static const AttrType alternateDomain = AttrType(0x8003);

  // Attributes from SPED.
  static const AttrType dtlsInStun = AttrType(0xC070);
  static const AttrType dtlsInStunAck = AttrType(0xC071);
}

/// Port of `attrNames` (attributes.go:126-160).
final Map<AttrType, String> _attrNames = {
  AttrType.mappedAddress: 'MAPPED-ADDRESS',
  AttrType.username: 'USERNAME',
  AttrType.errorCode: 'ERROR-CODE',
  AttrType.messageIntegrity: 'MESSAGE-INTEGRITY',
  AttrType.unknownAttributes: 'UNKNOWN-ATTRIBUTES',
  AttrType.realm: 'REALM',
  AttrType.nonce: 'NONCE',
  AttrType.xorMappedAddress: 'XOR-MAPPED-ADDRESS',
  AttrType.software: 'SOFTWARE',
  AttrType.alternateServer: 'ALTERNATE-SERVER',
  AttrType.fingerprint: 'FINGERPRINT',
  AttrType.priority: 'PRIORITY',
  AttrType.useCandidate: 'USE-CANDIDATE',
  AttrType.iceControlled: 'ICE-CONTROLLED',
  AttrType.iceControlling: 'ICE-CONTROLLING',
  AttrType.channelNumber: 'CHANNEL-NUMBER',
  AttrType.lifetime: 'LIFETIME',
  AttrType.xorPeerAddress: 'XOR-PEER-ADDRESS',
  AttrType.data: 'DATA',
  AttrType.xorRelayedAddress: 'XOR-RELAYED-ADDRESS',
  AttrType.evenPort: 'EVEN-PORT',
  AttrType.requestedTransport: 'REQUESTED-TRANSPORT',
  AttrType.dontFragment: 'DONT-FRAGMENT',
  AttrType.reservationToken: 'RESERVATION-TOKEN',
  AttrType.connectionId: 'CONNECTION-ID',
  AttrType.requestedAddressFamily: 'REQUESTED-ADDRESS-FAMILY',
  AttrType.messageIntegritySha256: 'MESSAGE-INTEGRITY-SHA256',
  AttrType.passwordAlgorithm: 'PASSWORD-ALGORITHM',
  AttrType.userhash: 'USERHASH',
  AttrType.passwordAlgorithms: 'PASSWORD-ALGORITHMS',
  AttrType.alternateDomain: 'ALTERNATE-DOMAIN',
  AttrType.dtlsInStun: 'DTLS-IN-STUN',
  AttrType.dtlsInStunAck: 'DTLS-IN-STUN-ACKNOWLEDGEMENT',
};

/// Port of `RawAttribute` (attributes.go:190-196): a Type-Length-Value (TLV)
/// object that can be added to a STUN message.
final class RawAttribute implements Setter {
  RawAttribute({required this.type, required this.length, required this.value});

  AttrType type;

  /// Ignored while encoding.
  int length;
  Uint8List value;

  /// Port of `RawAttribute.AddTo` (attributes.go:199-203): adds attribute as
  /// `type` with `value`, ignoring `length`.
  @override
  void addTo(Message m) => m.add(type, value);

  /// Port of `RawAttribute.Equal` (attributes.go:206-220).
  bool equalTo(RawAttribute b) {
    if (type != b.type) return false;
    if (length != b.length) return false;
    if (value.length != b.value.length) return false;
    for (var i = 0; i < value.length; i++) {
      if (b.value[i] != value[i]) return false;
    }
    return true;
  }

  /// Port of `RawAttribute.String` (attributes.go:223-225).
  @override
  String toString() {
    final hex = value.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$type: 0x$hex';
  }
}

/// Port of `ErrAttributeNotFound` (attributes.go:229): no attribute with the
/// requested type exists in the message.
final class AttributeNotFoundException implements Exception {
  const AttributeNotFoundException();

  @override
  String toString() => 'attribute not found';
}

/// Port of `Attributes.Get` (attributes.go:16-26), as an extension over the
/// plain `List<RawAttribute>` used for `Message.attributes`; see the
/// file-level doc comment for why there is no dedicated `Attributes` type.
extension AttributesX on List<RawAttribute> {
  /// Returns the first attribute of type [t], or `null` if none is present
  /// (Go's `(RawAttribute, bool)` "comma ok" becomes a nullable return, the
  /// idiomatic Dart shape for a non-error "found or not" query).
  RawAttribute? get(AttrType t) {
    for (final candidate in this) {
      if (candidate.type == t) return candidate;
    }
    return null;
  }
}

/// STUN aligns attributes on 32-bit boundaries; padding is 4 bytes.
/// Port of `padding` (attributes.go:255).
const int padding = 4;

/// Port of `nearestPaddedValueLength` (attributes.go:257-263).
int nearestPaddedValueLength(int l) {
  var n = padding * (l ~/ padding);
  if (n < l) n += padding;
  return n;
}

/// Port of `compatAttrType` (attributes.go:267-273): translates the old
/// (pre-RFC5389bis-03) 0x8020 XOR-MAPPED-ADDRESS type to the current one,
/// for backward compatibility. See
/// https://github.com/pion/stun/issues/21.
AttrType compatAttrType(int val) {
  if (val == 0x8020) return AttrType.xorMappedAddress;
  return AttrType(val);
}

/// Port of `Message.Get` (attributes.go:232-239): returns the byte slice
/// that represents the attribute value, throwing
/// [AttributeNotFoundException] if there is no attribute with type [t].
extension MessageGetX on Message {
  Uint8List get(AttrType t) {
    final v = attributes.get(t);
    if (v == null) throw const AttributeNotFoundException();
    return v.value;
  }
}
