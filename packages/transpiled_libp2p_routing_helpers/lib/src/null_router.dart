// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/null_router.dart
//
// Port of go-libp2p-routing-helpers's null.go. Named NullRouter rather
// than the Go name (`Null`), which collides with Dart's own `Null` type.
import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

import 'bootstrap.dart';

/// A router that doesn't do anything. Equivalent to
/// go-libp2p-routing-helpers's `Null`.
class NullRouter implements Routing, Bootstrap {
  /// Creates the router.
  const NullRouter();

  @override
  Future<void> putValue(
    String key,
    Uint8List value, {
    List<RoutingOption> options = const [],
  }) async => throw const RoutingNotSupportedException();

  @override
  Future<Uint8List> getValue(
    String key, {
    List<RoutingOption> options = const [],
  }) async => throw const RoutingNotFoundException();

  @override
  Stream<Uint8List> searchValue(
    String key, {
    List<RoutingOption> options = const [],
  }) => Stream.error(const RoutingNotFoundException());

  @override
  Future<void> provide(Cid cid, bool local) async =>
      throw const RoutingNotSupportedException();

  @override
  Stream<AddrInfo> findProvidersAsync(Cid cid, int count) =>
      const Stream.empty();

  @override
  Future<AddrInfo> findPeer(PeerId id) async =>
      throw const RoutingNotFoundException();

  @override
  Future<void> bootstrap() async {}
}
