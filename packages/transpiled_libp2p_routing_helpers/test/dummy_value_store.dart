// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Small in-memory ValueStore fixture for tests, in the spirit of
// go-libp2p-routing-helpers's own dummy_test.go dummyValueStore (not a
// port of it -- purpose-built for this port's own tests).
import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p_routing_helpers/transpiled_libp2p_routing_helpers.dart';

class DummyValueStore implements ValueStore, Bootstrap {
  final Map<String, Uint8List> _values = {};
  int bootstrapCalls = 0;

  @override
  Future<void> putValue(
    String key,
    Uint8List value, {
    List<RoutingOption> options = const [],
  }) async {
    _values[key] = value;
  }

  @override
  Future<Uint8List> getValue(
    String key, {
    List<RoutingOption> options = const [],
  }) async {
    final value = _values[key];
    if (value == null) throw const RoutingNotFoundException();
    return value;
  }

  @override
  Stream<Uint8List> searchValue(
    String key, {
    List<RoutingOption> options = const [],
  }) async* {
    final value = _values[key];
    if (value != null) yield value;
  }

  @override
  Future<void> bootstrap() async {
    bootstrapCalls++;
  }
}
