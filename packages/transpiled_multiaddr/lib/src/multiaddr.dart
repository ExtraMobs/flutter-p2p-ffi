// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/multiaddr/multiaddr.dart
//
// Port of go-multiaddr's Component/Multiaddr types and codec
// (github.com/multiformats/go-multiaddr component.go, multiaddr.go,
// codec.go, util.go). Wire format: a sequence of components, each a varint
// protocol code followed by an optional value (fixed-width, 0-width, or
// varint-length-prefixed, per Protocol.size).
import 'dart:typed_data';

import 'package:transpiled_varint/transpiled_varint.dart';

import 'protocol.dart';

/// One `/protocol/value` (or bare `/protocol` for a flag protocol) segment
/// of a [Multiaddr]. Equivalent to go-multiaddr's `Component`.
class Component {
  Component._(this.protocol, this.valueBytes);

  /// Parses a single component's string value (everything after the
  /// protocol name) via the protocol's transcoder.
  factory Component(Protocol protocol, String value) {
    Uint8List valueBytes;
    if (protocol.size == 0) {
      valueBytes = Uint8List(0);
    } else {
      final transcoder = protocol.transcoder;
      if (transcoder == null) {
        throw FormatException(
          'protocol ${protocol.name} has no transcoder for value "$value"',
        );
      }
      valueBytes = transcoder.stringToBytes(value);
      transcoder.validateBytes(valueBytes);
    }
    return Component._(protocol, valueBytes);
  }

  /// Builds a component from already-decoded value bytes (used when parsing
  /// the binary wire format), validating them against the protocol's
  /// transcoder.
  factory Component.fromValueBytes(Protocol protocol, Uint8List valueBytes) {
    protocol.transcoder?.validateBytes(valueBytes);
    return Component._(protocol, valueBytes);
  }

  /// The protocol this component's value belongs to.
  final Protocol protocol;

  /// The component's decoded value, in its raw wire-format bytes (not
  /// including the protocol code or length prefix).
  final Uint8List valueBytes;

  /// The component's value in string form (empty for flag protocols).
  String get value {
    if (protocol.size == 0) return '';
    return protocol.transcoder!.bytesToString(valueBytes);
  }

  /// The wire encoding of this component: varint code, an optional varint
  /// length (for variable-size protocols), then the value bytes.
  Uint8List toBytes() {
    final out = BytesBuilder();
    out.add(encodeVarint(protocol.code));
    if (protocol.size != 0) {
      if (protocol.isVariableSize) {
        out.add(encodeVarint(valueBytes.length));
      }
      out.add(valueBytes);
    }
    return out.toBytes();
  }

  /// The `/name` or `/name/value` string form of this component. A path
  /// protocol's value already begins with `/` (e.g. `unix`'s `/tmp/sock`),
  /// so no extra separator is inserted in that case.
  String toAddrString() {
    if (protocol.size == 0) return '/${protocol.name}';
    final v = value;
    if (v.isEmpty) return '/${protocol.name}';
    if (protocol.path && v.startsWith('/')) return '/${protocol.name}$v';
    return '/${protocol.name}/$v';
  }

  @override
  String toString() => toAddrString();

  @override
  bool operator ==(Object other) =>
      other is Component && _bytesEqual(toBytes(), other.toBytes());

  @override
  int get hashCode => Object.hashAll(toBytes());

  /// Lexicographic comparison of the two components' wire bytes, matching
  /// go-multiaddr's `Component.Compare` (`strings.Compare` on the raw
  /// bytes).
  int compareTo(Component other) {
    final a = toBytes();
    final b = other.toBytes();
    final n = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A self-describing network address: an ordered sequence of [Component]s.
/// Equivalent to go-multiaddr's `Multiaddr` type
/// (github.com/multiformats/go-multiaddr).
class Multiaddr {
  /// Wraps an already-built component list. Prefer [Multiaddr.parse] or
  /// [Multiaddr.fromBytes] when starting from a string or wire bytes.
  const Multiaddr(this.components);

  /// Parses the `/protocol/value/...` string form. Equivalent to
  /// go-multiaddr's `NewMultiaddr`.
  factory Multiaddr.parse(String s) {
    var trimmed = s;
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    var parts = trimmed.split('/');
    if (parts.isEmpty || parts[0] != '') {
      throw FormatException('failed to parse multiaddr "$s": must begin with /');
    }
    parts = parts.sublist(1);
    if (parts.isEmpty) {
      throw FormatException('failed to parse multiaddr "$s": empty multiaddr');
    }

    final out = <Component>[];
    var i = 0;
    while (i < parts.length) {
      final name = parts[i];
      final protocol = Protocols.byName(name);
      if (protocol == null) {
        throw FormatException('failed to parse multiaddr "$s": unknown protocol $name');
      }
      i++;

      if (protocol.size == 0) {
        out.add(Component(protocol, ''));
        continue;
      }

      if (i >= parts.length) {
        throw FormatException('failed to parse multiaddr "$s": unexpected end of multiaddr');
      }

      String rawValue;
      if (protocol.path) {
        // Terminal path protocol: everything remaining is the value.
        rawValue = '/${parts.sublist(i).join('/')}';
        i = parts.length;
      } else {
        rawValue = parts[i];
        i++;
      }

      try {
        out.add(Component(protocol, rawValue));
      } on FormatException catch (e) {
        throw FormatException(
          'failed to parse multiaddr "$s": invalid value "$rawValue" for protocol ${protocol.name}: ${e.message}',
        );
      }
    }
    return Multiaddr(out);
  }

  /// Parses the binary wire form. Equivalent to go-multiaddr's
  /// `NewMultiaddrBytes`.
  factory Multiaddr.fromBytes(Uint8List b) {
    if (b.isEmpty) {
      throw const FormatException('empty multiaddr');
    }
    final out = <Component>[];
    var offset = 0;
    var sawPathComponent = false;
    while (offset < b.length) {
      final (code, codeLen) = readVarint(b, offset);
      offset += codeLen;
      final protocol = Protocols.byCode(code);
      if (protocol == null) {
        throw FormatException('no protocol with code $code');
      }

      int size;
      if (protocol.size == 0) {
        size = 0;
      } else if (protocol.isVariableSize) {
        final (len, lenLen) = readVarint(b, offset);
        offset += lenLen;
        size = len;
      } else {
        size = protocol.size ~/ 8;
      }

      if (size < 0 || offset + size > b.length) {
        throw FormatException('invalid value for size ${b.length - offset}');
      }
      final valueBytes = b.sublist(offset, offset + size);
      offset += size;

      if (sawPathComponent) {
        throw const FormatException('unexpected component after path component');
      }
      sawPathComponent = protocol.path;
      out.add(Component.fromValueBytes(protocol, valueBytes));
    }
    return Multiaddr(out);
  }

  /// The empty multiaddr.
  static const Multiaddr empty = Multiaddr([]);

  /// This multiaddr's components, in order.
  final List<Component> components;

  /// The binary wire representation.
  Uint8List toBytes() {
    final out = BytesBuilder();
    for (final c in components) {
      out.add(c.toBytes());
    }
    return out.toBytes();
  }

  /// The `/protocol/value/...` string representation.
  String toAddrString() => components.map((c) => c.toAddrString()).join();

  @override
  String toString() => toAddrString();

  /// The list of protocols present, in order.
  List<Protocol> get protocols => components.map((c) => c.protocol).toList();

  /// The value of the first component matching [code], or `null` if absent
  /// (mirrors go-multiaddr's `ValueForProtocol`, which distinguishes "not
  /// found" via an error rather than an empty string).
  String? valueForProtocol(int code) {
    for (final c in components) {
      if (c.protocol.code == code) return c.value;
    }
    return null;
  }

  /// Whether any component uses the protocol identified by [code].
  bool hasProtocol(int code) => components.any((c) => c.protocol.code == code);

  /// Appends [other]'s components to this multiaddr. Equivalent to
  /// go-multiaddr's `Encapsulate`.
  Multiaddr encapsulate(Multiaddr other) =>
      Multiaddr([...components, ...other.components]);

  /// Removes the last occurrence of [other]'s component sequence and
  /// everything after it. Returns the empty multiaddr if [other] matches
  /// from the very start, or this multiaddr unchanged if no match is found.
  /// Equivalent to go-multiaddr's `Decapsulate`.
  Multiaddr decapsulate(Multiaddr other) {
    if (other.components.isEmpty) return this;
    var lastIndex = -1;
    for (var i = 0; i < components.length; i++) {
      var matched = true;
      for (var j = 0; j < other.components.length; j++) {
        if (i + j >= components.length ||
            components[i + j] != other.components[j]) {
          matched = false;
          break;
        }
      }
      if (matched) lastIndex = i;
    }
    if (lastIndex == 0) return Multiaddr.empty;
    if (lastIndex < 0) return this;
    return Multiaddr(components.sublist(0, lastIndex));
  }

  /// Walks the components in order, stopping early if [callback] returns
  /// `false`. Equivalent to go-multiaddr's `ForEach` (prefer a plain `for`
  /// loop over [components] when early exit isn't needed).
  void forEach(bool Function(Component c) callback) {
    for (final c in components) {
      if (!callback(c)) return;
    }
  }

  /// Splits at the first component for which [callback] returns `true`;
  /// that component is included in the *second* half. Equivalent to
  /// go-multiaddr's `SplitFunc`.
  (Multiaddr pre, Multiaddr? post) splitFunc(bool Function(Component c) callback) {
    if (components.isEmpty) return (Multiaddr.empty, null);
    var idx = components.length;
    for (var i = 0; i < components.length; i++) {
      if (callback(components[i])) {
        idx = i;
        break;
      }
    }
    final pre = components.sublist(0, idx);
    final post = components.sublist(idx);
    return (Multiaddr(pre), post.isEmpty ? null : Multiaddr(post));
  }

  /// Splits off the first component. Returns `(null, null)` if this
  /// multiaddr is empty. Equivalent to go-multiaddr's `SplitFirst`.
  (Component? first, Multiaddr? rest) splitFirst() {
    if (components.isEmpty) return (null, null);
    if (components.length == 1) return (components[0], null);
    return (components[0], Multiaddr(components.sublist(1)));
  }

  /// Splits off the last component. Returns `(null, null)` if this
  /// multiaddr is empty. Equivalent to go-multiaddr's `SplitLast`.
  (Multiaddr? prefix, Component? last) splitLast() {
    if (components.isEmpty) return (null, null);
    if (components.length == 1) return (null, components[0]);
    return (
      Multiaddr(components.sublist(0, components.length - 1)),
      components.last,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! Multiaddr) return false;
    if (components.length != other.components.length) return false;
    for (var i = 0; i < components.length; i++) {
      if (components[i] != other.components[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(components);

  /// Component-wise lexicographic comparison, matching go-multiaddr's
  /// `Multiaddr.Compare`.
  int compareTo(Multiaddr other) {
    final n = components.length < other.components.length
        ? components.length
        : other.components.length;
    for (var i = 0; i < n; i++) {
      final c = components[i].compareTo(other.components[i]);
      if (c != 0) return c;
    }
    return components.length - other.components.length;
  }
}
