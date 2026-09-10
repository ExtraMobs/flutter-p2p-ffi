// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/key.dart
//
// Port of go-datastore's key.go: `Key`, a hierarchical, filesystem-path-like
// object identifier.
import 'dart:convert';
import 'dart:math';

import 'path_clean.dart';
import 'query/query.dart';

/// A hierarchical, filesystem-path-like identifier of an object. Equivalent
/// to go-datastore's `Key`.
///
/// Keys are meant to be unique across a system, and can be `parent`s or
/// `child`ren of other keys: `Key('/Comedy')` is the parent of
/// `Key('/Comedy/MontyPython')`. Every namespace can optionally embed a
/// `type`, delimited by `:` -- e.g. `/Comedy/MontyPython/Actor:JohnCleese`.
class Key implements Comparable<Key> {
  /// Constructs a key from [s], cleaning it (equivalent to `path.Clean`)
  /// first. Equivalent to go-datastore's `NewKey`.
  factory Key(String s) {
    if (s.isEmpty) return const Key._('/');
    if (s.codeUnitAt(0) == 0x2F) return Key._(cleanPath(s));
    return Key._(cleanPath('/$s'));
  }

  /// Constructs a key from [s] WITHOUT cleaning it -- [s] must already
  /// start with `/` and, unless it's exactly `/`, must not end with `/`.
  /// Equivalent to go-datastore's `RawKey`, including its "panic on
  /// malformed input" contract (ported as [ArgumentError]).
  factory Key.raw(String s) {
    if (s.isEmpty) return const Key._('/');
    if (s.codeUnitAt(0) != 0x2F || (s.length > 1 && s.codeUnitAt(s.length - 1) == 0x2F)) {
      throw ArgumentError('invalid datastore key: $s');
    }
    return Key._(s);
  }

  /// Constructs a key by joining [namespaces] with `/`. Equivalent to
  /// go-datastore's `KeyWithNamespaces`.
  factory Key.withNamespaces(List<String> namespaces) => Key(namespaces.join('/'));

  /// Parses a key back out of [marshalJson]'s output. Equivalent to
  /// go-datastore's `Key.UnmarshalJSON`.
  ///
  /// Unlike Go (whose `*Key` receiver is left unchanged on error, an
  /// `encoding/json` idiom with no clean Dart equivalent for a factory
  /// constructor), this throws [FormatException] on invalid input.
  factory Key.unmarshalJson(List<int> data) {
    final decoded = json.decode(utf8.decode(data));
    if (decoded is! String) {
      throw const FormatException('expected a JSON string');
    }
    return Key(decoded);
  }

  const Key._(this._value);

  final String _value;

  /// The string value of this key. Equivalent to go-datastore's
  /// `Key.String`.
  String get value => _value;

  /// The raw bytes of [value].
  List<int> get bytes => utf8.encode(_value);

  /// Whether this key equals [other]. Equivalent to go-datastore's
  /// `Key.Equal`.
  bool equalTo(Key other) => _value == other._value;

  @override
  bool operator ==(Object other) => other is Key && _value == other._value;

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() => _value;

  /// Returns -1/0/1 as this key sorts lower/the same/higher than [other],
  /// comparing namespace-by-namespace. Equivalent to go-datastore's
  /// `Key.Compare`.
  @override
  int compareTo(Key other) {
    final list1 = namespaces;
    final list2 = other.namespaces;
    final list2end = list2.length - 1;
    for (var i = 0; i < list1.length; i++) {
      if (list2end < i) return 1;
      final c1 = list1[i];
      final c2 = list2[i];
      if (c1 != c2) return c1.compareTo(c2) < 0 ? -1 : 1;
    }
    if (list1.length < list2.length) return -1;
    return 0;
  }

  /// Whether this key sorts lower than [other]. Equivalent to
  /// go-datastore's `Key.Less`.
  bool less(Key other) => compareTo(other) == -1;

  /// The `list` representation of this key, e.g.
  /// `Key('/Comedy/MontyPython/Actor:JohnCleese').list` is
  /// `['Comedy', 'MontyPython', 'Actor:JohnCleese']`. Equivalent to
  /// go-datastore's `Key.List`.
  List<String> get list => _value.split('/').sublist(1);

  /// Alias for [list]. Equivalent to go-datastore's `Key.Namespaces`.
  List<String> get namespaces => list;

  /// The reverse of this key. Equivalent to go-datastore's `Key.Reverse`.
  Key get reverse => Key.withNamespaces(namespaces.reversed.toList());

  /// The "base" namespace of this key (the last one). Equivalent to
  /// go-datastore's `Key.BaseNamespace`.
  String get baseNamespace => namespaces.last;

  /// The "root" namespace of this key (the first one; `''` for the root
  /// key `/`). Equivalent to go-datastore's `Key.RootNamespace`.
  String get rootNamespace => namespaces.first;

  /// The "type" of this key (the part of [baseNamespace] before `:`, or
  /// `''` if it has no `:`). Equivalent to go-datastore's `Key.Type`.
  String get type => namespaceType(baseNamespace);

  /// The "name" of this key (the part of [baseNamespace] after the last
  /// `:`). Equivalent to go-datastore's `Key.Name`.
  String get name => namespaceValue(baseNamespace);

  /// An "instance" of this type key: appends `:` + [s] to this key's
  /// namespace. Equivalent to go-datastore's `Key.Instance`.
  Key instance(String s) => Key('$_value:$s');

  /// The "path" of this key (parent + type). Equivalent to go-datastore's
  /// `Key.Path`.
  Key get path => Key('${parent._value}/${namespaceType(baseNamespace)}');

  /// The parent key of this key. Equivalent to go-datastore's `Key.Parent`.
  Key get parent {
    final n = list;
    if (n.length == 1) return Key.raw('/');
    return Key(n.sublist(0, n.length - 1).join('/'));
  }

  /// The child key of this key, appending [other]. Equivalent to
  /// go-datastore's `Key.Child`.
  Key child(Key other) {
    if (_value == '/') return other;
    if (other._value == '/') return this;
    return Key.raw('$_value${other._value}');
  }

  /// The child key of this key, appending the raw string [s]. Equivalent
  /// to go-datastore's `Key.ChildString`.
  Key childString(String s) => Key('$_value/$s');

  /// Whether this key is a (strict) prefix of [other]. Equivalent to
  /// go-datastore's `Key.IsAncestorOf`.
  bool isAncestorOf(Key other) {
    if (other._value.length <= _value.length) return false;
    if (_value == '/') return true;
    return other._value[_value.length] == '/' &&
        other._value.startsWith(_value);
  }

  /// Whether [other] is a (strict) prefix of this key. Equivalent to
  /// go-datastore's `Key.IsDescendantOf`.
  bool isDescendantOf(Key other) => other.isAncestorOf(this);

  /// Whether this key has only one namespace. Equivalent to go-datastore's
  /// `Key.IsTopLevel`.
  bool get isTopLevel => list.length == 1;

  /// The JSON string representation of this key. Equivalent to
  /// go-datastore's `Key.MarshalJSON`.
  List<int> marshalJson() => utf8.encode(json.encode(_value));
}

/// A randomly generated key (32 random hex digits, the same shape as a
/// UUIDv4 with its dashes/version bits stripped). Equivalent to
/// go-datastore's `RandomKey`. Uses `dart:math`'s secure RNG rather than a
/// UUID library dependency -- the only property this needs is "practically
/// unique identifier", which a raw random hex string already gives.
Key randomKey() {
  final random = Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < 32; i++) {
    buffer.write(_hexDigits[random.nextInt(16)]);
  }
  return Key(buffer.toString());
}

const _hexDigits = '0123456789abcdef';

/// The first component of a namespace: `foo` in `foo:bar`. Equivalent to
/// go-datastore's `NamespaceType`.
String namespaceType(String namespace) {
  final parts = namespace.split(':');
  if (parts.length < 2) return '';
  return parts.sublist(0, parts.length - 1).join(':');
}

/// The last component of a namespace: `baz` in `f:b:baz`. Equivalent to
/// go-datastore's `NamespaceValue`.
String namespaceValue(String namespace) => namespace.split(':').last;

/// The keys of [entries]. Equivalent to go-datastore's `EntryKeys`.
List<Key> entryKeys(List<Entry> entries) => [for (final e in entries) Key(e.key)];
