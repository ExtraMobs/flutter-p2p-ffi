// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of go-ipld-prime/traversal/selector.
// ignore_for_file: duplicate_ignore, public_member_api_docs
library;

import 'dart:typed_data';

import '../../basicnode/scalars.dart';
import '../../basicnode/stream_bytes.dart';
import '../../datamodel/kind.dart';
import '../../datamodel/node.dart';
import '../../datamodel/errors.dart';
import '../../datamodel/path_segment.dart';

const selectorKeyMatcher = '.';
const selectorKeyExploreAll = 'a';
const selectorKeyExploreFields = 'f';
const selectorKeyExploreIndex = 'i';
const selectorKeyExploreRange = 'r';
const selectorKeyExploreRecursive = 'R';
const selectorKeyExploreUnion = '|';
const selectorKeyExploreConditional = '&';
const selectorKeyExploreRecursiveEdge = '@';
const selectorKeyExploreInterpretAs = '~';
const selectorKeyNext = '>';
const selectorKeyFields = 'f>';
const selectorKeyIndex = 'i';
const selectorKeyStart = '^';
const selectorKeyEnd = r'$';
const selectorKeySequence = ':>';
const selectorKeyLimit = 'l';
const selectorKeyLimitDepth = 'depth';
const selectorKeyLimitNone = 'none';
const selectorKeyStopAt = '!';
const selectorKeyCondition = '&';
const selectorKeyAs = 'as';
const selectorKeySubset = 'subset';
const selectorKeyFrom = '[';
const selectorKeyTo = ']';

abstract interface class Selector {
  /// `null` means all child segments; an empty list means none.
  List<PathSegment>? interests();
  Selector? explore(Node node, PathSegment child);
  bool decide(Node node);
  Node? match(Node node);
}

final class SelectorParseException implements Exception {
  SelectorParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

Never _bad(String message) =>
    throw SelectorParseException('selector spec parse rejected: $message');

final class Matcher implements Selector {
  const Matcher([this.slice]);
  final Slice? slice;
  @override
  List<PathSegment> interests() => const [];
  @override
  Selector? explore(Node node, PathSegment child) => null;
  @override
  bool decide(Node node) => true;
  @override
  Node? match(Node node) => slice?.apply(node) ?? node;
}

final class Slice {
  const Slice(this.from, this.to);
  final int from;
  final int to;

  Node? apply(Node node) {
    switch (node.kind()) {
      case Kind.string:
        final value = node.asString();
        final bounds = _bounds(value.length);
        return bounds == null
            ? null
            : PlainString(value.substring(bounds.$1, bounds.$2));
      case Kind.bytes:
        if (node is LargeBytesNode) {
          final reader = node.asLargeBytes();
          final length = reader.seek(0, SeekOrigin.end);
          reader.seek(0, SeekOrigin.start);
          final bounds = _bounds(length);
          if (bounds == null) return null;
          reader.seek(bounds.$1, SeekOrigin.start);
          final data = Uint8List(bounds.$2 - bounds.$1);
          var at = 0;
          while (at < data.length) {
            final n = reader.read(Uint8List.sublistView(data, at));
            if (n == 0) break;
            at += n;
          }
          return StreamBytes(_MemoryReader(data));
        }
        final value = node.asBytes();
        final bounds = _bounds(value.length);
        return bounds == null
            ? null
            : PlainBytes(
                Uint8List.fromList(value.sublist(bounds.$1, bounds.$2)),
              );
      default:
        return null;
    }
  }

  /// Go's `Slice.Slice`; [apply] is the idiomatic Dart spelling.
  Node? slice(Node node) => apply(node);

  (int, int)? _bounds(int length) {
    var end = to < 0 ? length + to : (to > length ? length : to);
    var start = from < 0 ? length + from : from;
    if (start < 0) start = 0;
    if (start > end || start >= length) return null;
    return (start, end);
  }
}

final class _MemoryReader implements ByteReadSeeker {
  _MemoryReader(this.data);
  final Uint8List data;
  int _offset = 0;
  @override
  int read(Uint8List buffer) {
    final n = (data.length - _offset).clamp(0, buffer.length);
    buffer.setRange(0, n, data, _offset);
    _offset += n;
    return n;
  }

  @override
  int seek(int offset, SeekOrigin origin) {
    _offset =
        (origin == SeekOrigin.start
                ? offset
                : origin == SeekOrigin.current
                ? _offset + offset
                : data.length + offset)
            .clamp(0, data.length);
    return _offset;
  }
}

final class ExploreAll implements Selector {
  const ExploreAll(this.next);
  final Selector next;
  @override
  List<PathSegment>? interests() => null;
  @override
  Selector explore(Node node, PathSegment child) => next;
  @override
  bool decide(Node node) => false;
  @override
  Node? match(Node node) => null;
}

final class ExploreFields implements Selector {
  ExploreFields(Map<String, Selector> selections)
    : selections = Map.unmodifiable(selections),
      _interests = selections.keys
          .map(PathSegment.ofString)
          .toList(growable: false);
  final Map<String, Selector> selections;
  final List<PathSegment> _interests;
  @override
  List<PathSegment> interests() => _interests;
  @override
  Selector? explore(Node node, PathSegment child) =>
      selections[child.toString()];
  @override
  bool decide(Node node) => false;
  @override
  Node? match(Node node) => null;
}

final class ExploreIndex implements Selector {
  const ExploreIndex(this.index, this.next);
  final int index;
  final Selector next;
  @override
  List<PathSegment> interests() => [PathSegment.ofInt(index)];
  @override
  Selector? explore(Node node, PathSegment child) {
    if (node.kind() != Kind.list) return null;
    try {
      return child.index() == index ? next : null;
    } on FormatException {
      return null;
    }
  }

  @override
  bool decide(Node node) => false;
  @override
  Node? match(Node node) => null;
}

final class ExploreRange implements Selector {
  ExploreRange(this.start, this.end, this.next)
    : _interests = [for (var i = start; i < end; i++) PathSegment.ofInt(i)];
  final int start, end;
  final Selector next;
  final List<PathSegment> _interests;
  @override
  List<PathSegment> interests() => _interests;
  @override
  Selector? explore(Node node, PathSegment child) {
    if (node.kind() != Kind.list) return null;
    try {
      final i = child.index();
      return i >= start && i < end ? next : null;
    } on FormatException {
      return null;
    }
  }

  @override
  bool decide(Node node) => false;
  @override
  Node? match(Node node) => null;
}

final class ExploreUnion implements Selector {
  const ExploreUnion(this.members);
  final List<Selector> members;
  @override
  List<PathSegment>? interests() {
    final result = <PathSegment>[];
    for (final member in members) {
      final interest = member.interests();
      if (interest == null) return null;
      result.addAll(interest);
    }
    return result;
  }

  @override
  Selector? explore(Node node, PathSegment child) {
    final found = [
      for (final member in members)
        if (member.explore(node, child) case final value?) value,
    ];
    return found.isEmpty
        ? null
        : found.length == 1
        ? found.single
        : ExploreUnion(found);
  }

  @override
  bool decide(Node node) => members.any((member) => member.decide(node));
  @override
  Node? match(Node node) {
    for (final member in members) {
      final value = member.match(node);
      if (value != null) return value;
    }
    return null;
  }
}

enum RecursionLimitMode { none, depth }

final class RecursionLimit {
  const RecursionLimit.depth(this.depth) : mode = RecursionLimitMode.depth;
  const RecursionLimit.none() : mode = RecursionLimitMode.none, depth = 0;
  final RecursionLimitMode mode;
  final int depth;
}

/// Equivalent to Go's `RecursionLimitDepth`.
RecursionLimit recursionLimitDepth(int depth) => RecursionLimit.depth(depth);

/// Equivalent to Go's `RecursionLimitNone`.
RecursionLimit recursionLimitNone() => const RecursionLimit.none();

final class ExploreRecursiveEdge implements Selector {
  const ExploreRecursiveEdge();
  @override
  List<PathSegment> interests() => const [];
  @override
  Selector? explore(Node node, PathSegment child) =>
      throw StateError('Traversed Explore Recursive Edge Node With No Parent');
  @override
  bool decide(Node node) => false;
  @override
  Node? match(Node node) => null;
}

final class Condition {
  const Condition.link(this.match);
  final Node match;
  bool applies(Node node) {
    if (node.kind() != Kind.link) return false;
    return node.asLink().toString() == match.asLink().toString();
  }
}

/// Feature detection for selectors which request ADL reification.
abstract interface class Reifiable {
  String get namedReifier;
}

final class ExploreRecursive implements Selector {
  const ExploreRecursive(
    this.sequence,
    this.current,
    this.limit, [
    this.stopAt,
  ]);
  final Selector sequence, current;
  final RecursionLimit limit;
  final Condition? stopAt;
  @override
  List<PathSegment>? interests() => current.interests();
  @override
  Selector? explore(Node node, PathSegment child) {
    if (stopAt != null && stopAt!.applies(node.lookupBySegment(child)))
      return null;
    if (current is ExploreRecursiveEdge) return null;
    final next = current.explore(node, child);
    if (next == null) return null;
    if (!_hasEdge(next)) return ExploreRecursive(sequence, next, limit, stopAt);
    if (limit.mode == RecursionLimitMode.depth) {
      if (limit.depth < 2) return _replaceEdge(next, null);
      return ExploreRecursive(
        sequence,
        _replaceEdge(next, sequence)!,
        RecursionLimit.depth(limit.depth - 1),
        stopAt,
      );
    }
    return ExploreRecursive(
      sequence,
      _replaceEdge(next, sequence)!,
      limit,
      stopAt,
    );
  }

  bool _hasEdge(Selector selector) =>
      selector is ExploreRecursiveEdge ||
      selector is ExploreUnion && selector.members.any(_hasEdge);
  Selector? _replaceEdge(Selector selector, Selector? replacement) {
    if (selector is ExploreRecursiveEdge) return replacement;
    if (selector is ExploreUnion) {
      final items = selector.members
          .map((e) => _replaceEdge(e, replacement))
          .whereType<Selector>()
          .toList();
      return items.isEmpty
          ? null
          : items.length == 1
          ? items.single
          : ExploreUnion(items);
    }
    return selector;
  }

  @override
  bool decide(Node node) => current.decide(node);
  @override
  Node? match(Node node) => current.match(node);
}

final class ExploreInterpretAs implements Selector, Reifiable {
  const ExploreInterpretAs(this.adl, this.next);
  final String adl;
  @override
  String get namedReifier => adl;
  final Selector next;
  @override
  List<PathSegment>? interests() => next.interests();
  @override
  Selector explore(Node node, PathSegment child) => next;
  @override
  bool decide(Node node) => false;
  @override
  Node? match(Node node) => null;
}

Selector compileSelector(Node node) => ParseContext().parseSelector(node);
Selector parseSelector(Node node) => compileSelector(node);

final class ParseContext {
  ParseContext([this._parents = const []]);
  final List<_RecursiveParseParent> _parents;
  ParseContext _push(_RecursiveParseParent parent) =>
      ParseContext([parent, ..._parents]);
  Selector parseSelector(Node node) {
    if (node.kind() != Kind.map)
      _bad('selector is a keyed union and thus must be a map');
    if (node.length() != 1)
      _bad('selector is a keyed union and thus must be single-entry map');
    final (key, value) = node.mapIterator()!.next();
    switch (key.asString()) {
      case selectorKeyMatcher:
        return parseMatcher(value);
      case selectorKeyExploreAll:
        return parseExploreAll(value);
      case selectorKeyExploreFields:
        return parseExploreFields(value);
      case selectorKeyExploreIndex:
        return parseExploreIndex(value);
      case selectorKeyExploreRange:
        return parseExploreRange(value);
      case selectorKeyExploreUnion:
        return parseExploreUnion(value);
      case selectorKeyExploreRecursive:
        return parseExploreRecursive(value);
      case selectorKeyExploreRecursiveEdge:
        return parseExploreRecursiveEdge(value);
      case selectorKeyExploreInterpretAs:
        return parseExploreInterpretAs(value);
      default:
        _bad('"${key.asString()}" is not a known member of the selector union');
    }
  }

  void _map(Node node, String message) {
    if (node.kind() != Kind.map) _bad(message);
  }

  Node _field(Node node, String key, String message) {
    try {
      return node.lookupByString(key);
    } catch (_) {
      _bad(message);
    }
  }

  Matcher parseMatcher(Node node) {
    _map(node, 'selector body must be a map');
    try {
      final subset = node.lookupByString(selectorKeySubset);
      _map(subset, 'subset body must be a map');
      final from = _field(
        subset,
        selectorKeyFrom,
        "selector body must be a map with a from '[' key",
      );
      final to = _field(
        subset,
        selectorKeyTo,
        "selector body must be a map with a to ']' key",
      );
      final a = from.asInt();
      final b = to.asInt();
      if (b >= 0 && a > b)
        _bad(
          "selector body must be a map with a 'from' key that is less than or equal to the 'to' key",
        );
      return Matcher(Slice(a, b));
    } catch (e) {
      if (e is SelectorParseException) rethrow;
      return const Matcher();
    }
  }

  ExploreAll parseExploreAll(Node node) {
    _map(node, 'selector body must be a map');
    return ExploreAll(
      parseSelector(
        _field(
          node,
          selectorKeyNext,
          'next field must be present in ExploreAll selector',
        ),
      ),
    );
  }

  ExploreFields parseExploreFields(Node node) {
    _map(node, 'selector body must be a map');
    final fields = _field(
      node,
      selectorKeyFields,
      'fields in ExploreFields selector must be present',
    );
    _map(fields, 'fields in ExploreFields selector must be a map');
    final values = <String, Selector>{};
    final it = fields.mapIterator()!;
    while (!it.done()) {
      final (key, value) = it.next();
      values[key.asString()] = parseSelector(value);
    }
    return ExploreFields(values);
  }

  ExploreIndex parseExploreIndex(Node node) {
    _map(node, 'selector body must be a map');
    final index = _field(
      node,
      selectorKeyIndex,
      'index field must be present in ExploreIndex selector',
    );
    int value;
    try {
      value = index.asInt();
    } catch (_) {
      _bad('index field must be a number in ExploreIndex selector');
    }
    return ExploreIndex(
      value,
      parseSelector(
        _field(
          node,
          selectorKeyNext,
          'next field must be present in ExploreIndex selector',
        ),
      ),
    );
  }

  ExploreRange parseExploreRange(Node node) {
    _map(node, 'selector body must be a map');
    int number(String key, String absent) {
      final n = _field(node, key, absent);
      try {
        return n.asInt();
      } catch (_) {
        _bad('$key field must be a number in ExploreRange selector');
      }
    }

    final start = number(
      selectorKeyStart,
      'start field must be present in ExploreRange selector',
    );
    final end = number(
      selectorKeyEnd,
      'end field must be present in ExploreRange selector',
    );
    if (start >= end)
      _bad(
        'end field must be greater than start field in ExploreRange selector',
      );
    return ExploreRange(
      start,
      end,
      parseSelector(
        _field(
          node,
          selectorKeyNext,
          'next field must be present in ExploreRange selector',
        ),
      ),
    );
  }

  ExploreUnion parseExploreUnion(Node node) {
    if (node.kind() != Kind.list) _bad('explore union selector must be a list');
    final result = <Selector>[];
    final it = node.listIterator()!;
    while (!it.done()) {
      result.add(parseSelector(it.next().$2));
    }
    return ExploreUnion(result);
  }

  ExploreRecursiveEdge parseExploreRecursiveEdge(Node node) {
    _map(node, 'selector body must be a map');
    if (_parents.isEmpty)
      _bad('ExploreRecursiveEdge must be beneath ExploreRecursive');
    _parents.first.edges++;
    return const ExploreRecursiveEdge();
  }

  ExploreRecursive parseExploreRecursive(Node node) {
    _map(node, 'selector body must be a map');
    final limit = _parseLimit(
      _field(
        node,
        selectorKeyLimit,
        'limit field must be present in ExploreRecursive selector',
      ),
    );
    final parent = _RecursiveParseParent();
    final sequence = _push(parent).parseSelector(
      _field(
        node,
        selectorKeySequence,
        'sequence field must be present in ExploreRecursive selector',
      ),
    );
    if (parent.edges == 0)
      _bad('ExploreRecursive must have at least one ExploreRecursiveEdge');
    Condition? condition;
    try {
      final stop = node.lookupByString(selectorKeyStopAt);
      condition = parseCondition(stop);
    } on Object catch (error) {
      if (error is! NotExistsException) rethrow;
    }
    return ExploreRecursive(sequence, sequence, limit, condition);
  }

  RecursionLimit _parseLimit(Node node) {
    _map(
      node,
      'limit in ExploreRecursive is a keyed union and thus must be a map',
    );
    if (node.length() != 1)
      _bad(
        'limit in ExploreRecursive is a keyed union and thus must be a single-entry map',
      );
    final (key, value) = node.mapIterator()!.next();
    if (key.asString() == selectorKeyLimitNone)
      return const RecursionLimit.none();
    if (key.asString() == selectorKeyLimitDepth) {
      try {
        return RecursionLimit.depth(value.asInt());
      } catch (_) {
        _bad(
          'limit field of type depth must be a number in ExploreRecursive selector',
        );
      }
    }
    _bad(
      '"${key.asString()}" is not a known member of the limit union in ExploreRecursive',
    );
  }

  ExploreInterpretAs parseExploreInterpretAs(Node node) {
    _map(node, 'selector body must be a map');
    final adl = _field(
      node,
      selectorKeyAs,
      "the 'as' field must be present in ExploreInterpretAs clause",
    );
    String value;
    try {
      value = adl.asString();
    } catch (_) {
      rethrow;
    }
    return ExploreInterpretAs(
      value,
      parseSelector(
        _field(
          node,
          selectorKeyNext,
          "the 'next' field must be present in ExploreInterpretAs clause",
        ),
      ),
    );
  }

  Condition parseCondition(Node node) {
    _map(node, 'condition body must be a map');
    if (node.length() != 1)
      _bad('condition is a keyed union and thus must be single-entry map');
    final (key, value) = node.mapIterator()!.next();
    if (key.asString() != '/')
      _bad('"${key.asString()}" is not a known member of the condition union');
    if (value.kind() != Kind.link) _bad('condition_link must be a link');
    return Condition.link(value);
  }
}

final class _RecursiveParseParent {
  int edges = 0;
}

abstract interface class SegmentIterator {
  factory SegmentIterator(Node node) => node.kind() == Kind.list
      ? _ListSegmentIterator(node.listIterator()!)
      : _MapSegmentIterator(node.mapIterator()!);

  bool get done;
  (PathSegment, Node) next();
}

final class _ListSegmentIterator implements SegmentIterator {
  _ListSegmentIterator(this._iterator);
  final ListIterator _iterator;
  @override
  bool get done => _iterator.done();
  @override
  (PathSegment, Node) next() {
    final pair = _iterator.next();
    return (PathSegment.ofInt(pair.$1), pair.$2);
  }
}

final class _MapSegmentIterator implements SegmentIterator {
  _MapSegmentIterator(this._iterator);
  final MapIterator _iterator;
  @override
  bool get done => _iterator.done();
  @override
  (PathSegment, Node) next() {
    final pair = _iterator.next();
    return (PathSegment.ofString(pair.$1.asString()), pair.$2);
  }
}
