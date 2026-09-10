// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/basicnode/scalars.dart
//
// Port of go-ipld-prime's node/basicnode/{bool,int,float,string,bytes,link}.go.
// Go splits each kind into a `plainX` Node, a `plainX__Builder`, and a
// `plainX__Assembler` purely to amortize allocations (the Builder embeds
// the Assembler so `NewBuilder` does one allocation, not two); Dart's GC
// has no equivalent payoff for that split, so each kind's assembler class
// here directly implements NodeBuilder too -- same public surface, one
// fewer type per kind. `plainUint`/`NewUint`/`UintNode` (int.go) IS still
// ported separately from plainInt, since it's a real behavioral variant
// (full uint64 range), not just an allocation trick.
import 'dart:typed_data';

import '../datamodel/kind.dart';
import '../datamodel/link.dart';
import '../datamodel/node.dart';
import '../datamodel/node_builder.dart';
import 'base_node.dart';

/// Static factory methods for basicnode scalar nodes. Equivalent to
/// go-ipld-prime's `node/basicnode.New{Bool,Int,Float,String,Bytes,Link}`.
abstract final class Basicnode {
  const Basicnode._();

  /// Creates a boolean node. Equivalent to go-ipld-prime's `basicnode.NewBool`.
  static PlainBool ofBool(bool value) => PlainBool(value);

  /// Creates an integer node. Equivalent to go-ipld-prime's `basicnode.NewInt`.
  static PlainInt ofInt(int value) => PlainInt(value);

  /// Creates a float node. Equivalent to go-ipld-prime's `basicnode.NewFloat`.
  static PlainFloat ofFloat(double value) => PlainFloat(value);

  /// Creates a string node. Equivalent to go-ipld-prime's `basicnode.NewString`.
  static PlainString ofString(String value) => PlainString(value);

  /// Creates a bytes node. Equivalent to go-ipld-prime's `basicnode.NewBytes`.
  static PlainBytes ofBytes(Uint8List value) => PlainBytes(value);

  /// Creates a link node. Equivalent to go-ipld-prime's `basicnode.NewLink`.
  static PlainLink ofLink(Link value) => PlainLink(value);

  /// Convenience aliases.
  static PlainBool boolNode(bool value) => PlainBool(value);
  static PlainInt intNode(int value) => PlainInt(value);
  static PlainFloat floatNode(double value) => PlainFloat(value);
  static PlainString stringNode(String value) => PlainString(value);
  static PlainBytes bytesNode(Uint8List value) => PlainBytes(value);
  static PlainLink linkNode(Link value) => PlainLink(value);
}

/// A boxed [bool] conforming to [Node]. Equivalent to go-ipld-prime's
/// `plainBool`.
class PlainBool extends BaseNode {
  /// Creates the node.
  const PlainBool(this._value);

  final bool _value;

  @override
  String get typeName => 'bool';
  @override
  Kind kind() => Kind.bool_;
  @override
  bool asBool() => _value;
  @override
  NodePrototype prototype() => const PrototypeBool();
}

/// Describes [PlainBool]. Equivalent to go-ipld-prime's `Prototype__Bool`.
class PrototypeBool implements NodePrototype {
  /// Creates the prototype.
  const PrototypeBool();
  @override
  NodeBuilder newBuilder() => PlainBoolAssembler();
}

/// Builds a [PlainBool]. Equivalent to go-ipld-prime's
/// `plainBool__Builder`/`plainBool__Assembler` (merged -- see file header).
class PlainBoolAssembler extends BaseAssembler implements NodeBuilder {
  bool? _value;

  @override
  String get typeName => 'bool';
  @override
  Kind get selfKind => Kind.bool_;

  @override
  void assignBool(bool v) => _value = v;
  @override
  void assignNode(Node v) => assignBool(v.asBool());
  @override
  NodePrototype prototype() => const PrototypeBool();
  @override
  Node build() => PlainBool(_value!);
  @override
  void reset() => _value = null;
}


/// A boxed integer conforming to [Node]. Equivalent to go-ipld-prime's
/// `plainInt`.
class PlainInt extends BaseNode {
  /// Creates the node.
  const PlainInt(this._value);

  final int _value;

  @override
  String get typeName => 'int';
  @override
  Kind kind() => Kind.int_;
  @override
  int asInt() => _value;
  @override
  NodePrototype prototype() => const PrototypeInt();
}

/// A boxed unsigned integer conforming to [Node] and [UintNode], allowing
/// representation of values above the signed 64-bit maximum. Equivalent
/// to go-ipld-prime's `NewUint` + `plainUint`.
///
/// EXPERIMENTAL: matches the upstream Go API's own experimental status.
class PlainUint extends BaseNode implements UintNode {
  /// Creates the node from a non-negative [value]. Dart has no native
  /// unsigned 64-bit type, so [value] is stored as a (non-negative) `int`;
  /// values above `2^63-1` that Go's `uint64` could hold but Dart's `int`
  /// cannot are out of reach here -- a real limitation, not ported around.
  const PlainUint(this._value) : assert(_value >= 0);

  final int _value;

  @override
  String get typeName => 'int';
  @override
  Kind kind() => Kind.int_;
  @override
  int asInt() => _value;
  @override
  int asUint() => _value;
  @override
  NodePrototype prototype() => const PrototypeInt();
}

/// Describes [PlainInt]/[PlainUint]. Equivalent to go-ipld-prime's
/// `Prototype__Int`.
class PrototypeInt implements NodePrototype {
  /// Creates the prototype.
  const PrototypeInt();
  @override
  NodeBuilder newBuilder() => PlainIntAssembler();
}

/// Builds a [PlainInt]. Equivalent to go-ipld-prime's
/// `plainInt__Builder`/`plainInt__Assembler` (merged -- see file header).
class PlainIntAssembler extends BaseAssembler implements NodeBuilder {
  int? _value;

  @override
  String get typeName => 'int';
  @override
  Kind get selfKind => Kind.int_;

  @override
  void assignInt(int v) => _value = v;
  @override
  void assignNode(Node v) => assignInt(v.asInt());
  @override
  NodePrototype prototype() => const PrototypeInt();
  @override
  Node build() => PlainInt(_value!);
  @override
  void reset() => _value = null;
}

/// A boxed [double] conforming to [Node]. Equivalent to go-ipld-prime's
/// `plainFloat`.
class PlainFloat extends BaseNode {
  /// Creates the node.
  const PlainFloat(this._value);

  final double _value;

  @override
  String get typeName => 'float';
  @override
  Kind kind() => Kind.float;
  @override
  double asFloat() => _value;
  @override
  NodePrototype prototype() => const PrototypeFloat();
}

/// Describes [PlainFloat]. Equivalent to go-ipld-prime's
/// `Prototype__Float`.
class PrototypeFloat implements NodePrototype {
  /// Creates the prototype.
  const PrototypeFloat();
  @override
  NodeBuilder newBuilder() => PlainFloatAssembler();
}

/// Builds a [PlainFloat]. Equivalent to go-ipld-prime's
/// `plainFloat__Builder`/`plainFloat__Assembler` (merged -- see file
/// header).
class PlainFloatAssembler extends BaseAssembler implements NodeBuilder {
  double? _value;

  @override
  String get typeName => 'float';
  @override
  Kind get selfKind => Kind.float;

  @override
  void assignFloat(double v) => _value = v;
  @override
  void assignNode(Node v) => assignFloat(v.asFloat());
  @override
  NodePrototype prototype() => const PrototypeFloat();
  @override
  Node build() => PlainFloat(_value!);
  @override
  void reset() => _value = null;
}

/// A boxed [String] conforming to [Node]. Equivalent to go-ipld-prime's
/// `plainString`.
class PlainString extends BaseNode {
  /// Creates the node.
  const PlainString(this._value);

  final String _value;

  @override
  String get typeName => 'string';
  @override
  Kind kind() => Kind.string;
  @override
  String asString() => _value;
  @override
  NodePrototype prototype() => const PrototypeString();
}

/// Describes [PlainString]. Equivalent to go-ipld-prime's
/// `Prototype__String`.
class PrototypeString implements NodePrototype {
  /// Creates the prototype.
  const PrototypeString();
  @override
  NodeBuilder newBuilder() => PlainStringAssembler();
}

/// Builds a [PlainString]. Equivalent to go-ipld-prime's
/// `plainString__Builder`/`plainString__Assembler` (merged -- see file
/// header).
class PlainStringAssembler extends BaseAssembler implements NodeBuilder {
  String? _value;

  @override
  String get typeName => 'string';
  @override
  Kind get selfKind => Kind.string;

  @override
  void assignString(String v) => _value = v;
  @override
  void assignNode(Node v) => assignString(v.asString());
  @override
  NodePrototype prototype() => const PrototypeString();
  @override
  Node build() => PlainString(_value!);
  @override
  void reset() => _value = null;
}

/// A boxed byte string conforming to [Node]. Equivalent to go-ipld-prime's
/// `plainBytes`.
class PlainBytes extends BaseNode implements LargeBytesNode {
  /// Creates the node.
  const PlainBytes(this._value);

  final Uint8List _value;

  @override
  String get typeName => 'bytes';
  @override
  Kind kind() => Kind.bytes;
  @override
  Uint8List asBytes() => _value;
  @override
  NodePrototype prototype() => const PrototypeBytes();
  @override
  ByteReadSeeker asLargeBytes() => _Uint8ListReadSeeker(_value);
}

class _Uint8ListReadSeeker implements ByteReadSeeker {
  _Uint8ListReadSeeker(this._data);
  final Uint8List _data;
  int _pos = 0;

  @override
  int read(Uint8List buffer) {
    final remaining = _data.length - _pos;
    if (remaining <= 0) return 0;
    final n = remaining < buffer.length ? remaining : buffer.length;
    buffer.setRange(0, n, _data, _pos);
    _pos += n;
    return n;
  }

  @override
  int seek(int offset, SeekOrigin origin) {
    final base = switch (origin) {
      SeekOrigin.start => 0,
      SeekOrigin.current => _pos,
      SeekOrigin.end => _data.length,
    };
    _pos = base + offset;
    return _pos;
  }
}

/// Describes [PlainBytes]. Equivalent to go-ipld-prime's
/// `Prototype__Bytes`.
class PrototypeBytes implements NodePrototype {
  /// Creates the prototype.
  const PrototypeBytes();
  @override
  NodeBuilder newBuilder() => PlainBytesAssembler();
}

/// Builds a [PlainBytes] (or, via [assignNode] from a [LargeBytesNode], a
/// stream-backed bytes node -- see `stream_bytes.dart`). Equivalent to
/// go-ipld-prime's `plainBytes__Builder`/`plainBytes__Assembler` (merged --
/// see file header).
class PlainBytesAssembler extends BaseAssembler implements NodeBuilder {
  Node? _value;

  @override
  String get typeName => 'bytes';
  @override
  Kind get selfKind => Kind.bytes;

  @override
  void assignBytes(Uint8List v) => _value = PlainBytes(v);

  @override
  void assignNode(Node v) {
    if (v is LargeBytesNode) {
      _value = v;
      return;
    }
    assignBytes(v.asBytes());
  }

  @override
  NodePrototype prototype() => const PrototypeBytes();
  @override
  Node build() => _value!;
  @override
  void reset() => _value = null;
}

/// A boxed [Link] conforming to [Node]. Equivalent to go-ipld-prime's
/// `plainLink`.
class PlainLink extends BaseNode {
  /// Creates the node.
  const PlainLink(this._value);

  final Link _value;

  @override
  String get typeName => 'link';
  @override
  Kind kind() => Kind.link;
  @override
  Link asLink() => _value;
  @override
  NodePrototype prototype() => const PrototypeLink();
}

/// Describes [PlainLink]. Equivalent to go-ipld-prime's `Prototype__Link`.
class PrototypeLink implements NodePrototype {
  /// Creates the prototype.
  const PrototypeLink();
  @override
  NodeBuilder newBuilder() => PlainLinkAssembler();
}

/// Builds a [PlainLink]. Equivalent to go-ipld-prime's
/// `plainLink__Builder`/`plainLink__Assembler` (merged -- see file
/// header).
class PlainLinkAssembler extends BaseAssembler implements NodeBuilder {
  Link? _value;

  @override
  String get typeName => 'link';
  @override
  Kind get selfKind => Kind.link;

  @override
  void assignLink(Link v) => _value = v;
  @override
  void assignNode(Node v) => assignLink(v.asLink());
  @override
  NodePrototype prototype() => const PrototypeLink();
  @override
  Node build() => PlainLink(_value!);
  @override
  void reset() => _value = null;
}
