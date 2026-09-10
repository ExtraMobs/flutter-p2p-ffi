// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/limited_value_store.dart
//
// Port of go-libp2p-routing-helpers's limited.go: restricts an underlying
// ValueStore to a fixed set of key namespaces.
import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart'
    as core_routing
    show getPublicKey;

import 'bootstrap.dart';

/// Limits an underlying [ValueStore] to a fixed set of key [namespaces]
/// (the `$namespace` in a `/$namespace/$path` key). Equivalent to
/// go-libp2p-routing-helpers's `LimitedValueStore`.
class LimitedValueStore implements ValueStore, PubKeyFetcher, Bootstrap {
  /// Wraps [valueStore], limiting it to [namespaces].
  const LimitedValueStore({required this.valueStore, required this.namespaces});

  /// The underlying value store.
  final ValueStore valueStore;

  /// The key namespaces this store supports.
  final List<String> namespaces;

  /// Whether [key] (a `/$namespace/$path` string) falls under one of
  /// [namespaces]. Equivalent to go-libp2p-routing-helpers's
  /// `LimitedValueStore.KeySupported`.
  bool keySupported(String key) {
    if (key.length < 3 || key[0] != '/') return false;
    final rest = key.substring(1);
    for (final ns in namespaces) {
      if (ns.length < rest.length &&
          rest.startsWith(ns) &&
          rest[ns.length] == '/') {
        return true;
      }
    }
    return false;
  }

  @override
  Future<PubKey> getPublicKey(PeerId id) async {
    if (namespaces.contains('pk')) {
      return core_routing.getPublicKey(valueStore, id);
    }
    throw const RoutingNotFoundException();
  }

  @override
  Future<void> putValue(
    String key,
    Uint8List value, {
    List<RoutingOption> options = const [],
  }) async {
    if (!keySupported(key)) throw const RoutingNotSupportedException();
    return valueStore.putValue(key, value, options: options);
  }

  @override
  Future<Uint8List> getValue(
    String key, {
    List<RoutingOption> options = const [],
  }) async {
    if (!keySupported(key)) throw const RoutingNotFoundException();
    return valueStore.getValue(key, options: options);
  }

  @override
  Stream<Uint8List> searchValue(
    String key, {
    List<RoutingOption> options = const [],
  }) {
    if (!keySupported(key)) return const Stream.empty();
    return valueStore.searchValue(key, options: options);
  }

  @override
  Future<void> bootstrap() async {
    final store = valueStore;
    if (store is Bootstrap) {
      await (store as Bootstrap).bootstrap();
    }
  }
}
