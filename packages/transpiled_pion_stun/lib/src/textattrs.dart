/// Port of `textattrs.go` (pion/stun v3.1.1).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'attributes.dart';
import 'checks.dart';
import 'helpers.dart';
import 'message.dart';

/// Port of `TextAttribute` (textattrs.go:99): helper for adding and getting
/// text attributes.
final class TextAttribute {
  const TextAttribute(this.value);

  final Uint8List value;

  /// Port of `TextAttribute.AddToAs` (textattrs.go:103-109). If `maxLen` is
  /// negative, no length check is performed.
  void addToAs(Message m, AttrType t, int maxLen) {
    if (maxLen >= 0) checkOverflow(t, value.length, maxLen);
    m.add(t, value);
  }

  /// Port of `TextAttribute.GetFromAs` (textattrs.go:112-120).
  static Uint8List getFromAs(Message m, AttrType t) => m.get(t);
}

const int _maxUsernameB = 513;

/// Port of `Username` (textattrs.go:14): the USERNAME attribute (RFC 5389
/// Section 15.3).
final class Username implements Setter, Getter {
  Username(String username) : value = Uint8List.fromList(utf8.encode(username));

  Uint8List value;

  /// Port of `Username.String` (textattrs.go:17-19).
  @override
  String toString() => utf8.decode(value, allowMalformed: true);

  /// Port of `Username.AddTo` (textattrs.go:23-25).
  @override
  void addTo(Message m) =>
      TextAttribute(value).addToAs(m, AttrType.username, _maxUsernameB);

  /// Port of `Username.GetFrom` (textattrs.go:28-30).
  @override
  void getFrom(Message m) {
    value = TextAttribute.getFromAs(m, AttrType.username);
  }
}

const int _maxRealmB = 763;

/// Port of `Realm` (textattrs.go:38): the REALM attribute (RFC 5389
/// Section 15.7). Must be SASL-prepared.
final class Realm implements Setter, Getter {
  Realm(String realm) : value = Uint8List.fromList(utf8.encode(realm));

  Uint8List value;

  /// Port of `Realm.String` (textattrs.go:41-43).
  @override
  String toString() => utf8.decode(value, allowMalformed: true);

  /// Port of `Realm.AddTo` (textattrs.go:49-51).
  @override
  void addTo(Message m) =>
      TextAttribute(value).addToAs(m, AttrType.realm, _maxRealmB);

  /// Port of `Realm.GetFrom` (textattrs.go:54-56).
  @override
  void getFrom(Message m) {
    value = TextAttribute.getFromAs(m, AttrType.realm);
  }
}

const int _softwareRawMaxB = 763;

/// Port of `Software` (textattrs.go:63): the SOFTWARE attribute (RFC 5389
/// Section 15.10).
final class Software implements Setter, Getter {
  Software(String software) : value = Uint8List.fromList(utf8.encode(software));

  Uint8List value;

  /// Port of `Software.String` (textattrs.go:67-69).
  @override
  String toString() => utf8.decode(value, allowMalformed: true);

  /// Port of `Software.AddTo` (textattrs.go:76-78).
  @override
  void addTo(Message m) =>
      TextAttribute(value).addToAs(m, AttrType.software, _softwareRawMaxB);

  /// Port of `Software.GetFrom` (textattrs.go:81-83).
  @override
  void getFrom(Message m) {
    value = TextAttribute.getFromAs(m, AttrType.software);
  }
}

const int _maxNonceB = 763;

/// Port of `Nonce` (textattrs.go:87): the NONCE attribute (RFC 5389
/// Section 15.8).
final class Nonce implements Setter, Getter {
  Nonce(String nonce) : value = Uint8List.fromList(utf8.encode(nonce));

  Uint8List value;

  /// Port of `Nonce.String` (textattrs.go:93-95).
  @override
  String toString() => utf8.decode(value, allowMalformed: true);

  /// Port of `Nonce.AddTo` (textattrs.go:101-103, second block).
  @override
  void addTo(Message m) =>
      TextAttribute(value).addToAs(m, AttrType.nonce, _maxNonceB);

  /// Port of `Nonce.GetFrom` (textattrs.go:106-108, second block).
  @override
  void getFrom(Message m) {
    value = TextAttribute.getFromAs(m, AttrType.nonce);
  }
}
