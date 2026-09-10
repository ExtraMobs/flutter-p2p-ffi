// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/basicnode/prototypes.dart
//
// Port of go-ipld-prime's node/basicnode/prototypes.go: a single object
// exposing every basicnode NodePrototype, e.g. `Prototype.map.newBuilder()`.
import 'any_node.dart';
import 'list_node.dart';
import 'map_node.dart';
import 'scalars.dart';

/// Every [NodePrototype] this package provides. Equivalent to
/// go-ipld-prime's `Prototype` (the package-level `var Prototype prototype`
/// singleton).
class BasicnodePrototype {
  const BasicnodePrototype._();

  /// Accepts any kind of data. Equivalent to go-ipld-prime's `prototype.Any`.
  final PrototypeAny any = const PrototypeAny();

  /// Equivalent to go-ipld-prime's `prototype.Map`.
  final PrototypeMap map = const PrototypeMap();

  /// Equivalent to go-ipld-prime's `prototype.List`.
  final PrototypeList list = const PrototypeList();

  /// Equivalent to go-ipld-prime's `prototype.Bool`.
  final PrototypeBool bool_ = const PrototypeBool();

  /// Equivalent to go-ipld-prime's `prototype.Int`.
  final PrototypeInt int_ = const PrototypeInt();

  /// Equivalent to go-ipld-prime's `prototype.Float`.
  final PrototypeFloat float = const PrototypeFloat();

  /// Equivalent to go-ipld-prime's `prototype.String`.
  final PrototypeString string = const PrototypeString();

  /// Equivalent to go-ipld-prime's `prototype.Bytes`.
  final PrototypeBytes bytes = const PrototypeBytes();

  /// Equivalent to go-ipld-prime's `prototype.Link`.
  final PrototypeLink link = const PrototypeLink();
}

/// Equivalent to go-ipld-prime's package-level `Prototype` variable:
/// `Prototype.map.newBuilder()`, `Prototype.string.newBuilder()`, etc.
const BasicnodePrototype prototype = BasicnodePrototype._();
