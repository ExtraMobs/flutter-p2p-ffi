// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/basicnode/map_node.dart
//
// Port of go-ipld-prime's node/basicnode/map.go. See value_assembler.dart's
// header for why Go's allocation-amortizing ValueAssembler wrapper types
// aren't ported separately. Dart's built-in `Map` already preserves
// insertion order (it's a linked hash map), matching Go's own combination
// of a `map[string]Node` (for O(1) lookup) plus a `[]Entry` table (for
// order) -- one Dart `Map` covers both roles here.
import '../datamodel/errors.dart';
import '../datamodel/kind.dart';
import '../datamodel/node.dart';
import '../datamodel/node_builder.dart';
import '../datamodel/path_segment.dart';
import 'any_node.dart';
import 'base_node.dart';
import 'scalars.dart';
import 'value_assembler.dart';

/// A map-kind [Node] that can contain any kind of value, with `string`
/// keys (the only key type the IPLD Data Model itself has). Equivalent to
/// go-ipld-prime's `plainMap`.
class PlainMap extends BaseNode {
  /// Creates the node from [entries] (not copied -- callers must not
  /// mutate it afterward, matching the immutability contract [Node]
  /// documents).
  const PlainMap(this._entries);

  final Map<String, Node> _entries;

  @override
  String get typeName => 'map';
  @override
  Kind kind() => Kind.map;

  @override
  Node lookupByString(String key) {
    final v = _entries[key];
    if (v == null) throw NotExistsException(PathSegment.ofString(key));
    return v;
  }

  @override
  Node lookupByNode(Node key) => lookupByString(key.asString());

  @override
  Node lookupBySegment(PathSegment seg) => lookupByString(seg.toString());

  @override
  MapIterator mapIterator() => _PlainMapIterator(_entries.entries.iterator);

  @override
  int length() => _entries.length;

  @override
  NodePrototype prototype() => const PrototypeMap();
}

class _PlainMapIterator implements MapIterator {
  _PlainMapIterator(this._it);
  final Iterator<MapEntry<String, Node>> _it;
  bool _hasNext = true;
  bool _advanced = false;

  void _ensureAdvanced() {
    if (_advanced) return;
    _hasNext = _it.moveNext();
    _advanced = true;
  }

  @override
  bool done() {
    _ensureAdvanced();
    return !_hasNext;
  }

  @override
  (Node, Node) next() {
    _ensureAdvanced();
    if (!_hasNext) throw const IteratorOverreadException();
    final entry = _it.current;
    _advanced = false;
    return (PlainString(entry.key), entry.value);
  }
}

/// Describes [PlainMap]. Equivalent to go-ipld-prime's `Prototype__Map`.
class PrototypeMap implements NodePrototype {
  /// Creates the prototype.
  const PrototypeMap();
  @override
  NodeBuilder newBuilder() => PlainMapAssembler();
}

enum _MapAsmState { initial, midKey, expectValue, midValue, finished }

/// Builds a [PlainMap]. Equivalent to go-ipld-prime's
/// `plainMap__Builder`/`plainMap__Assembler` (merged -- see
/// `scalars.dart`'s header for why builder/assembler splits aren't ported
/// separately).
class PlainMapAssembler extends BaseAssembler
    implements NodeBuilder, MapAssembler {
  final Map<String, Node> _entries = {};
  _MapAsmState _state = _MapAsmState.initial;
  String? _pendingKey;

  @override
  String get typeName => 'map';
  @override
  Kind get selfKind => Kind.map;

  @override
  MapAssembler beginMap(int sizeHint) {
    // Matches Go's "return self as MapAssembler": this same object
    // already has every MapAssembler method needed.
    return this;
  }

  @override
  NodeAssembler assembleEntry(String k) {
    if (_state != _MapAsmState.initial) throw StateError('misuse');
    if (_entries.containsKey(k)) throw RepeatedMapKeyException(PlainString(k));
    _pendingKey = k;
    _state = _MapAsmState.midValue;
    return ValueAssembler((v) {
      _entries[_pendingKey!] = v;
      _pendingKey = null;
      _state = _MapAsmState.initial;
    });
  }

  @override
  NodeAssembler assembleKey() {
    if (_state != _MapAsmState.initial) throw StateError('misuse');
    _state = _MapAsmState.midKey;
    return _MapKeyAssembler(this);
  }

  @override
  NodeAssembler assembleValue() {
    if (_state != _MapAsmState.expectValue) throw StateError('misuse');
    _state = _MapAsmState.midValue;
    return ValueAssembler((v) {
      _entries[_pendingKey!] = v;
      _pendingKey = null;
      _state = _MapAsmState.initial;
    });
  }

  @override
  void finish() {
    if (_state != _MapAsmState.initial) throw StateError('misuse');
    _state = _MapAsmState.finished;
  }

  @override
  NodePrototype keyPrototype() => const PrototypeString();
  @override
  NodePrototype valuePrototype(String k) => const PrototypeAny();

  @override
  void assignNode(Node v) {
    if (_state != _MapAsmState.initial) throw StateError('misuse');
    if (v is PlainMap) {
      _entries
        ..clear()
        ..addAll(v._entries);
      _state = _MapAsmState.finished;
      return;
    }
    if (v.kind() != Kind.map) {
      throw WrongKindException(
        typeName: 'map',
        methodName: 'AssignNode',
        appropriateKind: KindSet.justMap,
        actualKind: v.kind(),
      );
    }
    final itr = v.mapIterator()!;
    while (!itr.done()) {
      final (k, val) = itr.next();
      assembleKey().assignNode(k);
      assembleValue().assignNode(val);
    }
    finish();
  }

  @override
  NodePrototype prototype() => const PrototypeMap();

  @override
  Node build() {
    if (_state != _MapAsmState.finished) {
      throw StateError(
        "invalid state: assembler must be 'finished' before build can be called!",
      );
    }
    return PlainMap(Map.of(_entries));
  }

  @override
  void reset() {
    _entries.clear();
    _pendingKey = null;
    _state = _MapAsmState.initial;
  }
}

class _MapKeyAssembler extends BaseAssembler {
  _MapKeyAssembler(this._parent);

  // Matches Go's "invalidate self to prevent further incorrect use" --
  // nulled out after one use, so a stale reference to an already-used key
  // assembler throws instead of silently re-mutating the parent.
  PlainMapAssembler? _parent;

  @override
  String get typeName => 'string';
  @override
  Kind get selfKind => Kind.string;

  @override
  void assignString(String v) {
    final parent = _parent;
    if (parent == null)
      throw StateError('misuse: this key assembler has already been used');
    if (parent._entries.containsKey(v)) {
      parent._state = _MapAsmState.initial;
      _parent = null;
      throw RepeatedMapKeyException(PlainString(v));
    }
    parent._pendingKey = v;
    parent._state = _MapAsmState.expectValue;
    _parent = null;
  }

  @override
  void assignNode(Node v) => assignString(v.asString());

  @override
  NodePrototype prototype() => const PrototypeString();
}
