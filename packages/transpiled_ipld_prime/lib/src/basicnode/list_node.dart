// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/basicnode/list_node.dart
//
// Port of go-ipld-prime's node/basicnode/list.go. See value_assembler.dart's
// header for why Go's allocation-amortizing ValueAssembler wrapper types
// aren't ported separately.
import '../datamodel/errors.dart';
import '../datamodel/kind.dart';
import '../datamodel/node.dart';
import '../datamodel/node_builder.dart';
import '../datamodel/path_segment.dart';
import 'any_node.dart';
import 'base_node.dart';
import 'value_assembler.dart';

/// A list-kind [Node] that can contain any kind of value. Equivalent to
/// go-ipld-prime's `plainList`.
class PlainList extends BaseNode {
  /// Creates the node from [items] (not copied -- callers must not mutate
  /// it afterward, matching the immutability contract [Node] documents).
  const PlainList(this._items);

  final List<Node> _items;

  @override
  String get typeName => 'list';
  @override
  Kind kind() => Kind.list;

  @override
  Node lookupByIndex(int idx) {
    if (idx < 0 || idx >= _items.length) {
      throw NotExistsException(PathSegment.ofInt(idx));
    }
    return _items[idx];
  }

  @override
  Node lookupBySegment(PathSegment seg) {
    final int idx;
    try {
      idx = seg.index();
    } on FormatException catch (e) {
      throw InvalidSegmentForListException(troubleSegment: seg, reason: e);
    }
    return lookupByIndex(idx);
  }

  @override
  ListIterator listIterator() => _PlainListIterator(_items);

  @override
  int length() => _items.length;

  @override
  NodePrototype prototype() => const PrototypeList();
}

class _PlainListIterator implements ListIterator {
  _PlainListIterator(this._items);
  final List<Node> _items;
  int _idx = 0;

  @override
  bool done() => _idx >= _items.length;

  @override
  (int, Node) next() {
    if (done()) throw const IteratorOverreadException();
    final idx = _idx;
    final v = _items[idx];
    _idx++;
    return (idx, v);
  }
}

/// Describes [PlainList]. Equivalent to go-ipld-prime's `Prototype__List`.
class PrototypeList implements NodePrototype {
  /// Creates the prototype.
  const PrototypeList();
  @override
  NodeBuilder newBuilder() => PlainListAssembler();
}

enum _ListAsmState { initial, midValue, finished }

/// Builds a [PlainList]. Equivalent to go-ipld-prime's
/// `plainList__Builder`/`plainList__Assembler` (merged -- see
/// `scalars.dart`'s header for why builder/assembler splits aren't ported
/// separately).
class PlainListAssembler extends BaseAssembler
    implements NodeBuilder, ListAssembler {
  final List<Node> _items = [];
  _ListAsmState _state = _ListAsmState.initial;

  @override
  String get typeName => 'list';
  @override
  Kind get selfKind => Kind.list;

  @override
  ListAssembler beginList(int sizeHint) {
    // Matches Go's "return self as ListAssembler": this same object
    // already has every ListAssembler method needed.
    return this;
  }

  @override
  NodeAssembler assembleValue() {
    if (_state != _ListAsmState.initial) throw StateError('misuse');
    _state = _ListAsmState.midValue;
    return ValueAssembler((v) {
      _items.add(v);
      _state = _ListAsmState.initial;
    });
  }

  @override
  void finish() {
    if (_state != _ListAsmState.initial) throw StateError('misuse');
    _state = _ListAsmState.finished;
  }

  @override
  NodePrototype valuePrototype(int idx) => const PrototypeAny();

  @override
  void assignNode(Node v) {
    if (_state != _ListAsmState.initial) throw StateError('misuse');
    if (v is PlainList) {
      _items
        ..clear()
        ..addAll(v._items);
      _state = _ListAsmState.finished;
      return;
    }
    if (v.kind() != Kind.list) {
      throw WrongKindException(
        typeName: 'list',
        methodName: 'AssignNode',
        appropriateKind: KindSet.justList,
        actualKind: v.kind(),
      );
    }
    final itr = v.listIterator()!;
    while (!itr.done()) {
      final (_, child) = itr.next();
      assembleValue().assignNode(child);
    }
    finish();
  }

  @override
  NodePrototype prototype() => const PrototypeList();

  @override
  Node build() {
    if (_state != _ListAsmState.finished) {
      throw StateError(
        "invalid state: assembler must be 'finished' before build can be called!",
      );
    }
    return PlainList(List.of(_items));
  }

  @override
  void reset() {
    _items.clear();
    _state = _ListAsmState.initial;
  }
}
