// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-dag-jose/dagjose/jose_bytes.go.

import 'dart:convert';
import 'dart:typed_data';

import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

/// Encodes binary [decoded] into raw base64url string without padding.
String encodeBase64Url(List<int> decoded) {
  return base64Url.encode(decoded).replaceAll('=', '');
}

/// Decodes raw base64url string [encoded] without padding into bytes.
Uint8List decodeBase64Url(String encoded) {
  var padded = encoded;
  final remainder = encoded.length % 4;
  if (remainder > 0) {
    padded = encoded + ('=' * (4 - remainder));
  }
  return Uint8List.fromList(base64Url.decode(padded));
}

/// Base64Url matches the IPLD Schema type "Base64Url". It has string kind.
class Base64Url extends BaseNode {
  final Uint8List _bytes;

  const Base64Url(Uint8List bytes) : _bytes = bytes;

  Base64Url.fromString(String encoded) : _bytes = decodeBase64Url(encoded);

  @override
  String get typeName => 'dagjose.Base64Url';

  @override
  Kind kind() => Kind.string;

  @override
  String asString() => encodeBase64Url(_bytes);

  @override
  Uint8List asBytes() => _bytes;

  @override
  NodePrototype prototype() => const _Base64UrlPrototype();

  Link link() {
    final c = Cid.fromBytes(_bytes);
    return CidLink(c);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Base64Url) {
      if (_bytes.length != other._bytes.length) return false;
      for (var i = 0; i < _bytes.length; i++) {
        if (_bytes[i] != other._bytes[i]) return false;
      }
      return true;
    }
    return false;
  }

  @override
  int get hashCode => Object.hashAll(_bytes);
}

/// Prototype for [Base64Url].
class _Base64UrlPrototype implements NodePrototype {
  const _Base64UrlPrototype();

  @override
  NodeBuilder newBuilder() => _Base64UrlBuilder();
}

/// Builder for [Base64Url].
class _Base64UrlBuilder extends BaseAssembler implements NodeBuilder {
  Uint8List? _value;

  @override
  String get typeName => 'dagjose.Base64Url';

  @override
  Kind get selfKind => Kind.string;

  @override
  void assignString(String v) {
    _value = decodeBase64Url(v);
  }

  @override
  void assignBytes(Uint8List v) {
    _value = Uint8List.fromList(v);
  }

  @override
  void assignNode(Node v) {
    if (v.isNull()) {
      assignNull();
      return;
    }
    if (v is Base64Url) {
      _value = v._bytes;
      return;
    }
    try {
      _value = decodeBase64Url(v.asString());
    } catch (_) {
      _value = v.asBytes();
    }
  }

  @override
  Node build() {
    final val = _value;
    if (val == null) {
      throw StateError(
        'cannot call build on an assembler that is not finished',
      );
    }
    return Base64Url(val);
  }

  @override
  NodePrototype prototype() => const _Base64UrlPrototype();

  @override
  void reset() {
    _value = null;
  }
}

/// Raw matches the IPLD Schema type "Raw". It has bytes kind.
class Raw extends BaseNode {
  final Uint8List _bytes;

  const Raw(Uint8List bytes) : _bytes = bytes;

  Raw.fromString(String encoded) : _bytes = decodeBase64Url(encoded);

  @override
  String get typeName => 'dagjose.Raw';

  @override
  Kind kind() => Kind.bytes;

  @override
  Uint8List asBytes() => _bytes;

  @override
  String asString() => encodeBase64Url(_bytes);

  @override
  NodePrototype prototype() => const _RawPrototype();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Raw) {
      if (_bytes.length != other._bytes.length) return false;
      for (var i = 0; i < _bytes.length; i++) {
        if (_bytes[i] != other._bytes[i]) return false;
      }
      return true;
    }
    return false;
  }

  @override
  int get hashCode => Object.hashAll(_bytes);
}

/// Prototype for [Raw].
class _RawPrototype implements NodePrototype {
  const _RawPrototype();

  @override
  NodeBuilder newBuilder() => _RawBuilder();
}

/// Builder for [Raw].
class _RawBuilder extends BaseAssembler implements NodeBuilder {
  Uint8List? _value;

  @override
  String get typeName => 'dagjose.Raw';

  @override
  Kind get selfKind => Kind.bytes;

  @override
  void assignBytes(Uint8List v) {
    _value = Uint8List.fromList(v);
  }

  @override
  void assignString(String v) {
    _value = decodeBase64Url(v);
  }

  @override
  void assignNode(Node v) {
    if (v.isNull()) {
      assignNull();
      return;
    }
    if (v is Raw) {
      _value = v._bytes;
      return;
    }
    try {
      _value = v.asBytes();
    } catch (_) {
      _value = decodeBase64Url(v.asString());
    }
  }

  @override
  Node build() {
    final val = _value;
    if (val == null) {
      throw StateError(
        'cannot call build on an assembler that is not finished',
      );
    }
    return Raw(val);
  }

  @override
  NodePrototype prototype() => const _RawPrototype();

  @override
  void reset() {
    _value = null;
  }
}
