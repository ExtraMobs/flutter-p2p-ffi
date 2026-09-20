/// Port of `uattrs.go` (pion/stun v3.1.1).
///
/// Go's `type UnknownAttributes []AttrType` becomes a class wrapping
/// `List<AttrType>` (rather than a bare list + extension, unlike
/// `attributes.dart`'s `Attributes`): this type must itself implement
/// [Setter]/[Getter] to be usable polymorphically in `Message.build`/
/// `Message.parse` calls, which Dart extension methods cannot provide (they
/// add static, not interface, dispatch).
library;

import 'dart:typed_data';

import 'attributes.dart';
import 'helpers.dart';
import 'message.dart';

const int _attrTypeSize = 4;

/// Port of `ErrBadUnknownAttrsSize` (uattrs.go:51): the UNKNOWN-ATTRIBUTES
/// attribute value has an invalid length.
final class BadUnknownAttrsSizeException implements Exception {
  const BadUnknownAttrsSizeException();

  @override
  String toString() => 'bad UNKNOWN-ATTRIBUTES size';
}

/// Port of `UnknownAttributes` (uattrs.go:10): the UNKNOWN-ATTRIBUTES
/// attribute (RFC 5389 Section 15.9).
final class UnknownAttributes implements Setter, Getter {
  UnknownAttributes([List<AttrType>? types]) : types = types ?? <AttrType>[];

  List<AttrType> types;

  /// Port of `UnknownAttributes.String` (uattrs.go:13-26).
  @override
  String toString() {
    if (types.isEmpty) return '<nil>';
    return types.map((t) => t.toString()).join(', ');
  }

  /// Port of `UnknownAttributes.AddTo` (uattrs.go:31-42).
  @override
  void addTo(Message m) {
    final v = Uint8List(_attrTypeSize * types.length);
    for (var i = 0; i < types.length; i++) {
      final first = _attrTypeSize * i;
      ByteData.sublistView(v, first, first + _attrTypeSize)
          .setUint16(0, types[i].value, Endian.big);
    }
    m.add(AttrType.unknownAttributes, v);
  }

  /// Port of `UnknownAttributes.GetFrom` (uattrs.go:55-69). Throws
  /// [BadUnknownAttrsSizeException] if the attribute value's length is not
  /// a multiple of 4.
  @override
  void getFrom(Message m) {
    final v = m.get(AttrType.unknownAttributes);
    if (v.length % _attrTypeSize != 0) {
      throw const BadUnknownAttrsSizeException();
    }
    final newTypes = <AttrType>[];
    var first = 0;
    while (first < v.length) {
      final last = first + _attrTypeSize;
      newTypes.add(
        AttrType(ByteData.sublistView(v, first, last).getUint16(0, Endian.big)),
      );
      first = last;
    }
    types = newTypes;
  }
}
