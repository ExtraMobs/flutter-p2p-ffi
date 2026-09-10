// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/datamodel/copy.dart
//
// Port of go-ipld-prime's datamodel/copy.go.
import 'kind.dart';
import 'node.dart';
import 'node_builder.dart';

/// Does an explicit shallow copy of [node]'s data into [assembler]: for
/// recursive kinds, ranges over the contents and calls `assignNode` on
/// each child; for scalars, calls the matching `assign*` method. Throws
/// [ArgumentError] if [node] is `null`, or is the special "absent" node.
/// Equivalent to go-ipld-prime's `Copy`.
void copyNode(Node? node, NodeAssembler assembler) {
  if (node == null) {
    throw ArgumentError('cannot copy a nil node');
  }
  switch (node.kind()) {
    case Kind.null_:
      if (node.isAbsent()) {
        throw ArgumentError('copying an absent node makes no sense');
      }
      assembler.assignNull();
    case Kind.bool_:
      assembler.assignBool(node.asBool());
    case Kind.int_:
      assembler.assignInt(node.asInt());
    case Kind.float:
      assembler.assignFloat(node.asFloat());
    case Kind.string:
      assembler.assignString(node.asString());
    case Kind.bytes:
      assembler.assignBytes(node.asBytes());
    case Kind.link:
      assembler.assignLink(node.asLink());
    case Kind.map:
      final ma = assembler.beginMap(node.length());
      final itr = node.mapIterator()!;
      while (!itr.done()) {
        final (k, v) = itr.next();
        if (v.isAbsent()) continue;
        ma.assembleKey().assignNode(k);
        ma.assembleValue().assignNode(v);
      }
      ma.finish();
    case Kind.list:
      final la = assembler.beginList(node.length());
      final itr = node.listIterator()!;
      while (!itr.done()) {
        final (_, v) = itr.next();
        if (v.isAbsent()) continue;
        la.assembleValue().assignNode(v);
      }
      la.finish();
    case Kind.invalid:
      throw ArgumentError('node has invalid kind ${node.kind()}');
  }
}
