// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// A minimal, purpose-built Node/NodeBuilder implementation used ONLY to
// exercise datamodel's deepEqual/copyNode logic in tests -- NOT a port of
// go-ipld-prime's node/basicnode (that's real future work; see
// doc/transpilation/PROGRESS.md). The real Go equal_test.go/copy_test.go
// build their test fixtures using node/basicnode + fluent/qp, neither
// ported yet, so this stands in for just enough surface to reproduce the
// same test *cases* against the ported datamodel logic.
import 'dart:typed_data';

import 'package:transpiled_ipld_prime/transpiled_ipld_prime.dart';

class SimpleNode implements Node {
  const SimpleNode._(this._kind, this._value);

  factory SimpleNode.ofNull() => const SimpleNode._(Kind.null_, null);
  factory SimpleNode.ofBool(bool v) => SimpleNode._(Kind.bool_, v);
  factory SimpleNode.ofInt(int v) => SimpleNode._(Kind.int_, v);
  factory SimpleNode.ofFloat(double v) => SimpleNode._(Kind.float, v);
  factory SimpleNode.ofString(String v) => SimpleNode._(Kind.string, v);
  factory SimpleNode.ofBytes(Uint8List v) => SimpleNode._(Kind.bytes, v);
  factory SimpleNode.ofLink(Link v) => SimpleNode._(Kind.link, v);
  factory SimpleNode.ofList(List<Node> v) => SimpleNode._(Kind.list, v);
  factory SimpleNode.ofMap(Map<String, Node> v) => SimpleNode._(Kind.map, v);

  final Kind _kind;
  final Object? _value;

  WrongKindException _wrongKind(String method, KindSet appropriate) =>
      WrongKindException(
        methodName: method,
        appropriateKind: appropriate,
        actualKind: _kind,
      );

  @override
  Kind kind() => _kind;

  @override
  Node lookupByString(String key) {
    if (_kind != Kind.map) throw _wrongKind('lookupByString', KindSet.justMap);
    final v = (_value! as Map<String, Node>)[key];
    if (v == null) throw NotExistsException(PathSegment.ofString(key));
    return v;
  }

  @override
  Node lookupByNode(Node key) => lookupByString(key.asString());

  @override
  Node lookupByIndex(int idx) {
    if (_kind != Kind.list) throw _wrongKind('lookupByIndex', KindSet.justList);
    final list = _value! as List<Node>;
    if (idx < 0 || idx >= list.length)
      throw NotExistsException(PathSegment.ofInt(idx));
    return list[idx];
  }

  @override
  Node lookupBySegment(PathSegment seg) {
    if (_kind == Kind.map) return lookupByString(seg.toString());
    if (_kind == Kind.list) return lookupByIndex(seg.index());
    throw _wrongKind('lookupBySegment', KindSet.recursive);
  }

  @override
  MapIterator? mapIterator() => _kind == Kind.map
      ? _SimpleMapIterator((_value! as Map<String, Node>).entries.iterator)
      : null;

  @override
  ListIterator? listIterator() =>
      _kind == Kind.list ? _SimpleListIterator(_value! as List<Node>) : null;

  @override
  int length() {
    if (_kind == Kind.map) return (_value! as Map<String, Node>).length;
    if (_kind == Kind.list) return (_value! as List<Node>).length;
    return -1;
  }

  @override
  bool isAbsent() => false;

  @override
  bool isNull() => _kind == Kind.null_;

  @override
  bool asBool() {
    if (_kind != Kind.bool_) throw _wrongKind('asBool', KindSet.justBool);
    return _value! as bool;
  }

  @override
  int asInt() {
    if (_kind != Kind.int_) throw _wrongKind('asInt', KindSet.justInt);
    return _value! as int;
  }

  @override
  double asFloat() {
    if (_kind != Kind.float) throw _wrongKind('asFloat', KindSet.justFloat);
    return _value! as double;
  }

  @override
  String asString() {
    if (_kind != Kind.string) throw _wrongKind('asString', KindSet.justString);
    return _value! as String;
  }

  @override
  Uint8List asBytes() {
    if (_kind != Kind.bytes) throw _wrongKind('asBytes', KindSet.justBytes);
    return _value! as Uint8List;
  }

  @override
  Link asLink() {
    if (_kind != Kind.link) throw _wrongKind('asLink', KindSet.justLink);
    return _value! as Link;
  }

  @override
  NodePrototype prototype() => const SimplePrototype();
}

class _SimpleMapIterator implements MapIterator {
  _SimpleMapIterator(this._it);
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
    return (SimpleNode.ofString(entry.key), entry.value);
  }
}

class _SimpleListIterator implements ListIterator {
  _SimpleListIterator(this._list);
  final List<Node> _list;
  int _i = 0;

  @override
  bool done() => _i >= _list.length;

  @override
  (int, Node) next() {
    if (done()) throw const IteratorOverreadException();
    final idx = _i;
    _i++;
    return (idx, _list[idx]);
  }
}

class SimplePrototype implements NodePrototype {
  const SimplePrototype();
  @override
  NodeBuilder newBuilder() => SimpleNodeBuilder();
}

enum _BuildState { empty, scalar, map, list }

class SimpleNodeBuilder implements NodeBuilder {
  Node? _result;
  _BuildState _state = _BuildState.empty;
  final Map<String, Node> _mapValues = {};
  final List<Node> _listValues = [];

  void _requireEmpty() {
    if (_state != _BuildState.empty) {
      throw StateError('assembler already used');
    }
  }

  @override
  MapAssembler beginMap(int sizeHint) {
    _requireEmpty();
    _state = _BuildState.map;
    return _SimpleMapAssembler(this);
  }

  @override
  ListAssembler beginList(int sizeHint) {
    _requireEmpty();
    _state = _BuildState.list;
    return _SimpleListAssembler(this);
  }

  @override
  void assignNull() {
    _requireEmpty();
    _result = SimpleNode.ofNull();
    _state = _BuildState.scalar;
  }

  @override
  void assignBool(bool v) {
    _requireEmpty();
    _result = SimpleNode.ofBool(v);
    _state = _BuildState.scalar;
  }

  @override
  void assignInt(int v) {
    _requireEmpty();
    _result = SimpleNode.ofInt(v);
    _state = _BuildState.scalar;
  }

  @override
  void assignFloat(double v) {
    _requireEmpty();
    _result = SimpleNode.ofFloat(v);
    _state = _BuildState.scalar;
  }

  @override
  void assignString(String v) {
    _requireEmpty();
    _result = SimpleNode.ofString(v);
    _state = _BuildState.scalar;
  }

  @override
  void assignBytes(Uint8List v) {
    _requireEmpty();
    _result = SimpleNode.ofBytes(v);
    _state = _BuildState.scalar;
  }

  @override
  void assignLink(Link v) {
    _requireEmpty();
    _result = SimpleNode.ofLink(v);
    _state = _BuildState.scalar;
  }

  @override
  void assignNode(Node v) => copyNode(v, this);

  @override
  NodePrototype prototype() => const SimplePrototype();

  @override
  Node build() {
    if (_result == null) throw StateError('nothing assembled yet');
    return _result!;
  }

  @override
  void reset() {
    _result = null;
    _state = _BuildState.empty;
    _mapValues.clear();
    _listValues.clear();
  }
}

class _SimpleMapAssembler implements MapAssembler {
  _SimpleMapAssembler(this._parent);
  final SimpleNodeBuilder _parent;
  String? _pendingKey;
  SimpleNodeBuilder? _pendingKeyBuilder;
  SimpleNodeBuilder? _pendingValueBuilder;

  // Pushes the previous entry (if any) into the parent's map before
  // starting a new one -- entries only become final once a NEW entry
  // starts or finish() is called, matching the "assemble key, then value,
  // then loop" contract.
  void _flushPending() {
    if (_pendingKey != null && _pendingValueBuilder != null) {
      _parent._mapValues[_pendingKey!] = _pendingValueBuilder!.build();
    }
    _pendingKey = null;
    _pendingValueBuilder = null;
  }

  @override
  NodeAssembler assembleKey() {
    _flushPending();
    final keyBuilder = SimpleNodeBuilder();
    _pendingKeyBuilder = keyBuilder;
    return keyBuilder;
  }

  @override
  NodeAssembler assembleValue() {
    _pendingKey = _pendingKeyBuilder!.build().asString();
    final valueBuilder = SimpleNodeBuilder();
    _pendingValueBuilder = valueBuilder;
    return valueBuilder;
  }

  @override
  NodeAssembler assembleEntry(String k) {
    _flushPending();
    _pendingKey = k;
    final valueBuilder = SimpleNodeBuilder();
    _pendingValueBuilder = valueBuilder;
    return valueBuilder;
  }

  @override
  void finish() {
    _flushPending();
    _parent._result = SimpleNode.ofMap(Map.of(_parent._mapValues));
  }

  @override
  NodePrototype keyPrototype() => const SimplePrototype();

  @override
  NodePrototype valuePrototype(String k) => const SimplePrototype();
}

class _SimpleListAssembler implements ListAssembler {
  _SimpleListAssembler(this._parent);
  final SimpleNodeBuilder _parent;
  SimpleNodeBuilder? _pendingValueBuilder;

  void _flush() {
    if (_pendingValueBuilder != null) {
      _parent._listValues.add(_pendingValueBuilder!.build());
      _pendingValueBuilder = null;
    }
  }

  @override
  NodeAssembler assembleValue() {
    _flush();
    final builder = SimpleNodeBuilder();
    _pendingValueBuilder = builder;
    return builder;
  }

  @override
  void finish() {
    _flush();
    _parent._result = SimpleNode.ofList(List.of(_parent._listValues));
  }

  @override
  NodePrototype valuePrototype(int idx) => const SimplePrototype();
}
