// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/basicnode/value_assembler.dart
//
// A generic recursion-capable value assembler shared by PlainList's and
// PlainMap's `assembleValue()`/`assembleEntry()`, reporting the finished
// child Node via a callback (immediately for scalars; on `finish()` for
// recursive map/list children).
//
// Go instead defines fully specialized `plainList__ValueAssembler`/
// `plainMap__ValueAssembler` types (plus, for their recursive cases,
// further `plainX__ValueAssemblerMap`/`...List` wrapper types) purely to
// amortize allocations -- each embeds pre-allocated storage in the parent
// assembler struct so filling a list/map of scalars never allocates a
// child assembler at all. That payoff doesn't carry over to Dart's GC
// model, so this single reusable `ValueAssembler` (plus the two thin
// `_Committing*Assembler` wrappers below, needed only to hook the
// recursive case's `finish()`) replaces all of those Go types across both
// list.go and map.go. It's still a function-for-function match of
// observable behavior -- notably, `assignNode` on an already-built [Node]
// stores it directly with no re-copy, exactly like Go's own
// `plainList__ValueAssembler.AssignNode`/`plainMap__ValueAssembler.AssignNode`.
import 'dart:typed_data';

import '../datamodel/link.dart';
import '../datamodel/node.dart';
import '../datamodel/node_builder.dart';
import '../datamodel/null_node.dart';
import 'any_node.dart';
import 'list_node.dart';
import 'map_node.dart';
import 'scalars.dart';

/// Assembles a single value that will be reported to [onDone] once
/// complete. Equivalent, in role, to go-ipld-prime's
/// `plainList__ValueAssembler`/`plainMap__ValueAssembler` -- see this
/// file's header for why they're merged into one type here.
class ValueAssembler implements NodeAssembler {
  /// Creates a value assembler that reports its finished [Node] to
  /// [onDone] exactly once.
  ValueAssembler(this.onDone);

  /// Called exactly once, with the fully-assembled node.
  final void Function(Node) onDone;

  // Matches Go's "invalidate self to prevent further incorrect use" (e.g.
  // `mva.ma = nil` in plainMap__ValueAssembler.AssignNode): a stale
  // reference to an already-used value assembler must throw, not silently
  // corrupt whatever the parent has moved on to.
  bool _used = false;

  void _markUsed() {
    if (_used)
      throw StateError('misuse: this value assembler has already been used');
    _used = true;
  }

  @override
  MapAssembler beginMap(int sizeHint) {
    _markUsed();
    final ma = PlainMapAssembler();
    ma.beginMap(sizeHint);
    return _CommittingMapAssembler(ma, onDone);
  }

  @override
  ListAssembler beginList(int sizeHint) {
    _markUsed();
    final la = PlainListAssembler();
    la.beginList(sizeHint);
    return _CommittingListAssembler(la, onDone);
  }

  @override
  void assignNull() {
    _markUsed();
    onDone(nullNode);
  }

  @override
  void assignBool(bool v) {
    _markUsed();
    onDone(PlainBool(v));
  }

  @override
  void assignInt(int v) {
    _markUsed();
    onDone(PlainInt(v));
  }

  @override
  void assignFloat(double v) {
    _markUsed();
    onDone(PlainFloat(v));
  }

  @override
  void assignString(String v) {
    _markUsed();
    onDone(PlainString(v));
  }

  @override
  void assignBytes(Uint8List v) {
    _markUsed();
    onDone(PlainBytes(v));
  }

  @override
  void assignLink(Link v) {
    _markUsed();
    onDone(PlainLink(v));
  }

  @override
  void assignNode(Node v) {
    _markUsed();
    onDone(v);
  }

  @override
  NodePrototype prototype() => const PrototypeAny();
}

class _CommittingMapAssembler implements MapAssembler {
  _CommittingMapAssembler(this._inner, this._onDone);
  final PlainMapAssembler _inner;
  final void Function(Node) _onDone;

  @override
  NodeAssembler assembleKey() => _inner.assembleKey();
  @override
  NodeAssembler assembleValue() => _inner.assembleValue();
  @override
  NodeAssembler assembleEntry(String k) => _inner.assembleEntry(k);
  @override
  NodePrototype keyPrototype() => _inner.keyPrototype();
  @override
  NodePrototype valuePrototype(String k) => _inner.valuePrototype(k);

  @override
  void finish() {
    _inner.finish();
    _onDone(_inner.build());
  }
}

class _CommittingListAssembler implements ListAssembler {
  _CommittingListAssembler(this._inner, this._onDone);
  final PlainListAssembler _inner;
  final void Function(Node) _onDone;

  @override
  NodeAssembler assembleValue() => _inner.assembleValue();
  @override
  NodePrototype valuePrototype(int idx) => _inner.valuePrototype(idx);

  @override
  void finish() {
    _inner.finish();
    _onDone(_inner.build());
  }
}
