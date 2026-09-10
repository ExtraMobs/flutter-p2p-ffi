// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart'
    as core
    show getPublicKey;
import 'package:transpiled_libp2p_record/transpiled_libp2p_record.dart';

import 'bootstrap.dart';
import 'multi_error.dart';
import 'parallel.dart';

/// Legacy tiered router: reads run in order, writes and provider lookups fan out.
class Tiered implements Routing, PubKeyFetcher, Bootstrap {
  /// Creates a tiered router that reads [routers] in order.
  const Tiered({this.routers = const [], this.validator});

  /// Routers queried by this instance.
  final List<Routing> routers;

  /// Chooses the freshest value returned by [searchValue].
  final Validator? validator;
  Parallel get _parallel => Parallel(routers: routers, validator: validator);

  Future<T> _get<T>(Future<T> Function(Routing router) call) async {
    final errors = <Object>[];
    for (final router in routers) {
      try {
        return await call(router);
      } catch (error) {
        if (error is! RoutingNotFoundException &&
            error is! RoutingNotSupportedException) {
          errors.add(error);
        }
      }
    }
    final combined = combineErrors(errors);
    if (combined != null) throw combined;
    throw const RoutingNotFoundException();
  }

  @override
  Future<void> putValue(
    String key,
    Uint8List value, {
    List<RoutingOption> options = const [],
  }) => _parallel.putValue(key, value, options: options);
  @override
  Future<Uint8List> getValue(
    String key, {
    List<RoutingOption> options = const [],
  }) => _get((router) => router.getValue(key, options: options));
  @override
  Stream<Uint8List> searchValue(
    String key, {
    List<RoutingOption> options = const [],
  }) => _parallel.searchValue(key, options: options);
  @override
  Future<PubKey> getPublicKey(PeerId id) =>
      _get((router) => core.getPublicKey(router, id));
  @override
  Future<AddrInfo> findPeer(PeerId id) => _get((router) => router.findPeer(id));
  @override
  Future<void> provide(Cid cid, bool local) => _parallel.provide(cid, local);
  @override
  Stream<AddrInfo> findProvidersAsync(Cid cid, int count) =>
      _parallel.findProvidersAsync(cid, count);
  @override
  Future<void> bootstrap() => _parallel.bootstrap();

  /// Closes every nested router that implements [Closable].
  Future<void> close() => _parallel.close();
}
